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

import Vestigia.Contract
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
  , contractTests
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
      tr <- one <$> fixture "probe.xml"
      fmap (\s -> (siClass s, frFn (at s), frLine (at s))) (trSites tr)
        @?= [ (Address, Just "lookup", Just 16)
            , (Address, Just "main", Just 33) ]
      trUnrelated tr @?= []
      trFaults tr @?= []

  , testCase "only a secret's descendants are sites" $ do
      tr <- one <$> either assertFailure pure (readMemcheck mixed)
      fmap (\s -> (siClass s, frIp (at s), siCount s)) (trSites tr)
        @?= [ (Control, 0x10, 5) ]
      fmap (meKind . snd) (trUnrelated tr) @?= [ "UninitValue" ]
      fmap (meKind . snd) (trFaults tr) @?= [ "InvalidRead" ]

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
      tr <- one <$> fixture "probe.xml"
      length (trSites (sitesIn [ "probe" ] tr)) @?= 2
      trSites (sitesIn [ "libc" ] tr) @?= []
      length (trSites (sitesIn [] tr)) @?= 2

  , testCase "one site per instruction, whatever called it" $ do
      tr <- one <$> either assertFailure pure (readMemcheck twoCallers)
      fmap (\s -> (frIp (at s), siCount s, length (siStacks s)))
          (trSites tr)
        @?= [ (0x10, 7, 2) ]

  , testCase "runs' sites are one per instruction, with their runs" $ do
      a <- either assertFailure pure (readMemcheck mixed)
      b <- either assertFailure pure (readMemcheck twoCallers)
      -- the same object loaded 0x100 higher in the second run: its
      -- branch at 0x110 is the first run's at 0x10
      let obj = "/lib.so"
          inObj mc = mc { mcErrors =
            [ e { meStack = [ f { frObj = Just obj }
                            | f <- meStack e ] }
            | e <- mcErrors mc ] }
          moved mc = mc { mcErrors =
            [ e { meStack = [ f { frIp = frIp f + 0x100 }
                            | f <- meStack e ] }
            | e <- mcErrors mc ] }
          tr = trace
            [ Taint "a" (inObj a) [ (0, obj) ] (Just 0)
            , Taint "b" (moved (inObj b)) [ (0x100, obj) ] (Just 1) ]
      fmap (\s -> (siClass s, lcOffset (siAt s), siCount s, siRuns s
                  , length (siStacks s)))
          (trSites tr)
        @?= [ (Control, Just 0x10, 5 + 7, [ 0, 1 ], 1 + 2) ]
      fmap fst (trUnrelated tr) @?= [ 0 ]
  ]

