{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE ForeignFunctionInterface #-}

-- | ppad-secp256k1 under vestigia: each run draws a fresh secret key
--   (and Schnorr auxiliary randomness), marked secret, and runs the
--   library's secret-key roots on fixed public messages: public key
--   derivation, Schnorr and ECDSA signing (with and without a
--   precomputed context), and ECDH against a fixed public peer.
--
--   usage: harness [RUNS [SEED]]
--
--   SEED (hex) seeds the secrets alone, so runs that differ in SEED
--   differ only in their secrets.

module Main (
    main
  ) where

import Control.Monad (forM_)
import qualified Crypto.Curve.Secp256k1 as S
import Data.Bits (shiftR, xor, (.&.))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Unsafe as BU
import Data.IORef (modifyIORef', newIORef, readIORef, writeIORef)
import Data.Word (Word64)
import Foreign.C.Types (CSize(..))
import Foreign.Ptr (Ptr, castPtr)
import Numeric (readHex)
import System.Environment (getArgs)

foreign import ccall unsafe "vestigia_secret_c"
  c_secret :: Ptr () -> CSize -> IO ()

foreign import ccall unsafe "vestigia_public_c"
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

-- a key below the group order: random bytes with the top bit clear
key :: Word64 -> (BS.ByteString, Word64)
key s =
  let (b, s') = bytes 32 s
  in case BS.uncons b of
       Just (h, t) -> (BS.cons (h .&. 0x7f) t, s')
       Nothing -> (b, s')

-- a result's bytes, made public again: a signature is meant to be
-- revealed
reveal :: Maybe BS.ByteString -> IO Int
reveal r = case r of
  Just b -> mark c_public b >> pure (BS.length b)
  Nothing -> pure 0

-- a result forced, and nothing of it revealed
forced :: Maybe a -> IO Int
forced r = case r of
  Just !_ -> pure 1
  Nothing -> pure 0

main :: IO ()
main = do
  args <- getArgs
  let runs = case args of
        (r : _) | [ (n, "") ] <- reads r -> n
        _ -> 2 :: Int
      seed = case args of
        (_ : s : _) | [ (n, "") ] <- readHex s -> n
        _ -> 1
      (msg, p1) = bytes 32 0x0123456789abcdef
      (peerKey, _) = key p1
      !tex = S.precompute
  peer <- case S.parse_int256 peerKey >>= S.derive_pub of
    Just p -> pure p
    Nothing -> fail "no peer key"
  secrets <- newIORef seed
  total <- newIORef (0 :: Int)
  forM_ [ 1 .. runs ] $ \_ -> do
    s <- readIORef secrets
    let (skBytes, s1) = key s
        (aux, s2) = bytes 32 s1
    writeIORef secrets s2
    mark c_secret skBytes
    mark c_secret aux
    case S.parse_int256 skBytes of
      Nothing -> pure ()
      Just sk -> do
        n1 <- forced (S.derive_pub sk)
        n2 <- reveal (S.sign_schnorr sk msg aux)
        n3 <- reveal (S.sign_schnorr' tex sk msg aux)
        n4 <- forced (S.sign_ecdsa sk msg)
        n5 <- forced (S.sign_ecdsa' tex sk msg)
        n6 <- forced (S.ecdh peer sk)
        modifyIORef' total (+ (n1 + n2 + n3 + n4 + n5 + n6))
  n <- readIORef total
  putStrLn (show runs <> " run(s), " <> show n <> " result(s)")
