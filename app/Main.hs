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
import Control.Monad (unless)
import qualified Data.ByteString as BS
import Data.Version (showVersion)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Encoding.Error as TEE
import qualified Data.Text.IO as TIO
import System.Directory (getTemporaryDirectory, removeFile)
import System.Environment (getArgs, getEnvironment, lookupEnv)
import System.Exit (ExitCode(..), exitWith)
import System.IO (hClose, hPutStrLn, openTempFile, stderr)
import System.Process (proc, waitForProcess, withCreateProcess)
import qualified System.Process as P

import Paths_vestigia (version)
import Vestigia.Diff
  (diffDesigned, divergenceJson, divergenceSummary, dvOrigins,
   inObject, inOffset, readDump, restrictTo)
import Vestigia.Json (encode)
import Vestigia.Layout (fixLayout)
import Vestigia.Memcheck (readMemcheck)
import Vestigia.Symbol (symbolize)
import Vestigia.Trace
  (readObjects, trace, traceJson, traceSummary, withObjects)

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
      \-- PROGRAM [ARG...]"
    , "  vestigia read [--out FILE] FILE.xml"
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
    , ""
    , "record executes PROGRAM under QEMU with vestigia's plugin and"
    , "dumps its leakage trace per instruction; diff compares dumps"
    , "of runs that differ only in a secret and reports where they"
    , "diverge (vestigia/diff-v1), naming sources with addr2line."
    , "--object keeps origins in objects whose path contains TEXT;"
    , "--control names a run repeating the first run's secret, and"
    , "what differs in it is unsteady, not an origin."
    , "qemu, the plugin, and addr2line default to $VESTIGIA_QEMU,"
    , "$VESTIGIA_PLUGIN, and $VESTIGIA_ADDR2LINE."
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
-- the precise definedness checks optimised code needs, and no
-- leak report
memcheckArgs :: FilePath -> [String]
memcheckArgs xml =
  [ "--tool=memcheck"
  , "--xml=yes"
  , "--xml-file=" <> xml
  , "--track-origins=yes"
  , "--error-limit=no"
  , "--num-callers=24"
  , "--expensive-definedness-checks=yes"
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
  report o (Just (exitCode code)) os xml
  if temporary then removeFile xml else pure ()
  where
    exitCode c = case c of
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
      let tr = withObjects os (trace mc)
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
  unless fixed $ hPutStrLn stderr
    "vestigia: address randomisation is still on; runs may differ \
    \in layout, and so everywhere"
  qemu <- tool (oQemu o) "VESTIGIA_QEMU" "qemu-x86_64"
  plugin <- tool (oPlugin o) "VESTIGIA_PLUGIN" "libvestigia-qemu.so"
  r <- try (withCreateProcess
         (proc qemu ([ "-seed", "0"
                     , "-plugin", plugin <> ",out=" <> dump, prog ]
                     <> progArgs))
         (\_ _ _ ph -> waitForProcess ph))
  case r of
    Left e -> do
      hPutStrLn stderr ("vestigia: cannot run " <> qemu <> ": "
        <> show (e :: IOException))
      exitWith (ExitFailure 2)
    Right c -> exitWith c

diff :: Opts -> [FilePath] -> IO ()
diff o paths = do
  addr2line <- tool (oAddr2line o) "VESTIGIA_ADDR2LINE" "addr2line"
  dumps <- traverse readOne paths
  controls <- traverse readOne (oControls o)
  designed <- traverse readOne (oDesigned o)
  let dv = restrictTo (oObjects o)
        (diffDesigned controls dumps designed)
  places <- symbolize addr2line
    [ (obj, inOffset i) | (_, i) <- dvOrigins dv
                        , Just obj <- [ inObject i ] ]
  let doc = encode
        (divergenceJson (T.pack (showVersion version)) places dv)
  maybe (TIO.putStr doc) (\p -> TIO.writeFile p doc) (oOut o)
  TIO.hPutStr stderr (divergenceSummary places dv)
  where
    readOne p = do
      bytes <- BS.readFile p
      case readDump (TE.decodeUtf8With TEE.lenientDecode bytes) of
        Left e -> do
          hPutStrLn stderr ("vestigia: " <> p <> ": " <> e)
          exitWith (ExitFailure 2)
        Right d -> pure d
