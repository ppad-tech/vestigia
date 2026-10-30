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
-- to each target, a fingerprint of the addresses it touched, and,
-- for an integer division, a fingerprint of its operands.
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
-- differ computed one from the secret: an `address` origin. A
-- division, whose time depends on its operands, run equally often
-- on other operands is an `operand` origin. Every
-- other instruction run a different number of times sits where
-- control had already diverged: it is downstream. So is a return
-- whose transfers differ, however often it ran: it goes where the
-- call before it sent it, so its outcomes differ only because
-- control had diverged before the call.
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
-- by the secret) and what was executed, never toward the address or
-- operand origins, which only runs alike in all but the secret can
-- show.
--
-- What every run executed, per object, is reported beside: the
-- instructions the chosen secrets exercised, and so, against what
-- a function could execute, the part of it the comparison saw.
--
-- Each origin names how the runs behaved there: the runs alike at
-- it, grouped (taking each transfer in the same proportion, at a
-- control origin; touching the same addresses, at an address
-- origin; dividing the same operands, at an operand origin), and the
-- runs that never reached it. Whether two runs
-- that differed there both had their secrets accepted is the
-- reader's to say, from what each run returned.
--
-- Runs recorded under a data-independent-timing contract
-- (Vestigia.Contract) also fingerprint the operands of every
-- instruction outside it. One run equally often on other operands
-- in some declared run is outside the contract on the secret: not an
-- origin, since the contract says nothing either way of its time,
-- but reported beside them, as is how many such instructions ran.

module Vestigia.Diff (
    Insn(..)
  , Run(..)
  , Dump(..)
  , readDump
  , callsOf
  , runApart
  , Kind(..)
  , Named(..)
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

import Control.Monad (foldM, unless)
import qualified Data.ByteString as BS
import qualified Data.List as L
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Encoding.Error as TEE
import Numeric (readHex, showHex)
import Text.Read (readMaybe)

import Vestigia.Contract (contractSource, readContract)
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

-- | How a run was made, as `vestigia record` appends it to the
--   plugin's dump: the program and its arguments, as the bytes it
--   passed them; the variables of the environment the guest was
--   given, and the bytes they take; and the run's exit status.
data Run = Run {
    rnArguments :: ![BS.ByteString]
  , rnEnvironment :: !(Integer, Integer)
  , rnStatus :: !Integer
  } deriving (Eq, Show)

-- | One run: its instructions by address, its transfers by source,
--   each a count per target, the instructions that return, the
--   divisions' operands, fingerprinted, the contexts calls made (each
--   by the context it was made in and the call's address, 0 being
--   the program's own), the contexts each instruction ran in (with
--   whether it ran in more than the plugin kept), and how the run
--   was made, where its dump says.
data Dump = Dump {
    dpInsns :: !(M.Map Integer Insn)
  , dpTransfers :: !(M.Map Integer (M.Map Integer Integer))
  , dpReturns :: !(S.Set Integer)
  , dpOperands :: !(M.Map Integer T.Text)
  , dpContexts :: !(M.Map Integer (Integer, Integer))
  , dpCallers :: !(M.Map Integer (Bool, [Integer]))
  , dpRun :: !(Maybe Run)
    -- | the operands, fingerprinted, of the instructions outside the
    --   contract the run was recorded under
  , dpOutside :: !(M.Map Integer T.Text)
    -- | the text of each instruction the watch list named
  , dpTexts :: !(M.Map Integer T.Text)
    -- | the guest's ISA, the contract, and the CPU model QEMU
    --   emulated, as `vestigia record` appends them
  , dpIsa :: !(Maybe T.Text)
  , dpContract :: !(Maybe T.Text)
  , dpCpu :: !(Maybe T.Text)
  } deriving (Eq, Show)

