{-# OPTIONS_HADDOCK prune #-}

-- |
-- Module: Vestigia.Contract.Types
-- Copyright: (c) 2026 Jared Tobin
-- License: MIT
-- Maintainer: Jared Tobin <jared@ppad.tech>
--
-- What a contract's table says of an AArch64 encoding.

module Vestigia.Contract.Types (
    Operand(..)
  , Status(..)
  , Encoding(..)
  ) where

import qualified Data.Text as T
import Data.Word (Word32)

-- | A source register an encoding names, by the field it is read
--   from: a general-purpose register at 64 or 32 bits (field value
--   31 the zero register, or the stack pointer where the encoding
--   says so), a SIMD&FP register at a fixed width, a vector whose
--   width is the encoding's Q bit (bit 30), or a SIMD&FP register
--   read whole where nothing fixes its width.
data Operand =
    OpX
  | OpXSp
  | OpW
  | OpWSp
  | OpQ
  | OpD
  | OpS
  | OpH
  | OpB
  | OpV
  | OpVWhole
  deriving (Eq, Show)

-- | An encoding the contract covers; one it does not that is control
--   flow or system, which reads no data the contract speaks to; or one
--   it does not, with its source registers, each by the low bit of its
--   field.
data Status =
    Covered
  | Control
  | Outside ![(Int, Operand)]
  deriving (Eq, Show)

-- | An encoding, by its name in the specification, its fixed bits,
--   and what the contract says of it.
data Encoding = Encoding {
    enName :: !T.Text
  , enMask :: !Word32
  , enValue :: !Word32
  , enStatus :: !Status
  } deriving (Eq, Show)
