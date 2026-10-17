{-# OPTIONS_HADDOCK prune #-}
{-# LANGUAGE ForeignFunctionInterface #-}

-- |
-- Module: Vestigia.Layout
-- Copyright: (c) 2026 Jared Tobin
-- License: MIT
-- Maintainer: Jared Tobin <jared@ppad.tech>
--
-- Runs compared to find where a secret mattered must lay memory out
-- alike, or every address differs between them and no difference
-- means anything.

module Vestigia.Layout (
    fixLayout
  ) where

import Foreign.C.Types (CInt(..))

foreign import ccall unsafe "vestigia_no_randomize"
  c_noRandomize :: IO CInt

-- | Turn address-space randomisation off for this process and every
--   process it starts (the personality is inherited across fork and
--   exec). 'False' where it cannot be: off Linux, or refused.
fixLayout :: IO Bool
fixLayout = fmap (== 0) c_noRandomize