-- | Read a plugin dump. A dump in which no instruction ran records
--   no run (the plugin writes every instruction the guest executed),
--   and is refused rather than compared as one that did nothing, as
--   is the dump of a guest the plugin stopped for starting a second
--   thread, or one whose contexts do not chain back to the
--   program's own. The record `vestigia record` appends (an @A@ line
--   per argument, its bytes in hex; @N@, the environment's variables
--   and bytes, in hex; @X@, the exit status, in decimal) is read
--   whole or not at all. Beside it, @M@ names the guest's ISA, @G@
--   the contract the run was recorded under, and @P@ the CPU model
--   QEMU emulated, where one was named.
readDump :: T.Text -> Either String Dump
readDump t = do
  d <- foldM line (Dump M.empty M.empty S.empty M.empty M.empty M.empty
                     Nothing M.empty M.empty Nothing Nothing Nothing, []
                  , Nothing
                  , Nothing) (T.lines t)
  let (dump, as, env, st) = d
      cx = dpContexts dump
  unless (any ((> 0) . inCount) (M.elems (dpInsns dump))) $
    Left "no instruction ran: the run was not recorded"
  -- each context made in one made before it, so that its calls end
  unless (and [ c' < c && (c' == 0 || M.member c' cx)
              | (c, (c', _)) <- M.toList cx ]) $
    Left "a context made in one not made before it"
  unless (and [ c == 0 || M.member c cx
              | (_, cs) <- M.elems (dpCallers dump), c <- cs ]) $
    Left "an instruction run in a context the dump does not make"
  r <- record (reverse as) env st
  pure dump { dpRun = r }
  where
    line (d, as, env, st) l = case T.words l of
      [ "I", pc, n, a, fp, ord, obj, off ] -> do
        i <- Insn <$> unhex pc <*> unhex n <*> unhex a <*> pure fp
                  <*> pure ord
                  <*> pure (if obj == "-" then Nothing else Just obj)
                  <*> unhex off
        pure (d { dpInsns = M.insert (inPc i) i (dpInsns d) }, as, env
             , st)
      [ "E", from, to, n ] -> do
        f <- unhex from
        k <- unhex to
        c <- unhex n
        pure (d { dpTransfers = M.insertWith M.union f (M.singleton k c)
                    (dpTransfers d) }, as, env, st)
      [ "R", pc ] -> do
        r <- unhex pc
        pure (d { dpReturns = S.insert r (dpReturns d) }, as, env, st)
      [ "D", pc, fp ] -> do
        k <- unhex pc
        pure (d { dpOperands = M.insert k fp (dpOperands d) }, as, env
             , st)
      [ "U", pc, fp ] -> do
        k <- unhex pc
        pure (d { dpOutside = M.insert k fp (dpOutside d) }, as, env
             , st)
      ("W" : pc : text@(_ : _)) -> do
        k <- unhex pc
        pure (d { dpTexts = M.insert k (T.unwords text) (dpTexts d) }, as
             , env, st)
      [ "M", isa ] -> pure (d { dpIsa = Just isa }, as, env, st)
      [ "G", c ] -> pure (d { dpContract = Just c }, as, env, st)
      [ "P", c ] -> pure (d { dpCpu = Just c }, as, env, st)
      [ "C", c, caller, call ] -> do
        v <- (,) <$> unhex caller <*> unhex call
        k <- unhex c
        pure (d { dpContexts = M.insert k v (dpContexts d) }, as, env
             , st)
      ("K" : pc : partial : cs@(_ : _)) -> do
        k <- unhex pc
        p <- case partial of
          "0" -> pure False
          "1" -> pure True
          _ -> Left ("an unreadable dump line: " <> T.unpack l)
        xs <- traverse unhex cs
        pure (d { dpCallers = M.insert k (p, xs) (dpCallers d) }, as
             , env, st)
      [ "T", _ ] ->
        Left "the guest started a second thread, which a trace \
             \cannot record: the run was stopped"
      [ "A" ] -> pure (d, BS.empty : as, env, st)
      [ "A", h ] -> do
        b <- unhexBytes h
        pure (d, b : as, env, st)
      [ "N", n, b ] -> do
        v <- (,) <$> unhex n <*> unhex b
        pure (d, as, Just v, st)
      [ "X", x ] -> case readMaybe (T.unpack x) of
        Just v -> pure (d, as, env, Just v)
        Nothing -> Left ("not an exit status: " <> T.unpack x)
      [] -> pure (d, as, env, st)
      _ -> Left ("an unreadable dump line: " <> T.unpack l)
    record as env st = case (as, env, st) of
      ([], Nothing, Nothing) -> pure Nothing
      (_ : _, Just e, Just x) -> pure (Just (Run as e x))
      _ -> Left "an incomplete record of the run"
    unhex x = case readHex (T.unpack x) of
      [ (v, "") ] -> pure v
      _ -> Left ("not hexadecimal: " <> T.unpack x)
    unhexBytes h
      | odd (T.length h) = Left ("not hexadecimal bytes: " <> T.unpack h)
      | otherwise =
          BS.pack <$> traverse (fmap fromInteger . unhex) (T.chunksOf 2 h)

-- | The calls that made a context, innermost first, at most 24 of
--   them (as memcheck keeps): each by its object and address there,
--   or by its run-time address where the run names no object for it.
callsOf :: Dump -> Integer -> [(Maybe T.Text, Integer)]
callsOf d = go (24 :: Int)
  where
    go n c
      | n <= 0 || c == 0 = []
      | otherwise = case M.lookup c (dpContexts d) of
          Just (caller, pc) -> site pc : go (n - 1) caller
          Nothing -> []
    site pc = case M.lookup pc (dpInsns d) of
      Just i | Just o <- inObject i -> (Just o, inOffset i)
      _ -> (Nothing, pc)

-- | Why a run cannot be set beside the first as differing from it in
--   the secret alone, if it cannot: it ran another program, its
--   arguments differ from the first run's in number or length, or it
--   was given an environment of another size. Each lays the guest's
--   stack out apart, and so every address on it.
runApart :: Run -> Run -> Maybe String
runApart first r
  | take 1 (rnArguments r) /= take 1 (rnArguments first) =
      Just "ran another program than the first run"
  | fmap BS.length (rnArguments r)
      /= fmap BS.length (rnArguments first) =
      Just "has arguments that differ from the first run's in number \
           \or length"
  | rnEnvironment r /= rnEnvironment first =
      Just "was given an environment of another size than the first \
           \run's"
  | otherwise = Nothing

-- | What a run is to a comparison: declared, designed for a path, or
--   a control repeating the first run's secret.
data Kind =
    DeclaredRun
  | DesignedRun
  | ControlRun
  deriving (Eq, Show)

-- | A run as the report names it: by its dump's file name, with what
--   it is to the comparison and how it was made.
data Named = Named {
    nmName :: !T.Text
  , nmKind :: !Kind
  , nmRun :: !Run
  } deriving (Eq, Show)

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
  | OperandOrigin
  deriving (Eq, Ord, Show)

-- | Where the runs differ: the origins, each an instruction run
--   equally often everywhere, and how many instructions ran a
--   different number of times.
data Divergence = Divergence {
    dvOrigins :: ![(Origin, Insn)]
    -- | at each origin, the runs alike there, grouped, and the runs
    --   that never reached it, as indices into the declared runs
    --   then the designed (an address or operand origin's, the
    --   declared alone)
  , dvBehaviour :: !(M.Map (Origin, Integer) ([[Int]], [Int]))
  , dvDownstream :: ![Insn]
  , dvUnsteady :: ![Insn]
  , dvRuns :: !Int
  , dvControls :: !Int
  , dvDesigned :: !Int
    -- | the offsets some run, control or not, executed, by object
  , dvExecuted :: !(M.Map T.Text (S.Set Integer))
    -- | at each origin, the distinct chains of calls that reached it
    --   in the declared and designed runs, at most 16 of them, and
    --   whether there were more than those
  , dvCallers :: !(M.Map Integer ([[(Maybe T.Text, Integer)]], Bool))
    -- | the instructions outside the contract run equally often in
    --   every declared run, on other operands in one, each with the
    --   runs alike there and those that never ran it
  , dvOutside :: ![Insn]
  , dvOutsideBehaviour :: !(M.Map Integer ([[Int]], [Int]))
    -- | the instructions outside the contract some run executed, by
    --   object
  , dvWatched :: !(M.Map T.Text (S.Set Integer))
    -- | the text of each instruction the watch list named
  , dvTexts :: !(M.Map Integer T.Text)
    -- | the guest's ISA, the contract, and the CPU model, as the
    --   declared runs name them
  , dvIsa :: !(Maybe T.Text)
  , dvContract :: !(Maybe T.Text)
  , dvCpu :: !(Maybe T.Text)
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
--   paths. The address and operand origins are the declared runs'
--   alone; the control origins and what was executed are every
--   run's.
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
  , dvCallers = M.fromList
      [ (inPc i, callersAt (inPc i))
      | i <- fmap snd origins <> outside ]
  , dvOutside = outside
  , dvOutsideBehaviour = M.fromList
      [ ( inPc i
        , ( classes (==) [ (k, M.lookup (inPc i) (dpOutside d))
                         | (k, d) <- ranIn' ds (inPc i) ]
          , [ k | (k, d) <- zip [ 0 .. ] ds
                , maybe True ((== 0) . inCount)
                    (M.lookup (inPc i) (dpInsns d)) ] ) )
      | i <- outside ]
  , dvWatched = M.fromListWith S.union
      [ (obj, S.singleton (inOffset i))
      | d <- ds <> xs <> cs
      , pc <- M.keys (dpOutside d)
      , Just i <- [ M.lookup pc (dpInsns d) ]
      , inCount i > 0
      , Just obj <- [ inObject i ] ]
  , dvTexts = M.unions (fmap dpTexts (ds <> xs <> cs))
  , dvIsa = case ds of
      (d : _) -> dpIsa d
      [] -> Nothing
  , dvContract = case ds of
      (d : _) -> dpContract d
      [] -> Nothing
  , dvCpu = case ds of
      (d : _) -> dpCpu d
      [] -> Nothing
  }
  where
    ranIn' rs pc = [ (k, d) | (k, d) <- zip [ 0 .. ] rs
                            , Just i <- [ M.lookup pc (dpInsns d) ]
                            , inCount i > 0 ]
    callersAt pc =
      let found = [ (partial, fmap (callsOf d) ks)
                  | d <- runs
                  , Just (partial, ks) <- [ M.lookup pc (dpCallers d) ] ]
          stacks = L.nub (concatMap snd found)
      in (take 16 stacks, any fst found || length stacks > 16)

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
      , fmap sig ia /= fmap sig ib || ta /= tb
          || M.lookup pc (dpOperands a) /= M.lookup pc (dpOperands b)
          || M.lookup pc (dpOutside a) /= M.lookup pc (dpOutside b) ]
    sig i = (inCount i, inFingerprint i, inOrder i)

    origins = [ o | o@(_, i) <- controls <> addresses <> operands
                  , not (inPc i `S.member` unsteady) ]

    -- every run, the declared first
    runs = ds <> xs

    -- how the runs behaved at an origin: those that ran it, grouped
    -- by what they did there, and those that never ran it. Only the
    -- declared runs speak to an address or an operand.
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
      OperandOrigin ->
        ( classes (==)
            [ (k, M.lookup pc (dpOperands d)) | (k, d, _) <- ranIn ds ]
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

    -- a return goes where its call sent it: downstream, never an
    -- origin, whatever its outcomes
    returns = S.unions (fmap dpReturns runs)
    divergentPcs = S.filter divergent transferSources
    controlPcs = divergentPcs `S.difference` returns
    -- the address and operand origins
    dataPcs = S.fromList [ inPc i | (_, i) <- addresses <> operands ]
    downstream =
      ((((pcs `S.difference` steady)
          `S.union` (divergentPcs `S.intersection` returns))
          `S.difference` controlPcs)
        `S.difference` dataPcs)
      `S.difference` S.fromList (fmap inPc outside)

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

    -- an instruction outside the contract run equally often in
    -- every declared run, on other operands in one, where it is not
    -- an origin already
    outside =
      [ i
      | pc <- S.toAscList steadyDeclared
      , not (pc `S.member` unsteady)
      , not (pc `S.member` controlPcs)
      , not (pc `S.member` dataPcs)
      , let fps = [ M.lookup pc (dpOutside d) | d <- ds ]
      , any (/= Nothing) fps
      , not (alike fps)
      , Just i <- [ firstInsn pc ] ]

    -- a division run equally often in every declared run, on other
    -- operands in one
    operands =
      [ (OperandOrigin, i)
      | pc <- S.toAscList steadyDeclared
      , let fps = [ M.lookup pc (dpOperands d) | d <- ds ]
      , any (/= Nothing) fps
      , not (alike fps)
      , Just i <- [ firstInsn pc ] ]

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
      , dvOutside = filter (inside . inObject) (dvOutside dv)
      , dvWatched = M.filterWithKey (\o _ -> inside (Just o))
          (dvWatched dv)
      }
  where
    inside mo = case mo of
      Just o -> any (`T.isInfixOf` o) ps
      Nothing -> False

originText :: Origin -> T.Text
originText o = case o of
  ControlOrigin -> "control"
  AddressOrigin -> "address"
  OperandOrigin -> "operand"

-- | The report: @vestigia/diff-v4@. Runs are given the declared,
--   then the designed, then the controls, and an origin names the
--   runs alike at it by the first two. An origin's stacks are its own
--   frames then its calls', innermost first, each frame with the
--   object and address of the instruction it names, as memcheck's
--   are in a taint report. The ISA, contract, and CPU model the runs
--   were recorded under head it; the instructions outside the contract
--   whose operands differed are given as origins are, and those that
--   ran, by object, as what was executed is.
divergenceJson
  :: T.Text -> [Named] -> M.Map (T.Text, Integer) [Place] -> Divergence
  -> Value
divergenceJson version runs places dv = Object
  [ ("schema", String "vestigia/diff-v4")
  , ("tool", Object [ ("name", String "vestigia")
                    , ("version", String version) ])
  , ("isa", maybe Null String (dvIsa dv))
  , ("contract", case dvContract dv of
      Just n -> Object
        [ ("name", String n)
        , ("source", maybe Null (String . contractSource)
            (readContract n)) ]
      Nothing -> Null)
  , ("cpu", maybe Null String (dvCpu dv))
  , ("runs", Array
      [ Object
          [ ("name", String (nmName r))
          , ("kind", String (kindText (nmKind r)))
          , ("arguments", Array
              [ String (TE.decodeUtf8With TEE.lenientDecode a)
              | a <- rnArguments (nmRun r) ])
          , ("status", Number (rnStatus (nmRun r)))
          ]
      | r <- runs ])
  , ("summary", Object
      [ ("control", count ControlOrigin)
      , ("address", count AddressOrigin)
      , ("operand", count OperandOrigin)
      , ("downstream", Number (toInteger (length (dvDownstream dv))))
      , ("unsteady", Number (toInteger (length (dvUnsteady dv))))
      , ("outside", Number (toInteger (length (dvOutside dv))))
      , ("watched", Number (toInteger (sum (fmap S.size
          (M.elems (dvWatched dv))))))
      ])
  , ("origins", Array
      [ site (originText o) i
          (M.findWithDefault ([], []) (o, inPc i) (dvBehaviour dv))
      | (o, i) <- dvOrigins dv ])
  , ("outside", Array
      [ site "outside" i
          (M.findWithDefault ([], []) (inPc i) (dvOutsideBehaviour dv))
      | i <- dvOutside dv ])
  , ("downstream", Object
      [ (obj, Array (fmap (String . hex) (S.toAscList offs)))
      | (obj, offs) <- M.toList (M.fromListWith S.union
          [ (obj, S.singleton (inOffset i))
          | i <- dvDownstream dv, Just obj <- [ inObject i ] ]) ])
  , ("unsteady", byObject (dvUnsteady dv))
  , ("executed", Object
      [ (o, Array (fmap (String . hex) (S.toAscList xs)))
      | (o, xs) <- M.toList (dvExecuted dv) ])
  , ("watched", Object
      [ (o, Array (fmap (String . hex) (S.toAscList xs)))
      | (o, xs) <- M.toList (dvWatched dv) ])
  ]
  where
    site cls i (groups, absent) =
      let (stacks, partial) = M.findWithDefault ([], False) (inPc i)
            (dvCallers dv)
      in Object
           [ ("class", String cls)
           , ("pc", String (hex (inPc i)))
           , ("object", maybe Null String (inObject i))
           , ("offset", String (hex (inOffset i)))
           , ("count", Number (inCount i))
           , ("instruction", maybe Null String
               (M.lookup (inPc i) (dvTexts dv)))
           , ("frames", Array (fmap placeJson (placesOf i)))
           , ("stacks", Array
               [ Array (located (inObject i, inOffset i)
                          <> concatMap located calls)
               | calls <- stacks ])
           , ("partial", Bool partial)
           , ("groups", Array (fmap (Array . fmap named) groups))
           , ("absent", Array (fmap named absent))
           ]
    names = [ nmName r | r <- runs, nmKind r /= ControlRun ]
    kindText k = case k of
      DeclaredRun -> "declared"
      DesignedRun -> "designed"
      ControlRun -> "control"
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
    -- an instruction's frames, innermost first, each with where the
    -- instruction is; one unnamed frame where nothing names it
    located (mo, a) =
      let at = [ ("object", maybe Null String mo)
               , ("offset", String (hex a)) ]
          ps = case mo of
            Just obj -> M.findWithDefault [] (obj, a) places
            Nothing -> []
      in case ps of
           [] -> [ Object (at <> [ ("function", Null), ("file", Null)
                                 , ("line", Null) ]) ]
           _ -> [ case placeJson p of
                    Object kvs -> Object (at <> kvs)
                    other -> other
                | p <- ps ]

-- | One line per origin, innermost frame first, for a terminal.
divergenceSummary
  :: M.Map (T.Text, Integer) [Place] -> Divergence -> T.Text
divergenceSummary places dv = T.unlines $
  [ T.intercalate "  "
      [ cls
      , hex (inOffset i)
      , maybe "?" id (plFunction =<< innermost i)
      , maybe "?" location (innermost i)
      , maybe "-" base (inObject i) ]
  | (cls, i) <- [ (originText o, i) | (o, i) <- dvOrigins dv ]
                  <> [ ("outside", i) | i <- dvOutside dv ] ]
  <> [ T.pack (show (length (dvOrigins dv))) <> " origin(s) over "
       <> T.pack (show (dvRuns dv)) <> " run(s)"
       <> (if dvDesigned dv == 0 then ""
           else " and " <> T.pack (show (dvDesigned dv)) <> " designed")
       <> "; "
       <> T.pack (show (length (dvDownstream dv)))
       <> " instruction(s) downstream; "
       <> T.pack (show (length (dvUnsteady dv)))
       <> " unsteady over " <> T.pack (show (dvControls dv))
       <> " control(s)"
       <> maybe ""
            (\c -> "; " <> T.pack (show watched)
               <> " instruction(s) outside " <> c <> " ran, "
               <> T.pack (show (length (dvOutside dv)))
               <> " on operands that differed")
            (dvContract dv) ]
  where
    watched = sum (fmap S.size (M.elems (dvWatched dv)))
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
