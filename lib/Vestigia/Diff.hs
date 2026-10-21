{-# OPTIONS_HADDOCK prune #-}
{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module: Vestigia.Diff
-- Copyright: (c) 2026 Jared Tobin
-- License: MIT
-- Maintainer: Jared Tobin <jared@ppad.tech>
--
-- Where runs that differ only in a secret differ. Each run is a
-- leakage trace summarised per instruction (the QEMU plugin's
-- dump): how often each instruction ran, how often it transferred
-- to each target, and a fingerprint of the addresses it touched.
--
-- A branch whose outcome did not depend on the secret takes each
-- of its transfers in the same proportion however often it runs; a
-- branch whose outcomes differ in proportion between runs had its
-- own condition depend on the secret, and is a `control` origin
-- (a loop whose trip count the secret sets is one, though it also
-- runs a different number of times). So is a branch run as often,
-- taking each transfer as often, in another order: the plugin keeps
-- an order-sensitive fingerprint of what followed each instruction.
-- An instruction run equally often in every run whose addresses
-- differ computed one from the secret: an `address` origin. Every
-- other instruction run a different number of times sits where
-- control had already diverged: it is downstream.
--
-- Unlike memcheck's taint, this sees what control flow does to
-- data as well as what data does: a value chosen by a secret
-- branch and then used as an index differs between runs, though
-- no undefined bit ever reached it. It sees only what the chosen
-- secrets actually varied.
--
-- A difference means the secret only if nothing else differs
-- between runs. Controls are runs repeating the first run's secret:
-- an instruction that differs between the first run and a control
-- differs without the secret (an entropy source, a clock) and is
-- `unsteady`, counted and excluded from the origins.
--
-- Runs designed to reach a particular path are compared beside these
-- but not alike: they differ from the others in where they go, not
-- only in the secret, so an instruction's addresses differing in one
-- of them says nothing about the secret. A designed run counts toward
-- the control origins (a branch whose outcomes shift under it chose
-- by the secret) and what was executed, never toward the address
-- origins, which only runs alike in all but the secret can show.
--
-- What every run executed, per object, is reported beside: the
-- instructions the chosen secrets exercised, and so, against what
-- a function could execute, the part of it the comparison saw.
--
-- Each origin names how the runs behaved there: the runs alike at
-- it, grouped (taking each transfer in the same proportion, at a
-- control origin; touching the same addresses, at an address
-- origin), and the runs that never reached it. Whether two runs
-- that differed there both had their secrets accepted is the
-- reader's to say, from what each run returned.

module Vestigia.Diff (
    Insn(..)
  , Dump(..)
  , readDump
  , Origin(..)
  , Divergence(..)
  , diffDumps
  , diffControlled
  , diffDesigned
  , restrictTo
  , loadBases
  , layoutApart
  , divergenceJson
  , divergenceSummary
  ) where

import qualified Data.List as L
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import qualified Data.Text as T
import Numeric (readHex, showHex)

import Vestigia.Json
import Vestigia.Symbol (Place(..))

-- | One instruction of a run: its run-time address, and its object
--   and address there, where the object's program headers place it.
data Insn = Insn {
    inPc :: !Integer
  , inCount :: !Integer
  , inAccesses :: !Integer
  , inFingerprint :: !T.Text
    -- | what followed it, in order, fingerprinted
  , inOrder :: !T.Text
  , inObject :: !(Maybe T.Text)
  , inOffset :: !Integer
  } deriving (Eq, Show)

-- | One run: its instructions by address, and its transfers by
--   source, each a count per target.
data Dump = Dump {
    dpInsns :: !(M.Map Integer Insn)
  , dpTransfers :: !(M.Map Integer (M.Map Integer Integer))
  } deriving (Eq, Show)

-- | Read a plugin dump. A dump in which no instruction ran records
--   no run (the plugin writes every instruction the guest executed),
--   and is refused rather than compared as one that did nothing, as
--   is the dump of a guest the plugin stopped for starting a second
--   thread.
readDump :: T.Text -> Either String Dump
readDump t = go (T.lines t) M.empty M.empty
  where
    go ls is es = case ls of
      []
        | any ((> 0) . inCount) (M.elems is) -> pure (Dump is es)
        | otherwise ->
            Left "no instruction ran: the run was not recorded"
      (l : rest) -> case T.words l of
        [ "I", pc, n, a, fp, ord, obj, off ] -> do
          i <- Insn <$> unhex pc <*> unhex n <*> unhex a <*> pure fp
                    <*> pure ord
                    <*> pure (if obj == "-" then Nothing else Just obj)
                    <*> unhex off
          go rest (M.insert (inPc i) i is) es
        [ "E", from, to, n ] -> do
          f <- unhex from
          k <- unhex to
          c <- unhex n
          go rest is (M.insertWith M.union f (M.singleton k c) es)
        [ "T", _ ] ->
          Left "the guest started a second thread, which a trace \
               \cannot record: the run was stopped"
        [] -> go rest is es
        _ -> Left ("an unreadable dump line: " <> T.unpack l)
    unhex x = case readHex (T.unpack x) of
      [ (v, "") ] -> pure v
      _ -> Left ("not hexadecimal: " <> T.unpack x)

-- | Where a run loaded each object it executed: any of its
--   instructions' run-time addresses less its address in the object.
loadBases :: Dump -> M.Map T.Text Integer
loadBases d = M.fromList
  [ (o, inPc i - inOffset i)
  | i <- M.elems (dpInsns d), Just o <- [ inObject i ] ]

-- | The objects two runs both executed but loaded at different
--   addresses, each with where the first run put it and where the
--   second did. Runs laid out apart touch other addresses wherever
--   they touch memory, so comparing them says nothing of the
--   secret.
layoutApart :: Dump -> Dump -> [(T.Text, Integer, Integer)]
layoutApart a b =
  [ (o, x, y)
  | (o, (x, y)) <- M.toList
      (M.intersectionWith (,) (loadBases a) (loadBases b))
  , x /= y ]

-- | How an origin depended on the secret.
data Origin =
    ControlOrigin
  | AddressOrigin
  deriving (Eq, Ord, Show)

-- | Where the runs differ: the origins, each an instruction run
--   equally often everywhere, and how many instructions ran a
--   different number of times.
data Divergence = Divergence {
    dvOrigins :: ![(Origin, Insn)]
    -- | at each origin, the runs alike there, grouped, and the runs
    --   that never reached it, as indices into the declared runs
    --   then the designed (an address origin's, the declared alone)
  , dvBehaviour :: !(M.Map (Origin, Integer) ([[Int]], [Int]))
  , dvDownstream :: ![Insn]
  , dvUnsteady :: ![Insn]
  , dvRuns :: !Int
  , dvControls :: !Int
  , dvDesigned :: !Int
    -- | the offsets some run, control or not, executed, by object
  , dvExecuted :: !(M.Map T.Text (S.Set Integer))
  } deriving (Eq, Show)

-- | Compare runs, uncontrolled.
diffDumps :: [Dump] -> Divergence
diffDumps = diffControlled []

-- | Compare runs, given controls repeating the first run's secret.
--   Every run is set against every other, so an origin is any
--   instruction at which some two runs differ, and which no control
--   shows differing without the secret.
diffControlled :: [Dump] -> [Dump] -> Divergence
diffControlled cs ds = diffDesigned cs ds []

-- | Compare runs, given controls and runs designed to reach particular
--   paths. The address origins are the declared runs' alone; the
--   control origins and what was executed are every run's.
diffDesigned :: [Dump] -> [Dump] -> [Dump] -> Divergence
diffDesigned cs ds xs = Divergence {
    dvOrigins = L.sortOn (inPc . snd) origins
  , dvBehaviour = M.fromList
      [ ((o, inPc i), behaviourAt o (inPc i)) | (o, i) <- origins ]
  , dvDownstream = [ i | pc <- S.toAscList downstream
                       , not (pc `S.member` unsteady)
                       , Just i <- [ firstInsn pc ] ]
  , dvUnsteady = [ i | pc <- S.toAscList unsteady
                     , Just i <- [ firstInsn pc ] ]
  , dvRuns = length ds
  , dvControls = length cs
  , dvDesigned = length xs
  , dvExecuted = M.fromListWith S.union
      [ (obj, S.singleton (inOffset i))
      | d <- ds <> xs <> cs
      , i <- M.elems (dpInsns d)
      , inCount i > 0
      , Just obj <- [ inObject i ] ]
  }
  where
    -- what differs between the first run and a repeat of its secret
    unsteady = case ds of
      (d : _) -> S.unions (fmap (differing d) cs)
      [] -> S.empty
    differing a b = S.fromList
      [ pc
      | pc <- S.toList (M.keysSet (dpInsns a)
                          `S.union` M.keysSet (dpInsns b))
      , let ia = M.lookup pc (dpInsns a)
            ib = M.lookup pc (dpInsns b)
            ta = M.lookup pc (dpTransfers a)
            tb = M.lookup pc (dpTransfers b)
      , fmap sig ia /= fmap sig ib || ta /= tb ]
    sig i = (inCount i, inFingerprint i, inOrder i)

    origins = [ o | o@(_, i) <- controls <> addresses
                  , not (inPc i `S.member` unsteady) ]

    -- every run, the declared first
    runs = ds <> xs

    -- how the runs behaved at an origin: those that ran it, grouped
    -- by what they did there, and those that never ran it. Only the
    -- declared runs speak to an address.
    behaviourAt o pc = case o of
      ControlOrigin ->
        ( classes outcomesAlike
            [ (k, (inCount i, M.findWithDefault M.empty pc
                                (dpTransfers d), inOrder i))
            | (k, d, i) <- ranIn runs ]
        , absentIn runs )
      AddressOrigin ->
        ( classes (==) [ (k, inFingerprint i) | (k, _, i) <- ranIn ds ]
        , absentIn ds )
      where
        ranIn rs = [ (k, d, i) | (k, d) <- zip [ 0 .. ] rs
                               , Just i <- [ M.lookup pc (dpInsns d) ]
                               , inCount i > 0 ]
        absentIn rs = [ k | (k, d) <- zip [ 0 .. ] rs
                          , maybe True ((== 0) . inCount)
                              (M.lookup pc (dpInsns d)) ]

    pcs = S.unions (fmap (M.keysSet . dpInsns) runs)
    firstInsn pc = case [ i | d <- runs
                            , Just i <- [ M.lookup pc (dpInsns d) ] ] of
      (i : _) -> Just i
      [] -> Nothing

    -- run counts per run, absent counted as never run
    countsIn rs pc =
      [ maybe 0 inCount (M.lookup pc (dpInsns d)) | d <- rs ]
    alike ys = case ys of
      [] -> True
      (y : rest) -> all (== y) rest

    -- run equally often in every run, and in every declared run
    steady = S.filter (alike . countsIn runs) pcs
    steadyDeclared = S.filter (alike . countsIn ds)
      (S.unions (fmap (M.keysSet . dpInsns) ds))

    -- an instruction's run count, transfers, and the order of what
    -- followed it, in each run that ran it
    ranAt pc =
      [ ( inCount i, M.findWithDefault M.empty pc (dpTransfers d)
        , inOrder i )
      | d <- runs, Just i <- [ M.lookup pc (dpInsns d) ]
      , inCount i > 0 ]
    transferSources = S.unions (fmap (M.keysSet . dpTransfers) runs)

    -- outcomes in the same proportion: each target taken as often,
    -- relative to the run count, in both
    proportional (c, ts) (c', ts') =
      M.keysSet ts == M.keysSet ts'
        && and (M.elems (M.intersectionWith (\e e' -> e * c' == e' * c)
                           ts ts'))
    -- outcomes alike: each target taken in the same proportion and,
    -- where it ran as often, in the same order
    outcomesAlike (c, ts, o) (c', ts', o') =
      proportional (c, ts) (c', ts') && (c /= c' || o == o')
    divergent pc = case ranAt pc of
      (r : rest) -> not (all (outcomesAlike r) rest)
      [] -> False

    controlPcs = S.filter divergent transferSources
    addressPcs = S.fromList [ inPc i | (_, i) <- addresses ]
    downstream = ((pcs `S.difference` steady) `S.difference` controlPcs)
      `S.difference` addressPcs

    controls =
      [ (ControlOrigin, i)
      | pc <- S.toAscList controlPcs
      , Just i <- [ firstInsn pc ] ]

    addresses =
      [ (AddressOrigin, i)
      | pc <- S.toAscList steadyDeclared
      , let fps = [ fmap inFingerprint (M.lookup pc (dpInsns d))
                  | d <- ds ]
      , not (alike fps)
      , Just i <- [ firstInsn pc ]
      , inAccesses i > 0 ]

-- | Only the origins, what was executed, and what ran downstream, in
--   objects whose path contains one of the given texts.
restrictTo :: [T.Text] -> Divergence -> Divergence
restrictTo ps dv
  | null ps = dv
  | otherwise = dv {
        dvOrigins = filter (inside . inObject . snd) (dvOrigins dv)
      , dvDownstream = filter (inside . inObject) (dvDownstream dv)
      , dvExecuted = M.filterWithKey (\o _ -> inside (Just o))
          (dvExecuted dv)
      }
  where
    inside mo = case mo of
      Just o -> any (`T.isInfixOf` o) ps
      Nothing -> False

originText :: Origin -> T.Text
originText o = case o of
  ControlOrigin -> "control"
  AddressOrigin -> "address"

-- | The report: @vestigia/diff-v2@. Runs are named as given, the
--   declared then the designed.
divergenceJson
  :: T.Text -> [T.Text] -> M.Map (T.Text, Integer) [Place] -> Divergence
  -> Value
divergenceJson version names places dv = Object
  [ ("schema", String "vestigia/diff-v2")
  , ("tool", Object [ ("name", String "vestigia")
                    , ("version", String version) ])
  , ("runs", Number (toInteger (dvRuns dv)))
  , ("controls", Number (toInteger (dvControls dv)))
  , ("designed", Number (toInteger (dvDesigned dv)))
  , ("summary", Object
      [ ("control", count ControlOrigin)
      , ("address", count AddressOrigin)
      , ("downstream", Number (toInteger (length (dvDownstream dv))))
      , ("unsteady", Number (toInteger (length (dvUnsteady dv))))
      ])
  , ("origins", Array
      [ Object $
          [ ("class", String (originText o))
          , ("pc", String (hex (inPc i)))
          , ("object", maybe Null String (inObject i))
          , ("offset", String (hex (inOffset i)))
          , ("count", Number (inCount i))
          , ("frames", Array (fmap placeJson (placesOf i)))
          , ("groups", Array (fmap (Array . fmap named) groups))
          , ("absent", Array (fmap named absent))
          ]
      | (o, i) <- dvOrigins dv
      , let (groups, absent) = M.findWithDefault ([], []) (o, inPc i)
              (dvBehaviour dv) ])
  , ("downstream", Object
      [ (obj, Array (fmap (String . hex) (S.toAscList offs)))
      | (obj, offs) <- M.toList (M.fromListWith S.union
          [ (obj, S.singleton (inOffset i))
          | i <- dvDownstream dv, Just obj <- [ inObject i ] ]) ])
  , ("unsteady", byObject (dvUnsteady dv))
  , ("executed", Object
      [ (o, Array (fmap (String . hex) (S.toAscList xs)))
      | (o, xs) <- M.toList (dvExecuted dv) ])
  ]
  where
    count o = Number (toInteger (length
      [ () | (o', _) <- dvOrigins dv, o' == o ]))
    named k = case drop k names of
      (n : _) -> String n
      [] -> String (T.pack (show k))
    byObject is = Object
      [ (o, Number (toInteger n))
      | (o, n) <- M.toList (M.fromListWith (+)
          [ (maybe "-" id (inObject i), 1 :: Int) | i <- is ]) ]
    placesOf i = case inObject i of
      Just obj -> M.findWithDefault [] (obj, inOffset i) places
      Nothing -> []
    placeJson p = Object
      [ ("function", maybe Null String (plFunction p))
      , ("file", maybe Null String (plFile p))
      , ("line", maybe Null (Number . toInteger) (plLine p))
      ]

-- | One line per origin, innermost frame first, for a terminal.
divergenceSummary
  :: M.Map (T.Text, Integer) [Place] -> Divergence -> T.Text
divergenceSummary places dv = T.unlines $
  [ T.intercalate "  "
      [ originText o
      , hex (inOffset i)
      , maybe "?" id (plFunction =<< innermost i)
      , maybe "?" location (innermost i)
      , maybe "-" base (inObject i) ]
  | (o, i) <- dvOrigins dv ]
  <> [ T.pack (show (length (dvOrigins dv))) <> " origin(s) over "
       <> T.pack (show (dvRuns dv)) <> " run(s)"
       <> (if dvDesigned dv == 0 then ""
           else " and " <> T.pack (show (dvDesigned dv)) <> " designed")
       <> "; "
       <> T.pack (show (length (dvDownstream dv)))
       <> " instruction(s) downstream; "
       <> T.pack (show (length (dvUnsteady dv)))
       <> " unsteady over " <> T.pack (show (dvControls dv))
       <> " control(s)" ]
  where
    innermost i = case inObject i of
      Just obj -> case M.findWithDefault [] (obj, inOffset i) places of
        (p : _) -> Just p
        [] -> Nothing
      Nothing -> Nothing
    location p = case (plFile p, plLine p) of
      (Just f, Just l) -> base f <> ":" <> T.pack (show l)
      (Just f, Nothing) -> base f
      _ -> "?"
    base p = case reverse (T.splitOn "/" p) of
      (x : _) -> x
      [] -> p

hex :: Integer -> T.Text
hex n = "0x" <> T.pack (showHex n "")

-- keys grouped by an equivalence on their values, each group in
-- order and the groups by their first member
classes :: (a -> a -> Bool) -> [(Int, a)] -> [[Int]]
classes eq ys = case ys of
  [] -> []
  ((k, y) : rest) ->
    let (same, other) = L.partition (eq y . snd) rest
    in (k : fmap fst same) : classes eq other
