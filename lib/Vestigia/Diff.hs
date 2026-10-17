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
-- runs a different number of times). An instruction run equally
-- often in every run whose addresses differ computed one from the
-- secret: an `address` origin. Every other instruction run a
-- different number of times sits where control had already
-- diverged: it is downstream, and is counted rather than listed.
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

module Vestigia.Diff (
    Insn(..)
  , Dump(..)
  , readDump
  , Origin(..)
  , Divergence(..)
  , diffDumps
  , diffControlled
  , restrictTo
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

-- | One instruction of a run.
data Insn = Insn {
    inPc :: !Integer
  , inCount :: !Integer
  , inAccesses :: !Integer
  , inFingerprint :: !T.Text
  , inObject :: !(Maybe T.Text)
  , inOffset :: !Integer
  } deriving (Eq, Show)

-- | One run: its instructions by address, and its transfers by
--   source, each a count per target.
data Dump = Dump {
    dpInsns :: !(M.Map Integer Insn)
  , dpTransfers :: !(M.Map Integer (M.Map Integer Integer))
  } deriving (Eq, Show)

-- | Read a plugin dump.
readDump :: T.Text -> Either String Dump
readDump t = go (T.lines t) M.empty M.empty
  where
    go ls is es = case ls of
      [] -> pure (Dump is es)
      (l : rest) -> case T.words l of
        [ "I", pc, n, a, fp, obj, off ] -> do
          i <- Insn <$> unhex pc <*> unhex n <*> unhex a <*> pure fp
                    <*> pure (if obj == "-" then Nothing else Just obj)
                    <*> unhex off
          go rest (M.insert (inPc i) i is) es
        [ "E", from, to, n ] -> do
          f <- unhex from
          k <- unhex to
          c <- unhex n
          go rest is (M.insertWith M.union f (M.singleton k c) es)
        [] -> go rest is es
        _ -> Left ("an unreadable dump line: " <> T.unpack l)
    unhex x = case readHex (T.unpack x) of
      [ (v, "") ] -> pure v
      _ -> Left ("not hexadecimal: " <> T.unpack x)

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
  , dvDownstream :: ![Insn]
  , dvUnsteady :: ![Insn]
  , dvRuns :: !Int
  , dvControls :: !Int
  } deriving (Eq, Show)

-- | Compare runs, uncontrolled.
diffDumps :: [Dump] -> Divergence
diffDumps = diffControlled []

-- | Compare runs, given controls repeating the first run's secret.
--   Every run is set against every other, so an origin is any
--   instruction at which some two runs differ, and which no control
--   shows differing without the secret.
diffControlled :: [Dump] -> [Dump] -> Divergence
diffControlled cs ds = Divergence {
    dvOrigins = L.sortOn (inPc . snd)
      [ o | o@(_, i) <- controls <> addresses
          , not (inPc i `S.member` unsteady) ]
  , dvDownstream = [ i | pc <- S.toAscList downstream
                       , not (pc `S.member` unsteady)
                       , Just i <- [ firstInsn pc ] ]
  , dvUnsteady = [ i | pc <- S.toAscList unsteady
                     , Just i <- [ firstInsn pc ] ]
  , dvRuns = length ds
  , dvControls = length cs
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
    sig i = (inCount i, inFingerprint i)

    pcs = S.unions (fmap (M.keysSet . dpInsns) ds)
    firstInsn pc = case [ i | d <- ds
                            , Just i <- [ M.lookup pc (dpInsns d) ] ] of
      (i : _) -> Just i
      [] -> Nothing

    -- run counts per run, absent counted as never run
    countsAt pc = [ maybe 0 inCount (M.lookup pc (dpInsns d)) | d <- ds ]
    alike xs = case xs of
      [] -> True
      (x : rest) -> all (== x) rest

    steady = S.filter (alike . countsAt) pcs

    -- an instruction's run count and transfers, in each run that ran
    -- it
    ranAt pc =
      [ (inCount i, M.findWithDefault M.empty pc (dpTransfers d))
      | d <- ds, Just i <- [ M.lookup pc (dpInsns d) ], inCount i > 0 ]
    transferSources = S.unions (fmap (M.keysSet . dpTransfers) ds)

    -- outcomes in the same proportion: each target taken as often,
    -- relative to the run count, in both
    proportional (c, ts) (c', ts') =
      M.keysSet ts == M.keysSet ts'
        && and (M.elems (M.intersectionWith (\e e' -> e * c' == e' * c)
                           ts ts'))
    divergent pc = case ranAt pc of
      (r : rest) -> not (all (proportional r) rest)
      [] -> False

    controlPcs = S.filter divergent transferSources
    downstream = (pcs `S.difference` steady) `S.difference` controlPcs

    controls =
      [ (ControlOrigin, i)
      | pc <- S.toAscList controlPcs
      , Just i <- [ firstInsn pc ] ]

    addresses =
      [ (AddressOrigin, i)
      | pc <- S.toAscList steady
      , let fps = [ fmap inFingerprint (M.lookup pc (dpInsns d))
                  | d <- ds ]
      , not (alike fps)
      , Just i <- [ firstInsn pc ]
      , inAccesses i > 0 ]

-- | Only the origins in objects whose path contains one of the
--   given texts; downstream instructions are kept, to be counted.
restrictTo :: [T.Text] -> Divergence -> Divergence
restrictTo ps dv
  | null ps = dv
  | otherwise = dv { dvOrigins = filter (inside . snd) (dvOrigins dv) }
  where
    inside i = case inObject i of
      Just o -> any (`T.isInfixOf` o) ps
      Nothing -> False

originText :: Origin -> T.Text
originText o = case o of
  ControlOrigin -> "control"
  AddressOrigin -> "address"

-- | The report: @vestigia/diff-v1@.
divergenceJson
  :: T.Text -> M.Map (T.Text, Integer) [Place] -> Divergence -> Value
divergenceJson version places dv = Object
  [ ("schema", String "vestigia/diff-v1")
  , ("tool", Object [ ("name", String "vestigia")
                    , ("version", String version) ])
  , ("runs", Number (toInteger (dvRuns dv)))
  , ("controls", Number (toInteger (dvControls dv)))
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
          ]
      | (o, i) <- dvOrigins dv ])
  , ("downstream", byObject (dvDownstream dv))
  , ("unsteady", byObject (dvUnsteady dv))
  ]
  where
    count o = Number (toInteger (length
      [ () | (o', _) <- dvOrigins dv, o' == o ]))
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
       <> T.pack (show (dvRuns dv)) <> " run(s); "
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
