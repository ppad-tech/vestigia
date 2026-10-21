{-# LANGUAGE OverloadedStrings #-}

module Main (
    main
  ) where

import qualified Data.ByteString as BS
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Test.Tasty
import Test.Tasty.HUnit

import Vestigia.Diff
import Vestigia.Json
import Vestigia.Memcheck
import Vestigia.Symbol
import Vestigia.Trace
import Vestigia.Xml

main :: IO ()
main = defaultMain $ testGroup "vestigia"
  [ xmlTests
  , memcheckTests
  , traceTests
  , diffTests
  , symbolTests
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

  , testCase "a frame is named by its address in its object" $ do
      os <- either assertFailure pure
        (readObjects "4000000 /nix/store/x-lib/lib/liba.so\n\
                     \0 /nix/store/y-h/bin/harness\n")
      let f o i = Frame i (Just o) Nothing Nothing Nothing
      objectOffset os (f "/nix/store/x-lib/lib/liba.so" 0x4001234)
        @?= Just 0x1234
      -- the same file reached by another path
      objectOffset os (f "/other/liba.so" 0x4000010) @?= Just 0x10
      objectOffset os (f "/nix/store/y-h/bin/harness" 0x401000)
        @?= Just 0x401000
      objectOffset os (f "/lib/libc.so.6" 0x7000) @?= Nothing

  , testCase "a site is kept to the objects named" $ do
      tr <- trace <$> fixture "probe.xml"
      length (trSites (sitesIn [ "probe" ] tr)) @?= 2
      trSites (sitesIn [ "libc" ] tr) @?= []
      length (trSites (sitesIn [] tr)) @?= 2

  , testCase "one site per instruction, whatever called it" $ do
      tr <- trace <$> either assertFailure pure (readMemcheck twoCallers)
      fmap (\s -> (frIp (siFrame s), siCount s, length (siStacks s)))
          (trSites tr)
        @?= [ (0x10, 7, 2) ]
  ]

diffTests :: TestTree
diffTests = testGroup "diff"
  [ testCase "a dump reads whole" $ do
      d <- either assertFailure pure (readDump dumpA)
      fmap inCount (dpInsns d) @?= M.fromList
        [ (0x10, 4), (0x20, 4), (0x30, 2), (0x40, 1) ]
      M.lookup 0x10 (fmap inObject (dpInsns d)) @?= Just (Just "/lib.so")
      dpTransfers d @?= M.fromList
        [ (0x10, M.fromList [ (0x30, 2) ]) ]

  , testCase "a run's objects are where its instructions put them" $ do
      a <- either assertFailure pure (readDump dumpA)
      loadBases a @?= M.fromList [ ("/lib.so", 0) ]
      -- the same run with /lib.so loaded 0x1000 higher
      b <- either assertFailure pure (readDump (T.unlines
        [ "I 1010 4 0 aaaa 0 /lib.so 10", "E 1010 1030 2"
        , "I 1020 4 4 bbbb 0 /lib.so 20", "I 1030 2 0 cccc 0 /lib.so 30"
        , "I 1040 1 1 dddd 0 /lib.so 40" ]))
      loadBases b @?= M.fromList [ ("/lib.so", 0x1000) ]
      layoutApart a b @?= [ ("/lib.so", 0, 0x1000) ]
      layoutApart a a @?= []

  , testCase "origins are where steady instructions differ" $ do
      a <- either assertFailure pure (readDump dumpA)
      b <- either assertFailure pure (readDump dumpB)
      let dv = diffDumps [ a, b ]
      fmap (\(o, i) -> (o, inPc i)) (dvOrigins dv)
        @?= [ (ControlOrigin, 0x10), (AddressOrigin, 0x20) ]
      fmap inPc (dvDownstream dv) @?= [ 0x30 ]

  , testCase "a loop the secret sets is an origin" $ do
      a <- either assertFailure pure (readDump loopA)
      b <- either assertFailure pure (readDump loopB)
      let dv = diffDumps [ a, b ]
      fmap (\(o, i) -> (o, inPc i)) (dvOrigins dv)
        @?= [ (ControlOrigin, 0x10) ]
      fmap inPc (dvDownstream dv) @?= [ 0x14, 0x18 ]

  , testCase "a branch downstream, always taken, is no origin" $ do
      a <- either assertFailure pure (readDump loopA)
      b <- either assertFailure pure (readDump loopB)
      let dv = diffDumps [ a, b ]
      notElem 0x18 (fmap (inPc . snd) (dvOrigins dv))
        @? "a branch that always jumps is not secret-dependent"

  , testCase "what differs without the secret is unsteady" $ do
      a <- either assertFailure pure (readDump dumpA)
      b <- either assertFailure pure (readDump dumpB)
      -- a repeat of A whose 0x20 touched other addresses: an
      -- entropy source, not the secret
      c <- either assertFailure pure (readDump (T.unlines
        [ "I 10 4 0 aaaa 0 /lib.so 10", "E 10 30 2"
        , "I 20 4 4 ffff 0 /lib.so 20", "I 30 2 0 cccc 0 /lib.so 30"
        , "I 40 1 1 dddd 0 /lib.so 40" ]))
      let dv = diffControlled [ c ] [ a, b ]
      fmap (\(o, i) -> (o, inPc i)) (dvOrigins dv)
        @?= [ (ControlOrigin, 0x10) ]
      fmap inPc (dvUnsteady dv) @?= [ 0x20 ]

  , testCase "a designed run moves control, not addresses" $ do
      a <- either assertFailure pure (readDump dumpA)
      b <- either assertFailure pure (readDump dumpB)
      -- a run designed onto another path: 0x10 taken every time, and
      -- 0x20's addresses its own
      x <- either assertFailure pure (readDump (T.unlines
        [ "I 10 4 0 aaaa 0 /lib.so 10", "E 10 30 4"
        , "I 20 4 4 9999 0 /lib.so 20", "I 30 4 0 cccc 0 /lib.so 30"
        , "I 50 1 0 eeee 0 /lib.so 50" ]))
      let dv = diffDesigned [] [ a, a ] [ x ]
      fmap (\(o, i) -> (o, inPc i)) (dvOrigins dv)
        @?= [ (ControlOrigin, 0x10) ]
      dvDesigned dv @?= 1
      M.lookup "/lib.so" (dvExecuted dv)
        @?= Just (S.fromList [ 0x10, 0x20, 0x30, 0x40, 0x50 ])
      -- a declared run differing there is still an address origin
      fmap (\(o, i) -> (o, inPc i)) (dvOrigins (diffDesigned [] [ a, b ]
        [ x ])) @?= [ (ControlOrigin, 0x10), (AddressOrigin, 0x20) ]

  , testCase "an origin names the runs alike at it" $ do
      a <- either assertFailure pure (readDump dumpA)
      b <- either assertFailure pure (readDump dumpB)
      x <- either assertFailure pure (readDump (T.unlines
        [ "I 10 4 0 aaaa 0 /lib.so 10", "E 10 30 4"
        , "I 20 4 4 9999 0 /lib.so 20", "I 30 4 0 cccc 0 /lib.so 30" ]))
      -- at the branch, the first and third runs alike; the designed
      -- run is a control origin's to group, and the address origin
      -- speaks only of the declared runs
      let dv = diffDesigned [] [ a, b, a ] [ x ]
      M.lookup (ControlOrigin, 0x10) (dvBehaviour dv)
        @?= Just ([ [ 0, 2 ], [ 1 ], [ 3 ] ], [])
      M.lookup (AddressOrigin, 0x20) (dvBehaviour dv)
        @?= Just ([ [ 0, 2 ], [ 1 ] ], [])
      -- the designed run never reaches 0x40
      M.lookup (ControlOrigin, 0x10)
        (dvBehaviour (diffDesigned [] [ a, a ] [ x ]))
        @?= Just ([ [ 0, 1 ], [ 2 ] ], [])

  , testCase "downstream is kept to the objects under audit" $ do
      a <- either assertFailure pure (readDump dumpA)
      b <- either assertFailure pure (readDump (T.unlines
        [ "I 10 4 0 aaaa 0 /lib.so 10", "E 10 30 3"
        , "I 20 4 4 bbbb 0 /lib.so 20", "I 30 3 0 cccc 0 /lib.so 30"
        , "I 40 1 1 dddd 0 /lib.so 40", "I 60 2 0 ffff 0 /libc.so 60" ]))
      let dv = diffDumps [ a, b ]
      fmap inPc (dvDownstream dv) @?= [ 0x30, 0x60 ]
      fmap inPc (dvDownstream (restrictTo [ "lib.so" ] dv))
        @?= [ 0x30 ]

  , testCase "a branch taken as often, in another order, is an origin" $ do
      -- 0x10 runs twice and falls through once and jumps once in both
      -- runs, but in the other order
      a <- either assertFailure pure (readDump (T.unlines
        [ "I 10 2 0 aaaa 1111 /lib.so 10", "E 10 30 1"
        , "I 20 1 0 bbbb 0 /lib.so 20", "I 30 1 0 cccc 0 /lib.so 30" ]))
      b <- either assertFailure pure (readDump (T.unlines
        [ "I 10 2 0 aaaa 2222 /lib.so 10", "E 10 30 1"
        , "I 20 1 0 bbbb 0 /lib.so 20", "I 30 1 0 cccc 0 /lib.so 30" ]))
      fmap (\(o, i) -> (o, inPc i)) (dvOrigins (diffDumps [ a, b ]))
        @?= [ (ControlOrigin, 0x10) ]
      M.lookup (ControlOrigin, 0x10) (dvBehaviour (diffDumps [ a, b, a ]))
        @?= Just ([ [ 0, 2 ], [ 1 ] ], [])
      -- in the same order, nothing
      dvOrigins (diffDumps [ a, a ]) @?= []

  , testCase "a return goes where its call sent it: downstream" $ do
      -- 0x50 returns four times in each run, to 0x30 twice in A and
      -- three times in B, as the branch at 0x10 sent it
      a <- either assertFailure pure (readDump (dumpA <> T.unlines
        [ "I 50 4 0 aaaa 0 /lib.so 50", "R 50", "E 50 30 2"
        , "E 50 60 2" ]))
      b <- either assertFailure pure (readDump (dumpB <> T.unlines
        [ "I 50 4 0 aaaa 0 /lib.so 50", "R 50", "E 50 30 3"
        , "E 50 60 1" ]))
      let dv = diffDumps [ a, b ]
      fmap (\(o, i) -> (o, inPc i)) (dvOrigins dv)
        @?= [ (ControlOrigin, 0x10), (AddressOrigin, 0x20) ]
      fmap inPc (dvDownstream dv) @?= [ 0x30, 0x50 ]

  , testCase "a division on other operands is an operand origin" $ do
      -- 0x40 divides once in every run, on other operands in B; in a
      -- designed run, on others again
      a <- either assertFailure pure (readDump (dumpA <> "D 40 1111\n"))
      b <- either assertFailure pure (readDump (dumpB <> "D 40 2222\n"))
      x <- either assertFailure pure (readDump (dumpA <> "D 40 3333\n"))
      let dv = diffDumps [ a, b ]
      fmap (\(o, i) -> (o, inPc i)) (dvOrigins dv)
        @?= [ (ControlOrigin, 0x10), (AddressOrigin, 0x20)
            , (OperandOrigin, 0x40) ]
      M.lookup (OperandOrigin, 0x40) (dvBehaviour (diffDumps [ a, b, a ]))
        @?= Just ([ [ 0, 2 ], [ 1 ] ], [])
      notElem 0x40 (fmap inPc (dvDownstream dv)) @? "downstream"
      -- a designed run's operands say nothing of the secret
      fmap (\(o, i) -> (o, inPc i)) (dvOrigins (diffDesigned [] [ a, a ]
        [ x ])) @?= []
      -- a control dividing other operands sets it apart as unsteady
      fmap inPc (dvUnsteady (diffControlled [ x ] [ a, b ])) @?= [ 0x40 ]

  , testCase "identical runs have no origins" $ do
      a <- either assertFailure pure (readDump dumpA)
      let dv = diffDumps [ a, a ]
      dvOrigins dv @?= []
      dvDownstream dv @?= []

  , testCase "what any run executed is kept per object" $ do
      a <- either assertFailure pure (readDump dumpA)
      b <- either assertFailure pure (readDump (T.unlines
        [ "I 10 4 0 aaaa 0 /lib.so 10", "I 50 1 0 eeee 0 /lib.so 50"
        , "I 60 1 0 ffff 0 /libc.so 60", "I 70 0 0 0000 0 /lib.so 70" ]))
      let dv = diffDumps [ a, b ]
      dvExecuted dv @?= M.fromList
        [ ("/lib.so", S.fromList [ 0x10, 0x20, 0x30, 0x40, 0x50 ])
        , ("/libc.so", S.fromList [ 0x60 ]) ]
      M.keys (dvExecuted (restrictTo [ "lib.so" ] dv))
        @?= [ "/lib.so" ]

  , testCase "a dump in which nothing ran is refused" $ do
      isLeft (readDump "") @? "an empty dump accepted"
      isLeft (readDump "I 10 0 0 aaaa 0 /lib.so 10\n")
        @? "a dump of instructions never run accepted"

  , testCase "an unreadable line is refused" $
      isLeft (readDump "I 10 zz 0 f 0 /lib.so 0\n") @? "accepted"

  , testCase "a guest stopped for a second thread is refused" $
      isLeft (readDump "T 2\n") @? "accepted"

  , testCase "a run's record reads whole" $ do
      d <- either assertFailure pure (readDump (dumpA <> T.unlines
        [ "A 2f62696e2f70", "A", "A 3035", "N 2 1a", "X -9" ]))
      dpRun d @?= Just (Run [ "/bin/p", "", "05" ] (2, 0x1a) (-9))
      fmap dpRun (readDump dumpA) @?= Right Nothing

  , testCase "an incomplete record is refused" $ do
      isLeft (readDump (dumpA <> "A 3035\nN 2 1a\n")) @? "no status"
      isLeft (readDump (dumpA <> "N 2 1a\nX 0\n")) @? "no arguments"
      isLeft (readDump (dumpA <> "A 305\nN 2 1a\nX 0\n"))
        @? "half a byte"

  , testCase "runs made apart are told apart" $ do
      let r = Run [ "/bin/p", "05" ] (2, 0x1a) 0
      runApart r r { rnArguments = [ "/bin/p", "3a" ], rnStatus = 1 }
        @?= Nothing
      isJust (runApart r r { rnArguments = [ "/bin/q", "05" ] })
        @? "another program"
      isJust (runApart r r { rnArguments = [ "/bin/p", "005" ] })
        @? "a longer argument"
      isJust (runApart r r { rnArguments = [ "/bin/p", "05", "x" ] })
        @? "another argument"
      isJust (runApart r r { rnEnvironment = (2, 0x1b) })
        @? "a larger environment"
  ]
  where
    -- 0x10 is a branch run four times, taken twice in A and three
    -- times in B; 0x20 reads other addresses in B; 0x30, inside the
    -- branch, runs a different number of times; 0x40 is the same
    dumpA = T.unlines
      [ "I 10 4 0 aaaa 0 /lib.so 10", "E 10 30 2"
      , "I 20 4 4 bbbb 0 /lib.so 20", "I 30 2 0 cccc 0 /lib.so 30"
      , "I 40 1 1 dddd 0 /lib.so 40" ]
    dumpB = T.unlines
      [ "I 10 4 0 aaaa 0 /lib.so 10", "E 10 30 3"
      , "I 20 4 4 eeee 0 /lib.so 20", "I 30 3 0 cccc 0 /lib.so 30"
      , "I 40 1 1 dddd 0 /lib.so 40" ]
    -- a loop at 0x10 the secret runs 5 or 9 times, its back edge to
    -- 0x14 taken every time but the last; 0x18, in the body, always
    -- jumps back to 0x10
    loopA = T.unlines
      [ "I 10 5 0 aaaa 0 /lib.so 10", "E 10 14 4"
      , "I 14 4 0 bbbb 0 /lib.so 14"
      , "I 18 4 0 cccc 0 /lib.so 18", "E 18 10 4" ]
    loopB = T.unlines
      [ "I 10 9 0 aaaa 0 /lib.so 10", "E 10 14 8"
      , "I 14 8 0 bbbb 0 /lib.so 14"
      , "I 18 8 0 cccc 0 /lib.so 18", "E 18 10 8" ]

symbolTests :: TestTree
symbolTests = testGroup "symbol"
  [ testCase "addr2line's inlined frames and discriminators" $
      parseAddr2line (T.unlines
        [ "0x0000000000001234", "inner", "/src/a.rs:12 (discriminator 3)"
        , "outer", "/src/b.rs:40", "0x0000000000005678", "??", "??:0" ])
        @?= [ (0x1234, [ Place (Just "inner") (Just "/src/a.rs") (Just 12)
                       , Place (Just "outer") (Just "/src/b.rs") (Just 40) ])
            , (0x5678, [ Place Nothing Nothing Nothing ]) ]
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

isJust :: Maybe a -> Bool
isJust m = case m of
  Just _ -> True
  Nothing -> False

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
