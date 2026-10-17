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
import qualified Data.ByteString as BS
import Data.Version (showVersion)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Encoding.Error as TEE
import qualified Data.Text.IO as TIO
import System.Directory (getTemporaryDirectory, removeFile)
import System.Environment (getArgs, lookupEnv)
import System.Exit (ExitCode(..), exitWith)
import System.IO (hClose, hPutStrLn, openTempFile, stderr)
import System.Process (proc, waitForProcess, withCreateProcess)

import Paths_vestigia (version)
import Vestigia.Json (encode)
import Vestigia.Memcheck (readMemcheck)
import Vestigia.Trace (trace, traceJson, traceSummary)

data Opts = Opts {
    oValgrind :: !(Maybe FilePath)
  , oXml :: !(Maybe FilePath)
  , oOut :: !(Maybe FilePath)
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
    , ""
    , "run executes PROGRAM under memcheck, which reports every"
    , "branch and address that depended on bytes the program marked"
    , "secret (vestigia.h), and writes the report (vestigia/trace-v1)."
    , "valgrind is --valgrind, else $VESTIGIA_VALGRIND, else on PATH."
    ]
  exitWith (ExitFailure 2)

-- options before the program; "--" ends them
options :: [String] -> Either String (Opts, [String])
options = go (Opts Nothing Nothing Nothing)
  where
    go o xs = case xs of
      ("--" : rest) -> Right (o, rest)
      ("--valgrind" : p : rest) -> go o { oValgrind = Just p } rest
      ("--xml" : p : rest) -> go o { oXml = Just p } rest
      ("--out" : p : rest) -> go o { oOut = Just p } rest
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
  r <- try (withCreateProcess
         (proc valgrind (memcheckArgs xml <> (prog : progArgs)))
         (\_ _ _ ph -> waitForProcess ph))
  code <- case r of
    Left e -> do
      hPutStrLn stderr ("vestigia: cannot run " <> valgrind <> ": "
        <> show (e :: IOException))
      exitWith (ExitFailure 2)
    Right c -> pure c
  report o (Just (exitCode code)) xml
  if temporary then removeFile xml else pure ()
  where
    exitCode c = case c of
      ExitSuccess -> 0
      ExitFailure n -> n

readXml :: Opts -> FilePath -> IO ()
readXml o xml = report o Nothing xml

report :: Opts -> Maybe Int -> FilePath -> IO ()
report o exit xml = do
  bytes <- BS.readFile xml
  let txt = TE.decodeUtf8With TEE.lenientDecode bytes
  case readMemcheck txt of
    Left e -> do
      hPutStrLn stderr ("vestigia: " <> xml <> ": " <> e)
      exitWith (ExitFailure 2)
    Right mc -> do
      let tr = trace mc
          doc = encode
            (traceJson (T.pack (showVersion version)) exit tr)
      maybe (TIO.putStr doc) (\p -> TIO.writeFile p doc) (oOut o)
      TIO.hPutStr stderr (traceSummary tr)
