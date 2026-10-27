{-# OPTIONS_HADDOCK prune #-}
{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module: Vestigia.Contract
-- Copyright: (c) 2026 Jared Tobin
-- License: MIT
-- Maintainer: Jared Tobin <jared@ppad.tech>
--
-- An ISA's data-independent-timing contract, and what it makes of
-- each instruction of an object: one it covers takes a time
-- independent of its data; one it does not, run on operands that
-- depend on the secret, is outside the contract; and a division is
-- variable-time on either ISA. Control flow and system instructions
-- are left to the comparison of what ran.
--
-- An object is read through LLVM's disassembler (@llvm-objdump@), in
-- Intel syntax on x86_64. On AArch64 an instruction is matched by its
-- encoding against Arm's own ('Vestigia.Contract.Arm'), its source
-- registers read off the fields the encoding names. On x86_64 it is
-- matched by its mnemonic and opcode byte against Intel's list
-- ('Vestigia.Contract.Intel'), its source registers read off its
-- operands: every register operand outside a memory reference, but
-- the first where the instruction only writes it, and the registers
-- some instructions read without naming.
--
-- What is outside the contract and reads data becomes the watch
-- list the QEMU plugin is given: each such instruction, by its
-- address in its object, with the registers to fingerprint before it
-- runs, as the plugin fingerprints a division's operands.

module Vestigia.Contract (
    Contract(..)
  , contractName
  , contractSource
  , contractIsa
  , readContract
  , Line(..)
  , readDisassembly
  , Register(..)
  , Verdict(..)
  , classify
  , watchSection
  ) where

import Data.Bits (popCount, shiftR, testBit, (.&.))
import Data.Char (isHexDigit)
import qualified Data.List as L
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import qualified Data.Text as T
import Data.Word (Word32, Word8)
import Numeric (readHex, showHex)

import qualified Vestigia.Contract.Arm as Arm
import qualified Vestigia.Contract.Intel as Intel
import Vestigia.Contract.Types

-- | A data-independent-timing contract: Arm's @PSTATE.DIT@, or
--   Intel's DOITM.
data Contract =
    ArmDit
  | IntelDoitm
  deriving (Eq, Show)

contractName :: Contract -> T.Text
contractName c = case c of
  ArmDit -> "arm-dit"
  IntelDoitm -> "intel-doitm"

-- | The release of the vendor's own statement the table transcribes.
contractSource :: Contract -> T.Text
contractSource c = case c of
  ArmDit -> "Arm A64 ISA XML, 2022-12"
  IntelDoitm -> "Intel 768547, Table 1, 2026-02-23"

-- | The ISA a contract speaks to, as QEMU names it.
contractIsa :: Contract -> String
contractIsa c = case c of
  ArmDit -> "aarch64"
  IntelDoitm -> "x86_64"

readContract :: T.Text -> Maybe Contract
readContract t = case t of
  "arm-dit" -> Just ArmDit
  "intel-doitm" -> Just IntelDoitm
  _ -> Nothing

-- | One instruction as the disassembler prints it: its address in
--   the object, its raw form (an AArch64 word, or x86_64's bytes),
--   any prefixes, its mnemonic, and its operands.
data Line = Line {
    lnAddress :: !Integer
  , lnRaw :: ![Integer]
  , lnPrefixes :: ![T.Text]
  , lnMnemonic :: !T.Text
  , lnOperands :: !T.Text
  } deriving (Eq, Show)

-- | The instructions of @llvm-objdump@'s disassembly; everything
--   else it prints (headers, symbols, elided runs) is passed over.
readDisassembly :: T.Text -> [Line]
readDisassembly = concatMap line . T.lines
  where
    line l = case T.breakOn ":" (T.stripStart l) of
      (a, rest)
        | not (T.null a), T.all isHexDigit a
        , Just body <- T.stripPrefix ":" rest
        , [ (addr, "") ] <- readHex (T.unpack a)
        , (raw, text) <- T.breakOn "\t" body
        , Just ws <- traverse hexToken (T.words raw)
        , not (null ws) ->
            case filter (not . T.null)
                   (fmap T.strip (T.splitOn "\t" text)) of
              [] -> []
              fs -> let (ps, rest') = L.span (`S.member` prefixes) fs
                    in case rest' of
                         (m : ops) -> [ Line addr ws ps m
                                          (uncomment (T.unwords ops)) ]
                         [] -> []
      _ -> []
    hexToken w
      | T.all isHexDigit w, [ (v, "") ] <- readHex (T.unpack w) = Just v
      | otherwise = Nothing
    -- the disassembler's annotations, x86_64's after " # " and
    -- AArch64's after " //": a target or a literal, never an operand
    -- (an AArch64 immediate is "#" with no space after it)
    uncomment t =
      T.stripEnd (fst (T.breakOn " //" (fst (T.breakOn " # " t))))

-- prefixes the disassembler prints as fields of their own
prefixes :: S.Set T.Text
prefixes = S.fromList
  [ "lock", "rep", "repe", "repz", "repne", "repnz", "data16", "data32"
  , "addr32", "notrack", "bnd", "xacquire", "xrelease", "cs", "ds"
  , "es", "fs", "gs", "ss" ]

-- | A register to fingerprint, as QEMU names it, by the bits read:
--   from its low bit, so many of them.
data Register = Register {
    rgName :: !T.Text
  , rgLow :: !Int
  , rgWidth :: !Int
  } deriving (Eq, Ord, Show)

-- | What a contract makes of an instruction: covered by it; control
--   flow or system, or reading no data; an integer division, which
--   the plugin reads for itself; or outside the contract, with the
--   registers it reads and whether it names memory.
data Verdict =
    Inside
  | Excluded
  | Division
  | Watched ![Register] !Bool
  deriving (Eq, Show)

-- | Classify one instruction under a contract.
classify :: Contract -> Line -> Verdict
classify c l = case c of
  ArmDit -> case lnRaw l of
    [ w ] | w >= 0, w < 2 ^ (32 :: Int) -> arm (fromInteger w) l
    _ -> Excluded
  IntelDoitm -> intel l

-- AArch64 ---------------------------------------------------------

arm :: Word32 -> Line -> Verdict
arm w l = case best of
  Nothing -> Excluded
  Just e
    | any (`T.isPrefixOf` enName e) [ "UDIV_", "SDIV_" ] -> Division
    | otherwise -> case enStatus e of
        Covered -> Inside
        Control -> Excluded
        Outside ops -> case concatMap (register w) ops of
          [] | not memory -> Excluded
          rs -> Watched (L.nub rs) memory
  where
    memory = "[" `T.isInfixOf` lnOperands l
    candidates = M.findWithDefault [] (bucket w) armIndex
    best = case [ e | e <- candidates, w .&. enMask e == enValue e ] of
      [] -> Nothing
      es -> Just (L.maximumBy (\a b -> compare (fixed a) (fixed b)) es)
    fixed e = popCount (enMask e)

-- an encoding's group, bits 28 to 25
bucket :: Word32 -> Word32
bucket w = (w `shiftR` 25) .&. 0xf

-- the encodings by every group their fixed bits allow
armIndex :: M.Map Word32 [Encoding]
armIndex = M.fromListWith (flip (<>))
  [ (b, [ e ])
  | e <- Arm.encodings
  , b <- [ 0 .. 15 ]
  , b .&. bucket (enMask e) == bucket (enValue e) ]

register :: Word32 -> (Int, Operand) -> [Register]
register w (lsb, op) =
  let n = fromIntegral ((w `shiftR` lsb) .&. 31) :: Int
      x = "x" <> T.pack (show n)
      v = "v" <> T.pack (show n)
  in case op of
       OpX | n == 31 -> []
           | otherwise -> [ Register x 0 64 ]
       OpXSp | n == 31 -> [ Register "sp" 0 64 ]
             | otherwise -> [ Register x 0 64 ]
       OpW | n == 31 -> []
           | otherwise -> [ Register x 0 32 ]
       OpWSp | n == 31 -> [ Register "sp" 0 32 ]
             | otherwise -> [ Register x 0 32 ]
       OpQ -> [ Register v 0 128 ]
       OpD -> [ Register v 0 64 ]
       OpS -> [ Register v 0 32 ]
       OpH -> [ Register v 0 16 ]
       OpB -> [ Register v 0 8 ]
       OpV -> [ Register v 0 (if testBit w 30 then 128 else 64) ]
       OpVWhole -> [ Register v 0 128 ]

-- x86_64 ----------------------------------------------------------

intel :: Line -> Verdict
intel l
  | m `S.member` control || "J" `T.isPrefixOf` m = Excluded
  | m == "DIV" || m == "IDIV" = Division
  | Just op <- opcode (lnRaw l)
  , (name, op) `S.member` intelRows = Inside
  | null sources && not memory = Excluded
  | otherwise = Watched (L.nub sources) memory
  where
    m = mnemonic l
    -- a repeat prefix names a string instruction's row; on any other
    -- it does nothing
    name
      | any (`elem` [ "rep", "repe", "repz", "repne", "repnz" ])
            (lnPrefixes l)
      , any (`T.isPrefixOf` m)
          [ "MOVS", "STOS", "LODS", "CMPS", "SCAS", "INS", "OUTS" ] =
          "REP_" <> m
      | otherwise = m
    operands = splitOperands (lnOperands l)
    memory = any ("[" `T.isInfixOf`) operands
    named = [ r | o <- operands, not ("[" `T.isInfixOf` o)
                , Just r <- [ M.lookup (bare o) intelRegisters ] ]
    explicit = case operands of
      (o : _) | writesOnly m, not ("[" `T.isInfixOf` o) -> drop 1 named
      _ -> named
    sources = explicit <> M.findWithDefault [] m implicit

intelRows :: S.Set (T.Text, Word8)
intelRows = S.fromList Intel.instructions

-- the mnemonic as Intel's list spells it: upper case, a condition by
-- its list name, a 64-bit immediate move as a move
mnemonic :: Line -> T.Text
mnemonic l =
  let m = T.toUpper (lnMnemonic l)
  in case m of
       "MOVABS" -> "MOV"
       _ -> case [ p <> c' | p <- [ "CMOV", "SET" ]
                           , Just c <- [ T.stripPrefix p m ]
                           , Just c' <- [ M.lookup c conditions ] ] of
              (n : _) -> n
              [] -> m

conditions :: M.Map T.Text T.Text
conditions = M.fromList
  [ ("O", "O"), ("NO", "NO"), ("B", "B"), ("C", "B"), ("NAE", "B")
  , ("NB", "NB"), ("AE", "NB"), ("NC", "NB"), ("Z", "Z"), ("E", "Z")
  , ("NZ", "NZ"), ("NE", "NZ"), ("BE", "BE"), ("NA", "BE")
  , ("NBE", "NBE"), ("A", "NBE"), ("S", "S"), ("NS", "NS"), ("P", "P")
  , ("PE", "P"), ("NP", "NP"), ("PO", "NP"), ("L", "L"), ("NGE", "L")
  , ("NL", "NL"), ("GE", "NL"), ("LE", "LE"), ("NG", "LE")
  , ("NLE", "NLE"), ("G", "NLE") ]

-- control flow, system, and instructions that read no data
control :: S.Set T.Text
control = S.fromList
  [ "CALL", "RET", "LOOP", "LOOPE", "LOOPNE", "SYSCALL", "SYSENTER"
  , "INT", "INT3", "INTO", "UD1", "UD2", "HLT", "NOP", "PAUSE"
  , "ENDBR32", "ENDBR64", "LFENCE", "MFENCE", "SFENCE", "CPUID"
  , "RDTSC", "RDTSCP", "XGETBV", "RDRAND", "RDSEED", "ENTER", "LEAVE"
  , "PREFETCHT0", "PREFETCHT1", "PREFETCHT2", "PREFETCHNTA"
  , "PREFETCHW", "CLFLUSH", "CLFLUSHOPT" ]

-- instructions that write their first operand without reading it
writesOnly :: T.Text -> Bool
writesOnly m =
  ("V" `T.isPrefixOf` m && m /= "VZEROUPPER" && m /= "VZEROALL")
    || "MOV" `T.isPrefixOf` m
    || "CVT" `T.isPrefixOf` m
    || any (`T.isPrefixOf` m) [ "SQRT", "RSQRT", "RCP" ]
    || m `elem` [ "POPCNT", "LZCNT", "TZCNT", "PDEP", "PEXT", "BZHI"
                , "BEXTR", "BLSI", "BLSR", "BLSMSK", "SARX", "LEA" ]

-- registers read without being named
implicit :: M.Map T.Text [Register]
implicit = M.fromList
  [ ("CBW", [ Register "rax" 0 8 ]), ("CWDE", [ Register "rax" 0 16 ])
  , ("CDQE", [ Register "rax" 0 32 ]), ("CWD", [ Register "rax" 0 16 ])
  , ("CDQ", [ Register "rax" 0 32 ]), ("CQO", [ Register "rax" 0 64 ])
  , ("SAHF", [ Register "rax" 8 8 ])
  , ("CMPXCHG", [ Register "rax" 0 64 ])
  , ("CMPXCHG8B", fmap (\r -> Register r 0 32)
      [ "rax", "rdx", "rbx", "rcx" ])
  , ("CMPXCHG16B", fmap (\r -> Register r 0 64)
      [ "rax", "rdx", "rbx", "rcx" ]) ]

-- an operand less its masking and broadcast decorations
bare :: T.Text -> T.Text
bare = T.strip . T.takeWhile (/= '{')

-- operands, split at the commas between them
splitOperands :: T.Text -> [T.Text]
splitOperands t
  | T.null (T.strip t) = []
  | otherwise = fmap T.strip (go 0 "" (T.unpack t))
  where
    go :: Int -> String -> String -> [T.Text]
    go _ acc [] = [ T.pack (reverse acc) ]
    go d acc (ch : rest) = case ch of
      '[' -> go (d + 1) (ch : acc) rest
      ']' -> go (d - 1) (ch : acc) rest
      ',' | d == 0 -> T.pack (reverse acc) : go d "" rest
      _ -> go d (ch : acc) rest

-- the general and vector registers QEMU exposes, by their names in
-- Intel syntax: a wide vector by its low 128 bits, which is all of
-- it QEMU names
intelRegisters :: M.Map T.Text Register
intelRegisters = M.fromList $
  concat
    [ [ (r64, Register r64 0 64), (r32, Register r64 0 32)
      , (r16, Register r64 0 16), (r8, Register r64 0 8) ]
    | (r64, r32, r16, r8) <-
        [ ("rax", "eax", "ax", "al"), ("rbx", "ebx", "bx", "bl")
        , ("rcx", "ecx", "cx", "cl"), ("rdx", "edx", "dx", "dl")
        , ("rsi", "esi", "si", "sil"), ("rdi", "edi", "di", "dil")
        , ("rbp", "ebp", "bp", "bpl"), ("rsp", "esp", "sp", "spl") ]
        <> [ (n, n <> "d", n <> "w", n <> "b")
           | k <- [ 8 .. 15 :: Int ], let n = "r" <> T.pack (show k) ] ]
  <> [ (h, Register r 8 8)
     | (h, r) <- [ ("ah", "rax"), ("bh", "rbx"), ("ch", "rcx")
                 , ("dh", "rdx") ] ]
  <> [ (p <> T.pack (show k), Register ("xmm" <> T.pack (show k)) 0 128)
     | p <- [ "xmm", "ymm", "zmm" ], k <- [ 0 .. 15 :: Int ] ]

-- the last opcode byte, past the prefixes, a REX, any VEX or EVEX
-- payload, and the escape bytes
opcode :: [Integer] -> Maybe Word8
opcode bs = fmap fromInteger (go (dropWhile legacy bs))
  where
    legacy b = b `elem` [ 0x66, 0x67, 0xf0, 0xf2, 0xf3, 0x2e, 0x36
                        , 0x3e, 0x26, 0x64, 0x65 ]
    go xs = case xs of
      (b : rest) | b >= 0x40 && b <= 0x4f -> escaped rest
      (0xd5 : _ : rest) -> at 0 rest
      _ -> escaped xs
    escaped xs = case xs of
      (0xc5 : rest) -> at 1 rest
      (0xc4 : rest) -> at 2 rest
      (0x62 : rest) -> at 3 rest
      (0x0f : 0x38 : rest) -> at 0 rest
      (0x0f : 0x3a : rest) -> at 0 rest
      (0x0f : rest) -> at 0 rest
      _ -> at 0 xs
    at k xs = case drop k xs of
      (b : _) -> Just b
      [] -> Nothing

-- the watch list ----------------------------------------------------

-- | The plugin's watch list for one object, at its path: an @O@ line
--   naming it, then a @D@ line per division and a @U@ line per
--   instruction outside the contract, each with its address and its
--   text (a @U@ line with whether it names memory and the registers
--   it reads, each as name:low:width, before the text).
watchSection :: Contract -> FilePath -> [Line] -> T.Text
watchSection c path ls = T.unlines $
  ("O " <> T.pack path)
  : concatMap entry ls
  where
    entry l = case classify c l of
      Division -> [ "D " <> hex (lnAddress l) <> " " <> text l ]
      Watched rs memory ->
        [ T.unwords $
            [ "U", hex (lnAddress l), if memory then "1" else "0"
            , T.pack (show (length rs)) ]
            <> [ rgName r <> ":" <> T.pack (show (rgLow r)) <> ":"
                   <> T.pack (show (rgWidth r)) | r <- rs ]
            <> [ text l ] ]
      _ -> []
    text l = T.unwords (filter (not . T.null)
      (lnPrefixes l <> [ lnMnemonic l, lnOperands l ]))
    hex n = T.pack (showHex n "")
