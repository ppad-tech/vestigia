{-# OPTIONS_HADDOCK prune #-}
{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module: Vestigia.Xml
-- Copyright: (c) 2026 Jared Tobin
-- License: MIT
-- Maintainer: Jared Tobin <jared@ppad.tech>
--
-- A reader for the XML memcheck writes: elements and text, with
-- the declaration, comments, and attributes skipped and the
-- standard entities decoded. It is not a general XML parser, and
-- refuses what it does not understand rather than guessing.

module Vestigia.Xml (
    Node(..)
  , parseDocument
  , children
  , child
  , textOf
  ) where

import Data.Char (chr, isAlphaNum, isDigit, isHexDigit, isSpace)
import qualified Data.Text as T
import Numeric (readDec, readHex)

-- | An element (its name and contents) or a run of text.
data Node =
    Element !T.Text ![Node]
  | Text !T.Text
  deriving (Eq, Show)

-- | The document's root element.
--
-- >>> parseDocument "<?xml version=\"1.0\"?><a><b>x &amp; y</b></a>"
-- Right (Element "a" [Element "b" [Text "x & y"]])
parseDocument :: T.Text -> Either String Node
parseDocument t = do
  (root, rest) <- element (misc t)
  if T.null (misc rest)
    then pure root
    else Left "trailing content after the root element"

-- | The child elements of a node with the given name.
children :: T.Text -> Node -> [Node]
children name n = case n of
  Element _ cs -> [ c | c@(Element m _) <- cs, m == name ]
  Text _ -> []

-- | The first child element with the given name.
child :: T.Text -> Node -> Maybe Node
child name n = case children name n of
  (c : _) -> Just c
  [] -> Nothing

-- | The text a node holds, stripped.
textOf :: Node -> T.Text
textOf n = case n of
  Text t -> T.strip t
  Element _ cs -> T.strip (T.concat [ t | Text t <- cs ])

-- whitespace, the declaration, comments, and a doctype
misc :: T.Text -> T.Text
misc t0 =
  let t = T.dropWhile isSpace t0
  in if "<?" `T.isPrefixOf` t then misc (after "?>" t)
     else if "<!--" `T.isPrefixOf` t then misc (after "-->" t)
     else if "<!" `T.isPrefixOf` t then misc (after ">" t)
     else t

after :: T.Text -> T.Text -> T.Text
after delim t = T.drop (T.length delim) (snd (T.breakOn delim t))

element :: T.Text -> Either String (Node, T.Text)
element t0 = case T.uncons t0 of
  Just ('<', t1) -> do
    let (name, t2) = T.span nameChar t1
    if T.null name then Left "an element without a name" else do
      let t3 = skipAttributes t2
      if "/>" `T.isPrefixOf` t3
        then pure (Element name [], T.drop 2 t3)
        else case T.uncons t3 of
          Just ('>', t4) -> do
            (cs, t5) <- content name t4 []
            pure (Element name (reverse cs), t5)
          _ -> Left ("malformed start tag: " <> T.unpack name)
  _ -> Left "expected an element"

-- attributes carry nothing memcheck's reader needs
skipAttributes :: T.Text -> T.Text
skipAttributes t = case T.uncons (T.dropWhile isSpace t) of
  Just (c, _) | c == '>' || c == '/' -> T.dropWhile isSpace t
  Just _ ->
    let t1 = T.dropWhile (\c -> c /= '"' && c /= '>' && c /= '/')
               (T.dropWhile isSpace t)
    in case T.uncons t1 of
         Just ('"', t2) ->
           skipAttributes (T.drop 1 (T.dropWhile (/= '"') t2))
         _ -> t1
  Nothing -> t

content
  :: T.Text -> T.Text -> [Node] -> Either String ([Node], T.Text)
content name t acc
  | T.null t = Left ("unclosed element: " <> T.unpack name)
  | "</" `T.isPrefixOf` t =
      let (close, rest) = T.span nameChar (T.drop 2 t)
          rest' = T.dropWhile isSpace rest
      in if close /= name
           then Left ("mismatched close tag: " <> T.unpack close)
           else case T.uncons rest' of
             Just ('>', r) -> pure (acc, r)
             _ -> Left ("malformed close tag: " <> T.unpack close)
  | "<!--" `T.isPrefixOf` t = content name (after "-->" t) acc
  | "<" `T.isPrefixOf` t = do
      (n, rest) <- element t
      content name rest (n : acc)
  | otherwise = do
      let (raw, rest) = T.break (== '<') t
      txt <- entities raw
      content name rest (Text txt : acc)

nameChar :: Char -> Bool
nameChar c = isAlphaNum c || c == '_' || c == '-' || c == '.'
  || c == ':'

entities :: T.Text -> Either String T.Text
entities t = case T.breakOn "&" t of
  (pre, rest)
    | T.null rest -> pure pre
    | otherwise -> do
        let (ent, rest') = T.breakOn ";" (T.drop 1 rest)
        if T.null rest' then Left "an unterminated entity" else do
          c <- entity ent
          more <- entities (T.drop 1 rest')
          pure (pre <> T.singleton c <> more)

entity :: T.Text -> Either String Char
entity e = case T.unpack e of
  "amp" -> pure '&'
  "lt" -> pure '<'
  "gt" -> pure '>'
  "quot" -> pure '"'
  "apos" -> pure '\''
  ('#' : 'x' : hs) | not (null hs), all isHexDigit hs ->
    code (readHex hs)
  ('#' : ds) | not (null ds), all isDigit ds -> code (readDec ds)
  _ -> Left ("an unknown entity: &" <> T.unpack e <> ";")
  where
    code rs = case rs of
      [ (n, "") ] | n <= 0x10FFFF -> pure (chr n)
      _ -> Left ("a malformed character reference: " <> T.unpack e)
