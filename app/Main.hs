{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module: Main
-- Copyright: (c) 2026 Jared Tobin
-- License: MIT
-- Maintainer: Jared Tobin <jared@ppad.tech>
--
-- The vestigia command: run a harness under memcheck and report
-- where its execution depended on the bytes it marked secret.

module Main (
    main
  ) where

import Control.Exception (IOException, try)
import Control.Monad (unless, when)
import qualified Data.ByteString as BS
import Data.Char (toUpper)
import Data.Foldable (for_)
import Data.Version (showVersion)
import qualified GHC.Foreign as GF
import GHC.IO.Encoding (getFileSystemEncoding)
import Numeric (showHex)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Encoding.Error as TEE
import qualified Data.Text.IO as TIO
import System.Directory (getTemporaryDirectory, removeFile)
import System.Environment (getArgs, getEnvironment, lookupEnv)
import System.Exit (ExitCode(..), exitWith)
import System.FilePath (takeFileName)
import System.IO
  (IOMode(..), hClose, hPutStrLn, openTempFile, stderr, withBinaryFile)
import System.Process (proc, waitForProcess, withCreateProcess)
import qualified System.Process as P

import Paths_vestigia (version)
import Vestigia.Diff
  (Dump(..), Kind(..), Named(..), Run(..), diffDesigned, divergenceJson,
   divergenceSummary, dvOrigins, inObject, inOffset, layoutApart,
   readDump, restrictTo, runApart)
import Vestigia.Json (encode)
import Vestigia.Layout (fixLayout)
import Vestigia.Memcheck (readMemcheck)
import Vestigia.Symbol (symbolize)
import Vestigia.Trace
  (readObjects, sitesIn, trace, traceJson, traceSummary, withObjects)

data Opts = Opts {
    oValgrind :: !(Maybe FilePath)
  , oXml :: !(Maybe FilePath)
  , oOut :: !(Maybe FilePath)
  , oQemu :: !(Maybe FilePath)
  , oPlugin :: !(Maybe FilePath)
  , oDump :: !(Maybe FilePath)
  , oAddr2line :: !(Maybe FilePath)
  , oObjects :: ![T.Text]
  , oControls :: ![FilePath]
  , oDesigned :: ![FilePath]
  }

main :: IO ()
main = do
  args <- getArgs
  case args of
    ("run" : rest) -> case options rest of
      Right (o, prog : progArgs) -> run o prog progArgs
      Right (_, []) -> usage "run: no program given"
      Left e -> usage e
    ("read" : rest) -> case options rest of
      Right (o, [ xml ]) -> readXml o xml
      Right _ -> usage "read: one XML file expected"
      Left e -> usage e
    ("record" : rest) -> case options rest of
      Right (o, prog : progArgs) -> record o prog progArgs
      Right (_, []) -> usage "record: no program given"
      Left e -> usage e
    ("diff" : rest) -> case options rest of
      Right (o, dumps@(_ : _ : _)) -> diff o dumps
      Right _ -> usage "diff: two or more dumps expected"
      Left e -> usage e
    [ "--version" ] -> putStrLn (showVersion version)
    _ -> usage "expected a command"

usage :: String -> IO a
usage e = do
  hPutStrLn stderr ("vestigia: " <> e)
  hPutStrLn stderr $ unlines
    [ "usage:"
    , "  vestigia run [--valgrind PATH] [--xml FILE] [--out FILE] \
      \[--object TEXT]... -- PROGRAM [ARG...]"
    , "  vestigia read [--out FILE] [--object TEXT]... FILE.xml"
    , "  vestigia record [--qemu PATH] [--plugin PATH] --dump FILE \
      \-- PROGRAM [ARG...]"
    , "  vestigia diff [--out FILE] [--addr2line PATH] \
      \[--object TEXT]... [--control DUMP]... [--designed DUMP]... \
      \DUMP DUMP..."
    , ""
    , "run executes PROGRAM under memcheck, which reports every"
    , "branch and address that depended on bytes the program marked"
    , "secret (vestigia.h), and writes the report (vestigia/trace-v1)."
    , "valgrind is --valgrind, else $VESTIGIA_VALGRIND, else on PATH."
    , "--object keeps sites in objects whose path contains TEXT."
    , ""
    , "record executes PROGRAM under QEMU with vestigia's plugin and"
    , "dumps its leakage trace per instruction, with how it was run;"
    , "diff compares dumps of runs that differ only in a secret and"
    , "reports where they diverge (vestigia/diff-v3), naming sources"
    , "with addr2line."
    , "--object keeps origins in objects whose path contains TEXT;"
    , "--control names a run repeating the first run's secret, and"
    , "what differs in it is unsteady, not an origin."
    , "QEMU is the one for PROGRAM's architecture: --qemu, else"
    , "$VESTIGIA_QEMU_X86_64 or $VESTIGIA_QEMU_AARCH64, else"
    , "qemu-x86_64 or qemu-aarch64 on PATH. The plugin and addr2line"
    , "default to $VESTIGIA_PLUGIN and $VESTIGIA_ADDR2LINE."
    ]
  exitWith (ExitFailure 2)

-- options before the program; "--" ends them
options :: [String] -> Either String (Opts, [String])
options = go (Opts Nothing Nothing Nothing Nothing Nothing Nothing
              Nothing [] [] [])
  where
    go o xs = case xs of
      ("--" : rest) -> Right (o, rest)
      ("--valgrind" : p : rest) -> go o { oValgrind = Just p } rest
      ("--xml" : p : rest) -> go o { oXml = Just p } rest
      ("--out" : p : rest) -> go o { oOut = Just p } rest
      ("--qemu" : p : rest) -> go o { oQemu = Just p } rest
      ("--plugin" : p : rest) -> go o { oPlugin = Just p } rest
      ("--dump" : p : rest) -> go o { oDump = Just p } rest
      ("--addr2line" : p : rest) -> go o { oAddr2line = Just p } rest
      ("--object" : t : rest) ->
        go o { oObjects = oObjects o <> [ T.pack t ] } rest
      ("--control" : p : rest) ->
        go o { oControls = oControls o <> [ p ] } rest
      ("--designed" : p : rest) ->
        go o { oDesigned = oDesigned o <> [ p ] } rest
      (x : _) | take 2 x == "--" -> Left ("unknown option: " <> x)
      _ -> Right (o, xs)

-- the settings every trace runs under: origins tracked so a
-- secret's descendants are known as such, no limit on contexts,
-- the precise definedness checks optimised code needs, every
-- register (the instruction pointer among them) brought up to date
-- at each instruction of a program's own code, so that a site that
-- touches no memory, a division by a register, is named by its own
-- address rather than the last memory access before it, and no leak
-- report
memcheckArgs :: FilePath -> [String]
memcheckArgs xml =
  [ "--tool=memcheck"
  , "--xml=yes"
  , "--xml-file=" <> xml
  , "--track-origins=yes"
  , "--error-limit=no"
  , "--num-callers=24"
  , "--expensive-definedness-checks=yes"
  , "--px-file-backed=allregs-at-each-insn"
  , "--leak-check=no"
  , "--child-silent-after-fork=yes"
  ]

run :: Opts -> FilePath -> [String] -> IO ()
run o prog progArgs = do
  env <- lookupEnv "VESTIGIA_VALGRIND"
  let valgrind = maybe (maybe "valgrind" id env) id (oValgrind o)
  (xml, temporary) <- case oXml o of
    Just p -> pure (p, False)
    Nothing -> do
      tmp <- getTemporaryDirectory
      (p, h) <- openTempFile tmp "vestigia.xml"
      hClose h
      pure (p, True)
  -- where the harness's loader put its objects, which the
  -- harness's first mark writes (vestigia.h)
  tmp <- getTemporaryDirectory
  (objects, oh) <- openTempFile tmp "vestigia-objects"
  hClose oh
  environment <- getEnvironment
  r <- try (withCreateProcess
         (proc valgrind (memcheckArgs xml <> (prog : progArgs)))
           { P.env = Just (("VESTIGIA_OBJECTS", objects)
                         : filter ((/= "VESTIGIA_OBJECTS") . fst)
                             environment) }
         (\_ _ _ ph -> waitForProcess ph))
  code <- case r of
    Left e -> do
      hPutStrLn stderr ("vestigia: cannot run " <> valgrind <> ": "
        <> show (e :: IOException))
      exitWith (ExitFailure 2)
    Right c -> pure c
  otext <- TIO.readFile objects
  os <- case readObjects otext of
    Left e -> do
      hPutStrLn stderr ("vestigia: " <> objects <> ": " <> e)
      exitWith (ExitFailure 2)
    Right v -> pure v
  removeFile objects
  -- no objects written, no secret marked: a run that found nothing
  -- because nothing was secret is no evidence, and is refused
  when (null os) $ do
    hPutStrLn stderr "vestigia: the harness marked no secret \
      \(vestigia_secret was never called on any bytes); its run \
      \says nothing"
    exitWith (ExitFailure 2)
  report o (Just (exitStatus code)) os xml
  if temporary then removeFile xml else pure ()

exitStatus :: ExitCode -> Int
exitStatus c = case c of
  ExitSuccess -> 0
  ExitFailure n -> n

readXml :: Opts -> FilePath -> IO ()
readXml o xml = report o Nothing [] xml

report :: Opts -> Maybe Int -> [(Integer, T.Text)] -> FilePath -> IO ()
report o exit os xml = do
  bytes <- BS.readFile xml
  let txt = TE.decodeUtf8With TEE.lenientDecode bytes
  case readMemcheck txt of
    Left e -> do
      hPutStrLn stderr ("vestigia: " <> xml <> ": " <> e)
      exitWith (ExitFailure 2)
    Right mc -> do
      let tr = sitesIn (oObjects o) (withObjects os (trace mc))
          doc = encode
            (traceJson (T.pack (showVersion version)) exit tr)
      maybe (TIO.putStr doc) (\p -> TIO.writeFile p doc) (oOut o)
      TIO.hPutStr stderr (traceSummary tr)

-- a tool named by its option, else its environment variable, else
-- the given default
tool :: Maybe FilePath -> String -> String -> IO FilePath
tool opt var dflt = do
  env <- lookupEnv var
  pure (maybe (maybe dflt id env) id opt)

record :: Opts -> FilePath -> [String] -> IO ()
record o prog progArgs = do
  dump <- maybe (usage "record: --dump FILE is needed") pure (oDump o)
  -- runs to be compared must lay memory out alike, and draw the
  -- same entropy: a hash table seeded from the operating system's
  -- randomness is laid out anew in every process
  fixed <- fixLayout
  unless fixed $ do
    hPutStrLn stderr "vestigia: address randomisation could not be \
      \turned off; runs would differ in layout, and so everywhere"
    exitWith (ExitFailure 2)
  -- QEMU's user mode runs the programs of one architecture
  isa <- machineOf prog
  qemu <- tool (oQemu o) ("VESTIGIA_QEMU_" <> fmap toUpper isa)
    ("qemu-" <> isa)
  plugin <- tool (oPlugin o) "VESTIGIA_PLUGIN" "libvestigia-qemu.so"
  -- QEMU maps the guest's libraries and heap in its own address
  -- space, wherever its own allocations leave room, and those vary
  -- with how its threads run: a second malloc arena, or a large block
  -- mapped rather than drawn from the heap, takes the room the
  -- guest's next mapping would have had, and under load one run lays
  -- out apart from another. One arena, and large blocks drawn from
  -- the heap, keep QEMU's allocations off the guest's mappings. The
  -- guest keeps its own setting of the variable, or has none
  environment <- getEnvironment
  let tunables = "GLIBC_TUNABLES"
      host = "glibc.malloc.arena_max=1:glibc.malloc.mmap_threshold="
        <> "33554432"
      own = lookup tunables environment
      guest = maybe [ "-U", tunables ]
        (\v -> [ "-E", tunables <> "=" <> v ]) own
      others = filter ((/= tunables) . fst) environment
  r <- try (withCreateProcess
         ((proc qemu (guest
                     <> [ "-seed", "0"
                        , "-plugin", plugin <> ",out=" <> dump, prog ]
                     <> progArgs))
            { P.env = Just ((tunables, host) : others) })
         (\_ _ _ ph -> waitForProcess ph))
  case r of
    Left e -> do
      hPutStrLn stderr ("vestigia: cannot run " <> qemu <> ": "
        <> show (e :: IOException))
      exitWith (ExitFailure 2)
    Right c -> do
      -- how the run was made, by which diff tells runs that differ
      -- in the secret alone from runs laid out apart: the guest's
      -- environment is QEMU's, with its own tunables restored
      appendRun dump (prog : progArgs)
        (others <> [ (tunables, v) | Just v <- [ own ] ]) c
      exitWith c

-- the architecture an ELF program is built for, as QEMU names its
-- user-mode emulators: the header's machine, at byte 18
machineOf :: FilePath -> IO String
machineOf prog = do
  r <- try (withBinaryFile prog ReadMode (\h -> BS.hGet h 20))
  case fmap BS.unpack r of
    Right (0x7f : 0x45 : 0x4c : 0x46 : _ : 1 : rest)
      | [ 0x3e, 0 ] <- drop 12 rest -> pure "x86_64"
      | [ 0xb7, 0 ] <- drop 12 rest -> pure "aarch64"
    Right _ -> unknown "not an x86_64 or aarch64 ELF program"
    Left e -> unknown (show (e :: IOException))
  where
    unknown why = do
      hPutStrLn stderr ("vestigia: " <> prog <> ": " <> why
        <> "; QEMU's user mode runs one")
      exitWith (ExitFailure 2)

-- append a run's record to its dump (Vestigia.Diff.readDump): its
-- arguments' bytes, its environment's variables and the bytes they
-- take, and its exit status
appendRun :: FilePath -> [String] -> [(String, String)] -> ExitCode
          -> IO ()
appendRun dump args env code = do
  enc <- getFileSystemEncoding
  let bytes s = GF.withCStringLen enc s BS.packCStringLen
  as <- traverse bytes args
  es <- traverse (\(k, v) -> bytes (k <> "=" <> v)) env
  appendFile dump $ unlines $
    [ unwords ("A" : [ concatMap byte (BS.unpack a) | not (BS.null a) ])
    | a <- as ]
    <> [ "N " <> showHex (length es) "" <> " "
           <> showHex (sum (fmap ((+ 1) . BS.length) es)) ""
       , "X " <> show (exitStatus code) ]
  where
    byte w = case showHex w "" of
      [ d ] -> [ '0', d ]
      ds -> ds

diff :: Opts -> [FilePath] -> IO ()
diff o paths = do
  addr2line <- tool (oAddr2line o) "VESTIGIA_ADDR2LINE" "addr2line"
  dumps <- traverse readOne paths
  controls <- traverse readOne (oControls o)
  designed <- traverse readOne (oDesigned o)
  -- every run with how it was made: the declared, the designed, then
  -- the controls. Runs made apart differ by more than the secret,
  -- and are refused, not compared
  named <- traverse (\(p, k, d) -> case dpRun d of
      Just r -> pure (p, Named (T.pack (takeFileName p)) k r)
      Nothing -> refuse (p <> " holds no record of how it was run \
        \(vestigia record appends one), so nothing says what it ran"))
    (zip3 (paths <> oDesigned o <> oControls o)
          (fmap (const DeclaredRun) paths
             <> fmap (const DesignedRun) (oDesigned o)
             <> fmap (const ControlRun) (oControls o))
          (dumps <> designed <> controls))
  case named of
    ((p0, first) : rest) -> for_ rest $ \(p, n) -> do
      for_ (runApart (nmRun first) (nmRun n)) $ \why ->
        refuse (p <> " " <> why <> " (" <> p0 <> "); runs compared \
          \must differ in the secret alone")
      when (nmKind n == ControlRun
              && rnArguments (nmRun n) /= rnArguments (nmRun first)) $
        refuse (p <> " is a control, but does not repeat the \
          \arguments of " <> p0 <> ", the run it controls")
    [] -> pure ()
  -- runs laid out apart differ wherever they touch memory, not by
  -- the secret: such runs are refused, not compared
  case zip paths dumps of
    ((p0, first) : _) -> case
        [ (p, obj, x, y)
        | (p, d) <- zip (paths <> oControls o <> oDesigned o)
                        (dumps <> controls <> designed)
        , (obj, x, y) <- take 1 (layoutApart first d) ] of
      ((p, obj, x, y) : _) -> do
        hPutStrLn stderr ("vestigia: " <> p <> " loaded "
          <> T.unpack obj <> " at 0x" <> showHex y "" <> " where "
          <> p0 <> " loaded it at 0x"
          <> showHex x "" <> "; runs laid out apart differ wherever \
             \they touch memory, not by the secret, and are not compared")
        exitWith (ExitFailure 2)
      [] -> pure ()
    [] -> pure ()
  let dv = restrictTo (oObjects o)
        (diffDesigned controls dumps designed)
  places <- symbolize addr2line
    [ (obj, inOffset i) | (_, i) <- dvOrigins dv
                        , Just obj <- [ inObject i ] ]
  let doc = encode (divergenceJson (T.pack (showVersion version))
        (fmap snd named) places dv)
  maybe (TIO.putStr doc) (\p -> TIO.writeFile p doc) (oOut o)
  TIO.hPutStr stderr (divergenceSummary places dv)
  where
    readOne p = do
      bytes <- BS.readFile p
      case readDump (TE.decodeUtf8With TEE.lenientDecode bytes) of
        Left e -> refuse (p <> ": " <> e)
        Right d -> pure d
    refuse e = do
      hPutStrLn stderr ("vestigia: " <> e)
      exitWith (ExitFailure 2)
