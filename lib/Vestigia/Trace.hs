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
-- address computed from it (`address`), or a system call handed
-- it (`syscall`). Every other uninitialised read is kept apart as
-- `unrelated`, and memory errors as `faults`: neither says
-- anything about the secret. Leak reports say nothing about the
-- execution and are dropped.

module Vestigia.Trace (
    Class(..)
  , Site(..)
  , Trace(..)
  , trace
  , traceJson
  , traceSummary
  , classText
  ) where

import qualified Data.List as L
import qualified Data.Map.Strict as M
import qualified Data.Text as T
import Numeric (showHex)

import Vestigia.Json
import Vestigia.Memcheck

-- | How an execution depended on a secret at a site.
data Class =
    Control
  | Address
  | Syscall
  deriving (Eq, Ord, Show)

-- | One instruction that depended on a secret, with every stack
--   that reached it.
data Site = Site {
    siClass :: !Class
  , siFrame :: !Frame
  , siCount :: !Int
  , siStacks :: ![[Frame]]
  } deriving (Eq, Show)

-- | A run's sites, in the order first reported, and what memcheck
--   reported that says nothing about the secret.
data Trace = Trace {
    trRun :: !Memcheck
  , trSites :: ![Site]
  , trUnrelated :: ![MemError]
  , trFaults :: ![MemError]
  } deriving (Eq, Show)

classText :: Class -> T.Text
classText c = case c of
  Control -> "control"
  Address -> "address"
  Syscall -> "syscall"

-- what a secret-originated error says about the execution
classify :: MemError -> Maybe Class
classify e = case (meOrigin e, meKind e) of
  (ClientRequest _, "UninitCondition") -> Just Control
  (ClientRequest _, "UninitValue") -> Just Address
  (ClientRequest _, "SyscallParam") -> Just Syscall
  _ -> Nothing

uninitialised :: MemError -> Bool
uninitialised e =
  meKind e `elem` [ "UninitCondition", "UninitValue", "SyscallParam" ]

-- | The run's leakage. Sites are one per instruction and class:
--   memcheck reports one context per distinct stack, and the
--   instruction is what depended on the secret, whatever called
--   it.
trace :: Memcheck -> Trace
trace mc = Trace {
    trRun = mc
  , trSites =
      [ Site {
            siClass = c
          , siFrame = top
          , siCount = sum (fmap (meCount . snd) xs)
          , siStacks = L.nub (fmap (meStack . snd) xs)
          }
      | k@(c, _) <- order
      , Just xs@((top, _) : _) <- [ M.lookup k grouped ] ]
  , trUnrelated =
      [ e | e <- mcErrors mc, uninitialised e
          , classify e == Nothing ]
  , trFaults =
      [ e | e <- mcErrors mc, not (uninitialised e)
          , not ("Leak_" `T.isPrefixOf` meKind e) ]
  }
  where
    tagged =
      [ ((c, top), e)
      | e <- mcErrors mc
      , Just c <- [ classify e ]
      , (top : _) <- [ meStack e ] ]
    order = L.nub (fmap (\((c, top), _) -> (c, frIp top)) tagged)
    grouped = M.fromListWith (flip (<>))
      [ ((c, frIp top), [ (top, e) ]) | ((c, top), e) <- tagged ]

-- | The report: @vestigia/trace-v1@.
traceJson :: T.Text -> Maybe Int -> Trace -> Value
traceJson version exit tr = Object
  [ ("schema", String "vestigia/trace-v1")
  , ("tool", Object [ ("name", String "vestigia")
                    , ("version", String version) ])
  , ("valgrind", maybe Null String (mcVersion mc))
  , ("command", Array (fmap String (mcCommand mc)))
  , ("finished", Bool (mcFinished mc))
  , ("exit", maybe Null (Number . toInteger) exit)
  , ("summary", Object
      [ ("control", count Control)
      , ("address", count Address)
      , ("syscall", count Syscall)
      , ("unrelated", Number (toInteger (length (trUnrelated tr))))
      , ("faults", Number (toInteger (length (trFaults tr))))
      ])
  , ("sites", Array (fmap siteJson (trSites tr)))
  , ("unrelated", Array (fmap errorJson (trUnrelated tr)))
  , ("faults", Array (fmap errorJson (trFaults tr)))
  ]
  where
    mc = trRun tr
    count c = Number (toInteger (length
      [ () | s <- trSites tr, siClass s == c ]))

siteJson :: Site -> Value
siteJson s = Object $
  [ ("class", String (classText (siClass s))) ]
  <> frameFields (siFrame s)
  <> [ ("count", Number (toInteger (siCount s)))
     , ("stacks", Array [ Array (fmap frameJson st)
                        | st <- siStacks s ])
     ]

errorJson :: MemError -> Value
errorJson e = Object
  [ ("kind", String (meKind e))
  , ("what", String (meWhat e))
  , ("origin", case meOrigin e of
      ClientRequest _ -> String "client request"
      OtherOrigin w _ -> String w
      NoOrigin -> Null)
  , ("count", Number (toInteger (meCount e)))
  , ("stack", Array (fmap frameJson (meStack e)))
  ]

frameJson :: Frame -> Value
frameJson = Object . frameFields

frameFields :: Frame -> [(T.Text, Value)]
frameFields f =
  [ ("ip", String (hex (frIp f)))
  , ("object", maybe Null String (frObj f))
  , ("function", maybe Null String (frFn f))
  , ("file", maybe Null String (frFile f))
  , ("line", maybe Null (Number . toInteger) (frLine f))
  ]

hex :: Integer -> T.Text
hex n = "0x" <> T.pack (showHex n "")

-- | One line per site, for a reader at a terminal.
traceSummary :: Trace -> T.Text
traceSummary tr = T.unlines $
  [ T.intercalate "  "
      [ classText (siClass s)
      , hex (frIp (siFrame s))
      , maybe "?" id (frFn (siFrame s))
      , location (siFrame s)
      , "x" <> T.pack (show (siCount s)) ]
  | s <- trSites tr ]
  <> [ T.pack (show (length (trSites tr))) <> " secret-dependent \
       \site(s); " <> T.pack (show (length (trUnrelated tr)))
       <> " unrelated; " <> T.pack (show (length (trFaults tr)))
       <> " fault(s)" ]
  where
    location f = case (frFile f, frLine f) of
      (Just p, Just l) -> base p <> ":" <> T.pack (show l)
      (Just p, Nothing) -> base p
      _ -> maybe "?" id (frObj f)
    base p = last' p (T.splitOn "/" p)
    last' d xs = case reverse xs of
      (x : _) -> x
      [] -> d