contractTests :: TestTree
contractTests = testGroup "contract"
  [ testCase "AArch64: a division, and what DIT covers" $ do
      classify ArmDit (word 0x1ac20820) @?= Division        -- udiv w0
      classify ArmDit (word 0x9ac20c20) @?= Division        -- sdiv x0
      classify ArmDit (word 0x8b020020) @?= Inside          -- add x0
      classify ArmDit (word 0x9bc27c20) @?= Inside          -- umulh x0
      classify ArmDit (word 0xdac00c20) @?= Inside          -- rev x0
      classify ArmDit (word 0xd65f03c0) @?= Excluded        -- ret
      classify ArmDit (word 0x90000420) @?= Excluded        -- adrp x0

  , testCase "AArch64: outside DIT, with the registers read" $ do
      -- fdiv d0, d1, d2
      classify ArmDit (word 0x1e621820)
        @?= Watched [ Register "v1" 0 64, Register "v2" 0 64 ] False
      -- fmov x0, d1
      classify ArmDit (word 0x9e660020)
        @?= Watched [ Register "v1" 0 64 ] False
      -- fadd v0.4s, v1.4s, v2.4s, and its 64-bit arrangement
      classify ArmDit (word 0x4e22d420)
        @?= Watched [ Register "v1" 0 128, Register "v2" 0 128 ] False
      classify ArmDit (word 0x0e22d420)
        @?= Watched [ Register "v1" 0 64, Register "v2" 0 64 ] False

  , testCase "x86_64: a division, and what DOITM covers" $ do
      classify IntelDoitm (x86 [ 0x48, 0xf7, 0xf6 ] "div" "rsi")
        @?= Division
      classify IntelDoitm (x86 [ 0xc1, 0xc0, 0x07 ] "rol" "eax, 0x7")
        @?= Inside
      classify IntelDoitm (x86 [ 0x48, 0x0f, 0xc8 ] "bswap" "rax")
        @?= Inside
      classify IntelDoitm (x86 [ 0x48, 0x0f, 0x44, 0xc3 ] "cmove"
                             "rax, rbx") @?= Inside
      classify IntelDoitm (x86 [ 0x48, 0xb8, 1, 0, 0, 0, 0, 0, 0, 0 ]
                             "movabs" "rax, 0x1") @?= Inside
      classify IntelDoitm (x86 [ 0xc5, 0xf5, 0xd4, 0xc2 ] "vpaddq"
                             "ymm0, ymm1, ymm2") @?= Inside
      classify IntelDoitm (x86 [ 0x75, 0x02 ] "jne" "0x10") @?= Excluded
      classify IntelDoitm (x86 [ 0x90 ] "nop" "") @?= Excluded

  , testCase "x86_64: outside DOITM, with the registers read" $ do
      -- popcnt only writes its destination
      classify IntelDoitm (x86 [ 0xf3, 0x48, 0x0f, 0xb8, 0xc3 ] "popcnt"
                             "rax, rbx")
        @?= Watched [ Register "rbx" 0 64 ] False
      classify IntelDoitm (x86 [ 0x92 ] "xchg" "eax, edx")
        @?= Watched [ Register "rax" 0 32, Register "rdx" 0 32 ] False
      -- a legacy SSE division reads its destination too
      classify IntelDoitm (x86 [ 0xf2, 0x0f, 0x5e, 0xc1 ] "divsd"
                             "xmm0, xmm1")
        @?= Watched [ Register "xmm0" 0 128, Register "xmm1" 0 128 ] False
      classify IntelDoitm (x86 [ 0x98 ] "cwde" "")
        @?= Watched [ Register "rax" 0 16 ] False
      -- a memory operand's registers are its address's, not its data
      classify IntelDoitm (x86 [ 0x0f, 0x54, 0x07 ] "andps"
                             "xmm0, xmmword ptr [rdi]")
        @?= Watched [ Register "xmm0" 0 128 ] True

  , testCase "llvm-objdump's lines are read" $ do
      readDisassembly (T.unlines
        [ "0000000000001000 <f>:"
        , "    1000: 48 89 e5                     \tmov\trbp, rsp"
        , "    1003: f3 48 ab                     \trep\t\tstosq\tqword \
          \ptr es:[rdi], rax"
        , "    1006: 48 8b 05 4d b5 06 00         \tmov\trax, qword ptr \
          \[rip + 0x6b54d] # 0x86d58 <x>"
        , "\t\t..."
        , "   1b824: 9112a000     \tadd\tx0, x0, #0x4a8" ])
        @?= [ Line 0x1000 [ 0x48, 0x89, 0xe5 ] [] "mov" "rbp, rsp"
            , Line 0x1003 [ 0xf3, 0x48, 0xab ] [ "rep" ] "stosq"
                "qword ptr es:[rdi], rax"
            , Line 0x1006 [ 0x48, 0x8b, 0x05, 0x4d, 0xb5, 0x06, 0x00 ] []
                "mov" "rax, qword ptr [rip + 0x6b54d]"
            , Line 0x1b824 [ 0x9112a000 ] [] "add" "x0, x0, #0x4a8" ]

  , testCase "the watch list names what lies outside" $
      watchSection IntelDoitm "/lib.so"
        [ x86 [ 0x48, 0xf7, 0xf6 ] "div" "rsi"
        , x86 [ 0x48, 0x01, 0xd8 ] "add" "rax, rbx"
        , x86 [ 0x92 ] "xchg" "eax, edx" ]
        @?= T.unlines
              [ "O /lib.so", "D 0 div rsi"
              , "U 0 0 2 rax:0:32 rdx:0:32 xchg eax, edx" ]
  ]
  where
    word w = Line 0 [ w ] [] "" ""
    x86 bs m ops = Line 0 bs [] m ops

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

  , testCase "an instruction outside the contract is reported apart" $ do
      -- 0x40 runs once in every run, outside the contract, on other
      -- operands in B; 0x30 is watched too, on the same operands
      let under d = d <> "U 30 7777\nW 30 popcnt rax, rbx\nU 40 "
      a <- either assertFailure pure
        (readDump (under dumpA <> "1111\nM x86_64\nG intel-doitm\n"))
      b <- either assertFailure pure
        (readDump (under dumpB <> "2222\nM x86_64\nG intel-doitm\n"))
      x <- either assertFailure pure
        (readDump (under dumpA <> "3333\nM x86_64\nG intel-doitm\n"))
      dpIsa a @?= Just "x86_64"
      dpContract a @?= Just "intel-doitm"
      M.lookup 0x30 (dpTexts a) @?= Just "popcnt rax, rbx"
      let dv = diffDumps [ a, b ]
      -- not an origin: the contract says nothing either way of it
      fmap (\(o, i) -> (o, inPc i)) (dvOrigins dv)
        @?= [ (ControlOrigin, 0x10), (AddressOrigin, 0x20) ]
      fmap inPc (dvOutside dv) @?= [ 0x40 ]
      M.lookup 0x40 (dvOutsideBehaviour (diffDumps [ a, b, a ]))
        @?= Just ([ [ 0, 2 ], [ 1 ] ], [])
      dvWatched dv @?= M.fromList [ ("/lib.so", S.fromList [ 0x30, 0x40 ]) ]
      notElem 0x40 (fmap inPc (dvDownstream dv)) @? "downstream"
      -- runs alike in their operands show nothing outside
      dvOutside (diffDumps [ a, a ]) @?= []
      -- a control on other operands sets it apart as unsteady
      dvOutside (diffControlled [ x ] [ a, b ]) @?= []
      fmap inPc (dvUnsteady (diffControlled [ x ] [ a, b ])) @?= [ 0x40 ]
      -- and the objects kept are the objects reported
      dvOutside (restrictTo [ "/other.so" ] dv) @?= []

  , testCase "an origin is given the calls that reached it" $ do
      -- 0x10 ran in context 2 (the call at 0x40 made in context 1,
      -- the call at 0x30 made in the program's own) in A, and in the
      -- program's own context too in B
      let calls = T.unlines
            [ "C 1 0 30", "C 2 1 40" ]
      a <- either assertFailure pure (readDump (dumpA <> calls
        <> "K 10 0 2\n"))
      b <- either assertFailure pure (readDump (dumpB <> calls
        <> "K 10 1 2 0\n"))
      callsOf a 2 @?= [ (Just "/lib.so", 0x40), (Just "/lib.so", 0x30) ]
      callsOf a 0 @?= []
      M.lookup 0x10 (dvCallers (diffDumps [ a, b ]))
        @?= Just ([ [ (Just "/lib.so", 0x40), (Just "/lib.so", 0x30) ]
                  , [] ], True)
      M.lookup 0x10 (dvCallers (diffDumps [ a, a ]))
        @?= Nothing

  , testCase "contexts that do not chain back are refused" $ do
      isLeft (readDump (dumpA <> "C 1 2 30\nC 2 1 40\n"))
        @? "a context made in a later one"
      isLeft (readDump (dumpA <> "K 10 0 5\n"))
        @? "a context never made"

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

  , testCase "a legacy Rust name's escapes and hash undone" $ do
      rustLegacy "decaf377::ark_curve::encoding::_$LT$impl$u20$decaf377\
                 \..ark_curve..element..projective..Element$GT$::vartime\
                 \_compress_to_field::h346fee1681a4f34f"
        @?= "decaf377::ark_curve::encoding::<impl decaf377::ark_curve::\
            \element::projective::Element>::vartime_compress_to_field"
      rustLegacy "_$LT$$RF$T$u20$as$u20$core..fmt..Debug$GT$::fmt::\
                 \h0123456789abcdef"
        @?= "<&T as core::fmt::Debug>::fmt"
      -- a C++ name, or one without a hash, is left as it is
      rustLegacy "std::vector<int>::size" @?= "std::vector<int>::size"
      rustLegacy "a::b$LT$c" @?= "a::b$LT$c"
  ]

jsonTests :: TestTree
jsonTests = testGroup "json"
  [ testCase "objects keep their order and strings escape" $
      encode (Object [ ("b", Number 1)
                     , ("a", String "q\"\n\1") ])
        @?= "{\n  \"b\": 1,\n  \"a\": \"q\\\"\\n\\u0001\"\n}\n"
  ]

-- a trace of one run, of which memcheck's report is all that is
-- known
one :: Memcheck -> Trace
one mc = trace [ Taint "run" mc [] Nothing ]

at :: Site -> Frame
at = lcFrame . siAt

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
