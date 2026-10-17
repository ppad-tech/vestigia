{-# OPTIONS_HADDOCK prune #-}
{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module: Vestigia.Json
-- Copyright: (c) 2026 Jared Tobin
-- License: MIT
-- Maintainer: Jared Tobin <jared@ppad.tech>
--
-- A JSON value and its encoding: enough to write a report, with
-- object keys in the order given.

module Vestigia.Json (
    Value(..)
  , encode
  ) where

import Data.Char (ord)
import qualified Data.Text as T
import Numeric (showHex)

-- | A JSON value. An object keeps its keys in the order given.
data Value =
    Null
  | Bool !Bool
  | Number !Integer
  | String !T.Text
  | Array ![Value]
  | Object ![(T.Text, Value)]
  deriving (Eq, Show)

-- | The value's encoding, indented two spaces per level.
--
-- >>> encode (Object [("a", Array [Number 1, Null])])
-- "{\n  \"a\": [\n    1,\n    null\n  ]\n}\n"
encode :: Value -> T.Text
encode v = go 0 v <> "\n"
  where
    go :: Int -> Value -> T.Text
    go d x = case x of
      Null -> "null"
      Bool b -> if b then "true" else "false"
      Number n -> T.pack (show n)
      String s -> str s
      Array [] -> "[]"
      Array xs -> "[\n" <> T.intercalate ",\n"
        [ pad (d + 1) <> go (d + 1) y | y <- xs ]
        <> "\n" <> pad d <> "]"
      Object [] -> "{}"
      Object kvs -> "{\n" <> T.intercalate ",\n"
        [ pad (d + 1) <> str k <> ": " <> go (d + 1) y
        | (k, y) <- kvs ]
        <> "\n" <> pad d <> "}"

    pad d = T.replicate (2 * d) " "

str :: T.Text -> T.Text
str s = "\"" <> T.concatMap esc s <> "\""
  where
    esc c = case c of
      '"' -> "\\\""
      '\\' -> "\\\\"
      '\n' -> "\\n"
      '\r' -> "\\r"
      '\t' -> "\\t"
      _ | ord c < 0x20 ->
            let h = showHex (ord c) ""
            in T.pack ("\\u" <> replicate (4 - length h) '0' <> h)
        | otherwise -> T.singleton c
