{-# OPTIONS_HADDOCK prune #-}
{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module: Vestigia.Memcheck
-- Copyright: (c) 2026 Jared Tobin
-- License: MIT
-- Maintainer: Jared Tobin <jared@ppad.tech>
--
-- What a memcheck run reported, read from its XML (protocol
-- version 4 and later): each error context with its kind, its
-- stack, the origin of the undefined value where memcheck tracked
-- one, and how many times it occurred.

module Vestigia.Memcheck (
    Frame(..)
  , Origin(..)
  , MemError(..)
  , Memcheck(..)
  , readMemcheck
  ) where

import qualified Data.Map.Strict as M
import Data.Maybe (fromMaybe)
import qualified Data.Text as T
import Numeric (readHex)
import Text.Read (readMaybe)

import Vestigia.Xml

-- | One stack frame: the instruction address, and what debug
--   information says of it.
data Frame = Frame {
    frIp :: !Integer
  , frObj :: !(Maybe T.Text)
  , frFn :: !(Maybe T.Text)
  , frFile :: !(Maybe T.Text)
  , frLine :: !(Maybe Int)
  } deriving (Eq, Show)

-- | Where an undefined value came from: a client request (the
--   harness's mark on a secret), something else memcheck named
--   (an allocation, an uninitialised stack slot), or nothing
--   tracked.
data Origin =
    ClientRequest ![Frame]
  | OtherOrigin !T.Text ![Frame]
  | NoOrigin
  deriving (Eq, Show)

-- | One error context.
data MemError = MemError {
    meKind :: !T.Text
  , meWhat :: !T.Text
  , meStack :: ![Frame]
  , meOrigin :: !Origin
  , meCount :: !Int
  } deriving (Eq, Show)

-- | A run: the tool's version, the command it ran, whether it
--   finished, and its errors in the order reported.
data Memcheck = Memcheck {
    mcVersion :: !(Maybe T.Text)
  , mcCommand :: ![T.Text]
  , mcFinished :: !Bool
  , mcErrors :: ![MemError]
  } deriving (Eq, Show)

-- | Read a memcheck XML document.
readMemcheck :: T.Text -> Either String Memcheck
readMemcheck t = do
  root <- parseDocument t
  case root of
    Element "valgrindoutput" _ -> pure ()
    _ -> Left "not a valgrind XML document"
  case fmap textOf (child "protocoltool" root) of
    Just "memcheck" -> pure ()
    other -> Left ("not a memcheck run: " <> show other)
  let counts = M.fromList
        [ (textOf u, n)
        | ec <- children "errorcounts" root
        , p <- children "pair" ec
        , Just u <- [ child "unique" p ]
        , Just c <- [ child "count" p ]
        , Just n <- [ readMaybe (T.unpack (textOf c)) ]
        ]
  errs <- traverse (memError counts) (children "error" root)
  pure Memcheck {
      mcVersion = version root
    , mcCommand =
        [ textOf x
        | as <- children "args" root
        , av <- children "argv" as
        , x <- elementsOf av ]
    , mcFinished = any ((== "FINISHED") . textOf)
        [ s | st <- children "status" root
            , s <- children "state" st ]
    , mcErrors = errs
    }
  where
    elementsOf n = case n of
      Element _ cs -> [ c | c@(Element m _) <- cs
                          , m == "exe" || m == "arg" ]
      Text _ -> []

    -- "Using Valgrind-3.26.0 and LibVEX; ..."
    version root = case
      [ v
      | pre <- children "preamble" root
      , l <- children "line" pre
      , let w = textOf l
      , "Using Valgrind-" `T.isPrefixOf` w
      , let v = T.takeWhile (/= ' ') (T.drop 15 w) ] of
        (v : _) -> Just v
        [] -> Nothing

memError :: M.Map T.Text Int -> Node -> Either String MemError
memError counts n = do
  kind <- need "kind"
  let what = maybe "" textOf (child "what" n)
      stacks = children "stack" n
      unique = maybe "" textOf (child "unique" n)
  stack <- case stacks of
    (s : _) -> traverse frame (children "frame" s)
    [] -> pure []
  -- the origin is the auxwhat that names it, and the stack that
  -- follows it
  origin <- case (originText, drop 1 stacks) of
    (Just w, (s : _)) -> do
      fs <- traverse frame (children "frame" s)
      pure (if "client request" `T.isInfixOf` w
              then ClientRequest fs
              else OtherOrigin w fs)
    (Just w, []) -> pure (OtherOrigin w [])
    (Nothing, _) -> pure NoOrigin
  pure MemError {
      meKind = kind
    , meWhat = what
    , meStack = stack
    , meOrigin = origin
    , meCount = fromMaybe 1 (M.lookup unique counts)
    }
  where
    need k = maybe (Left ("an error without " <> T.unpack k)) (pure
      . textOf) (child k n)
    originText = case
      [ w | a <- children "auxwhat" n
          , let w = textOf a
          , "was created by" `T.isInfixOf` w ] of
        (w : _) -> Just w
        [] -> Nothing

frame :: Node -> Either String Frame
frame n = do
  ip <- case fmap textOf (child "ip" n) of
    Just t | Just v <- hex t -> pure v
    other -> Left ("a frame without an address: " <> show other)
  pure Frame {
      frIp = ip
    , frObj = field "obj"
    , frFn = field "fn"
    , frFile = case (field "dir", field "file") of
        (Just d, Just f) -> Just (d <> "/" <> f)
        (Nothing, Just f) -> Just f
        _ -> Nothing
    , frLine = field "line" >>= readMaybe . T.unpack
    }
  where
    field k = fmap textOf (child k n)
    hex t = case readHex (T.unpack (stripPrefix0x t)) of
      [ (v, "") ] -> Just v
      _ -> Nothing
    stripPrefix0x t = fromMaybe t (T.stripPrefix "0x" t)
