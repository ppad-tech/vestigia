{-# OPTIONS_HADDOCK prune #-}
{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module: Vestigia.Symbol
-- Copyright: (c) 2026 Jared Tobin
-- License: MIT
-- Maintainer: Jared Tobin <jared@ppad.tech>
--
-- Naming an instruction by its source: an addr2line over an
-- object's debug information, inlined frames included, at the
-- instruction's address in the object (where the object's program
-- headers place it, as its disassembly does). LLVM's names each
-- inlined frame by its own function, and an address no symbol covers
-- by none, where binutils' gives the innermost frame the name of the
-- function it was inlined into, and code without debug information
-- (a GHC program's) the name of whatever function precedes it. LLVM
-- leaves a legacy Rust symbol as an Itanium demangler does, its
-- escapes and hash in place, which are undone here.

module Vestigia.Symbol (
    Place(..)
  , symbolize
  , parseAddr2line
  , rustLegacy
  ) where

import Control.Exception (IOException, try)
import Data.Char (chr, isHexDigit)
import qualified Data.Map.Strict as M
import qualified Data.Text as T
import Numeric (readHex, showHex)
import System.Process (readProcess)
import Text.Read (readMaybe)

-- | One frame of a source location: the function and, where the
--   debug information has it, the file and line. The innermost
--   frame comes first.
data Place = Place {
    plFunction :: !(Maybe T.Text)
  , plFile :: !(Maybe T.Text)
  , plLine :: !(Maybe Int)
  } deriving (Eq, Show)

-- | The source of each address, per object, by one addr2line call
--   per object. An object addr2line cannot read names nothing.
symbolize
  :: FilePath -> [(T.Text, Integer)]
  -> IO (M.Map (T.Text, Integer) [Place])
symbolize addr2line keys = do
  let byObject = M.fromListWith (<>) [ (o, [ off ]) | (o, off) <- keys ]
  parts <- traverse one (M.toList byObject)
  pure (M.unions parts)
  where
    one (obj, offs) = do
      r <- try (readProcess addr2line
             [ "-a", "-f", "-i", "-C", "-e", T.unpack obj ]
             (unlines [ "0x" <> showHex o "" | o <- offs ]))
             :: IO (Either IOException String)
      pure $ case r of
        Left _ -> M.empty
        Right out -> M.fromList
          [ ((obj, a), ps) | (a, ps) <- parseAddr2line (T.pack out) ]

-- | addr2line's output under @-a -f -i@: an address line, then a
--   function line and a location line per frame.
--
-- >>> parseAddr2line "0x20\n??\n??:0\n"
-- [(32,[Place Nothing Nothing Nothing])]
parseAddr2line :: T.Text -> [(Integer, [Place])]
parseAddr2line = go . T.lines
  where
    go ls = case ls of
      (a : rest) | Just addr <- address a ->
        let (body, more) = break (\l -> address l /= Nothing) rest
        in (addr, frames body) : go more
      (_ : rest) -> go rest
      [] -> []

    address :: T.Text -> Maybe Integer
    address l = case T.stripPrefix "0x" l of
      Just h | not (T.null h), [ (v, "") ] <- readHex (T.unpack h) ->
        Just v
      _ -> Nothing

    frames ls = case ls of
      (f : loc : rest) -> place f loc : frames rest
      _ -> []

    place f loc =
      let (file, line) = location loc
      in Place {
             plFunction = if f == "??" then Nothing else Just (rustLegacy f)
           , plFile = file
           , plLine = line
           }

    -- "path:line", "path:line (discriminator n)", or "??:0"
    location loc =
      let l = T.takeWhile (/= ' ') loc
          (p, n) = T.breakOnEnd ":" l
          path = T.dropEnd 1 p
      in ( if T.null path || path == "??" then Nothing else Just path
         , case readMaybe (T.unpack n) of
             Just 0 -> Nothing
             other -> other )

-- | A legacy Rust symbol, as an Itanium demangler leaves it, as
--   rustc-demangle gives it: its hash dropped, each path segment's
--   escapes undone. Any other name is left as it is.
--
-- >>> rustLegacy "a::_$LT$impl$u20$b..C$GT$::f::h346fee1681a4f34f"
-- "a::<impl b::C>::f"
rustLegacy :: T.Text -> T.Text
rustLegacy t = case T.breakOnEnd "::" t of
  (pre, h) | not (T.null pre), hash h ->
    T.intercalate "::"
      (fmap segment (T.splitOn "::" (T.dropEnd 2 pre)))
  _ -> t
  where
    hash h = case T.uncons h of
      Just ('h', ds) -> T.length ds == 16 && T.all isHexDigit ds
      _ -> False
    segment g = T.pack (unescape (T.unpack
      (maybe g ("$" <>) (T.stripPrefix "_$" g))))
    unescape cs = case cs of
      '$' : rest
        | (code, '$' : more) <- break (== '$') rest
        , Just r <- escape code -> r <> unescape more
      '.' : '.' : more -> "::" <> unescape more
      c : more -> c : unescape more
      [] -> []
    escape code = case code of
      "SP" -> Just "@"
      "BP" -> Just "*"
      "RF" -> Just "&"
      "LT" -> Just "<"
      "GT" -> Just ">"
      "LP" -> Just "("
      "RP" -> Just ")"
      "C" -> Just ","
      'u' : h | [ (n, "") ] <- readHex h -> Just [ chr n ]
      _ -> Nothing
