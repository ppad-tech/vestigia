{-# LANGUAGE OverloadedStrings #-}

module Main (
    main
  ) where

import qualified Data.ByteString as BS
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Test.Tasty
import Test.Tasty.HUnit

import Vestigia.Json
import Vestigia.Memcheck
import Vestigia.Trace
import Vestigia.Xml

main :: IO ()
main = defaultMain $ testGroup "vestigia"
  [ xmlTests
  , memcheckTests
  , traceTests
  , jsonTests
  ]

xmlTests :: TestTree
xmlTests = testGroup "xml"
  [ testCase "elements, text, and entities" $
      parseDocument "<?xml version=\"1.0\"?>\n<a>\n <b>x &amp; \
                    \&lt;y&gt; &#65;&#x42;</b><c/></a>"
        @?= Right (Element "a"
              [ Text "\n ", Element "b" [ Text "x & <y> AB" ]
              , Element "c" [] ])

  , testCase "attributes and comments are skipped" $
      parseDocument "<!-- head --><a k=\"v>\" j='w'><!-- c --><b/></a>"
        @?= Right (Element "a" [ Element "b" [] ])

  , testCase "a mismatched close tag is refused" $
      isLeft (parseDocument "<a><b></a></b>") @? "accepted"

  , testCase "an unclosed element is refused" $
      isLeft (parseDocument "<a><b>text") @? "accepted"

  , testCase "an unknown entity is refused" $
      isLeft (parseDocument "<a>&nbsp;</a>") @? "accepted"
  ]

memcheckTests :: TestTree
memcheckTests = testGroup "memcheck"
  [ testCase "the probe run reads whole" $ do
      mc <- fixture "probe.xml"
      mcVersion mc @?= Just "3.26.0"
      mcFinished mc @?= True
      mcCommand mc @?= [ "./probe" ]
      fmap meKind (mcErrors mc) @?= [ "UninitValue", "UninitValue" ]
      fmap meCount (mcErrors mc) @?= [ 1, 1 ]
      case mcErrors mc of
        (e : _) -> do
          fmap frFn (meStack e) @?= [ Just "lookup", Just "main" ]
          fmap frLine (meStack e) @?= [ Just 16, Just 31 ]
          case meOrigin e of
            ClientRequest (o : _) -> frLine o @?= Just 30
            other -> assertFailure ("origin: " <> show other)
        [] -> assertFailure "no errors read"

  , testCase "a document from another tool is refused" $
      isLeft (readMemcheck "<valgrindoutput><protocoltool>helgrind\
                           \</protocoltool></valgrindoutput>")
        @? "accepted"
  ]

traceTests :: TestTree
traceTests = testGroup "trace"
  [ testCase "the probe's secret addresses are its sites" $ do
      tr <- trace <$> fixture "probe.xml"
      fmap (\s -> (siClass s, frFn (siFrame s), frLine (siFrame s)))
          (trSites tr)
        @?= [ (Address, Just "lookup", Just 16)
            , (Address, Just "main", Just 33) ]
      trUnrelated tr @?= []
      trFaults tr @?= []

  , testCase "only a secret's descendants are sites" $ do
      tr <- trace <$> either assertFailure pure (readMemcheck mixed)
      fmap (\s -> (siClass s, frIp (siFrame s), siCount s))
          (trSites tr)
        @?= [ (Control, 0x10, 5) ]
      fmap meKind (trUnrelated tr) @?= [ "UninitValue" ]
      fmap meKind (trFaults tr) @?= [ "InvalidRead" ]

  , testCase "one site per instruction, whatever called it" $ do
      tr <- trace <$> either assertFailure pure (readMemcheck twoCallers)
      fmap (\s -> (frIp (siFrame s), siCount s, length (siStacks s)))
          (trSites tr)
        @?= [ (0x10, 7, 2) ]
  ]

jsonTests :: TestTree
jsonTests = testGroup "json"
  [ testCase "objects keep their order and strings escape" $
      encode (Object [ ("b", Number 1)
                     , ("a", String "q\"\n\1") ])
        @?= "{\n  \"b\": 1,\n  \"a\": \"q\\\"\\n\\u0001\"\n}\n"
  ]

fixture :: FilePath -> IO Memcheck
fixture f = do
  b <- BS.readFile ("test/fixtures/" <> f)
  either assertFailure pure (readMemcheck (TE.decodeUtf8 b))

isLeft :: Either a b -> Bool
isLeft e = case e of
  Left _ -> True
  Right _ -> False

-- a secret branch, an uninitialised heap read, a bad read, and a
-- leak report
mixed :: T.Text
mixed = doc
  [ err "0x0" "UninitCondition" "0x10"
      (Just "Uninitialised value was created by a client request")
  , err "0x1" "UninitValue" "0x20"
      (Just "Uninitialised value was created by a heap allocation")
  , err "0x2" "InvalidRead" "0x30" Nothing
  , err "0x3" "Leak_PossiblyLost" "0x40" Nothing
  ]
  [ ("0x0", 5), ("0x1", 1), ("0x2", 1) ]

-- one secret branch reached by two callers
twoCallers :: T.Text
twoCallers = doc
  [ errStack "0x0" "UninitCondition" [ "0x10", "0x40" ]
  , errStack "0x1" "UninitCondition" [ "0x10", "0x50" ]
  ]
  [ ("0x0", 3), ("0x1", 4) ]
  where
    errStack u k ips = T.concat
      [ "<error><unique>", u, "</unique><kind>", k, "</kind>"
      , "<what>w</what><stack>"
      , T.concat [ "<frame><ip>" <> ip <> "</ip></frame>" | ip <- ips ]
      , "</stack><auxwhat>Uninitialised value was created by a \
        \client request</auxwhat><stack><frame><ip>0x1</ip>\
        \</frame></stack></error>" ]

doc :: [T.Text] -> [(T.Text, Int)] -> T.Text
doc errs counts = T.concat $
  [ "<?xml version=\"1.0\"?><valgrindoutput>"
  , "<protocolversion>6</protocolversion>"
  , "<protocoltool>memcheck</protocoltool>" ]
  <> errs
  <> [ "<errorcounts>" ]
  <> [ "<pair><count>" <> T.pack (show n) <> "</count><unique>" <> u
       <> "</unique></pair>" | (u, n) <- counts ]
  <> [ "</errorcounts></valgrindoutput>" ]

err :: T.Text -> T.Text -> T.Text -> Maybe T.Text -> T.Text
err u k ip morigin = T.concat $
  [ "<error><unique>", u, "</unique><kind>", k, "</kind>"
  , "<what>w</what><stack><frame><ip>", ip, "</ip></frame></stack>" ]
  <> case morigin of
       Just o -> [ "<auxwhat>", o, "</auxwhat><stack><frame><ip>0x1"
                 , "</ip></frame></stack>" ]
       Nothing -> []
  <> [ "</error>" ]
