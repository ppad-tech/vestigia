{-# LANGUAGE ForeignFunctionInterface #-}

-- | ppad-poly1305 under vestigia: each run draws a fresh one-time
--   key, marked secret, and MACs a fixed set of public messages,
--   comparing each tag with a public candidate.
--
--   usage: harness [RUNS [SEED]]
--
--   SEED (hex) seeds the keys alone; the messages and candidates
--   come from a fixed stream, so runs that differ in SEED differ
--   only in their keys.

module Main (
    main
  ) where

import Control.Monad (forM_)
import qualified Crypto.MAC.Poly1305 as P
import Data.Bits (shiftR, xor)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Unsafe as BU
import Data.IORef (modifyIORef', newIORef, readIORef, writeIORef)
import Data.Word (Word64)
import Foreign.C.Types (CSize(..))
import Foreign.Ptr (Ptr, castPtr)
import Numeric (readHex)
import System.Environment (getArgs)

foreign import ccall unsafe "vestigia_secret"
  c_secret :: Ptr () -> CSize -> IO ()

foreign import ccall unsafe "vestigia_public"
  c_public :: Ptr () -> CSize -> IO ()

mark :: (Ptr () -> CSize -> IO ()) -> BS.ByteString -> IO ()
mark f bs =
  BU.unsafeUseAsCStringLen bs (\(p, n) -> f (castPtr p) (fromIntegral n))

splitmix :: Word64 -> (Word64, Word64)
splitmix s0 =
  let s = s0 + 0x9e3779b97f4a7c15
      z1 = (s `xor` (s `shiftR` 30)) * 0xbf58476d1ce4e5b9
      z2 = (z1 `xor` (z1 `shiftR` 27)) * 0x94d049bb133111eb
  in (z2 `xor` (z2 `shiftR` 31), s)

bytes :: Int -> Word64 -> (BS.ByteString, Word64)
bytes n s0 = go n s0 []
  where
    go 0 s acc = (BS.pack (reverse acc), s)
    go k s acc =
      let (x, s') = splitmix s in go (k - 1) s' (fromIntegral x : acc)

-- message lengths around the 16-byte block: empty, short final
-- chunks, exact blocks
lengths :: [Int]
lengths = [ 0, 1, 15, 16, 17, 31, 32, 33, 64, 100 ]

main :: IO ()
main = do
  args <- getArgs
  let runs = case args of
        (r : _) | [ (n, "") ] <- reads r -> n
        _ -> 2 :: Int
      seed = case args of
        (_ : s : _) | [ (n, "") ] <- readHex s -> n
        _ -> 1
  let (messages, _) = foldr
        (\l (ms, s) -> let (m, s') = bytes l s in (m : ms, s'))
        ([], 0x0123456789abcdef) lengths
      candidates = [ fst (bytes 16 (0xfeed + fromIntegral k))
                   | k <- [ 0 .. length lengths - 1 ] ]
  secrets <- newIORef seed
  matches <- newIORef (0 :: Int)
  forM_ [ 1 .. runs ] $ \_ -> do
    s <- readIORef secrets
    let (key, s') = bytes 32 s
    writeIORef secrets s'
    mark c_secret key
    forM_ (zip messages candidates) $ \(m, c) -> case P.mac key m of
      Just t -> do
        let ok = t == P.MAC c
        modifyIORef' matches (+ fromEnum ok)
      Nothing -> pure ()
  n <- readIORef matches
  putStrLn (show runs <> " run(s), " <> show n <> " match(es)")
