{-# OPTIONS_HADDOCK prune #-}
{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module: Vestigia.Trace
-- Copyright: (c) 2026 Jared Tobin
-- License: MIT
-- Maintainer: Jared Tobin <jared@ppad.tech>
--
-- A run's leakage, read from what memcheck reported. An error
-- whose undefined value was created by a client request descends
-- from a byte the harness marked secret, so it is a site where the
-- execution depended on the secret: a branch (`control`), an
-- address computed from it (`address`), an integer division's
-- operand (`operand`, from vestigia's patched memcheck), or a
-- system call handed it (`syscall`). Every other uninitialised read
-- is kept apart as `unrelated`, and memory errors as `faults`:
-- neither says anything about the secret. Leak reports say nothing
-- about the execution and are dropped.
--
-- memcheck sees the path a run took, so runs of one harness on
-- several secrets are read together: a site is one instruction and
-- class however many runs reached it, with the runs that did. Where
-- a run's objects are known, a site is named by its address in its
-- object, so runs that loaded an object apart still agree on it.

module Vestigia.Trace (
    Class(..)
  , Taint(..)
  , Located(..)
  , Site(..)
  , Trace(..)
  , trace
  , sitesIn
  , readObjects
  , resolveObjects
  , objectOffset
  , traceJson
  , traceSummary
  , classText
  ) where

import Control.Exception (IOException, try)
import qualified Data.List as L
import qualified Data.Map.Strict as M
import qualified Data.Text as T
import Numeric (readHex, showHex)
import System.Directory (canonicalizePath, doesPathExist)

import Vestigia.Json
import Vestigia.Memcheck

-- | How an execution depended on a secret at a site.
data Class =
    Control
  | Address
  | Operand
  | Syscall
  deriving (Eq, Ord, Show)

-- | One run under memcheck: its name, what memcheck reported, where
--   the harness's loader put each object (its load bias and path,
--   as the harness reported them; none for a report made
--   elsewhere), and the harness's exit status, where known.
data Taint = Taint {
    tnName :: !T.Text
  , tnMemcheck :: !Memcheck
  , tnObjects :: ![(Integer, T.Text)]
  , tnExit :: !(Maybe Int)
  } deriving (Eq, Show)

-- | A frame, with its address in its object where its run's objects
--   say.
data Located = Located {
    lcFrame :: !Frame
  , lcOffset :: !(Maybe Integer)
  } deriving (Eq, Show)

-- | One instruction that depended on a secret: where, as the first
--   run to reach it saw it; how many times, over every run; the runs
--   that reached it, as indices into the runs; and every stack that
--   did.
data Site = Site {
    siClass :: !Class
  , siAt :: !Located
  , siCount :: !Int
  , siRuns :: ![Int]
  , siStacks :: ![[Located]]
  } deriving (Eq, Show)

-- | Runs' sites, in the order first reported, and what memcheck
--   reported that says nothing about the secret, each with the
--   index of the run that reported it.
data Trace = Trace {
    trRuns :: ![Taint]
  , trSites :: ![Site]
  , trUnrelated :: ![(Int, MemError)]
  , trFaults :: ![(Int, MemError)]
  } deriving (Eq, Show)

classText :: Class -> T.Text
classText c = case c of
  Control -> "control"
  Address -> "address"
  Operand -> "operand"
  Syscall -> "syscall"

-- what a secret-originated error says about the execution
classify :: MemError -> Maybe Class
classify e = case (meOrigin e, meKind e) of
  (ClientRequest _, "UninitCondition") -> Just Control
  (ClientRequest _, "UninitValue") -> Just Address
  (ClientRequest _, "UninitOperand") -> Just Operand
  (ClientRequest _, "SyscallParam") -> Just Syscall
  _ -> Nothing

uninitialised :: MemError -> Bool
uninitialised e = meKind e `elem`
  [ "UninitCondition", "UninitValue", "UninitOperand", "SyscallParam" ]

-- | The runs' leakage. Sites are one per instruction and class:
--   memcheck reports one context per distinct stack, and the
--   instruction is what depended on the secret, whatever called it
--   and in whichever run.
trace :: [Taint] -> Trace
trace ts = Trace {
    trRuns = ts
  , trSites =
      [ Site {
            siClass = c
          , siAt = at
          , siCount = sum [ meCount e | (_, e, _) <- xs ]
          , siRuns = L.nub [ k | (k, _, _) <- xs ]
          , siStacks = L.nubBy (\a b -> fmap ident a == fmap ident b)
              [ st | (_, _, st) <- xs ]
          }
      | key@(c, _) <- L.nub (fmap fst tagged)
      , Just xs@((_, _, at : _) : _) <- [ M.lookup key grouped ] ]
  , trUnrelated =
      [ (k, e) | (k, t) <- runs, e <- mcErrors (tnMemcheck t)
               , uninitialised e, classify e == Nothing ]
  , trFaults =
      [ (k, e) | (k, t) <- runs, e <- mcErrors (tnMemcheck t)
               , not (uninitialised e)
               , not ("Leak_" `T.isPrefixOf` meKind e) ]
  }
  where
    runs = zip [ 0 .. ] ts
    tagged =
      [ ((c, ident top), (k, e, st))
      | (k, t) <- runs
      , e <- mcErrors (tnMemcheck t)
      , Just c <- [ classify e ]
      , let st = fmap (locate (tnObjects t)) (meStack e)
      , (top : _) <- [ st ] ]
    grouped = M.fromListWith (flip (<>))
      [ (key, [ v ]) | (key, v) <- tagged ]
    -- an instruction is its address in its object where that is
    -- known, else its address in the run
    ident (Located f off) =
      ( frObj f, maybe (Left (frIp f)) Right off, frFn f, frFile f
      , frLine f )

locate :: [(Integer, T.Text)] -> Frame -> Located
locate os f = Located f (objectOffset os f)

-- | Only the sites in objects whose path contains one of the given
--   texts, as a differential run keeps its origins; every site when
--   none is given.
sitesIn :: [T.Text] -> Trace -> Trace
sitesIn ts tr
  | null ts = tr
  | otherwise = tr { trSites = filter inside (trSites tr) }
  where
    inside s = case frObj (lcFrame (siAt s)) of
      Just o -> any (`T.isInfixOf` o) ts
      Nothing -> False

-- | The objects file the harness's first mark writes: a load bias
--   (hex) and a path per line.
--
-- >>> readObjects "7f0000 /lib/libc.so.6\n400000 /bin/harness\n"
-- Right [(8323072,"/lib/libc.so.6"),(4194304,"/bin/harness")]
readObjects :: T.Text -> Either String [(Integer, T.Text)]
readObjects = traverse line . filter (not . T.null . T.strip) . T.lines
  where
    line l = case T.breakOn " " l of
      (b, p) | not (T.null p)
             , [ (v, "") ] <- readHex (T.unpack b) ->
          Right (v, T.drop 1 p)
      _ -> Left ("an unreadable object line: " <> T.unpack l)

-- | A frame's address in its object, where the harness reported the
--   object: by its path, else by its file name.
-- | A run's objects, each path resolved to the file it names, as
--   memcheck names a frame's object: a loader reaches a library by
--   the link its soname names, memcheck by the file the link leads
--   to. A path that names nothing here, as in a report made
--   elsewhere, is kept as reported.
resolveObjects :: [(Integer, T.Text)] -> IO [(Integer, T.Text)]
resolveObjects = traverse resolve
  where
    resolve (b, p) = do
      let path = T.unpack p
      here <- doesPathExist path
      if not here then pure (b, p) else do
        r <- try (canonicalizePath path)
        pure (b, either (keep p) T.pack r)
    keep :: T.Text -> IOException -> T.Text
    keep p _ = p

objectOffset :: [(Integer, T.Text)] -> Frame -> Maybe Integer
objectOffset os f = do
  obj <- frObj f
  base <- case [ b | (b, p) <- os, p == obj ] of
    (b : _) -> Just b
    [] -> case [ b | (b, p) <- os, fileName p == fileName obj ] of
      (b : _) -> Just b
      [] -> Nothing
  if frIp f >= base then Just (frIp f - base) else Nothing
  where
    fileName p = case reverse (T.splitOn "/" p) of
      (x : _) -> x
      [] -> p

-- | The report: @vestigia/trace-v2@.
traceJson :: T.Text -> Trace -> Value
traceJson version tr = Object
  [ ("schema", String "vestigia/trace-v2")
  , ("tool", Object [ ("name", String "vestigia")
                    , ("version", String version) ])
  , ("runs", Array
      [ Object
          [ ("name", String (tnName t))
          , ("valgrind", maybe Null String (mcVersion mc))
          , ("command", Array (fmap String (mcCommand mc)))
          , ("finished", Bool (mcFinished mc))
          , ("exit", maybe Null (Number . toInteger) (tnExit t))
          , ("objects", Array
              [ Object [ ("base", String (hex b)), ("path", String p) ]
              | (b, p) <- tnObjects t ])
          ]
      | t <- trRuns tr, let mc = tnMemcheck t ])
  , ("summary", Object
      [ ("control", count Control)
      , ("address", count Address)
      , ("operand", count Operand)
      , ("syscall", count Syscall)
      , ("unrelated", Number (toInteger (length (trUnrelated tr))))
      , ("faults", Number (toInteger (length (trFaults tr))))
      ])
  , ("sites", Array (fmap siteJson (trSites tr)))
  , ("unrelated", Array (fmap errorJson (trUnrelated tr)))
  , ("faults", Array (fmap errorJson (trFaults tr)))
  ]
  where
    count c = Number (toInteger (length
      [ () | s <- trSites tr, siClass s == c ]))
    name k = case drop k (trRuns tr) of
      (t : _) -> String (tnName t)
      [] -> String (T.pack (show k))
    objectsOf k = case drop k (trRuns tr) of
      (t : _) -> tnObjects t
      [] -> []
    siteJson s = Object $
      [ ("class", String (classText (siClass s))) ]
      <> locatedFields (siAt s)
      <> [ ("count", Number (toInteger (siCount s)))
         , ("runs", Array (fmap name (siRuns s)))
         , ("stacks", Array [ Array (fmap (Object . locatedFields) st)
                            | st <- siStacks s ])
         ]
    errorJson (k, e) = Object
      [ ("run", name k)
      , ("kind", String (meKind e))
      , ("what", String (meWhat e))
      , ("origin", case meOrigin e of
          ClientRequest _ -> String "client request"
          OtherOrigin w _ -> String w
          NoOrigin -> Null)
      , ("count", Number (toInteger (meCount e)))
      , ("stack", Array (fmap (Object . locatedFields
                                . locate (objectsOf k)) (meStack e)))
      ]

locatedFields :: Located -> [(T.Text, Value)]
locatedFields (Located f off) =
  [ ("ip", String (hex (frIp f)))
  , ("object", maybe Null String (frObj f))
  , ("offset", maybe Null (String . hex) off)
  , ("function", maybe Null String (frFn f))
  , ("file", maybe Null String (frFile f))
  , ("line", maybe Null (Number . toInteger) (frLine f))
  ]

hex :: Integer -> T.Text
hex n = "0x" <> T.pack (showHex n "")

-- | One line per site, for a reader at a terminal: with how many runs
--   reached it, where there were several.
traceSummary :: Trace -> T.Text
traceSummary tr = T.unlines $
  [ T.intercalate "  " $
      [ classText (siClass s)
      , hex (frIp f)
      , maybe "?" id (frFn f)
      , location f
      , "x" <> T.pack (show (siCount s)) ]
      <> [ T.pack (show (length (siRuns s))) <> "/"
             <> T.pack (show runs) <> " runs"
         | runs > 1 ]
  | s <- trSites tr, let f = lcFrame (siAt s) ]
  <> [ T.pack (show (length (trSites tr))) <> " secret-dependent \
       \site(s) over " <> T.pack (show runs) <> " run(s); "
       <> T.pack (show (length (trUnrelated tr)))
       <> " unrelated; " <> T.pack (show (length (trFaults tr)))
       <> " fault(s)" ]
  where
    runs = length (trRuns tr)
    location f = case (frFile f, frLine f) of
      (Just p, Just l) -> base p <> ":" <> T.pack (show l)
      (Just p, Nothing) -> base p
      _ -> maybe "?" id (frObj f)
    base p = last' p (T.splitOn "/" p)
    last' d xs = case reverse xs of
      (x : _) -> x
      [] -> d
