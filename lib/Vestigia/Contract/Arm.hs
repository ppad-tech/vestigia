{-# OPTIONS_HADDOCK prune #-}
{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module: Vestigia.Contract.Arm
-- Copyright: (c) 2026 Jared Tobin
-- License: MIT
-- Maintainer: Jared Tobin <jared@ppad.tech>
--
-- Arm's data-independent-timing contract (@PSTATE.DIT@), encoding by
-- encoding, generated from Arm's machine-readable specification.
--
-- == Source
--
-- /A64 ISA XML for A-profile Architecture/, version @2022-12@
-- (package @ISA_A64_xml_A_profile-2022-12@, sha256
-- @1839a9722eab26aa3bdcd91adeeaf2e6c5c6df085f0e096f949c55cbee7d1a5a@),
-- retrieved 2026-10-27 from the Internet Archive mirror of Arm's
-- exploration-tools release,
-- @archive.org\/details\/arm-xml-a-profile-2022-12@, its md5
-- matching the mirror's record.
--
-- == Rule
--
-- Every encoding of every A64 instruction section (type
-- @instruction@, one per file) of the general, Advanced SIMD,
-- floating-point, SIMD&FP load/store, and system classes; SVE and SME
-- are left out. An instruction is covered exactly when its section's
-- @\<operationalnotes\>@ name @PSTATE.DIT@, whose data-processing
-- note reads:
--
-- > If PSTATE.DIT is 1: The execution time of this instruction is
-- > independent of: The values of the data supplied in any of its
-- > registers. The values of the NZCV flags.
--
-- An encoding's fixed bits are its class's register diagram with the
-- encoding's own boxes over it. One not covered is control flow or
-- system ('Control') where its pseudocode lies under
-- @aarch64\/instrs\/branch\/@ or @aarch64\/instrs\/system\/@, or
-- its section is of the system class; otherwise it is 'Outside', with
-- its source registers: the five-bit register fields its assembler
-- template names whose explanation is neither destination-only nor
-- an address (a base register, or one holding an address).

module Vestigia.Contract.Arm (
    encodings
  ) where

import Vestigia.Contract.Types

-- | Every encoding, in the specification's file order.
encodings :: [Encoding]
encodings =
  [ Encoding "ABS_32_dp_1src" 0xfffffc00 0x5ac02000 Covered
  , Encoding "ABS_64_dp_1src" 0xfffffc00 0xdac02000 Covered
  , Encoding "ABS_asisdmisc_R" 0xff3ffc00 0x5e20b800 Covered
  , Encoding "ABS_asimdmisc_R" 0xbf3ffc00 0x0e20b800 Covered
  , Encoding "ADC_32_addsub_carry" 0xffe0fc00 0x1a000000 Covered
  , Encoding "ADC_64_addsub_carry" 0xffe0fc00 0x9a000000 Covered
  , Encoding "ADCS_32_addsub_carry" 0xffe0fc00 0x3a000000 Covered
  , Encoding "ADCS_64_addsub_carry" 0xffe0fc00 0xba000000 Covered
  , Encoding "ADD_32_addsub_ext" 0xffe00000 0x0b200000 Covered
  , Encoding "ADD_64_addsub_ext" 0xffe00000 0x8b200000 Covered
  , Encoding "ADD_32_addsub_imm" 0xff800000 0x11000000 Covered
  , Encoding "ADD_64_addsub_imm" 0xff800000 0x91000000 Covered
  , Encoding "ADD_32_addsub_shift" 0xff200000 0x0b000000 Covered
  , Encoding "ADD_64_addsub_shift" 0xff200000 0x8b000000 Covered
  , Encoding "ADD_asisdsame_only" 0xff20fc00 0x5e208400 Covered
  , Encoding "ADD_asimdsame_only" 0xbf20fc00 0x0e208400 Covered
  , Encoding "ADDG_64_addsub_immtags" 0xffc00000 0x91800000
      (Outside [(5, OpXSp)])
  , Encoding "ADDHN_asimddiff_N" 0xbf20fc00 0x0e204000 Covered
  , Encoding "ADDP_asisdpair_only" 0xff3ffc00 0x5e31b800 Covered
  , Encoding "ADDP_asimdsame_only" 0xbf20fc00 0x0e20bc00 Covered
  , Encoding "ADDS_32S_addsub_ext" 0xffe00000 0x2b200000 Covered
  , Encoding "ADDS_64S_addsub_ext" 0xffe00000 0xab200000 Covered
  , Encoding "ADDS_32S_addsub_imm" 0xff800000 0x31000000 Covered
  , Encoding "ADDS_64S_addsub_imm" 0xff800000 0xb1000000 Covered
  , Encoding "ADDS_32_addsub_shift" 0xff200000 0x2b000000 Covered
  , Encoding "ADDS_64_addsub_shift" 0xff200000 0xab000000 Covered
  , Encoding "ADDV_asimdall_only" 0xbf3ffc00 0x0e31b800 Covered
  , Encoding "ADR_only_pcreladdr" 0x9f000000 0x10000000 (Outside [])
  , Encoding "ADRP_only_pcreladdr" 0x9f000000 0x90000000 (Outside [])
  , Encoding "AESD_B_cryptoaes" 0xfffffc00 0x4e285800 Covered
  , Encoding "AESE_B_cryptoaes" 0xfffffc00 0x4e284800 Covered
  , Encoding "AESIMC_B_cryptoaes" 0xfffffc00 0x4e287800 Covered
  , Encoding "AESMC_B_cryptoaes" 0xfffffc00 0x4e286800 Covered
  , Encoding "AND_asimdsame_only" 0xbfe0fc00 0x0e201c00 Covered
  , Encoding "AND_32_log_imm" 0xffc00000 0x12000000 Covered
  , Encoding "AND_64_log_imm" 0xff800000 0x92000000 Covered
  , Encoding "AND_32_log_shift" 0xff200000 0x0a000000 Covered
  , Encoding "AND_64_log_shift" 0xff200000 0x8a000000 Covered
  , Encoding "ANDS_32S_log_imm" 0xffc00000 0x72000000 Covered
  , Encoding "ANDS_64S_log_imm" 0xff800000 0xf2000000 Covered
  , Encoding "ANDS_32_log_shift" 0xff200000 0x6a000000 Covered
  , Encoding "ANDS_64_log_shift" 0xff200000 0xea000000 Covered
  , Encoding "ASRV_32_dp_2src" 0xffe0fc00 0x1ac02800 Covered
  , Encoding "ASRV_64_dp_2src" 0xffe0fc00 0x9ac02800 Covered
  , Encoding "AUTDA_64P_dp_1src" 0xfffffc00 0xdac11800 (Outside [(5, OpXSp)])
  , Encoding "AUTDZA_64Z_dp_1src" 0xffffffe0 0xdac13be0 (Outside [])
  , Encoding "AUTDB_64P_dp_1src" 0xfffffc00 0xdac11c00 (Outside [(5, OpXSp)])
  , Encoding "AUTDZB_64Z_dp_1src" 0xffffffe0 0xdac13fe0 (Outside [])
  , Encoding "AUTIA_64P_dp_1src" 0xfffffc00 0xdac11000 (Outside [(5, OpXSp)])
  , Encoding "AUTIZA_64Z_dp_1src" 0xffffffe0 0xdac133e0 (Outside [])
  , Encoding "AUTIA1716_HI_hints" 0xfffff23f 0xd503201f (Outside [])
  , Encoding "AUTIASP_HI_hints" 0xfffff23f 0xd503223f (Outside [])
  , Encoding "AUTIAZ_HI_hints" 0xfffff23f 0xd503221f (Outside [])
  , Encoding "AUTIB_64P_dp_1src" 0xfffffc00 0xdac11400 (Outside [(5, OpXSp)])
  , Encoding "AUTIZB_64Z_dp_1src" 0xffffffe0 0xdac137e0 (Outside [])
  , Encoding "AUTIB1716_HI_hints" 0xfffff23f 0xd503201f (Outside [])
  , Encoding "AUTIBSP_HI_hints" 0xfffff23f 0xd503223f (Outside [])
  , Encoding "AUTIBZ_HI_hints" 0xfffff23f 0xd503221f (Outside [])
  , Encoding "AXFLAG_M_pstate" 0xfffff0ff 0xd500405f Control
  , Encoding "B_only_condbranch" 0xff000010 0x54000000 Control
  , Encoding "B_only_branch_imm" 0xfc000000 0x14000000 Control
  , Encoding "BC_only_condbranch" 0xff000010 0x54000010 Control
  , Encoding "BCAX_VVV16_crypto4" 0xffe08000 0xce200000 Covered
  , Encoding "BFCVT_BS_floatdp1" 0xfffffc00 0x1e634000 (Outside [(5, OpS)])
  , Encoding "BFCVTN_asimdmisc_4S" 0xbffffc00 0x0ea16800 (Outside [(5, OpV)])
  , Encoding "BFDOT_asimdelem_E" 0xbfc0f400 0x0f40f000 (Outside [(5, OpV)])
  , Encoding "BFDOT_asimdsame2_D" 0xbfe0fc00 0x2e40fc00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "BFM_32M_bitfield" 0xffc00000 0x33000000 Covered
  , Encoding "BFM_64M_bitfield" 0xffc00000 0xb3400000 Covered
  , Encoding "BFMLAL_asimdelem_F" 0xbfc0f400 0x0fc0f000 (Outside [(5, OpV)])
  , Encoding "BFMLAL_asimdsame2_F_" 0xbfe0fc00 0x2ec0fc00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "BFMMLA_asimdsame2_E" 0xffe0fc00 0x6e40ec00
      (Outside [(0, OpV), (5, OpV), (16, OpV)])
  , Encoding "BIC_asimdimm_L_hl" 0xbff8cc00 0x2f008400 Covered
  , Encoding "BIC_asimdimm_L_sl" 0xbff88c00 0x2f000400 Covered
  , Encoding "BIC_asimdsame_only" 0xbfe0fc00 0x0e601c00 Covered
  , Encoding "BIC_32_log_shift" 0xff200000 0x0a200000 Covered
  , Encoding "BIC_64_log_shift" 0xff200000 0x8a200000 Covered
  , Encoding "BICS_32_log_shift" 0xff200000 0x6a200000 Covered
  , Encoding "BICS_64_log_shift" 0xff200000 0xea200000 Covered
  , Encoding "BIF_asimdsame_only" 0xbfe0fc00 0x2ee01c00 Covered
  , Encoding "BIT_asimdsame_only" 0xbfe0fc00 0x2ea01c00 Covered
  , Encoding "BL_only_branch_imm" 0xfc000000 0x94000000 Control
  , Encoding "BLR_64_branch_reg" 0xfffffc1f 0xd63f0000 Control
  , Encoding "BLRAAZ_64_branch_reg" 0xfffffc1f 0xd63f081f Control
  , Encoding "BLRAA_64P_branch_reg" 0xfffffc00 0xd73f0800 Control
  , Encoding "BLRABZ_64_branch_reg" 0xfffffc1f 0xd63f0c1f Control
  , Encoding "BLRAB_64P_branch_reg" 0xfffffc00 0xd73f0c00 Control
  , Encoding "BR_64_branch_reg" 0xfffffc1f 0xd61f0000 Control
  , Encoding "BRAAZ_64_branch_reg" 0xfffffc1f 0xd61f081f Control
  , Encoding "BRAA_64P_branch_reg" 0xfffffc00 0xd71f0800 Control
  , Encoding "BRABZ_64_branch_reg" 0xfffffc1f 0xd61f0c1f Control
  , Encoding "BRAB_64P_branch_reg" 0xfffffc00 0xd71f0c00 Control
  , Encoding "BRK_EX_exception" 0xffe0001f 0xd4200000 Control
  , Encoding "BSL_asimdsame_only" 0xbfe0fc00 0x2e601c00 Covered
  , Encoding "BTI_HB_hints" 0xffffff3f 0xd503241f Control
  , Encoding "CAS_C32_comswap" 0x7fe0fc00 0x08a07c00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASA_C32_comswap" 0x7fe0fc00 0x08e07c00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASAL_C32_comswap" 0x7fe0fc00 0x08e0fc00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASL_C32_comswap" 0x7fe0fc00 0x08a0fc00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CAS_C64_comswap" 0x7fe0fc00 0x48a07c00
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "CASA_C64_comswap" 0x7fe0fc00 0x48e07c00
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "CASAL_C64_comswap" 0x7fe0fc00 0x48e0fc00
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "CASL_C64_comswap" 0x7fe0fc00 0x48a0fc00
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "CASAB_C32_comswap" 0xffe0fc00 0x08e07c00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASALB_C32_comswap" 0xffe0fc00 0x08e0fc00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASB_C32_comswap" 0xffe0fc00 0x08a07c00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASLB_C32_comswap" 0xffe0fc00 0x08a0fc00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASAH_C32_comswap" 0xffe0fc00 0x48e07c00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASALH_C32_comswap" 0xffe0fc00 0x48e0fc00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASH_C32_comswap" 0xffe0fc00 0x48a07c00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASLH_C32_comswap" 0xffe0fc00 0x48a0fc00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASP_CP32_comswappr" 0xffe0fc00 0x08207c00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASPA_CP32_comswappr" 0xffe0fc00 0x08607c00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASPAL_CP32_comswappr" 0xffe0fc00 0x0860fc00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASPL_CP32_comswappr" 0xffe0fc00 0x0820fc00
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "CASP_CP64_comswappr" 0xffe0fc00 0x48207c00
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "CASPA_CP64_comswappr" 0xffe0fc00 0x48607c00
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "CASPAL_CP64_comswappr" 0xffe0fc00 0x4860fc00
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "CASPL_CP64_comswappr" 0xffe0fc00 0x4820fc00
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "CBNZ_32_compbranch" 0xff000000 0x35000000 Control
  , Encoding "CBNZ_64_compbranch" 0xff000000 0xb5000000 Control
  , Encoding "CBZ_32_compbranch" 0xff000000 0x34000000 Control
  , Encoding "CBZ_64_compbranch" 0xff000000 0xb4000000 Control
  , Encoding "CCMN_32_condcmp_imm" 0xffe00c10 0x3a400800 Covered
  , Encoding "CCMN_64_condcmp_imm" 0xffe00c10 0xba400800 Covered
  , Encoding "CCMN_32_condcmp_reg" 0xffe00c10 0x3a400000 Covered
  , Encoding "CCMN_64_condcmp_reg" 0xffe00c10 0xba400000 Covered
  , Encoding "CCMP_32_condcmp_imm" 0xffe00c10 0x7a400800 Covered
  , Encoding "CCMP_64_condcmp_imm" 0xffe00c10 0xfa400800 Covered
  , Encoding "CCMP_32_condcmp_reg" 0xffe00c10 0x7a400000 Covered
  , Encoding "CCMP_64_condcmp_reg" 0xffe00c10 0xfa400000 Covered
  , Encoding "CFINV_M_pstate" 0xfffff0ff 0xd500401f Covered
  , Encoding "CHKFEAT_HI_hints" 0xffffffff 0xd503251f Control
  , Encoding "CLRBHB_HI_hints" 0xffffffff 0xd50322df Control
  , Encoding "CLREX_BN_barriers" 0xfffff0ff 0xd503305f Control
  , Encoding "CLS_asimdmisc_R" 0xbf3ffc00 0x0e204800 Covered
  , Encoding "CLS_32_dp_1src" 0xfffffc00 0x5ac01400 Covered
  , Encoding "CLS_64_dp_1src" 0xfffffc00 0xdac01400 Covered
  , Encoding "CLZ_asimdmisc_R" 0xbf3ffc00 0x2e204800 Covered
  , Encoding "CLZ_32_dp_1src" 0xfffffc00 0x5ac01000 Covered
  , Encoding "CLZ_64_dp_1src" 0xfffffc00 0xdac01000 Covered
  , Encoding "CMEQ_asisdsame_only" 0xff20fc00 0x7e208c00 Covered
  , Encoding "CMEQ_asimdsame_only" 0xbf20fc00 0x2e208c00 Covered
  , Encoding "CMEQ_asisdmisc_Z" 0xff3ffc00 0x5e209800 Covered
  , Encoding "CMEQ_asimdmisc_Z" 0xbf3ffc00 0x0e209800 Covered
  , Encoding "CMGE_asisdsame_only" 0xff20fc00 0x5e203c00 Covered
  , Encoding "CMGE_asimdsame_only" 0xbf20fc00 0x0e203c00 Covered
  , Encoding "CMGE_asisdmisc_Z" 0xff3ffc00 0x7e208800 Covered
  , Encoding "CMGE_asimdmisc_Z" 0xbf3ffc00 0x2e208800 Covered
  , Encoding "CMGT_asisdsame_only" 0xff20fc00 0x5e203400 Covered
  , Encoding "CMGT_asimdsame_only" 0xbf20fc00 0x0e203400 Covered
  , Encoding "CMGT_asisdmisc_Z" 0xff3ffc00 0x5e208800 Covered
  , Encoding "CMGT_asimdmisc_Z" 0xbf3ffc00 0x0e208800 Covered
  , Encoding "CMHI_asisdsame_only" 0xff20fc00 0x7e203400 Covered
  , Encoding "CMHI_asimdsame_only" 0xbf20fc00 0x2e203400 Covered
  , Encoding "CMHS_asisdsame_only" 0xff20fc00 0x7e203c00 Covered
  , Encoding "CMHS_asimdsame_only" 0xbf20fc00 0x2e203c00 Covered
  , Encoding "CMLE_asisdmisc_Z" 0xff3ffc00 0x7e209800 Covered
  , Encoding "CMLE_asimdmisc_Z" 0xbf3ffc00 0x2e209800 Covered
  , Encoding "CMLT_asisdmisc_Z" 0xff3ffc00 0x5e20a800 Covered
  , Encoding "CMLT_asimdmisc_Z" 0xbf3ffc00 0x0e20a800 Covered
  , Encoding "CMTST_asisdsame_only" 0xff20fc00 0x5e208c00 Covered
  , Encoding "CMTST_asimdsame_only" 0xbf20fc00 0x0e208c00 Covered
  , Encoding "CNT_32_dp_1src" 0xfffffc00 0x5ac01c00 Covered
  , Encoding "CNT_64_dp_1src" 0xfffffc00 0xdac01c00 Covered
  , Encoding "CNT_asimdmisc_R" 0xbf3ffc00 0x0e205800 Covered
  , Encoding "CPYFE_CPY_memcms" 0x3fe0fc00 0x19800400 (Outside [(5, OpX)])
  , Encoding "CPYFM_CPY_memcms" 0x3fe0fc00 0x19400400 (Outside [(5, OpX)])
  , Encoding "CPYFP_CPY_memcms" 0x3fe0fc00 0x19000400 (Outside [])
  , Encoding "CPYFEN_CPY_memcms" 0x3fe0fc00 0x1980c400 (Outside [(5, OpX)])
  , Encoding "CPYFMN_CPY_memcms" 0x3fe0fc00 0x1940c400 (Outside [(5, OpX)])
  , Encoding "CPYFPN_CPY_memcms" 0x3fe0fc00 0x1900c400 (Outside [])
  , Encoding "CPYFERN_CPY_memcms" 0x3fe0fc00 0x19808400 (Outside [(5, OpX)])
  , Encoding "CPYFMRN_CPY_memcms" 0x3fe0fc00 0x19408400 (Outside [(5, OpX)])
  , Encoding "CPYFPRN_CPY_memcms" 0x3fe0fc00 0x19008400 (Outside [])
  , Encoding "CPYFERT_CPY_memcms" 0x3fe0fc00 0x19802400 (Outside [(5, OpX)])
  , Encoding "CPYFMRT_CPY_memcms" 0x3fe0fc00 0x19402400 (Outside [(5, OpX)])
  , Encoding "CPYFPRT_CPY_memcms" 0x3fe0fc00 0x19002400 (Outside [])
  , Encoding "CPYFERTN_CPY_memcms" 0x3fe0fc00 0x1980e400 (Outside [(5, OpX)])
  , Encoding "CPYFMRTN_CPY_memcms" 0x3fe0fc00 0x1940e400 (Outside [(5, OpX)])
  , Encoding "CPYFPRTN_CPY_memcms" 0x3fe0fc00 0x1900e400 (Outside [])
  , Encoding "CPYFERTRN_CPY_memcms" 0x3fe0fc00 0x1980a400 (Outside [(5, OpX)])
  , Encoding "CPYFMRTRN_CPY_memcms" 0x3fe0fc00 0x1940a400 (Outside [(5, OpX)])
  , Encoding "CPYFPRTRN_CPY_memcms" 0x3fe0fc00 0x1900a400 (Outside [])
  , Encoding "CPYFERTWN_CPY_memcms" 0x3fe0fc00 0x19806400 (Outside [(5, OpX)])
  , Encoding "CPYFMRTWN_CPY_memcms" 0x3fe0fc00 0x19406400 (Outside [(5, OpX)])
  , Encoding "CPYFPRTWN_CPY_memcms" 0x3fe0fc00 0x19006400 (Outside [])
  , Encoding "CPYFET_CPY_memcms" 0x3fe0fc00 0x19803400 (Outside [(5, OpX)])
  , Encoding "CPYFMT_CPY_memcms" 0x3fe0fc00 0x19403400 (Outside [(5, OpX)])
  , Encoding "CPYFPT_CPY_memcms" 0x3fe0fc00 0x19003400 (Outside [])
  , Encoding "CPYFETN_CPY_memcms" 0x3fe0fc00 0x1980f400 (Outside [(5, OpX)])
  , Encoding "CPYFMTN_CPY_memcms" 0x3fe0fc00 0x1940f400 (Outside [(5, OpX)])
  , Encoding "CPYFPTN_CPY_memcms" 0x3fe0fc00 0x1900f400 (Outside [])
  , Encoding "CPYFETRN_CPY_memcms" 0x3fe0fc00 0x1980b400 (Outside [(5, OpX)])
  , Encoding "CPYFMTRN_CPY_memcms" 0x3fe0fc00 0x1940b400 (Outside [(5, OpX)])
  , Encoding "CPYFPTRN_CPY_memcms" 0x3fe0fc00 0x1900b400 (Outside [])
  , Encoding "CPYFETWN_CPY_memcms" 0x3fe0fc00 0x19807400 (Outside [(5, OpX)])
  , Encoding "CPYFMTWN_CPY_memcms" 0x3fe0fc00 0x19407400 (Outside [(5, OpX)])
  , Encoding "CPYFPTWN_CPY_memcms" 0x3fe0fc00 0x19007400 (Outside [])
  , Encoding "CPYFEWN_CPY_memcms" 0x3fe0fc00 0x19804400 (Outside [(5, OpX)])
  , Encoding "CPYFMWN_CPY_memcms" 0x3fe0fc00 0x19404400 (Outside [(5, OpX)])
  , Encoding "CPYFPWN_CPY_memcms" 0x3fe0fc00 0x19004400 (Outside [])
  , Encoding "CPYFEWT_CPY_memcms" 0x3fe0fc00 0x19801400 (Outside [(5, OpX)])
  , Encoding "CPYFMWT_CPY_memcms" 0x3fe0fc00 0x19401400 (Outside [(5, OpX)])
  , Encoding "CPYFPWT_CPY_memcms" 0x3fe0fc00 0x19001400 (Outside [])
  , Encoding "CPYFEWTN_CPY_memcms" 0x3fe0fc00 0x1980d400 (Outside [(5, OpX)])
  , Encoding "CPYFMWTN_CPY_memcms" 0x3fe0fc00 0x1940d400 (Outside [(5, OpX)])
  , Encoding "CPYFPWTN_CPY_memcms" 0x3fe0fc00 0x1900d400 (Outside [])
  , Encoding "CPYFEWTRN_CPY_memcms" 0x3fe0fc00 0x19809400 (Outside [(5, OpX)])
  , Encoding "CPYFMWTRN_CPY_memcms" 0x3fe0fc00 0x19409400 (Outside [(5, OpX)])
  , Encoding "CPYFPWTRN_CPY_memcms" 0x3fe0fc00 0x19009400 (Outside [])
  , Encoding "CPYFEWTWN_CPY_memcms" 0x3fe0fc00 0x19805400 (Outside [(5, OpX)])
  , Encoding "CPYFMWTWN_CPY_memcms" 0x3fe0fc00 0x19405400 (Outside [(5, OpX)])
  , Encoding "CPYFPWTWN_CPY_memcms" 0x3fe0fc00 0x19005400 (Outside [])
  , Encoding "CPYE_CPY_memcms" 0x3fe0fc00 0x1d800400 (Outside [(5, OpX)])
  , Encoding "CPYM_CPY_memcms" 0x3fe0fc00 0x1d400400 (Outside [(5, OpX)])
  , Encoding "CPYP_CPY_memcms" 0x3fe0fc00 0x1d000400 (Outside [])
  , Encoding "CPYEN_CPY_memcms" 0x3fe0fc00 0x1d80c400 (Outside [(5, OpX)])
  , Encoding "CPYMN_CPY_memcms" 0x3fe0fc00 0x1d40c400 (Outside [(5, OpX)])
  , Encoding "CPYPN_CPY_memcms" 0x3fe0fc00 0x1d00c400 (Outside [])
  , Encoding "CPYERN_CPY_memcms" 0x3fe0fc00 0x1d808400 (Outside [(5, OpX)])
  , Encoding "CPYMRN_CPY_memcms" 0x3fe0fc00 0x1d408400 (Outside [(5, OpX)])
  , Encoding "CPYPRN_CPY_memcms" 0x3fe0fc00 0x1d008400 (Outside [])
  , Encoding "CPYERT_CPY_memcms" 0x3fe0fc00 0x1d802400 (Outside [(5, OpX)])
  , Encoding "CPYMRT_CPY_memcms" 0x3fe0fc00 0x1d402400 (Outside [(5, OpX)])
  , Encoding "CPYPRT_CPY_memcms" 0x3fe0fc00 0x1d002400 (Outside [])
  , Encoding "CPYERTN_CPY_memcms" 0x3fe0fc00 0x1d80e400 (Outside [(5, OpX)])
  , Encoding "CPYMRTN_CPY_memcms" 0x3fe0fc00 0x1d40e400 (Outside [(5, OpX)])
  , Encoding "CPYPRTN_CPY_memcms" 0x3fe0fc00 0x1d00e400 (Outside [])
  , Encoding "CPYERTRN_CPY_memcms" 0x3fe0fc00 0x1d80a400 (Outside [(5, OpX)])
  , Encoding "CPYMRTRN_CPY_memcms" 0x3fe0fc00 0x1d40a400 (Outside [(5, OpX)])
  , Encoding "CPYPRTRN_CPY_memcms" 0x3fe0fc00 0x1d00a400 (Outside [])
  , Encoding "CPYERTWN_CPY_memcms" 0x3fe0fc00 0x1d806400 (Outside [(5, OpX)])
  , Encoding "CPYMRTWN_CPY_memcms" 0x3fe0fc00 0x1d406400 (Outside [(5, OpX)])
  , Encoding "CPYPRTWN_CPY_memcms" 0x3fe0fc00 0x1d006400 (Outside [])
  , Encoding "CPYET_CPY_memcms" 0x3fe0fc00 0x1d803400 (Outside [(5, OpX)])
  , Encoding "CPYMT_CPY_memcms" 0x3fe0fc00 0x1d403400 (Outside [(5, OpX)])
  , Encoding "CPYPT_CPY_memcms" 0x3fe0fc00 0x1d003400 (Outside [])
  , Encoding "CPYETN_CPY_memcms" 0x3fe0fc00 0x1d80f400 (Outside [(5, OpX)])
  , Encoding "CPYMTN_CPY_memcms" 0x3fe0fc00 0x1d40f400 (Outside [(5, OpX)])
  , Encoding "CPYPTN_CPY_memcms" 0x3fe0fc00 0x1d00f400 (Outside [])
  , Encoding "CPYETRN_CPY_memcms" 0x3fe0fc00 0x1d80b400 (Outside [(5, OpX)])
  , Encoding "CPYMTRN_CPY_memcms" 0x3fe0fc00 0x1d40b400 (Outside [(5, OpX)])
  , Encoding "CPYPTRN_CPY_memcms" 0x3fe0fc00 0x1d00b400 (Outside [])
  , Encoding "CPYETWN_CPY_memcms" 0x3fe0fc00 0x1d807400 (Outside [(5, OpX)])
  , Encoding "CPYMTWN_CPY_memcms" 0x3fe0fc00 0x1d407400 (Outside [(5, OpX)])
  , Encoding "CPYPTWN_CPY_memcms" 0x3fe0fc00 0x1d007400 (Outside [])
  , Encoding "CPYEWN_CPY_memcms" 0x3fe0fc00 0x1d804400 (Outside [(5, OpX)])
  , Encoding "CPYMWN_CPY_memcms" 0x3fe0fc00 0x1d404400 (Outside [(5, OpX)])
  , Encoding "CPYPWN_CPY_memcms" 0x3fe0fc00 0x1d004400 (Outside [])
  , Encoding "CPYEWT_CPY_memcms" 0x3fe0fc00 0x1d801400 (Outside [(5, OpX)])
  , Encoding "CPYMWT_CPY_memcms" 0x3fe0fc00 0x1d401400 (Outside [(5, OpX)])
  , Encoding "CPYPWT_CPY_memcms" 0x3fe0fc00 0x1d001400 (Outside [])
  , Encoding "CPYEWTN_CPY_memcms" 0x3fe0fc00 0x1d80d400 (Outside [(5, OpX)])
  , Encoding "CPYMWTN_CPY_memcms" 0x3fe0fc00 0x1d40d400 (Outside [(5, OpX)])
  , Encoding "CPYPWTN_CPY_memcms" 0x3fe0fc00 0x1d00d400 (Outside [])
  , Encoding "CPYEWTRN_CPY_memcms" 0x3fe0fc00 0x1d809400 (Outside [(5, OpX)])
  , Encoding "CPYMWTRN_CPY_memcms" 0x3fe0fc00 0x1d409400 (Outside [(5, OpX)])
  , Encoding "CPYPWTRN_CPY_memcms" 0x3fe0fc00 0x1d009400 (Outside [])
  , Encoding "CPYEWTWN_CPY_memcms" 0x3fe0fc00 0x1d805400 (Outside [(5, OpX)])
  , Encoding "CPYMWTWN_CPY_memcms" 0x3fe0fc00 0x1d405400 (Outside [(5, OpX)])
  , Encoding "CPYPWTWN_CPY_memcms" 0x3fe0fc00 0x1d005400 (Outside [])
  , Encoding "CRC32B_32C_dp_2src" 0xffe0fc00 0x1ac04000 Covered
  , Encoding "CRC32H_32C_dp_2src" 0xffe0fc00 0x1ac04400 Covered
  , Encoding "CRC32W_32C_dp_2src" 0xffe0fc00 0x1ac04800 Covered
  , Encoding "CRC32X_64C_dp_2src" 0xffe0fc00 0x9ac04c00 Covered
  , Encoding "CRC32CB_32C_dp_2src" 0xffe0fc00 0x1ac05000 Covered
  , Encoding "CRC32CH_32C_dp_2src" 0xffe0fc00 0x1ac05400 Covered
  , Encoding "CRC32CW_32C_dp_2src" 0xffe0fc00 0x1ac05800 Covered
  , Encoding "CRC32CX_64C_dp_2src" 0xffe0fc00 0x9ac05c00 Covered
  , Encoding "CSDB_HI_hints" 0xffffffff 0xd503229f Control
  , Encoding "CSEL_32_condsel" 0xffe00c00 0x1a800000 Covered
  , Encoding "CSEL_64_condsel" 0xffe00c00 0x9a800000 Covered
  , Encoding "CSINC_32_condsel" 0xffe00c00 0x1a800400 Covered
  , Encoding "CSINC_64_condsel" 0xffe00c00 0x9a800400 Covered
  , Encoding "CSINV_32_condsel" 0xffe00c00 0x5a800000 Covered
  , Encoding "CSINV_64_condsel" 0xffe00c00 0xda800000 Covered
  , Encoding "CSNEG_32_condsel" 0xffe00c00 0x5a800400 Covered
  , Encoding "CSNEG_64_condsel" 0xffe00c00 0xda800400 Covered
  , Encoding "CTZ_32_dp_1src" 0xfffffc00 0x5ac01800 Covered
  , Encoding "CTZ_64_dp_1src" 0xfffffc00 0xdac01800 Covered
  , Encoding "DCPS1_DC_exception" 0xffe0001f 0xd4a00001 Control
  , Encoding "DCPS2_DC_exception" 0xffe0001f 0xd4a00002 Control
  , Encoding "DCPS3_DC_exception" 0xffe0001f 0xd4a00003 Control
  , Encoding "DGH_HI_hints" 0xffffffff 0xd50320df Control
  , Encoding "DMB_BO_barriers" 0xfffff0ff 0xd50330bf Control
  , Encoding "DRPS_64E_branch_reg" 0xffffffff 0xd6bf03e0 Control
  , Encoding "DSB_BO_barriers" 0xfffff0ff 0xd503309f Control
  , Encoding "DSB_BOn_barriers" 0xfffff3ff 0xd503323f Control
  , Encoding "DUP_asisdone_only" 0xffe0fc00 0x5e000400 Covered
  , Encoding "DUP_asimdins_DV_v" 0xbfe0fc00 0x0e000400 Covered
  , Encoding "DUP_asimdins_DR_r" 0xbfe0fc00 0x0e000c00 Covered
  , Encoding "EON_32_log_shift" 0xff200000 0x4a200000 Covered
  , Encoding "EON_64_log_shift" 0xff200000 0xca200000 Covered
  , Encoding "EOR3_VVV16_crypto4" 0xffe08000 0xce000000 Covered
  , Encoding "EOR_asimdsame_only" 0xbfe0fc00 0x2e201c00 Covered
  , Encoding "EOR_32_log_imm" 0xffc00000 0x52000000 Covered
  , Encoding "EOR_64_log_imm" 0xff800000 0xd2000000 Covered
  , Encoding "EOR_32_log_shift" 0xff200000 0x4a000000 Covered
  , Encoding "EOR_64_log_shift" 0xff200000 0xca000000 Covered
  , Encoding "ERET_64E_branch_reg" 0xffffffff 0xd69f03e0 Control
  , Encoding "ERETAA_64E_branch_reg" 0xffffffff 0xd69f0bff Control
  , Encoding "ERETAB_64E_branch_reg" 0xffffffff 0xd69f0fff Control
  , Encoding "ESB_HI_hints" 0xffffffff 0xd503221f Control
  , Encoding "EXT_asimdext_only" 0xbfe08400 0x2e000000 Covered
  , Encoding "EXTR_32_extract" 0xffe08000 0x13800000 Covered
  , Encoding "EXTR_64_extract" 0xffe00000 0x93c00000 Covered
  , Encoding "FABD_asisdsamefp16_only" 0xffe0fc00 0x7ec01400
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FABD_asisdsame_only" 0xffa0fc00 0x7ea0d400 (Outside [])
  , Encoding "FABD_asimdsamefp16_only" 0xbfe0fc00 0x2ec01400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FABD_asimdsame_only" 0xbfa0fc00 0x2ea0d400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FABS_asimdmiscfp16_R" 0xbffffc00 0x0ef8f800 (Outside [(5, OpV)])
  , Encoding "FABS_asimdmisc_R" 0xbfbffc00 0x0ea0f800 (Outside [(5, OpV)])
  , Encoding "FABS_H_floatdp1" 0xfffffc00 0x1ee0c000 (Outside [(5, OpH)])
  , Encoding "FABS_S_floatdp1" 0xfffffc00 0x1e20c000 (Outside [(5, OpS)])
  , Encoding "FABS_D_floatdp1" 0xfffffc00 0x1e60c000 (Outside [(5, OpD)])
  , Encoding "FACGE_asisdsamefp16_only" 0xffe0fc00 0x7e402c00
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FACGE_asisdsame_only" 0xffa0fc00 0x7e20ec00 (Outside [])
  , Encoding "FACGE_asimdsamefp16_only" 0xbfe0fc00 0x2e402c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FACGE_asimdsame_only" 0xbfa0fc00 0x2e20ec00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FACGT_asisdsamefp16_only" 0xffe0fc00 0x7ec02c00
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FACGT_asisdsame_only" 0xffa0fc00 0x7ea0ec00 (Outside [])
  , Encoding "FACGT_asimdsamefp16_only" 0xbfe0fc00 0x2ec02c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FACGT_asimdsame_only" 0xbfa0fc00 0x2ea0ec00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FADD_asimdsamefp16_only" 0xbfe0fc00 0x0e401400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FADD_asimdsame_only" 0xbfa0fc00 0x0e20d400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FADD_H_floatdp2" 0xffe0fc00 0x1ee02800
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FADD_S_floatdp2" 0xffe0fc00 0x1e202800
      (Outside [(5, OpS), (16, OpS)])
  , Encoding "FADD_D_floatdp2" 0xffe0fc00 0x1e602800
      (Outside [(5, OpD), (16, OpD)])
  , Encoding "FADDP_asisdpair_only_H" 0xffbffc00 0x5e30d800
      (Outside [(5, OpVWhole)])
  , Encoding "FADDP_asisdpair_only_SD" 0xffbffc00 0x7e30d800
      (Outside [(5, OpVWhole)])
  , Encoding "FADDP_asimdsamefp16_only" 0xbfe0fc00 0x2e401400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FADDP_asimdsame_only" 0xbfa0fc00 0x2e20d400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FCADD_asimdsame2_C" 0xbf20ec00 0x2e00e400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FCCMP_H_floatccmp" 0xffe00c10 0x1ee00400
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FCCMP_S_floatccmp" 0xffe00c10 0x1e200400
      (Outside [(5, OpS), (16, OpS)])
  , Encoding "FCCMP_D_floatccmp" 0xffe00c10 0x1e600400
      (Outside [(5, OpD), (16, OpD)])
  , Encoding "FCCMPE_H_floatccmp" 0xffe00c10 0x1ee00410
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FCCMPE_S_floatccmp" 0xffe00c10 0x1e200410
      (Outside [(5, OpS), (16, OpS)])
  , Encoding "FCCMPE_D_floatccmp" 0xffe00c10 0x1e600410
      (Outside [(5, OpD), (16, OpD)])
  , Encoding "FCMEQ_asisdsamefp16_only" 0xffe0fc00 0x5e402400
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FCMEQ_asisdsame_only" 0xffa0fc00 0x5e20e400 (Outside [])
  , Encoding "FCMEQ_asimdsamefp16_only" 0xbfe0fc00 0x0e402400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FCMEQ_asimdsame_only" 0xbfa0fc00 0x0e20e400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FCMEQ_asisdmiscfp16_FZ" 0xfffffc00 0x5ef8d800
      (Outside [(5, OpH)])
  , Encoding "FCMEQ_asisdmisc_FZ" 0xffbffc00 0x5ea0d800 (Outside [])
  , Encoding "FCMEQ_asimdmiscfp16_FZ" 0xbffffc00 0x0ef8d800
      (Outside [(5, OpV)])
  , Encoding "FCMEQ_asimdmisc_FZ" 0xbfbffc00 0x0ea0d800 (Outside [(5, OpV)])
  , Encoding "FCMGE_asisdsamefp16_only" 0xffe0fc00 0x7e402400
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FCMGE_asisdsame_only" 0xffa0fc00 0x7e20e400 (Outside [])
  , Encoding "FCMGE_asimdsamefp16_only" 0xbfe0fc00 0x2e402400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FCMGE_asimdsame_only" 0xbfa0fc00 0x2e20e400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FCMGE_asisdmiscfp16_FZ" 0xfffffc00 0x7ef8c800
      (Outside [(5, OpH)])
  , Encoding "FCMGE_asisdmisc_FZ" 0xffbffc00 0x7ea0c800 (Outside [])
  , Encoding "FCMGE_asimdmiscfp16_FZ" 0xbffffc00 0x2ef8c800
      (Outside [(5, OpV)])
  , Encoding "FCMGE_asimdmisc_FZ" 0xbfbffc00 0x2ea0c800 (Outside [(5, OpV)])
  , Encoding "FCMGT_asisdsamefp16_only" 0xffe0fc00 0x7ec02400
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FCMGT_asisdsame_only" 0xffa0fc00 0x7ea0e400 (Outside [])
  , Encoding "FCMGT_asimdsamefp16_only" 0xbfe0fc00 0x2ec02400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FCMGT_asimdsame_only" 0xbfa0fc00 0x2ea0e400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FCMGT_asisdmiscfp16_FZ" 0xfffffc00 0x5ef8c800
      (Outside [(5, OpH)])
  , Encoding "FCMGT_asisdmisc_FZ" 0xffbffc00 0x5ea0c800 (Outside [])
  , Encoding "FCMGT_asimdmiscfp16_FZ" 0xbffffc00 0x0ef8c800
      (Outside [(5, OpV)])
  , Encoding "FCMGT_asimdmisc_FZ" 0xbfbffc00 0x0ea0c800 (Outside [(5, OpV)])
  , Encoding "FCMLA_asimdelem_C_H" 0xbfc09400 0x2f401000 (Outside [(5, OpV)])
  , Encoding "FCMLA_asimdelem_C_S" 0xbfc09400 0x2f801000 (Outside [(5, OpV)])
  , Encoding "FCMLA_asimdsame2_C" 0xbf20e400 0x2e00c400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FCMLE_asisdmiscfp16_FZ" 0xfffffc00 0x7ef8d800
      (Outside [(5, OpH)])
  , Encoding "FCMLE_asisdmisc_FZ" 0xffbffc00 0x7ea0d800 (Outside [])
  , Encoding "FCMLE_asimdmiscfp16_FZ" 0xbffffc00 0x2ef8d800
      (Outside [(5, OpV)])
  , Encoding "FCMLE_asimdmisc_FZ" 0xbfbffc00 0x2ea0d800 (Outside [(5, OpV)])
  , Encoding "FCMLT_asisdmiscfp16_FZ" 0xfffffc00 0x5ef8e800
      (Outside [(5, OpH)])
  , Encoding "FCMLT_asisdmisc_FZ" 0xffbffc00 0x5ea0e800 (Outside [])
  , Encoding "FCMLT_asimdmiscfp16_FZ" 0xbffffc00 0x0ef8e800
      (Outside [(5, OpV)])
  , Encoding "FCMLT_asimdmisc_FZ" 0xbfbffc00 0x0ea0e800 (Outside [(5, OpV)])
  , Encoding "FCMP_H_floatcmp" 0xffe0fc0f 0x1ee02000
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FCMP_HZ_floatcmp" 0xffe0fc0f 0x1ee02008 (Outside [(5, OpH)])
  , Encoding "FCMP_S_floatcmp" 0xffe0fc0f 0x1e202000
      (Outside [(5, OpS), (16, OpS)])
  , Encoding "FCMP_SZ_floatcmp" 0xffe0fc0f 0x1e202008 (Outside [(5, OpS)])
  , Encoding "FCMP_D_floatcmp" 0xffe0fc0f 0x1e602000
      (Outside [(5, OpD), (16, OpD)])
  , Encoding "FCMP_DZ_floatcmp" 0xffe0fc0f 0x1e602008 (Outside [(5, OpD)])
  , Encoding "FCMPE_H_floatcmp" 0xffe0fc0f 0x1ee02000
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FCMPE_HZ_floatcmp" 0xffe0fc0f 0x1ee02008 (Outside [(5, OpH)])
  , Encoding "FCMPE_S_floatcmp" 0xffe0fc0f 0x1e202000
      (Outside [(5, OpS), (16, OpS)])
  , Encoding "FCMPE_SZ_floatcmp" 0xffe0fc0f 0x1e202008 (Outside [(5, OpS)])
  , Encoding "FCMPE_D_floatcmp" 0xffe0fc0f 0x1e602000
      (Outside [(5, OpD), (16, OpD)])
  , Encoding "FCMPE_DZ_floatcmp" 0xffe0fc0f 0x1e602008 (Outside [(5, OpD)])
  , Encoding "FCSEL_H_floatsel" 0xffe00c00 0x1ee00c00 Covered
  , Encoding "FCSEL_S_floatsel" 0xffe00c00 0x1e200c00 Covered
  , Encoding "FCSEL_D_floatsel" 0xffe00c00 0x1e600c00 Covered
  , Encoding "FCVT_SH_floatdp1" 0xfffffc00 0x1ee24000 (Outside [(5, OpH)])
  , Encoding "FCVT_DH_floatdp1" 0xfffffc00 0x1ee2c000 (Outside [(5, OpH)])
  , Encoding "FCVT_HS_floatdp1" 0xfffffc00 0x1e23c000 (Outside [(5, OpS)])
  , Encoding "FCVT_DS_floatdp1" 0xfffffc00 0x1e22c000 (Outside [(5, OpS)])
  , Encoding "FCVT_HD_floatdp1" 0xfffffc00 0x1e63c000 (Outside [(5, OpD)])
  , Encoding "FCVT_SD_floatdp1" 0xfffffc00 0x1e624000 (Outside [(5, OpD)])
  , Encoding "FCVTAS_asisdmiscfp16_R" 0xfffffc00 0x5e79c800
      (Outside [(5, OpH)])
  , Encoding "FCVTAS_asisdmisc_R" 0xffbffc00 0x5e21c800 (Outside [])
  , Encoding "FCVTAS_asimdmiscfp16_R" 0xbffffc00 0x0e79c800
      (Outside [(5, OpV)])
  , Encoding "FCVTAS_asimdmisc_R" 0xbfbffc00 0x0e21c800 (Outside [(5, OpV)])
  , Encoding "FCVTAS_32H_float2int" 0xfffffc00 0x1ee40000 (Outside [(5, OpH)])
  , Encoding "FCVTAS_64H_float2int" 0xfffffc00 0x9ee40000 (Outside [(5, OpH)])
  , Encoding "FCVTAS_32S_float2int" 0xfffffc00 0x1e240000 (Outside [(5, OpS)])
  , Encoding "FCVTAS_64S_float2int" 0xfffffc00 0x9e240000 (Outside [(5, OpS)])
  , Encoding "FCVTAS_32D_float2int" 0xfffffc00 0x1e640000 (Outside [(5, OpD)])
  , Encoding "FCVTAS_64D_float2int" 0xfffffc00 0x9e640000 (Outside [(5, OpD)])
  , Encoding "FCVTAU_asisdmiscfp16_R" 0xfffffc00 0x7e79c800
      (Outside [(5, OpH)])
  , Encoding "FCVTAU_asisdmisc_R" 0xffbffc00 0x7e21c800 (Outside [])
  , Encoding "FCVTAU_asimdmiscfp16_R" 0xbffffc00 0x2e79c800
      (Outside [(5, OpV)])
  , Encoding "FCVTAU_asimdmisc_R" 0xbfbffc00 0x2e21c800 (Outside [(5, OpV)])
  , Encoding "FCVTAU_32H_float2int" 0xfffffc00 0x1ee50000 (Outside [(5, OpH)])
  , Encoding "FCVTAU_64H_float2int" 0xfffffc00 0x9ee50000 (Outside [(5, OpH)])
  , Encoding "FCVTAU_32S_float2int" 0xfffffc00 0x1e250000 (Outside [(5, OpS)])
  , Encoding "FCVTAU_64S_float2int" 0xfffffc00 0x9e250000 (Outside [(5, OpS)])
  , Encoding "FCVTAU_32D_float2int" 0xfffffc00 0x1e650000 (Outside [(5, OpD)])
  , Encoding "FCVTAU_64D_float2int" 0xfffffc00 0x9e650000 (Outside [(5, OpD)])
  , Encoding "FCVTL_asimdmisc_L" 0xbfbffc00 0x0e217800 (Outside [(5, OpV)])
  , Encoding "FCVTMS_asisdmiscfp16_R" 0xfffffc00 0x5e79b800
      (Outside [(5, OpH)])
  , Encoding "FCVTMS_asisdmisc_R" 0xffbffc00 0x5e21b800 (Outside [])
  , Encoding "FCVTMS_asimdmiscfp16_R" 0xbffffc00 0x0e79b800
      (Outside [(5, OpV)])
  , Encoding "FCVTMS_asimdmisc_R" 0xbfbffc00 0x0e21b800 (Outside [(5, OpV)])
  , Encoding "FCVTMS_32H_float2int" 0xfffffc00 0x1ef00000 (Outside [(5, OpH)])
  , Encoding "FCVTMS_64H_float2int" 0xfffffc00 0x9ef00000 (Outside [(5, OpH)])
  , Encoding "FCVTMS_32S_float2int" 0xfffffc00 0x1e300000 (Outside [(5, OpS)])
  , Encoding "FCVTMS_64S_float2int" 0xfffffc00 0x9e300000 (Outside [(5, OpS)])
  , Encoding "FCVTMS_32D_float2int" 0xfffffc00 0x1e700000 (Outside [(5, OpD)])
  , Encoding "FCVTMS_64D_float2int" 0xfffffc00 0x9e700000 (Outside [(5, OpD)])
  , Encoding "FCVTMU_asisdmiscfp16_R" 0xfffffc00 0x7e79b800
      (Outside [(5, OpH)])
  , Encoding "FCVTMU_asisdmisc_R" 0xffbffc00 0x7e21b800 (Outside [])
  , Encoding "FCVTMU_asimdmiscfp16_R" 0xbffffc00 0x2e79b800
      (Outside [(5, OpV)])
  , Encoding "FCVTMU_asimdmisc_R" 0xbfbffc00 0x2e21b800 (Outside [(5, OpV)])
  , Encoding "FCVTMU_32H_float2int" 0xfffffc00 0x1ef10000 (Outside [(5, OpH)])
  , Encoding "FCVTMU_64H_float2int" 0xfffffc00 0x9ef10000 (Outside [(5, OpH)])
  , Encoding "FCVTMU_32S_float2int" 0xfffffc00 0x1e310000 (Outside [(5, OpS)])
  , Encoding "FCVTMU_64S_float2int" 0xfffffc00 0x9e310000 (Outside [(5, OpS)])
  , Encoding "FCVTMU_32D_float2int" 0xfffffc00 0x1e710000 (Outside [(5, OpD)])
  , Encoding "FCVTMU_64D_float2int" 0xfffffc00 0x9e710000 (Outside [(5, OpD)])
  , Encoding "FCVTN_asimdmisc_N" 0xbfbffc00 0x0e216800 (Outside [(5, OpV)])
  , Encoding "FCVTNS_asisdmiscfp16_R" 0xfffffc00 0x5e79a800
      (Outside [(5, OpH)])
  , Encoding "FCVTNS_asisdmisc_R" 0xffbffc00 0x5e21a800 (Outside [])
  , Encoding "FCVTNS_asimdmiscfp16_R" 0xbffffc00 0x0e79a800
      (Outside [(5, OpV)])
  , Encoding "FCVTNS_asimdmisc_R" 0xbfbffc00 0x0e21a800 (Outside [(5, OpV)])
  , Encoding "FCVTNS_32H_float2int" 0xfffffc00 0x1ee00000 (Outside [(5, OpH)])
  , Encoding "FCVTNS_64H_float2int" 0xfffffc00 0x9ee00000 (Outside [(5, OpH)])
  , Encoding "FCVTNS_32S_float2int" 0xfffffc00 0x1e200000 (Outside [(5, OpS)])
  , Encoding "FCVTNS_64S_float2int" 0xfffffc00 0x9e200000 (Outside [(5, OpS)])
  , Encoding "FCVTNS_32D_float2int" 0xfffffc00 0x1e600000 (Outside [(5, OpD)])
  , Encoding "FCVTNS_64D_float2int" 0xfffffc00 0x9e600000 (Outside [(5, OpD)])
  , Encoding "FCVTNU_asisdmiscfp16_R" 0xfffffc00 0x7e79a800
      (Outside [(5, OpH)])
  , Encoding "FCVTNU_asisdmisc_R" 0xffbffc00 0x7e21a800 (Outside [])
  , Encoding "FCVTNU_asimdmiscfp16_R" 0xbffffc00 0x2e79a800
      (Outside [(5, OpV)])
  , Encoding "FCVTNU_asimdmisc_R" 0xbfbffc00 0x2e21a800 (Outside [(5, OpV)])
  , Encoding "FCVTNU_32H_float2int" 0xfffffc00 0x1ee10000 (Outside [(5, OpH)])
  , Encoding "FCVTNU_64H_float2int" 0xfffffc00 0x9ee10000 (Outside [(5, OpH)])
  , Encoding "FCVTNU_32S_float2int" 0xfffffc00 0x1e210000 (Outside [(5, OpS)])
  , Encoding "FCVTNU_64S_float2int" 0xfffffc00 0x9e210000 (Outside [(5, OpS)])
  , Encoding "FCVTNU_32D_float2int" 0xfffffc00 0x1e610000 (Outside [(5, OpD)])
  , Encoding "FCVTNU_64D_float2int" 0xfffffc00 0x9e610000 (Outside [(5, OpD)])
  , Encoding "FCVTPS_asisdmiscfp16_R" 0xfffffc00 0x5ef9a800
      (Outside [(5, OpH)])
  , Encoding "FCVTPS_asisdmisc_R" 0xffbffc00 0x5ea1a800 (Outside [])
  , Encoding "FCVTPS_asimdmiscfp16_R" 0xbffffc00 0x0ef9a800
      (Outside [(5, OpV)])
  , Encoding "FCVTPS_asimdmisc_R" 0xbfbffc00 0x0ea1a800 (Outside [(5, OpV)])
  , Encoding "FCVTPS_32H_float2int" 0xfffffc00 0x1ee80000 (Outside [(5, OpH)])
  , Encoding "FCVTPS_64H_float2int" 0xfffffc00 0x9ee80000 (Outside [(5, OpH)])
  , Encoding "FCVTPS_32S_float2int" 0xfffffc00 0x1e280000 (Outside [(5, OpS)])
  , Encoding "FCVTPS_64S_float2int" 0xfffffc00 0x9e280000 (Outside [(5, OpS)])
  , Encoding "FCVTPS_32D_float2int" 0xfffffc00 0x1e680000 (Outside [(5, OpD)])
  , Encoding "FCVTPS_64D_float2int" 0xfffffc00 0x9e680000 (Outside [(5, OpD)])
  , Encoding "FCVTPU_asisdmiscfp16_R" 0xfffffc00 0x7ef9a800
      (Outside [(5, OpH)])
  , Encoding "FCVTPU_asisdmisc_R" 0xffbffc00 0x7ea1a800 (Outside [])
  , Encoding "FCVTPU_asimdmiscfp16_R" 0xbffffc00 0x2ef9a800
      (Outside [(5, OpV)])
  , Encoding "FCVTPU_asimdmisc_R" 0xbfbffc00 0x2ea1a800 (Outside [(5, OpV)])
  , Encoding "FCVTPU_32H_float2int" 0xfffffc00 0x1ee90000 (Outside [(5, OpH)])
  , Encoding "FCVTPU_64H_float2int" 0xfffffc00 0x9ee90000 (Outside [(5, OpH)])
  , Encoding "FCVTPU_32S_float2int" 0xfffffc00 0x1e290000 (Outside [(5, OpS)])
  , Encoding "FCVTPU_64S_float2int" 0xfffffc00 0x9e290000 (Outside [(5, OpS)])
  , Encoding "FCVTPU_32D_float2int" 0xfffffc00 0x1e690000 (Outside [(5, OpD)])
  , Encoding "FCVTPU_64D_float2int" 0xfffffc00 0x9e690000 (Outside [(5, OpD)])
  , Encoding "FCVTXN_asisdmisc_N" 0xffbffc00 0x7e216800 (Outside [])
  , Encoding "FCVTXN_asimdmisc_N" 0xbfbffc00 0x2e216800 (Outside [(5, OpV)])
  , Encoding "FCVTZS_asisdshf_C" 0xff80fc00 0x5f00fc00 (Outside [])
  , Encoding "FCVTZS_asimdshf_C" 0xbf80fc00 0x0f00fc00 (Outside [(5, OpV)])
  , Encoding "FCVTZS_asisdmiscfp16_R" 0xfffffc00 0x5ef9b800
      (Outside [(5, OpH)])
  , Encoding "FCVTZS_asisdmisc_R" 0xffbffc00 0x5ea1b800 (Outside [])
  , Encoding "FCVTZS_asimdmiscfp16_R" 0xbffffc00 0x0ef9b800
      (Outside [(5, OpV)])
  , Encoding "FCVTZS_asimdmisc_R" 0xbfbffc00 0x0ea1b800 (Outside [(5, OpV)])
  , Encoding "FCVTZS_32H_float2fix" 0xffff0000 0x1ed80000 (Outside [(5, OpH)])
  , Encoding "FCVTZS_64H_float2fix" 0xffff0000 0x9ed80000 (Outside [(5, OpH)])
  , Encoding "FCVTZS_32S_float2fix" 0xffff0000 0x1e180000 (Outside [(5, OpS)])
  , Encoding "FCVTZS_64S_float2fix" 0xffff0000 0x9e180000 (Outside [(5, OpS)])
  , Encoding "FCVTZS_32D_float2fix" 0xffff0000 0x1e580000 (Outside [(5, OpD)])
  , Encoding "FCVTZS_64D_float2fix" 0xffff0000 0x9e580000 (Outside [(5, OpD)])
  , Encoding "FCVTZS_32H_float2int" 0xfffffc00 0x1ef80000 (Outside [(5, OpH)])
  , Encoding "FCVTZS_64H_float2int" 0xfffffc00 0x9ef80000 (Outside [(5, OpH)])
  , Encoding "FCVTZS_32S_float2int" 0xfffffc00 0x1e380000 (Outside [(5, OpS)])
  , Encoding "FCVTZS_64S_float2int" 0xfffffc00 0x9e380000 (Outside [(5, OpS)])
  , Encoding "FCVTZS_32D_float2int" 0xfffffc00 0x1e780000 (Outside [(5, OpD)])
  , Encoding "FCVTZS_64D_float2int" 0xfffffc00 0x9e780000 (Outside [(5, OpD)])
  , Encoding "FCVTZU_asisdshf_C" 0xff80fc00 0x7f00fc00 (Outside [])
  , Encoding "FCVTZU_asimdshf_C" 0xbf80fc00 0x2f00fc00 (Outside [(5, OpV)])
  , Encoding "FCVTZU_asisdmiscfp16_R" 0xfffffc00 0x7ef9b800
      (Outside [(5, OpH)])
  , Encoding "FCVTZU_asisdmisc_R" 0xffbffc00 0x7ea1b800 (Outside [])
  , Encoding "FCVTZU_asimdmiscfp16_R" 0xbffffc00 0x2ef9b800
      (Outside [(5, OpV)])
  , Encoding "FCVTZU_asimdmisc_R" 0xbfbffc00 0x2ea1b800 (Outside [(5, OpV)])
  , Encoding "FCVTZU_32H_float2fix" 0xffff0000 0x1ed90000 (Outside [(5, OpH)])
  , Encoding "FCVTZU_64H_float2fix" 0xffff0000 0x9ed90000 (Outside [(5, OpH)])
  , Encoding "FCVTZU_32S_float2fix" 0xffff0000 0x1e190000 (Outside [(5, OpS)])
  , Encoding "FCVTZU_64S_float2fix" 0xffff0000 0x9e190000 (Outside [(5, OpS)])
  , Encoding "FCVTZU_32D_float2fix" 0xffff0000 0x1e590000 (Outside [(5, OpD)])
  , Encoding "FCVTZU_64D_float2fix" 0xffff0000 0x9e590000 (Outside [(5, OpD)])
  , Encoding "FCVTZU_32H_float2int" 0xfffffc00 0x1ef90000 (Outside [(5, OpH)])
  , Encoding "FCVTZU_64H_float2int" 0xfffffc00 0x9ef90000 (Outside [(5, OpH)])
  , Encoding "FCVTZU_32S_float2int" 0xfffffc00 0x1e390000 (Outside [(5, OpS)])
  , Encoding "FCVTZU_64S_float2int" 0xfffffc00 0x9e390000 (Outside [(5, OpS)])
  , Encoding "FCVTZU_32D_float2int" 0xfffffc00 0x1e790000 (Outside [(5, OpD)])
  , Encoding "FCVTZU_64D_float2int" 0xfffffc00 0x9e790000 (Outside [(5, OpD)])
  , Encoding "FDIV_asimdsamefp16_only" 0xbfe0fc00 0x2e403c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FDIV_asimdsame_only" 0xbfa0fc00 0x2e20fc00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FDIV_H_floatdp2" 0xffe0fc00 0x1ee01800
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FDIV_S_floatdp2" 0xffe0fc00 0x1e201800
      (Outside [(5, OpS), (16, OpS)])
  , Encoding "FDIV_D_floatdp2" 0xffe0fc00 0x1e601800
      (Outside [(5, OpD), (16, OpD)])
  , Encoding "FJCVTZS_32D_float2int" 0xfffffc00 0x1e7e0000 (Outside [(5, OpD)])
  , Encoding "FMADD_H_floatdp3" 0xffe08000 0x1fc00000
      (Outside [(5, OpH), (10, OpH), (16, OpH)])
  , Encoding "FMADD_S_floatdp3" 0xffe08000 0x1f000000
      (Outside [(5, OpS), (10, OpS), (16, OpS)])
  , Encoding "FMADD_D_floatdp3" 0xffe08000 0x1f400000
      (Outside [(5, OpD), (10, OpD), (16, OpD)])
  , Encoding "FMAX_asimdsamefp16_only" 0xbfe0fc00 0x0e403400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMAX_asimdsame_only" 0xbfa0fc00 0x0e20f400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMAX_H_floatdp2" 0xffe0fc00 0x1ee04800
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FMAX_S_floatdp2" 0xffe0fc00 0x1e204800
      (Outside [(5, OpS), (16, OpS)])
  , Encoding "FMAX_D_floatdp2" 0xffe0fc00 0x1e604800
      (Outside [(5, OpD), (16, OpD)])
  , Encoding "FMAXNM_asimdsamefp16_only" 0xbfe0fc00 0x0e400400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMAXNM_asimdsame_only" 0xbfa0fc00 0x0e20c400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMAXNM_H_floatdp2" 0xffe0fc00 0x1ee06800
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FMAXNM_S_floatdp2" 0xffe0fc00 0x1e206800
      (Outside [(5, OpS), (16, OpS)])
  , Encoding "FMAXNM_D_floatdp2" 0xffe0fc00 0x1e606800
      (Outside [(5, OpD), (16, OpD)])
  , Encoding "FMAXNMP_asisdpair_only_H" 0xffbffc00 0x5e30c800
      (Outside [(5, OpVWhole)])
  , Encoding "FMAXNMP_asisdpair_only_SD" 0xffbffc00 0x7e30c800
      (Outside [(5, OpVWhole)])
  , Encoding "FMAXNMP_asimdsamefp16_only" 0xbfe0fc00 0x2e400400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMAXNMP_asimdsame_only" 0xbfa0fc00 0x2e20c400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMAXNMV_asimdall_only_H" 0xbffffc00 0x0e30c800
      (Outside [(5, OpV)])
  , Encoding "FMAXNMV_asimdall_only_SD" 0xbfbffc00 0x2e30c800
      (Outside [(5, OpV)])
  , Encoding "FMAXP_asisdpair_only_H" 0xffbffc00 0x5e30f800
      (Outside [(5, OpVWhole)])
  , Encoding "FMAXP_asisdpair_only_SD" 0xffbffc00 0x7e30f800
      (Outside [(5, OpVWhole)])
  , Encoding "FMAXP_asimdsamefp16_only" 0xbfe0fc00 0x2e403400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMAXP_asimdsame_only" 0xbfa0fc00 0x2e20f400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMAXV_asimdall_only_H" 0xbffffc00 0x0e30f800 (Outside [(5, OpV)])
  , Encoding "FMAXV_asimdall_only_SD" 0xbfbffc00 0x2e30f800
      (Outside [(5, OpV)])
  , Encoding "FMIN_asimdsamefp16_only" 0xbfe0fc00 0x0ec03400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMIN_asimdsame_only" 0xbfa0fc00 0x0ea0f400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMIN_H_floatdp2" 0xffe0fc00 0x1ee05800
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FMIN_S_floatdp2" 0xffe0fc00 0x1e205800
      (Outside [(5, OpS), (16, OpS)])
  , Encoding "FMIN_D_floatdp2" 0xffe0fc00 0x1e605800
      (Outside [(5, OpD), (16, OpD)])
  , Encoding "FMINNM_asimdsamefp16_only" 0xbfe0fc00 0x0ec00400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMINNM_asimdsame_only" 0xbfa0fc00 0x0ea0c400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMINNM_H_floatdp2" 0xffe0fc00 0x1ee07800
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FMINNM_S_floatdp2" 0xffe0fc00 0x1e207800
      (Outside [(5, OpS), (16, OpS)])
  , Encoding "FMINNM_D_floatdp2" 0xffe0fc00 0x1e607800
      (Outside [(5, OpD), (16, OpD)])
  , Encoding "FMINNMP_asisdpair_only_H" 0xffbffc00 0x5eb0c800
      (Outside [(5, OpVWhole)])
  , Encoding "FMINNMP_asisdpair_only_SD" 0xffbffc00 0x7eb0c800
      (Outside [(5, OpVWhole)])
  , Encoding "FMINNMP_asimdsamefp16_only" 0xbfe0fc00 0x2ec00400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMINNMP_asimdsame_only" 0xbfa0fc00 0x2ea0c400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMINNMV_asimdall_only_H" 0xbffffc00 0x0eb0c800
      (Outside [(5, OpV)])
  , Encoding "FMINNMV_asimdall_only_SD" 0xbfbffc00 0x2eb0c800
      (Outside [(5, OpV)])
  , Encoding "FMINP_asisdpair_only_H" 0xffbffc00 0x5eb0f800
      (Outside [(5, OpVWhole)])
  , Encoding "FMINP_asisdpair_only_SD" 0xffbffc00 0x7eb0f800
      (Outside [(5, OpVWhole)])
  , Encoding "FMINP_asimdsamefp16_only" 0xbfe0fc00 0x2ec03400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMINP_asimdsame_only" 0xbfa0fc00 0x2ea0f400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMINV_asimdall_only_H" 0xbffffc00 0x0eb0f800 (Outside [(5, OpV)])
  , Encoding "FMINV_asimdall_only_SD" 0xbfbffc00 0x2eb0f800
      (Outside [(5, OpV)])
  , Encoding "FMLA_asisdelem_RH_H" 0xffc0f400 0x5f001000 (Outside [(5, OpH)])
  , Encoding "FMLA_asisdelem_R_SD" 0xff80f400 0x5f801000 (Outside [])
  , Encoding "FMLA_asimdelem_RH_H" 0xbfc0f400 0x0f001000 (Outside [(5, OpV)])
  , Encoding "FMLA_asimdelem_R_SD" 0xbf80f400 0x0f801000 (Outside [(5, OpV)])
  , Encoding "FMLA_asimdsamefp16_only" 0xbfe0fc00 0x0e400c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMLA_asimdsame_only" 0xbfa0fc00 0x0e20cc00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMLAL_asimdelem_LH" 0xbfc0f400 0x0f800000 (Outside [(5, OpV)])
  , Encoding "FMLAL2_asimdelem_LH" 0xbfc0f400 0x2f808000 (Outside [(5, OpV)])
  , Encoding "FMLAL_asimdsame_F" 0xbfe0fc00 0x0e20ec00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMLAL2_asimdsame_F" 0xbfe0fc00 0x2e20cc00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMLS_asisdelem_RH_H" 0xffc0f400 0x5f005000 (Outside [(5, OpH)])
  , Encoding "FMLS_asisdelem_R_SD" 0xff80f400 0x5f805000 (Outside [])
  , Encoding "FMLS_asimdelem_RH_H" 0xbfc0f400 0x0f005000 (Outside [(5, OpV)])
  , Encoding "FMLS_asimdelem_R_SD" 0xbf80f400 0x0f805000 (Outside [(5, OpV)])
  , Encoding "FMLS_asimdsamefp16_only" 0xbfe0fc00 0x0ec00c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMLS_asimdsame_only" 0xbfa0fc00 0x0ea0cc00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMLSL_asimdelem_LH" 0xbfc0f400 0x0f804000 (Outside [(5, OpV)])
  , Encoding "FMLSL2_asimdelem_LH" 0xbfc0f400 0x2f80c000 (Outside [(5, OpV)])
  , Encoding "FMLSL_asimdsame_F" 0xbfe0fc00 0x0ea0ec00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMLSL2_asimdsame_F" 0xbfe0fc00 0x2ea0cc00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMOV_asimdimm_H_h" 0xbff8fc00 0x0f00fc00 (Outside [])
  , Encoding "FMOV_asimdimm_S_s" 0xbff8fc00 0x0f00f400 (Outside [])
  , Encoding "FMOV_asimdimm_D2_d" 0xfff8fc00 0x6f00f400 (Outside [])
  , Encoding "FMOV_H_floatdp1" 0xfffffc00 0x1ee04000 (Outside [(5, OpH)])
  , Encoding "FMOV_S_floatdp1" 0xfffffc00 0x1e204000 (Outside [(5, OpS)])
  , Encoding "FMOV_D_floatdp1" 0xfffffc00 0x1e604000 (Outside [(5, OpD)])
  , Encoding "FMOV_32H_float2int" 0xffe9fc00 0x1ee00000 (Outside [(5, OpH)])
  , Encoding "FMOV_64H_float2int" 0xffe9fc00 0x9ee00000 (Outside [(5, OpH)])
  , Encoding "FMOV_H32_float2int" 0xffe9fc00 0x1ee10000 (Outside [(5, OpW)])
  , Encoding "FMOV_S32_float2int" 0xffe9fc00 0x1e210000 (Outside [(5, OpW)])
  , Encoding "FMOV_32S_float2int" 0xffe9fc00 0x1e200000 (Outside [(5, OpS)])
  , Encoding "FMOV_H64_float2int" 0xffe9fc00 0x9ee10000 (Outside [(5, OpX)])
  , Encoding "FMOV_D64_float2int" 0xffe9fc00 0x9e610000 (Outside [(5, OpX)])
  , Encoding "FMOV_V64I_float2int" 0xffe9fc00 0x9ea90000 (Outside [(5, OpX)])
  , Encoding "FMOV_64D_float2int" 0xffe9fc00 0x9e600000 (Outside [(5, OpD)])
  , Encoding "FMOV_64VX_float2int" 0xffe9fc00 0x9ea80000
      (Outside [(5, OpVWhole)])
  , Encoding "FMOV_H_floatimm" 0xffe01fe0 0x1ee01000 (Outside [])
  , Encoding "FMOV_S_floatimm" 0xffe01fe0 0x1e201000 (Outside [])
  , Encoding "FMOV_D_floatimm" 0xffe01fe0 0x1e601000 (Outside [])
  , Encoding "FMSUB_H_floatdp3" 0xffe08000 0x1fc08000
      (Outside [(5, OpH), (10, OpH), (16, OpH)])
  , Encoding "FMSUB_S_floatdp3" 0xffe08000 0x1f008000
      (Outside [(5, OpS), (10, OpS), (16, OpS)])
  , Encoding "FMSUB_D_floatdp3" 0xffe08000 0x1f408000
      (Outside [(5, OpD), (10, OpD), (16, OpD)])
  , Encoding "FMUL_asisdelem_RH_H" 0xffc0f400 0x5f009000 (Outside [(5, OpH)])
  , Encoding "FMUL_asisdelem_R_SD" 0xff80f400 0x5f809000 (Outside [])
  , Encoding "FMUL_asimdelem_RH_H" 0xbfc0f400 0x0f009000 (Outside [(5, OpV)])
  , Encoding "FMUL_asimdelem_R_SD" 0xbf80f400 0x0f809000 (Outside [(5, OpV)])
  , Encoding "FMUL_asimdsamefp16_only" 0xbfe0fc00 0x2e401c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMUL_asimdsame_only" 0xbfa0fc00 0x2e20dc00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMUL_H_floatdp2" 0xffe0fc00 0x1ee00800
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FMUL_S_floatdp2" 0xffe0fc00 0x1e200800
      (Outside [(5, OpS), (16, OpS)])
  , Encoding "FMUL_D_floatdp2" 0xffe0fc00 0x1e600800
      (Outside [(5, OpD), (16, OpD)])
  , Encoding "FMULX_asisdelem_RH_H" 0xffc0f400 0x7f009000 (Outside [(5, OpH)])
  , Encoding "FMULX_asisdelem_R_SD" 0xff80f400 0x7f809000 (Outside [])
  , Encoding "FMULX_asimdelem_RH_H" 0xbfc0f400 0x2f009000 (Outside [(5, OpV)])
  , Encoding "FMULX_asimdelem_R_SD" 0xbf80f400 0x2f809000 (Outside [(5, OpV)])
  , Encoding "FMULX_asisdsamefp16_only" 0xffe0fc00 0x5e401c00
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FMULX_asisdsame_only" 0xffa0fc00 0x5e20dc00 (Outside [])
  , Encoding "FMULX_asimdsamefp16_only" 0xbfe0fc00 0x0e401c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FMULX_asimdsame_only" 0xbfa0fc00 0x0e20dc00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FNEG_asimdmiscfp16_R" 0xbffffc00 0x2ef8f800 (Outside [(5, OpV)])
  , Encoding "FNEG_asimdmisc_R" 0xbfbffc00 0x2ea0f800 (Outside [(5, OpV)])
  , Encoding "FNEG_H_floatdp1" 0xfffffc00 0x1ee14000 (Outside [(5, OpH)])
  , Encoding "FNEG_S_floatdp1" 0xfffffc00 0x1e214000 (Outside [(5, OpS)])
  , Encoding "FNEG_D_floatdp1" 0xfffffc00 0x1e614000 (Outside [(5, OpD)])
  , Encoding "FNMADD_H_floatdp3" 0xffe08000 0x1fe00000
      (Outside [(5, OpH), (10, OpH), (16, OpH)])
  , Encoding "FNMADD_S_floatdp3" 0xffe08000 0x1f200000
      (Outside [(5, OpS), (10, OpS), (16, OpS)])
  , Encoding "FNMADD_D_floatdp3" 0xffe08000 0x1f600000
      (Outside [(5, OpD), (10, OpD), (16, OpD)])
  , Encoding "FNMSUB_H_floatdp3" 0xffe08000 0x1fe08000
      (Outside [(5, OpH), (10, OpH), (16, OpH)])
  , Encoding "FNMSUB_S_floatdp3" 0xffe08000 0x1f208000
      (Outside [(5, OpS), (10, OpS), (16, OpS)])
  , Encoding "FNMSUB_D_floatdp3" 0xffe08000 0x1f608000
      (Outside [(5, OpD), (10, OpD), (16, OpD)])
  , Encoding "FNMUL_H_floatdp2" 0xffe0fc00 0x1ee08800
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FNMUL_S_floatdp2" 0xffe0fc00 0x1e208800
      (Outside [(5, OpS), (16, OpS)])
  , Encoding "FNMUL_D_floatdp2" 0xffe0fc00 0x1e608800
      (Outside [(5, OpD), (16, OpD)])
  , Encoding "FRECPE_asisdmiscfp16_R" 0xfffffc00 0x5ef9d800
      (Outside [(5, OpH)])
  , Encoding "FRECPE_asisdmisc_R" 0xffbffc00 0x5ea1d800 (Outside [])
  , Encoding "FRECPE_asimdmiscfp16_R" 0xbffffc00 0x0ef9d800
      (Outside [(5, OpV)])
  , Encoding "FRECPE_asimdmisc_R" 0xbfbffc00 0x0ea1d800 (Outside [(5, OpV)])
  , Encoding "FRECPS_asisdsamefp16_only" 0xffe0fc00 0x5e403c00
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FRECPS_asisdsame_only" 0xffa0fc00 0x5e20fc00 (Outside [])
  , Encoding "FRECPS_asimdsamefp16_only" 0xbfe0fc00 0x0e403c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FRECPS_asimdsame_only" 0xbfa0fc00 0x0e20fc00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FRECPX_asisdmiscfp16_R" 0xfffffc00 0x5ef9f800
      (Outside [(5, OpH)])
  , Encoding "FRECPX_asisdmisc_R" 0xffbffc00 0x5ea1f800 (Outside [])
  , Encoding "FRINT32X_asimdmisc_R" 0xbfbffc00 0x2e21e800 (Outside [(5, OpV)])
  , Encoding "FRINT32X_S_floatdp1" 0xff7ffc00 0x1e28c000 (Outside [(5, OpS)])
  , Encoding "FRINT32X_D_floatdp1" 0xff7ffc00 0x1e68c000 (Outside [(5, OpD)])
  , Encoding "FRINT32Z_asimdmisc_R" 0xbfbffc00 0x0e21e800 (Outside [(5, OpV)])
  , Encoding "FRINT32Z_S_floatdp1" 0xff7ffc00 0x1e284000 (Outside [(5, OpS)])
  , Encoding "FRINT32Z_D_floatdp1" 0xff7ffc00 0x1e684000 (Outside [(5, OpD)])
  , Encoding "FRINT64X_asimdmisc_R" 0xbfbffc00 0x2e21f800 (Outside [(5, OpV)])
  , Encoding "FRINT64X_S_floatdp1" 0xff7ffc00 0x1e29c000 (Outside [(5, OpS)])
  , Encoding "FRINT64X_D_floatdp1" 0xff7ffc00 0x1e69c000 (Outside [(5, OpD)])
  , Encoding "FRINT64Z_asimdmisc_R" 0xbfbffc00 0x0e21f800 (Outside [(5, OpV)])
  , Encoding "FRINT64Z_S_floatdp1" 0xff7ffc00 0x1e294000 (Outside [(5, OpS)])
  , Encoding "FRINT64Z_D_floatdp1" 0xff7ffc00 0x1e694000 (Outside [(5, OpD)])
  , Encoding "FRINTA_asimdmiscfp16_R" 0xbffffc00 0x2e798800
      (Outside [(5, OpV)])
  , Encoding "FRINTA_asimdmisc_R" 0xbfbffc00 0x2e218800 (Outside [(5, OpV)])
  , Encoding "FRINTA_H_floatdp1" 0xfffffc00 0x1ee64000 (Outside [(5, OpH)])
  , Encoding "FRINTA_S_floatdp1" 0xfffffc00 0x1e264000 (Outside [(5, OpS)])
  , Encoding "FRINTA_D_floatdp1" 0xfffffc00 0x1e664000 (Outside [(5, OpD)])
  , Encoding "FRINTI_asimdmiscfp16_R" 0xbffffc00 0x2ef99800
      (Outside [(5, OpV)])
  , Encoding "FRINTI_asimdmisc_R" 0xbfbffc00 0x2ea19800 (Outside [(5, OpV)])
  , Encoding "FRINTI_H_floatdp1" 0xfffffc00 0x1ee7c000 (Outside [(5, OpH)])
  , Encoding "FRINTI_S_floatdp1" 0xfffffc00 0x1e27c000 (Outside [(5, OpS)])
  , Encoding "FRINTI_D_floatdp1" 0xfffffc00 0x1e67c000 (Outside [(5, OpD)])
  , Encoding "FRINTM_asimdmiscfp16_R" 0xbffffc00 0x0e799800
      (Outside [(5, OpV)])
  , Encoding "FRINTM_asimdmisc_R" 0xbfbffc00 0x0e219800 (Outside [(5, OpV)])
  , Encoding "FRINTM_H_floatdp1" 0xfffffc00 0x1ee54000 (Outside [(5, OpH)])
  , Encoding "FRINTM_S_floatdp1" 0xfffffc00 0x1e254000 (Outside [(5, OpS)])
  , Encoding "FRINTM_D_floatdp1" 0xfffffc00 0x1e654000 (Outside [(5, OpD)])
  , Encoding "FRINTN_asimdmiscfp16_R" 0xbffffc00 0x0e798800
      (Outside [(5, OpV)])
  , Encoding "FRINTN_asimdmisc_R" 0xbfbffc00 0x0e218800 (Outside [(5, OpV)])
  , Encoding "FRINTN_H_floatdp1" 0xfffffc00 0x1ee44000 (Outside [(5, OpH)])
  , Encoding "FRINTN_S_floatdp1" 0xfffffc00 0x1e244000 (Outside [(5, OpS)])
  , Encoding "FRINTN_D_floatdp1" 0xfffffc00 0x1e644000 (Outside [(5, OpD)])
  , Encoding "FRINTP_asimdmiscfp16_R" 0xbffffc00 0x0ef98800
      (Outside [(5, OpV)])
  , Encoding "FRINTP_asimdmisc_R" 0xbfbffc00 0x0ea18800 (Outside [(5, OpV)])
  , Encoding "FRINTP_H_floatdp1" 0xfffffc00 0x1ee4c000 (Outside [(5, OpH)])
  , Encoding "FRINTP_S_floatdp1" 0xfffffc00 0x1e24c000 (Outside [(5, OpS)])
  , Encoding "FRINTP_D_floatdp1" 0xfffffc00 0x1e64c000 (Outside [(5, OpD)])
  , Encoding "FRINTX_asimdmiscfp16_R" 0xbffffc00 0x2e799800
      (Outside [(5, OpV)])
  , Encoding "FRINTX_asimdmisc_R" 0xbfbffc00 0x2e219800 (Outside [(5, OpV)])
  , Encoding "FRINTX_H_floatdp1" 0xfffffc00 0x1ee74000 (Outside [(5, OpH)])
  , Encoding "FRINTX_S_floatdp1" 0xfffffc00 0x1e274000 (Outside [(5, OpS)])
  , Encoding "FRINTX_D_floatdp1" 0xfffffc00 0x1e674000 (Outside [(5, OpD)])
  , Encoding "FRINTZ_asimdmiscfp16_R" 0xbffffc00 0x0ef99800
      (Outside [(5, OpV)])
  , Encoding "FRINTZ_asimdmisc_R" 0xbfbffc00 0x0ea19800 (Outside [(5, OpV)])
  , Encoding "FRINTZ_H_floatdp1" 0xfffffc00 0x1ee5c000 (Outside [(5, OpH)])
  , Encoding "FRINTZ_S_floatdp1" 0xfffffc00 0x1e25c000 (Outside [(5, OpS)])
  , Encoding "FRINTZ_D_floatdp1" 0xfffffc00 0x1e65c000 (Outside [(5, OpD)])
  , Encoding "FRSQRTE_asisdmiscfp16_R" 0xfffffc00 0x7ef9d800
      (Outside [(5, OpH)])
  , Encoding "FRSQRTE_asisdmisc_R" 0xffbffc00 0x7ea1d800 (Outside [])
  , Encoding "FRSQRTE_asimdmiscfp16_R" 0xbffffc00 0x2ef9d800
      (Outside [(5, OpV)])
  , Encoding "FRSQRTE_asimdmisc_R" 0xbfbffc00 0x2ea1d800 (Outside [(5, OpV)])
  , Encoding "FRSQRTS_asisdsamefp16_only" 0xffe0fc00 0x5ec03c00
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FRSQRTS_asisdsame_only" 0xffa0fc00 0x5ea0fc00 (Outside [])
  , Encoding "FRSQRTS_asimdsamefp16_only" 0xbfe0fc00 0x0ec03c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FRSQRTS_asimdsame_only" 0xbfa0fc00 0x0ea0fc00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FSQRT_asimdmiscfp16_R" 0xbffffc00 0x2ef9f800 (Outside [(5, OpV)])
  , Encoding "FSQRT_asimdmisc_R" 0xbfbffc00 0x2ea1f800 (Outside [(5, OpV)])
  , Encoding "FSQRT_H_floatdp1" 0xfffffc00 0x1ee1c000 (Outside [(5, OpH)])
  , Encoding "FSQRT_S_floatdp1" 0xfffffc00 0x1e21c000 (Outside [(5, OpS)])
  , Encoding "FSQRT_D_floatdp1" 0xfffffc00 0x1e61c000 (Outside [(5, OpD)])
  , Encoding "FSUB_asimdsamefp16_only" 0xbfe0fc00 0x0ec01400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FSUB_asimdsame_only" 0xbfa0fc00 0x0ea0d400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "FSUB_H_floatdp2" 0xffe0fc00 0x1ee03800
      (Outside [(5, OpH), (16, OpH)])
  , Encoding "FSUB_S_floatdp2" 0xffe0fc00 0x1e203800
      (Outside [(5, OpS), (16, OpS)])
  , Encoding "FSUB_D_floatdp2" 0xffe0fc00 0x1e603800
      (Outside [(5, OpD), (16, OpD)])
  , Encoding "GCSB_HD_hints" 0xffffffff 0xd503227f Control
  , Encoding "GCSSTR_64_ldst_gcs" 0xfffffc00 0xd91f0c00 (Outside [(0, OpX)])
  , Encoding "GCSSTTR_64_ldst_gcs" 0xfffffc00 0xd91f1c00 (Outside [(0, OpX)])
  , Encoding "GMI_64G_dp_2src" 0xffe0fc00 0x9ac01400
      (Outside [(5, OpXSp), (16, OpX)])
  , Encoding "HINT_HM_hints" 0xfffff01f 0xd503201f Control
  , Encoding "HLT_EX_exception" 0xffe0001f 0xd4400000 Control
  , Encoding "HVC_EX_exception" 0xffe0001f 0xd4000002 Control
  , Encoding "INS_asimdins_IV_v" 0xffe08400 0x6e000400 Covered
  , Encoding "INS_asimdins_IR_r" 0xffe0fc00 0x4e001c00 Covered
  , Encoding "IRG_64I_dp_2src" 0xffe0fc00 0x9ac01000
      (Outside [(5, OpXSp), (16, OpX)])
  , Encoding "ISB_BI_barriers" 0xfffff0ff 0xd50330df Control
  , Encoding "LD1_asisdlse_R1_1v" 0xbfffd000 0x0c405000 Covered
  , Encoding "LD1_asisdlse_R2_2v" 0xbfffd000 0x0c408000 Covered
  , Encoding "LD1_asisdlse_R3_3v" 0xbfffd000 0x0c404000 Covered
  , Encoding "LD1_asisdlse_R4_4v" 0xbfffd000 0x0c400000 Covered
  , Encoding "LD1_asisdlsep_I1_i1" 0xbfffd000 0x0cdf5000 Covered
  , Encoding "LD1_asisdlsep_R1_r1" 0xbfe0d000 0x0cc05000 Covered
  , Encoding "LD1_asisdlsep_I2_i2" 0xbfffd000 0x0cdf8000 Covered
  , Encoding "LD1_asisdlsep_R2_r2" 0xbfe0d000 0x0cc08000 Covered
  , Encoding "LD1_asisdlsep_I3_i3" 0xbfffd000 0x0cdf4000 Covered
  , Encoding "LD1_asisdlsep_R3_r3" 0xbfe0d000 0x0cc04000 Covered
  , Encoding "LD1_asisdlsep_I4_i4" 0xbfffd000 0x0cdf0000 Covered
  , Encoding "LD1_asisdlsep_R4_r4" 0xbfe0d000 0x0cc00000 Covered
  , Encoding "LD1_asisdlso_B1_1b" 0xbfffc000 0x0d400000 Covered
  , Encoding "LD1_asisdlso_H1_1h" 0xbfffc400 0x0d404000 Covered
  , Encoding "LD1_asisdlso_S1_1s" 0xbfffcc00 0x0d408000 Covered
  , Encoding "LD1_asisdlso_D1_1d" 0xbfffdc00 0x0d408400 Covered
  , Encoding "LD1_asisdlsop_B1_i1b" 0xbfffc000 0x0ddf0000 Covered
  , Encoding "LD1_asisdlsop_BX1_r1b" 0xbfe0c000 0x0dc00000 Covered
  , Encoding "LD1_asisdlsop_H1_i1h" 0xbfffc400 0x0ddf4000 Covered
  , Encoding "LD1_asisdlsop_HX1_r1h" 0xbfe0c400 0x0dc04000 Covered
  , Encoding "LD1_asisdlsop_S1_i1s" 0xbfffcc00 0x0ddf8000 Covered
  , Encoding "LD1_asisdlsop_SX1_r1s" 0xbfe0cc00 0x0dc08000 Covered
  , Encoding "LD1_asisdlsop_D1_i1d" 0xbfffdc00 0x0ddf8400 Covered
  , Encoding "LD1_asisdlsop_DX1_r1d" 0xbfe0dc00 0x0dc08400 Covered
  , Encoding "LD1R_asisdlso_R1" 0xbffff000 0x0d40c000 Covered
  , Encoding "LD1R_asisdlsop_R1_i" 0xbffff000 0x0ddfc000 Covered
  , Encoding "LD1R_asisdlsop_RX1_r" 0xbfe0f000 0x0dc0c000 Covered
  , Encoding "LD2_asisdlse_R2" 0xbffff000 0x0c408000 Covered
  , Encoding "LD2_asisdlsep_I2_i" 0xbffff000 0x0cdf8000 Covered
  , Encoding "LD2_asisdlsep_R2_r" 0xbfe0f000 0x0cc08000 Covered
  , Encoding "LD2_asisdlso_B2_2b" 0xbfffc000 0x0d600000 Covered
  , Encoding "LD2_asisdlso_H2_2h" 0xbfffc400 0x0d604000 Covered
  , Encoding "LD2_asisdlso_S2_2s" 0xbfffcc00 0x0d608000 Covered
  , Encoding "LD2_asisdlso_D2_2d" 0xbfffdc00 0x0d608400 Covered
  , Encoding "LD2_asisdlsop_B2_i2b" 0xbfffc000 0x0dff0000 Covered
  , Encoding "LD2_asisdlsop_BX2_r2b" 0xbfe0c000 0x0de00000 Covered
  , Encoding "LD2_asisdlsop_H2_i2h" 0xbfffc400 0x0dff4000 Covered
  , Encoding "LD2_asisdlsop_HX2_r2h" 0xbfe0c400 0x0de04000 Covered
  , Encoding "LD2_asisdlsop_S2_i2s" 0xbfffcc00 0x0dff8000 Covered
  , Encoding "LD2_asisdlsop_SX2_r2s" 0xbfe0cc00 0x0de08000 Covered
  , Encoding "LD2_asisdlsop_D2_i2d" 0xbfffdc00 0x0dff8400 Covered
  , Encoding "LD2_asisdlsop_DX2_r2d" 0xbfe0dc00 0x0de08400 Covered
  , Encoding "LD2R_asisdlso_R2" 0xbffff000 0x0d60c000 Covered
  , Encoding "LD2R_asisdlsop_R2_i" 0xbffff000 0x0dffc000 Covered
  , Encoding "LD2R_asisdlsop_RX2_r" 0xbfe0f000 0x0de0c000 Covered
  , Encoding "LD3_asisdlse_R3" 0xbffff000 0x0c404000 Covered
  , Encoding "LD3_asisdlsep_I3_i" 0xbffff000 0x0cdf4000 Covered
  , Encoding "LD3_asisdlsep_R3_r" 0xbfe0f000 0x0cc04000 Covered
  , Encoding "LD3_asisdlso_B3_3b" 0xbfffc000 0x0d400000 Covered
  , Encoding "LD3_asisdlso_H3_3h" 0xbfffc400 0x0d404000 Covered
  , Encoding "LD3_asisdlso_S3_3s" 0xbfffcc00 0x0d408000 Covered
  , Encoding "LD3_asisdlso_D3_3d" 0xbfffdc00 0x0d408400 Covered
  , Encoding "LD3_asisdlsop_B3_i3b" 0xbfffc000 0x0ddf0000 Covered
  , Encoding "LD3_asisdlsop_BX3_r3b" 0xbfe0c000 0x0dc00000 Covered
  , Encoding "LD3_asisdlsop_H3_i3h" 0xbfffc400 0x0ddf4000 Covered
  , Encoding "LD3_asisdlsop_HX3_r3h" 0xbfe0c400 0x0dc04000 Covered
  , Encoding "LD3_asisdlsop_S3_i3s" 0xbfffcc00 0x0ddf8000 Covered
  , Encoding "LD3_asisdlsop_SX3_r3s" 0xbfe0cc00 0x0dc08000 Covered
  , Encoding "LD3_asisdlsop_D3_i3d" 0xbfffdc00 0x0ddf8400 Covered
  , Encoding "LD3_asisdlsop_DX3_r3d" 0xbfe0dc00 0x0dc08400 Covered
  , Encoding "LD3R_asisdlso_R3" 0xbffff000 0x0d40e000 Covered
  , Encoding "LD3R_asisdlsop_R3_i" 0xbffff000 0x0ddfe000 Covered
  , Encoding "LD3R_asisdlsop_RX3_r" 0xbfe0f000 0x0dc0e000 Covered
  , Encoding "LD4_asisdlse_R4" 0xbffff000 0x0c400000 Covered
  , Encoding "LD4_asisdlsep_I4_i" 0xbffff000 0x0cdf0000 Covered
  , Encoding "LD4_asisdlsep_R4_r" 0xbfe0f000 0x0cc00000 Covered
  , Encoding "LD4_asisdlso_B4_4b" 0xbfffc000 0x0d600000 Covered
  , Encoding "LD4_asisdlso_H4_4h" 0xbfffc400 0x0d604000 Covered
  , Encoding "LD4_asisdlso_S4_4s" 0xbfffcc00 0x0d608000 Covered
  , Encoding "LD4_asisdlso_D4_4d" 0xbfffdc00 0x0d608400 Covered
  , Encoding "LD4_asisdlsop_B4_i4b" 0xbfffc000 0x0dff0000 Covered
  , Encoding "LD4_asisdlsop_BX4_r4b" 0xbfe0c000 0x0de00000 Covered
  , Encoding "LD4_asisdlsop_H4_i4h" 0xbfffc400 0x0dff4000 Covered
  , Encoding "LD4_asisdlsop_HX4_r4h" 0xbfe0c400 0x0de04000 Covered
  , Encoding "LD4_asisdlsop_S4_i4s" 0xbfffcc00 0x0dff8000 Covered
  , Encoding "LD4_asisdlsop_SX4_r4s" 0xbfe0cc00 0x0de08000 Covered
  , Encoding "LD4_asisdlsop_D4_i4d" 0xbfffdc00 0x0dff8400 Covered
  , Encoding "LD4_asisdlsop_DX4_r4d" 0xbfe0dc00 0x0de08400 Covered
  , Encoding "LD4R_asisdlso_R4" 0xbffff000 0x0d60e000 Covered
  , Encoding "LD4R_asisdlsop_R4_i" 0xbffff000 0x0dffe000 Covered
  , Encoding "LD4R_asisdlsop_RX4_r" 0xbfe0f000 0x0de0e000 Covered
  , Encoding "LD64B_64L_memop" 0xfffffc00 0xf83fd000 (Outside [(0, OpX)])
  , Encoding "LDADD_32_memop" 0x7fe0fc00 0x38200000 Covered
  , Encoding "LDADDA_32_memop" 0x7fe0fc00 0x38a00000 Covered
  , Encoding "LDADDAL_32_memop" 0x7fe0fc00 0x38e00000 Covered
  , Encoding "LDADDL_32_memop" 0x7fe0fc00 0x38600000 Covered
  , Encoding "LDADD_64_memop" 0x7fe0fc00 0x78200000 Covered
  , Encoding "LDADDA_64_memop" 0x7fe0fc00 0x78a00000 Covered
  , Encoding "LDADDAL_64_memop" 0x7fe0fc00 0x78e00000 Covered
  , Encoding "LDADDL_64_memop" 0x7fe0fc00 0x78600000 Covered
  , Encoding "LDADDAB_32_memop" 0xffe0fc00 0x38a00000 Covered
  , Encoding "LDADDALB_32_memop" 0xffe0fc00 0x38e00000 Covered
  , Encoding "LDADDB_32_memop" 0xffe0fc00 0x38200000 Covered
  , Encoding "LDADDLB_32_memop" 0xffe0fc00 0x38600000 Covered
  , Encoding "LDADDAH_32_memop" 0xffe0fc00 0x78a00000 Covered
  , Encoding "LDADDALH_32_memop" 0xffe0fc00 0x78e00000 Covered
  , Encoding "LDADDH_32_memop" 0xffe0fc00 0x78200000 Covered
  , Encoding "LDADDLH_32_memop" 0xffe0fc00 0x78600000 Covered
  , Encoding "LDAP1_asisdlso_D1" 0xbffffc00 0x0d418400 Covered
  , Encoding "LDAPR_32L_memop" 0x7fe0fc00 0x38a0c000 Covered
  , Encoding "LDAPR_64L_memop" 0x7fe0fc00 0x78a0c000 Covered
  , Encoding "LDAPR_32L_ldapstl_writeback" 0x7ffffc00 0x19c00800 Covered
  , Encoding "LDAPR_64L_ldapstl_writeback" 0x7ffffc00 0x59c00800 Covered
  , Encoding "LDAPRB_32L_memop" 0xffe0fc00 0x38a0c000 Covered
  , Encoding "LDAPRH_32L_memop" 0xffe0fc00 0x78a0c000 Covered
  , Encoding "LDAPUR_B_ldapstl_simd" 0xffa00c00 0x1d000800 Covered
  , Encoding "LDAPUR_H_ldapstl_simd" 0xffa00c00 0x5d000800 Covered
  , Encoding "LDAPUR_S_ldapstl_simd" 0xffa00c00 0x9d000800 Covered
  , Encoding "LDAPUR_D_ldapstl_simd" 0xffa00c00 0xdd000800 Covered
  , Encoding "LDAPUR_Q_ldapstl_simd" 0xffa00c00 0x1d800800 Covered
  , Encoding "LDAPUR_32_ldapstl_unscaled" 0x7fe00c00 0x19400000 Covered
  , Encoding "LDAPUR_64_ldapstl_unscaled" 0x7fe00c00 0x59400000 Covered
  , Encoding "LDAPURB_32_ldapstl_unscaled" 0xffe00c00 0x19400000 Covered
  , Encoding "LDAPURH_32_ldapstl_unscaled" 0xffe00c00 0x59400000 Covered
  , Encoding "LDAPURSB_32_ldapstl_unscaled" 0xff600c00 0x19400000 Covered
  , Encoding "LDAPURSB_64_ldapstl_unscaled" 0xff600c00 0x19000000 Covered
  , Encoding "LDAPURSH_32_ldapstl_unscaled" 0xff600c00 0x59400000 Covered
  , Encoding "LDAPURSH_64_ldapstl_unscaled" 0xff600c00 0x59000000 Covered
  , Encoding "LDAPURSW_64_ldapstl_unscaled" 0xffe00c00 0x99800000 Covered
  , Encoding "LDAR_LR32_ldstord" 0x7fe08000 0x08c08000 Covered
  , Encoding "LDAR_LR64_ldstord" 0x7fe08000 0x48c08000 Covered
  , Encoding "LDARB_LR32_ldstord" 0xffe08000 0x08c08000 Covered
  , Encoding "LDARH_LR32_ldstord" 0xffe08000 0x48c08000 Covered
  , Encoding "LDAXP_LP32_ldstexclp" 0xffe08000 0x88608000 Covered
  , Encoding "LDAXP_LP64_ldstexclp" 0xffe08000 0xc8608000 Covered
  , Encoding "LDAXR_LR32_ldstexclr" 0x7fe08000 0x08408000 Covered
  , Encoding "LDAXR_LR64_ldstexclr" 0x7fe08000 0x48408000 Covered
  , Encoding "LDAXRB_LR32_ldstexclr" 0xffe08000 0x08408000 Covered
  , Encoding "LDAXRH_LR32_ldstexclr" 0xffe08000 0x48408000 Covered
  , Encoding "LDCLR_32_memop" 0x7fe0fc00 0x38201000 Covered
  , Encoding "LDCLRA_32_memop" 0x7fe0fc00 0x38a01000 Covered
  , Encoding "LDCLRAL_32_memop" 0x7fe0fc00 0x38e01000 Covered
  , Encoding "LDCLRL_32_memop" 0x7fe0fc00 0x38601000 Covered
  , Encoding "LDCLR_64_memop" 0x7fe0fc00 0x78201000 Covered
  , Encoding "LDCLRA_64_memop" 0x7fe0fc00 0x78a01000 Covered
  , Encoding "LDCLRAL_64_memop" 0x7fe0fc00 0x78e01000 Covered
  , Encoding "LDCLRL_64_memop" 0x7fe0fc00 0x78601000 Covered
  , Encoding "LDCLRAB_32_memop" 0xffe0fc00 0x38a01000 Covered
  , Encoding "LDCLRALB_32_memop" 0xffe0fc00 0x38e01000 Covered
  , Encoding "LDCLRB_32_memop" 0xffe0fc00 0x38201000 Covered
  , Encoding "LDCLRLB_32_memop" 0xffe0fc00 0x38601000 Covered
  , Encoding "LDCLRAH_32_memop" 0xffe0fc00 0x78a01000 Covered
  , Encoding "LDCLRALH_32_memop" 0xffe0fc00 0x78e01000 Covered
  , Encoding "LDCLRH_32_memop" 0xffe0fc00 0x78201000 Covered
  , Encoding "LDCLRLH_32_memop" 0xffe0fc00 0x78601000 Covered
  , Encoding "LDCLRP_128_memop_128" 0xffe0fc00 0x19201000 Covered
  , Encoding "LDCLRPA_128_memop_128" 0xffe0fc00 0x19a01000 Covered
  , Encoding "LDCLRPAL_128_memop_128" 0xffe0fc00 0x19e01000 Covered
  , Encoding "LDCLRPL_128_memop_128" 0xffe0fc00 0x19601000 Covered
  , Encoding "LDEOR_32_memop" 0x7fe0fc00 0x38202000 Covered
  , Encoding "LDEORA_32_memop" 0x7fe0fc00 0x38a02000 Covered
  , Encoding "LDEORAL_32_memop" 0x7fe0fc00 0x38e02000 Covered
  , Encoding "LDEORL_32_memop" 0x7fe0fc00 0x38602000 Covered
  , Encoding "LDEOR_64_memop" 0x7fe0fc00 0x78202000 Covered
  , Encoding "LDEORA_64_memop" 0x7fe0fc00 0x78a02000 Covered
  , Encoding "LDEORAL_64_memop" 0x7fe0fc00 0x78e02000 Covered
  , Encoding "LDEORL_64_memop" 0x7fe0fc00 0x78602000 Covered
  , Encoding "LDEORAB_32_memop" 0xffe0fc00 0x38a02000 Covered
  , Encoding "LDEORALB_32_memop" 0xffe0fc00 0x38e02000 Covered
  , Encoding "LDEORB_32_memop" 0xffe0fc00 0x38202000 Covered
  , Encoding "LDEORLB_32_memop" 0xffe0fc00 0x38602000 Covered
  , Encoding "LDEORAH_32_memop" 0xffe0fc00 0x78a02000 Covered
  , Encoding "LDEORALH_32_memop" 0xffe0fc00 0x78e02000 Covered
  , Encoding "LDEORH_32_memop" 0xffe0fc00 0x78202000 Covered
  , Encoding "LDEORLH_32_memop" 0xffe0fc00 0x78602000 Covered
  , Encoding "LDG_64Loffset_ldsttags" 0xffe00c00 0xd9600000 (Outside [])
  , Encoding "LDGM_64bulk_ldsttags" 0xfffffc00 0xd9e00000 (Outside [])
  , Encoding "LDIAPP_32L_ldiappstilp" 0x7fe01c00 0x19401800 Covered
  , Encoding "LDIAPP_32LE_ldiappstilp" 0x7fe01c00 0x19400800 Covered
  , Encoding "LDIAPP_64L_ldiappstilp" 0x7fe01c00 0x59401800 Covered
  , Encoding "LDIAPP_64LS_ldiappstilp" 0x7fe01c00 0x59400800 Covered
  , Encoding "LDLAR_LR32_ldstord" 0x7fe08000 0x08c00000 Covered
  , Encoding "LDLAR_LR64_ldstord" 0x7fe08000 0x48c00000 Covered
  , Encoding "LDLARB_LR32_ldstord" 0xffe08000 0x08c00000 Covered
  , Encoding "LDLARH_LR32_ldstord" 0xffe08000 0x48c00000 Covered
  , Encoding "LDNP_S_ldstnapair_offs" 0xffc00000 0x2c400000 Covered
  , Encoding "LDNP_D_ldstnapair_offs" 0xffc00000 0x6c400000 Covered
  , Encoding "LDNP_Q_ldstnapair_offs" 0xffc00000 0xac400000 Covered
  , Encoding "LDNP_32_ldstnapair_offs" 0xbfc00000 0x28400000 Covered
  , Encoding "LDNP_64_ldstnapair_offs" 0xbfc00000 0xa8400000 Covered
  , Encoding "LDP_S_ldstpair_post" 0xffc00000 0x2cc00000 Covered
  , Encoding "LDP_D_ldstpair_post" 0xffc00000 0x6cc00000 Covered
  , Encoding "LDP_Q_ldstpair_post" 0xffc00000 0xacc00000 Covered
  , Encoding "LDP_S_ldstpair_pre" 0xffc00000 0x2dc00000 Covered
  , Encoding "LDP_D_ldstpair_pre" 0xffc00000 0x6dc00000 Covered
  , Encoding "LDP_Q_ldstpair_pre" 0xffc00000 0xadc00000 Covered
  , Encoding "LDP_S_ldstpair_off" 0xffc00000 0x2d400000 Covered
  , Encoding "LDP_D_ldstpair_off" 0xffc00000 0x6d400000 Covered
  , Encoding "LDP_Q_ldstpair_off" 0xffc00000 0xad400000 Covered
  , Encoding "LDP_32_ldstpair_post" 0xbfc00000 0x28c00000 Covered
  , Encoding "LDP_64_ldstpair_post" 0xbfc00000 0xa8c00000 Covered
  , Encoding "LDP_32_ldstpair_pre" 0xbfc00000 0x29c00000 Covered
  , Encoding "LDP_64_ldstpair_pre" 0xbfc00000 0xa9c00000 Covered
  , Encoding "LDP_32_ldstpair_off" 0xbfc00000 0x29400000 Covered
  , Encoding "LDP_64_ldstpair_off" 0xbfc00000 0xa9400000 Covered
  , Encoding "LDPSW_64_ldstpair_post" 0xffc00000 0x68c00000 Covered
  , Encoding "LDPSW_64_ldstpair_pre" 0xffc00000 0x69c00000 Covered
  , Encoding "LDPSW_64_ldstpair_off" 0xffc00000 0x69400000 Covered
  , Encoding "LDR_B_ldst_immpost" 0xffa00c00 0x3c000400 Covered
  , Encoding "LDR_H_ldst_immpost" 0xffa00c00 0x7c000400 Covered
  , Encoding "LDR_S_ldst_immpost" 0xffa00c00 0xbc000400 Covered
  , Encoding "LDR_D_ldst_immpost" 0xffa00c00 0xfc000400 Covered
  , Encoding "LDR_Q_ldst_immpost" 0xffa00c00 0x3c800400 Covered
  , Encoding "LDR_B_ldst_immpre" 0xffa00c00 0x3c000c00 Covered
  , Encoding "LDR_H_ldst_immpre" 0xffa00c00 0x7c000c00 Covered
  , Encoding "LDR_S_ldst_immpre" 0xffa00c00 0xbc000c00 Covered
  , Encoding "LDR_D_ldst_immpre" 0xffa00c00 0xfc000c00 Covered
  , Encoding "LDR_Q_ldst_immpre" 0xffa00c00 0x3c800c00 Covered
  , Encoding "LDR_B_ldst_pos" 0xff800000 0x3d000000 Covered
  , Encoding "LDR_H_ldst_pos" 0xff800000 0x7d000000 Covered
  , Encoding "LDR_S_ldst_pos" 0xff800000 0xbd000000 Covered
  , Encoding "LDR_D_ldst_pos" 0xff800000 0xfd000000 Covered
  , Encoding "LDR_Q_ldst_pos" 0xff800000 0x3d800000 Covered
  , Encoding "LDR_32_ldst_immpost" 0x7fe00c00 0x38400400 Covered
  , Encoding "LDR_64_ldst_immpost" 0x7fe00c00 0x78400400 Covered
  , Encoding "LDR_32_ldst_immpre" 0x7fe00c00 0x38400c00 Covered
  , Encoding "LDR_64_ldst_immpre" 0x7fe00c00 0x78400c00 Covered
  , Encoding "LDR_32_ldst_pos" 0x7fc00000 0x39400000 Covered
  , Encoding "LDR_64_ldst_pos" 0x7fc00000 0x79400000 Covered
  , Encoding "LDR_S_loadlit" 0xff000000 0x1c000000 Covered
  , Encoding "LDR_D_loadlit" 0xff000000 0x5c000000 Covered
  , Encoding "LDR_Q_loadlit" 0xff000000 0x9c000000 Covered
  , Encoding "LDR_32_loadlit" 0x7f000000 0x18000000 Covered
  , Encoding "LDR_64_loadlit" 0x7f000000 0x58000000 Covered
  , Encoding "LDR_B_ldst_regoff" 0xffa00c00 0x3c200800 Covered
  , Encoding "LDR_BL_ldst_regoff" 0xffa0ec00 0x3c206800 Covered
  , Encoding "LDR_H_ldst_regoff" 0xffa00c00 0x7c200800 Covered
  , Encoding "LDR_S_ldst_regoff" 0xffa00c00 0xbc200800 Covered
  , Encoding "LDR_D_ldst_regoff" 0xffa00c00 0xfc200800 Covered
  , Encoding "LDR_Q_ldst_regoff" 0xffa00c00 0x3ca00800 Covered
  , Encoding "LDR_32_ldst_regoff" 0x7fe00c00 0x38600800 Covered
  , Encoding "LDR_64_ldst_regoff" 0x7fe00c00 0x78600800 Covered
  , Encoding "LDRAA_64_ldst_pac" 0xffa00c00 0xf8200400 Covered
  , Encoding "LDRAA_64W_ldst_pac" 0xffa00c00 0xf8200c00 Covered
  , Encoding "LDRAB_64_ldst_pac" 0xffa00c00 0xf8a00400 Covered
  , Encoding "LDRAB_64W_ldst_pac" 0xffa00c00 0xf8a00c00 Covered
  , Encoding "LDRB_32_ldst_immpost" 0xffe00c00 0x38400400 Covered
  , Encoding "LDRB_32_ldst_immpre" 0xffe00c00 0x38400c00 Covered
  , Encoding "LDRB_32_ldst_pos" 0xffc00000 0x39400000 Covered
  , Encoding "LDRB_32B_ldst_regoff" 0xffe00c00 0x38600800 Covered
  , Encoding "LDRB_32BL_ldst_regoff" 0xffe0ec00 0x38606800 Covered
  , Encoding "LDRH_32_ldst_immpost" 0xffe00c00 0x78400400 Covered
  , Encoding "LDRH_32_ldst_immpre" 0xffe00c00 0x78400c00 Covered
  , Encoding "LDRH_32_ldst_pos" 0xffc00000 0x79400000 Covered
  , Encoding "LDRH_32_ldst_regoff" 0xffe00c00 0x78600800 Covered
  , Encoding "LDRSB_32_ldst_immpost" 0xff600c00 0x38400400 Covered
  , Encoding "LDRSB_64_ldst_immpost" 0xff600c00 0x38000400 Covered
  , Encoding "LDRSB_32_ldst_immpre" 0xff600c00 0x38400c00 Covered
  , Encoding "LDRSB_64_ldst_immpre" 0xff600c00 0x38000c00 Covered
  , Encoding "LDRSB_32_ldst_pos" 0xff400000 0x39400000 Covered
  , Encoding "LDRSB_64_ldst_pos" 0xff400000 0x39000000 Covered
  , Encoding "LDRSB_32B_ldst_regoff" 0xff600c00 0x38600800 Covered
  , Encoding "LDRSB_32BL_ldst_regoff" 0xff60ec00 0x38606800 Covered
  , Encoding "LDRSB_64B_ldst_regoff" 0xff600c00 0x38200800 Covered
  , Encoding "LDRSB_64BL_ldst_regoff" 0xff60ec00 0x38206800 Covered
  , Encoding "LDRSH_32_ldst_immpost" 0xff600c00 0x78400400 Covered
  , Encoding "LDRSH_64_ldst_immpost" 0xff600c00 0x78000400 Covered
  , Encoding "LDRSH_32_ldst_immpre" 0xff600c00 0x78400c00 Covered
  , Encoding "LDRSH_64_ldst_immpre" 0xff600c00 0x78000c00 Covered
  , Encoding "LDRSH_32_ldst_pos" 0xff400000 0x79400000 Covered
  , Encoding "LDRSH_64_ldst_pos" 0xff400000 0x79000000 Covered
  , Encoding "LDRSH_32_ldst_regoff" 0xff600c00 0x78600800 Covered
  , Encoding "LDRSH_64_ldst_regoff" 0xff600c00 0x78200800 Covered
  , Encoding "LDRSW_64_ldst_immpost" 0xffe00c00 0xb8800400 Covered
  , Encoding "LDRSW_64_ldst_immpre" 0xffe00c00 0xb8800c00 Covered
  , Encoding "LDRSW_64_ldst_pos" 0xffc00000 0xb9800000 Covered
  , Encoding "LDRSW_64_loadlit" 0xff000000 0x98000000 Covered
  , Encoding "LDRSW_64_ldst_regoff" 0xffe00c00 0xb8a00800 Covered
  , Encoding "LDSET_32_memop" 0x7fe0fc00 0x38203000 Covered
  , Encoding "LDSETA_32_memop" 0x7fe0fc00 0x38a03000 Covered
  , Encoding "LDSETAL_32_memop" 0x7fe0fc00 0x38e03000 Covered
  , Encoding "LDSETL_32_memop" 0x7fe0fc00 0x38603000 Covered
  , Encoding "LDSET_64_memop" 0x7fe0fc00 0x78203000 Covered
  , Encoding "LDSETA_64_memop" 0x7fe0fc00 0x78a03000 Covered
  , Encoding "LDSETAL_64_memop" 0x7fe0fc00 0x78e03000 Covered
  , Encoding "LDSETL_64_memop" 0x7fe0fc00 0x78603000 Covered
  , Encoding "LDSETAB_32_memop" 0xffe0fc00 0x38a03000 Covered
  , Encoding "LDSETALB_32_memop" 0xffe0fc00 0x38e03000 Covered
  , Encoding "LDSETB_32_memop" 0xffe0fc00 0x38203000 Covered
  , Encoding "LDSETLB_32_memop" 0xffe0fc00 0x38603000 Covered
  , Encoding "LDSETAH_32_memop" 0xffe0fc00 0x78a03000 Covered
  , Encoding "LDSETALH_32_memop" 0xffe0fc00 0x78e03000 Covered
  , Encoding "LDSETH_32_memop" 0xffe0fc00 0x78203000 Covered
  , Encoding "LDSETLH_32_memop" 0xffe0fc00 0x78603000 Covered
  , Encoding "LDSETP_128_memop_128" 0xffe0fc00 0x19203000 Covered
  , Encoding "LDSETPA_128_memop_128" 0xffe0fc00 0x19a03000 Covered
  , Encoding "LDSETPAL_128_memop_128" 0xffe0fc00 0x19e03000 Covered
  , Encoding "LDSETPL_128_memop_128" 0xffe0fc00 0x19603000 Covered
  , Encoding "LDSMAX_32_memop" 0x7fe0fc00 0x38204000 Covered
  , Encoding "LDSMAXA_32_memop" 0x7fe0fc00 0x38a04000 Covered
  , Encoding "LDSMAXAL_32_memop" 0x7fe0fc00 0x38e04000 Covered
  , Encoding "LDSMAXL_32_memop" 0x7fe0fc00 0x38604000 Covered
  , Encoding "LDSMAX_64_memop" 0x7fe0fc00 0x78204000 Covered
  , Encoding "LDSMAXA_64_memop" 0x7fe0fc00 0x78a04000 Covered
  , Encoding "LDSMAXAL_64_memop" 0x7fe0fc00 0x78e04000 Covered
  , Encoding "LDSMAXL_64_memop" 0x7fe0fc00 0x78604000 Covered
  , Encoding "LDSMAXAB_32_memop" 0xffe0fc00 0x38a04000 Covered
  , Encoding "LDSMAXALB_32_memop" 0xffe0fc00 0x38e04000 Covered
  , Encoding "LDSMAXB_32_memop" 0xffe0fc00 0x38204000 Covered
  , Encoding "LDSMAXLB_32_memop" 0xffe0fc00 0x38604000 Covered
  , Encoding "LDSMAXAH_32_memop" 0xffe0fc00 0x78a04000 Covered
  , Encoding "LDSMAXALH_32_memop" 0xffe0fc00 0x78e04000 Covered
  , Encoding "LDSMAXH_32_memop" 0xffe0fc00 0x78204000 Covered
  , Encoding "LDSMAXLH_32_memop" 0xffe0fc00 0x78604000 Covered
  , Encoding "LDSMIN_32_memop" 0x7fe0fc00 0x38205000 Covered
  , Encoding "LDSMINA_32_memop" 0x7fe0fc00 0x38a05000 Covered
  , Encoding "LDSMINAL_32_memop" 0x7fe0fc00 0x38e05000 Covered
  , Encoding "LDSMINL_32_memop" 0x7fe0fc00 0x38605000 Covered
  , Encoding "LDSMIN_64_memop" 0x7fe0fc00 0x78205000 Covered
  , Encoding "LDSMINA_64_memop" 0x7fe0fc00 0x78a05000 Covered
  , Encoding "LDSMINAL_64_memop" 0x7fe0fc00 0x78e05000 Covered
  , Encoding "LDSMINL_64_memop" 0x7fe0fc00 0x78605000 Covered
  , Encoding "LDSMINAB_32_memop" 0xffe0fc00 0x38a05000 Covered
  , Encoding "LDSMINALB_32_memop" 0xffe0fc00 0x38e05000 Covered
  , Encoding "LDSMINB_32_memop" 0xffe0fc00 0x38205000 Covered
  , Encoding "LDSMINLB_32_memop" 0xffe0fc00 0x38605000 Covered
  , Encoding "LDSMINAH_32_memop" 0xffe0fc00 0x78a05000 Covered
  , Encoding "LDSMINALH_32_memop" 0xffe0fc00 0x78e05000 Covered
  , Encoding "LDSMINH_32_memop" 0xffe0fc00 0x78205000 Covered
  , Encoding "LDSMINLH_32_memop" 0xffe0fc00 0x78605000 Covered
  , Encoding "LDTR_32_ldst_unpriv" 0x7fe00c00 0x38400800 Covered
  , Encoding "LDTR_64_ldst_unpriv" 0x7fe00c00 0x78400800 Covered
  , Encoding "LDTRB_32_ldst_unpriv" 0xffe00c00 0x38400800 Covered
  , Encoding "LDTRH_32_ldst_unpriv" 0xffe00c00 0x78400800 Covered
  , Encoding "LDTRSB_32_ldst_unpriv" 0xff600c00 0x38400800 Covered
  , Encoding "LDTRSB_64_ldst_unpriv" 0xff600c00 0x38000800 Covered
  , Encoding "LDTRSH_32_ldst_unpriv" 0xff600c00 0x78400800 Covered
  , Encoding "LDTRSH_64_ldst_unpriv" 0xff600c00 0x78000800 Covered
  , Encoding "LDTRSW_64_ldst_unpriv" 0xffe00c00 0xb8800800 Covered
  , Encoding "LDUMAX_32_memop" 0x7fe0fc00 0x38206000 Covered
  , Encoding "LDUMAXA_32_memop" 0x7fe0fc00 0x38a06000 Covered
  , Encoding "LDUMAXAL_32_memop" 0x7fe0fc00 0x38e06000 Covered
  , Encoding "LDUMAXL_32_memop" 0x7fe0fc00 0x38606000 Covered
  , Encoding "LDUMAX_64_memop" 0x7fe0fc00 0x78206000 Covered
  , Encoding "LDUMAXA_64_memop" 0x7fe0fc00 0x78a06000 Covered
  , Encoding "LDUMAXAL_64_memop" 0x7fe0fc00 0x78e06000 Covered
  , Encoding "LDUMAXL_64_memop" 0x7fe0fc00 0x78606000 Covered
  , Encoding "LDUMAXAB_32_memop" 0xffe0fc00 0x38a06000 Covered
  , Encoding "LDUMAXALB_32_memop" 0xffe0fc00 0x38e06000 Covered
  , Encoding "LDUMAXB_32_memop" 0xffe0fc00 0x38206000 Covered
  , Encoding "LDUMAXLB_32_memop" 0xffe0fc00 0x38606000 Covered
  , Encoding "LDUMAXAH_32_memop" 0xffe0fc00 0x78a06000 Covered
  , Encoding "LDUMAXALH_32_memop" 0xffe0fc00 0x78e06000 Covered
  , Encoding "LDUMAXH_32_memop" 0xffe0fc00 0x78206000 Covered
  , Encoding "LDUMAXLH_32_memop" 0xffe0fc00 0x78606000 Covered
  , Encoding "LDUMIN_32_memop" 0x7fe0fc00 0x38207000 Covered
  , Encoding "LDUMINA_32_memop" 0x7fe0fc00 0x38a07000 Covered
  , Encoding "LDUMINAL_32_memop" 0x7fe0fc00 0x38e07000 Covered
  , Encoding "LDUMINL_32_memop" 0x7fe0fc00 0x38607000 Covered
  , Encoding "LDUMIN_64_memop" 0x7fe0fc00 0x78207000 Covered
  , Encoding "LDUMINA_64_memop" 0x7fe0fc00 0x78a07000 Covered
  , Encoding "LDUMINAL_64_memop" 0x7fe0fc00 0x78e07000 Covered
  , Encoding "LDUMINL_64_memop" 0x7fe0fc00 0x78607000 Covered
  , Encoding "LDUMINAB_32_memop" 0xffe0fc00 0x38a07000 Covered
  , Encoding "LDUMINALB_32_memop" 0xffe0fc00 0x38e07000 Covered
  , Encoding "LDUMINB_32_memop" 0xffe0fc00 0x38207000 Covered
  , Encoding "LDUMINLB_32_memop" 0xffe0fc00 0x38607000 Covered
  , Encoding "LDUMINAH_32_memop" 0xffe0fc00 0x78a07000 Covered
  , Encoding "LDUMINALH_32_memop" 0xffe0fc00 0x78e07000 Covered
  , Encoding "LDUMINH_32_memop" 0xffe0fc00 0x78207000 Covered
  , Encoding "LDUMINLH_32_memop" 0xffe0fc00 0x78607000 Covered
  , Encoding "LDUR_B_ldst_unscaled" 0xffa00c00 0x3c000000 Covered
  , Encoding "LDUR_H_ldst_unscaled" 0xffa00c00 0x7c000000 Covered
  , Encoding "LDUR_S_ldst_unscaled" 0xffa00c00 0xbc000000 Covered
  , Encoding "LDUR_D_ldst_unscaled" 0xffa00c00 0xfc000000 Covered
  , Encoding "LDUR_Q_ldst_unscaled" 0xffa00c00 0x3c800000 Covered
  , Encoding "LDUR_32_ldst_unscaled" 0x7fe00c00 0x38400000 Covered
  , Encoding "LDUR_64_ldst_unscaled" 0x7fe00c00 0x78400000 Covered
  , Encoding "LDURB_32_ldst_unscaled" 0xffe00c00 0x38400000 Covered
  , Encoding "LDURH_32_ldst_unscaled" 0xffe00c00 0x78400000 Covered
  , Encoding "LDURSB_32_ldst_unscaled" 0xff600c00 0x38400000 Covered
  , Encoding "LDURSB_64_ldst_unscaled" 0xff600c00 0x38000000 Covered
  , Encoding "LDURSH_32_ldst_unscaled" 0xff600c00 0x78400000 Covered
  , Encoding "LDURSH_64_ldst_unscaled" 0xff600c00 0x78000000 Covered
  , Encoding "LDURSW_64_ldst_unscaled" 0xffe00c00 0xb8800000 Covered
  , Encoding "LDXP_LP32_ldstexclp" 0xffe08000 0x88600000 Covered
  , Encoding "LDXP_LP64_ldstexclp" 0xffe08000 0xc8600000 Covered
  , Encoding "LDXR_LR32_ldstexclr" 0x7fe08000 0x08400000 Covered
  , Encoding "LDXR_LR64_ldstexclr" 0x7fe08000 0x48400000 Covered
  , Encoding "LDXRB_LR32_ldstexclr" 0xffe08000 0x08400000 Covered
  , Encoding "LDXRH_LR32_ldstexclr" 0xffe08000 0x48400000 Covered
  , Encoding "LSLV_32_dp_2src" 0xffe0fc00 0x1ac02000 Covered
  , Encoding "LSLV_64_dp_2src" 0xffe0fc00 0x9ac02000 Covered
  , Encoding "LSRV_32_dp_2src" 0xffe0fc00 0x1ac02400 Covered
  , Encoding "LSRV_64_dp_2src" 0xffe0fc00 0x9ac02400 Covered
  , Encoding "MADD_32A_dp_3src" 0xffe08000 0x1b000000 Covered
  , Encoding "MADD_64A_dp_3src" 0xffe08000 0x9b000000 Covered
  , Encoding "MLA_asimdelem_R" 0xbf00f400 0x2f000000 Covered
  , Encoding "MLA_asimdsame_only" 0xbf20fc00 0x0e209400 Covered
  , Encoding "MLS_asimdelem_R" 0xbf00f400 0x2f004000 Covered
  , Encoding "MLS_asimdsame_only" 0xbf20fc00 0x2e209400 Covered
  , Encoding "MOVI_asimdimm_N_b" 0xbff8fc00 0x0f00e400 Covered
  , Encoding "MOVI_asimdimm_L_hl" 0xbff8dc00 0x0f008400 Covered
  , Encoding "MOVI_asimdimm_L_sl" 0xbff89c00 0x0f000400 Covered
  , Encoding "MOVI_asimdimm_M_sm" 0xbff8ec00 0x0f00c400 Covered
  , Encoding "MOVI_asimdimm_D_ds" 0xfff8fc00 0x2f00e400 Covered
  , Encoding "MOVI_asimdimm_D2_d" 0xfff8fc00 0x6f00e400 Covered
  , Encoding "MOVK_32_movewide" 0xffc00000 0x72800000 Covered
  , Encoding "MOVK_64_movewide" 0xff800000 0xf2800000 Covered
  , Encoding "MOVN_32_movewide" 0xffc00000 0x12800000 Covered
  , Encoding "MOVN_64_movewide" 0xff800000 0x92800000 Covered
  , Encoding "MOVZ_32_movewide" 0xffc00000 0x52800000 Covered
  , Encoding "MOVZ_64_movewide" 0xff800000 0xd2800000 Covered
  , Encoding "MRRS_RS_systemmovepr" 0xfff00000 0xd5700000 Control
  , Encoding "MRS_RS_systemmove" 0xfff00000 0xd5300000 Control
  , Encoding "MSR_SI_pstate" 0xfff8f01f 0xd500401f Control
  , Encoding "MSR_SR_systemmove" 0xfff00000 0xd5100000 Control
  , Encoding "MSRR_SR_systemmovepr" 0xfff00000 0xd5500000 Control
  , Encoding "MSUB_32A_dp_3src" 0xffe08000 0x1b008000 Covered
  , Encoding "MSUB_64A_dp_3src" 0xffe08000 0x9b008000 Covered
  , Encoding "MUL_asimdelem_R" 0xbf00f400 0x0f008000 Covered
  , Encoding "MUL_asimdsame_only" 0xbf20fc00 0x0e209c00 Covered
  , Encoding "MVNI_asimdimm_L_hl" 0xbff8dc00 0x2f008400 Covered
  , Encoding "MVNI_asimdimm_L_sl" 0xbff89c00 0x2f000400 Covered
  , Encoding "MVNI_asimdimm_M_sm" 0xbff8ec00 0x2f00c400 Covered
  , Encoding "NEG_asisdmisc_R" 0xff3ffc00 0x7e20b800 Covered
  , Encoding "NEG_asimdmisc_R" 0xbf3ffc00 0x2e20b800 Covered
  , Encoding "NOP_HI_hints" 0xffffffff 0xd503201f Covered
  , Encoding "NOT_asimdmisc_R" 0xbffffc00 0x2e205800 Covered
  , Encoding "ORN_asimdsame_only" 0xbfe0fc00 0x0ee01c00 Covered
  , Encoding "ORN_32_log_shift" 0xff200000 0x2a200000 Covered
  , Encoding "ORN_64_log_shift" 0xff200000 0xaa200000 Covered
  , Encoding "ORR_asimdimm_L_hl" 0xbff8cc00 0x0f008400 Covered
  , Encoding "ORR_asimdimm_L_sl" 0xbff88c00 0x0f000400 Covered
  , Encoding "ORR_asimdsame_only" 0xbfe0fc00 0x0ea01c00 Covered
  , Encoding "ORR_32_log_imm" 0xffc00000 0x32000000 Covered
  , Encoding "ORR_64_log_imm" 0xff800000 0xb2000000 Covered
  , Encoding "ORR_32_log_shift" 0xff200000 0x2a000000 Covered
  , Encoding "ORR_64_log_shift" 0xff200000 0xaa000000 Covered
  , Encoding "PACDA_64P_dp_1src" 0xfffffc00 0xdac10800 (Outside [(5, OpXSp)])
  , Encoding "PACDZA_64Z_dp_1src" 0xffffffe0 0xdac12be0 (Outside [])
  , Encoding "PACDB_64P_dp_1src" 0xfffffc00 0xdac10c00 (Outside [(5, OpXSp)])
  , Encoding "PACDZB_64Z_dp_1src" 0xffffffe0 0xdac12fe0 (Outside [])
  , Encoding "PACGA_64P_dp_2src" 0xffe0fc00 0x9ac03000
      (Outside [(5, OpX), (16, OpXSp)])
  , Encoding "PACIA_64P_dp_1src" 0xfffffc00 0xdac10000 (Outside [(5, OpXSp)])
  , Encoding "PACIZA_64Z_dp_1src" 0xffffffe0 0xdac123e0 (Outside [])
  , Encoding "PACIA1716_HI_hints" 0xfffff23f 0xd503201f (Outside [])
  , Encoding "PACIASP_HI_hints" 0xfffff23f 0xd503223f (Outside [])
  , Encoding "PACIAZ_HI_hints" 0xfffff23f 0xd503221f (Outside [])
  , Encoding "PACIB_64P_dp_1src" 0xfffffc00 0xdac10400 (Outside [(5, OpXSp)])
  , Encoding "PACIZB_64Z_dp_1src" 0xffffffe0 0xdac127e0 (Outside [])
  , Encoding "PACIB1716_HI_hints" 0xfffff23f 0xd503201f (Outside [])
  , Encoding "PACIBSP_HI_hints" 0xfffff23f 0xd503223f (Outside [])
  , Encoding "PACIBZ_HI_hints" 0xfffff23f 0xd503221f (Outside [])
  , Encoding "PMUL_asimdsame_only" 0xbf20fc00 0x2e209c00 Covered
  , Encoding "PMULL_asimddiff_L" 0xbf20fc00 0x0e20e000 Covered
  , Encoding "PRFM_P_ldst_pos" 0xffc00000 0xf9800000 (Outside [])
  , Encoding "PRFM_P_loadlit" 0xff000000 0xd8000000 (Outside [])
  , Encoding "PRFM_P_ldst_regoff" 0xffe04c00 0xf8a04800 (Outside [])
  , Encoding "PRFUM_P_ldst_unscaled" 0xffe00c00 0xf8800000 (Outside [])
  , Encoding "PSB_HC_hints" 0xffffffff 0xd503223f Control
  , Encoding "RADDHN_asimddiff_N" 0xbf20fc00 0x2e204000 Covered
  , Encoding "RAX1_VVV2_cryptosha512_3" 0xffe0fc00 0xce608c00 Covered
  , Encoding "RBIT_asimdmisc_R" 0xbffffc00 0x2e605800 Covered
  , Encoding "RBIT_32_dp_1src" 0xfffffc00 0x5ac00000 Covered
  , Encoding "RBIT_64_dp_1src" 0xfffffc00 0xdac00000 Covered
  , Encoding "RCWCAS_C64_rcwcomswap" 0xffe0fc00 0x19200800 Covered
  , Encoding "RCWCASA_C64_rcwcomswap" 0xffe0fc00 0x19a00800 Covered
  , Encoding "RCWCASAL_C64_rcwcomswap" 0xffe0fc00 0x19e00800 Covered
  , Encoding "RCWCASL_C64_rcwcomswap" 0xffe0fc00 0x19600800 Covered
  , Encoding "RCWCASP_C64_rcwcomswappr" 0xffe0fc00 0x19200c00 Covered
  , Encoding "RCWCASPA_C64_rcwcomswappr" 0xffe0fc00 0x19a00c00 Covered
  , Encoding "RCWCASPAL_C64_rcwcomswappr" 0xffe0fc00 0x19e00c00 Covered
  , Encoding "RCWCASPL_C64_rcwcomswappr" 0xffe0fc00 0x19600c00 Covered
  , Encoding "RCWCLR_64_memop" 0xffe0fc00 0x38209000 Covered
  , Encoding "RCWCLRA_64_memop" 0xffe0fc00 0x38a09000 Covered
  , Encoding "RCWCLRAL_64_memop" 0xffe0fc00 0x38e09000 Covered
  , Encoding "RCWCLRL_64_memop" 0xffe0fc00 0x38609000 Covered
  , Encoding "RCWCLRP_128_memop_128" 0xffe0fc00 0x19209000 Covered
  , Encoding "RCWCLRPA_128_memop_128" 0xffe0fc00 0x19a09000 Covered
  , Encoding "RCWCLRPAL_128_memop_128" 0xffe0fc00 0x19e09000 Covered
  , Encoding "RCWCLRPL_128_memop_128" 0xffe0fc00 0x19609000 Covered
  , Encoding "RCWSCAS_C64_rcwcomswap" 0xffe0fc00 0x59200800 Covered
  , Encoding "RCWSCASA_C64_rcwcomswap" 0xffe0fc00 0x59a00800 Covered
  , Encoding "RCWSCASAL_C64_rcwcomswap" 0xffe0fc00 0x59e00800 Covered
  , Encoding "RCWSCASL_C64_rcwcomswap" 0xffe0fc00 0x59600800 Covered
  , Encoding "RCWSCASP_C64_rcwcomswappr" 0xffe0fc00 0x59200c00 Covered
  , Encoding "RCWSCASPA_C64_rcwcomswappr" 0xffe0fc00 0x59a00c00 Covered
  , Encoding "RCWSCASPAL_C64_rcwcomswappr" 0xffe0fc00 0x59e00c00 Covered
  , Encoding "RCWSCASPL_C64_rcwcomswappr" 0xffe0fc00 0x59600c00 Covered
  , Encoding "RCWSCLR_64_memop" 0xffe0fc00 0x78209000 Covered
  , Encoding "RCWSCLRA_64_memop" 0xffe0fc00 0x78a09000 Covered
  , Encoding "RCWSCLRAL_64_memop" 0xffe0fc00 0x78e09000 Covered
  , Encoding "RCWSCLRL_64_memop" 0xffe0fc00 0x78609000 Covered
  , Encoding "RCWSCLRP_128_memop_128" 0xffe0fc00 0x59209000 Covered
  , Encoding "RCWSCLRPA_128_memop_128" 0xffe0fc00 0x59a09000 Covered
  , Encoding "RCWSCLRPAL_128_memop_128" 0xffe0fc00 0x59e09000 Covered
  , Encoding "RCWSCLRPL_128_memop_128" 0xffe0fc00 0x59609000 Covered
  , Encoding "RCWSET_64_memop" 0xffe0fc00 0x3820b000 Covered
  , Encoding "RCWSETA_64_memop" 0xffe0fc00 0x38a0b000 Covered
  , Encoding "RCWSETAL_64_memop" 0xffe0fc00 0x38e0b000 Covered
  , Encoding "RCWSETL_64_memop" 0xffe0fc00 0x3860b000 Covered
  , Encoding "RCWSETP_128_memop_128" 0xffe0fc00 0x1920b000 Covered
  , Encoding "RCWSETPA_128_memop_128" 0xffe0fc00 0x19a0b000 Covered
  , Encoding "RCWSETPAL_128_memop_128" 0xffe0fc00 0x19e0b000 Covered
  , Encoding "RCWSETPL_128_memop_128" 0xffe0fc00 0x1960b000 Covered
  , Encoding "RCWSSET_64_memop" 0xffe0fc00 0x7820b000 Covered
  , Encoding "RCWSSETA_64_memop" 0xffe0fc00 0x78a0b000 Covered
  , Encoding "RCWSSETAL_64_memop" 0xffe0fc00 0x78e0b000 Covered
  , Encoding "RCWSSETL_64_memop" 0xffe0fc00 0x7860b000 Covered
  , Encoding "RCWSSETP_128_memop_128" 0xffe0fc00 0x5920b000 Covered
  , Encoding "RCWSSETPA_128_memop_128" 0xffe0fc00 0x59a0b000 Covered
  , Encoding "RCWSSETPAL_128_memop_128" 0xffe0fc00 0x59e0b000 Covered
  , Encoding "RCWSSETPL_128_memop_128" 0xffe0fc00 0x5960b000 Covered
  , Encoding "RCWSSWP_64_memop" 0xffe0fc00 0x7820a000 Covered
  , Encoding "RCWSSWPA_64_memop" 0xffe0fc00 0x78a0a000 Covered
  , Encoding "RCWSSWPAL_64_memop" 0xffe0fc00 0x78e0a000 Covered
  , Encoding "RCWSSWPL_64_memop" 0xffe0fc00 0x7860a000 Covered
  , Encoding "RCWSSWPP_128_memop_128" 0xffe0fc00 0x5920a000 Covered
  , Encoding "RCWSSWPPA_128_memop_128" 0xffe0fc00 0x59a0a000 Covered
  , Encoding "RCWSSWPPAL_128_memop_128" 0xffe0fc00 0x59e0a000 Covered
  , Encoding "RCWSSWPPL_128_memop_128" 0xffe0fc00 0x5960a000 Covered
  , Encoding "RCWSWP_64_memop" 0xffe0fc00 0x3820a000 Covered
  , Encoding "RCWSWPA_64_memop" 0xffe0fc00 0x38a0a000 Covered
  , Encoding "RCWSWPAL_64_memop" 0xffe0fc00 0x38e0a000 Covered
  , Encoding "RCWSWPL_64_memop" 0xffe0fc00 0x3860a000 Covered
  , Encoding "RCWSWPP_128_memop_128" 0xffe0fc00 0x1920a000 Covered
  , Encoding "RCWSWPPA_128_memop_128" 0xffe0fc00 0x19a0a000 Covered
  , Encoding "RCWSWPPAL_128_memop_128" 0xffe0fc00 0x19e0a000 Covered
  , Encoding "RCWSWPPL_128_memop_128" 0xffe0fc00 0x1960a000 Covered
  , Encoding "RET_64R_branch_reg" 0xfffffc1f 0xd65f0000 Control
  , Encoding "RETAA_64E_branch_reg" 0xffffffff 0xd65f0bff Control
  , Encoding "RETAB_64E_branch_reg" 0xffffffff 0xd65f0fff Control
  , Encoding "REV_32_dp_1src" 0xfffff400 0x5ac00000 Covered
  , Encoding "REV_64_dp_1src" 0xfffff400 0xdac00400 Covered
  , Encoding "REV16_asimdmisc_R" 0xbf3ffc00 0x0e201800 Covered
  , Encoding "REV16_32_dp_1src" 0xfffffc00 0x5ac00400 Covered
  , Encoding "REV16_64_dp_1src" 0xfffffc00 0xdac00400 Covered
  , Encoding "REV32_asimdmisc_R" 0xbf3ffc00 0x2e200800 Covered
  , Encoding "REV32_64_dp_1src" 0xfffffc00 0xdac00800 Covered
  , Encoding "REV64_asimdmisc_R" 0xbf3ffc00 0x0e200800 Covered
  , Encoding "RMIF_only_rmif" 0xffe07c10 0xba000400 Covered
  , Encoding "RORV_32_dp_2src" 0xffe0fc00 0x1ac02c00 Covered
  , Encoding "RORV_64_dp_2src" 0xffe0fc00 0x9ac02c00 Covered
  , Encoding "RPRFM_R_ldst_regoff" 0xffe04c18 0xf8a04818 (Outside [(16, OpX)])
  , Encoding "RSHRN_asimdshf_N" 0xbf80fc00 0x0f008c00 Covered
  , Encoding "RSUBHN_asimddiff_N" 0xbf20fc00 0x2e206000 Covered
  , Encoding "SABA_asimdsame_only" 0xbf20fc00 0x0e207c00 Covered
  , Encoding "SABAL_asimddiff_L" 0xbf20fc00 0x0e205000 Covered
  , Encoding "SABD_asimdsame_only" 0xbf20fc00 0x0e207400 Covered
  , Encoding "SABDL_asimddiff_L" 0xbf20fc00 0x0e207000 Covered
  , Encoding "SADALP_asimdmisc_P" 0xbf3ffc00 0x0e206800 Covered
  , Encoding "SADDL_asimddiff_L" 0xbf20fc00 0x0e200000 Covered
  , Encoding "SADDLP_asimdmisc_P" 0xbf3ffc00 0x0e202800 Covered
  , Encoding "SADDLV_asimdall_only" 0xbf3ffc00 0x0e303800 Covered
  , Encoding "SADDW_asimddiff_W" 0xbf20fc00 0x0e201000 Covered
  , Encoding "SB_only_barriers" 0xfffff0ff 0xd50330ff Control
  , Encoding "SBC_32_addsub_carry" 0xffe0fc00 0x5a000000 Covered
  , Encoding "SBC_64_addsub_carry" 0xffe0fc00 0xda000000 Covered
  , Encoding "SBCS_32_addsub_carry" 0xffe0fc00 0x7a000000 Covered
  , Encoding "SBCS_64_addsub_carry" 0xffe0fc00 0xfa000000 Covered
  , Encoding "SBFM_32M_bitfield" 0xffc00000 0x13000000 Covered
  , Encoding "SBFM_64M_bitfield" 0xffc00000 0x93400000 Covered
  , Encoding "SCVTF_asisdshf_C" 0xff80fc00 0x5f00e400 (Outside [])
  , Encoding "SCVTF_asimdshf_C" 0xbf80fc00 0x0f00e400 (Outside [(5, OpV)])
  , Encoding "SCVTF_asisdmiscfp16_R" 0xfffffc00 0x5e79d800 (Outside [(5, OpH)])
  , Encoding "SCVTF_asisdmisc_R" 0xffbffc00 0x5e21d800 (Outside [])
  , Encoding "SCVTF_asimdmiscfp16_R" 0xbffffc00 0x0e79d800 (Outside [(5, OpV)])
  , Encoding "SCVTF_asimdmisc_R" 0xbfbffc00 0x0e21d800 (Outside [(5, OpV)])
  , Encoding "SCVTF_H32_float2fix" 0xffff0000 0x1ec20000 (Outside [(5, OpW)])
  , Encoding "SCVTF_S32_float2fix" 0xffff0000 0x1e020000 (Outside [(5, OpW)])
  , Encoding "SCVTF_D32_float2fix" 0xffff0000 0x1e420000 (Outside [(5, OpW)])
  , Encoding "SCVTF_H64_float2fix" 0xffff0000 0x9ec20000 (Outside [(5, OpX)])
  , Encoding "SCVTF_S64_float2fix" 0xffff0000 0x9e020000 (Outside [(5, OpX)])
  , Encoding "SCVTF_D64_float2fix" 0xffff0000 0x9e420000 (Outside [(5, OpX)])
  , Encoding "SCVTF_H32_float2int" 0xfffffc00 0x1ee20000 (Outside [(5, OpW)])
  , Encoding "SCVTF_S32_float2int" 0xfffffc00 0x1e220000 (Outside [(5, OpW)])
  , Encoding "SCVTF_D32_float2int" 0xfffffc00 0x1e620000 (Outside [(5, OpW)])
  , Encoding "SCVTF_H64_float2int" 0xfffffc00 0x9ee20000 (Outside [(5, OpX)])
  , Encoding "SCVTF_S64_float2int" 0xfffffc00 0x9e220000 (Outside [(5, OpX)])
  , Encoding "SCVTF_D64_float2int" 0xfffffc00 0x9e620000 (Outside [(5, OpX)])
  , Encoding "SDIV_32_dp_2src" 0xffe0fc00 0x1ac00c00
      (Outside [(5, OpW), (16, OpW)])
  , Encoding "SDIV_64_dp_2src" 0xffe0fc00 0x9ac00c00
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SDOT_asimdelem_D" 0xbf00f400 0x0f00e000
      (Outside [(0, OpV), (5, OpV)])
  , Encoding "SDOT_asimdsame2_D" 0xbf20fc00 0x0e009400
      (Outside [(0, OpV), (5, OpV), (16, OpV)])
  , Encoding "SETF8_only_setf" 0xfffffc1f 0x3a00080d Covered
  , Encoding "SETF16_only_setf" 0xfffffc1f 0x3a00480d Covered
  , Encoding "SETGE_SET_memcms" 0x3fe0cc00 0x1dc08400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETGM_SET_memcms" 0x3fe0cc00 0x1dc04400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETGP_SET_memcms" 0x3fe0cc00 0x1dc00400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETGEN_SET_memcms" 0x3fe0cc00 0x1dc08400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETGMN_SET_memcms" 0x3fe0cc00 0x1dc04400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETGPN_SET_memcms" 0x3fe0cc00 0x1dc00400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETGET_SET_memcms" 0x3fe0cc00 0x1dc08400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETGMT_SET_memcms" 0x3fe0cc00 0x1dc04400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETGPT_SET_memcms" 0x3fe0cc00 0x1dc00400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETGETN_SET_memcms" 0x3fe0cc00 0x1dc08400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETGMTN_SET_memcms" 0x3fe0cc00 0x1dc04400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETGPTN_SET_memcms" 0x3fe0cc00 0x1dc00400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETE_SET_memcms" 0x3fe0cc00 0x19c08400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETM_SET_memcms" 0x3fe0cc00 0x19c04400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETP_SET_memcms" 0x3fe0cc00 0x19c00400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETEN_SET_memcms" 0x3fe0cc00 0x19c08400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETMN_SET_memcms" 0x3fe0cc00 0x19c04400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETPN_SET_memcms" 0x3fe0cc00 0x19c00400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETET_SET_memcms" 0x3fe0cc00 0x19c08400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETMT_SET_memcms" 0x3fe0cc00 0x19c04400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETPT_SET_memcms" 0x3fe0cc00 0x19c00400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETETN_SET_memcms" 0x3fe0cc00 0x19c08400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETMTN_SET_memcms" 0x3fe0cc00 0x19c04400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SETPTN_SET_memcms" 0x3fe0cc00 0x19c00400
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "SEV_HI_hints" 0xffffffff 0xd503209f Control
  , Encoding "SEVL_HI_hints" 0xffffffff 0xd50320bf Control
  , Encoding "SHA1C_QSV_cryptosha3" 0xffe0fc00 0x5e000000 Covered
  , Encoding "SHA1H_SS_cryptosha2" 0xfffffc00 0x5e280800 Covered
  , Encoding "SHA1M_QSV_cryptosha3" 0xffe0fc00 0x5e002000 Covered
  , Encoding "SHA1P_QSV_cryptosha3" 0xffe0fc00 0x5e001000 Covered
  , Encoding "SHA1SU0_VVV_cryptosha3" 0xffe0fc00 0x5e003000 Covered
  , Encoding "SHA1SU1_VV_cryptosha2" 0xfffffc00 0x5e281800 Covered
  , Encoding "SHA256H2_QQV_cryptosha3" 0xffe0fc00 0x5e005000 Covered
  , Encoding "SHA256H_QQV_cryptosha3" 0xffe0fc00 0x5e004000 Covered
  , Encoding "SHA256SU0_VV_cryptosha2" 0xfffffc00 0x5e282800 Covered
  , Encoding "SHA256SU1_VVV_cryptosha3" 0xffe0fc00 0x5e006000 Covered
  , Encoding "SHA512H2_QQV_cryptosha512_3" 0xffe0fc00 0xce608400 Covered
  , Encoding "SHA512H_QQV_cryptosha512_3" 0xffe0fc00 0xce608000 Covered
  , Encoding "SHA512SU0_VV2_cryptosha512_2" 0xfffffc00 0xcec08000 Covered
  , Encoding "SHA512SU1_VVV2_cryptosha512_3" 0xffe0fc00 0xce608800 Covered
  , Encoding "SHADD_asimdsame_only" 0xbf20fc00 0x0e200400 Covered
  , Encoding "SHL_asisdshf_R" 0xff80fc00 0x5f005400 Covered
  , Encoding "SHL_asimdshf_R" 0xbf80fc00 0x0f005400 Covered
  , Encoding "SHLL_asimdmisc_S" 0xbf3ffc00 0x2e213800 Covered
  , Encoding "SHRN_asimdshf_N" 0xbf80fc00 0x0f008400 Covered
  , Encoding "SHSUB_asimdsame_only" 0xbf20fc00 0x0e202400 Covered
  , Encoding "SLI_asisdshf_R" 0xff80fc00 0x7f005400 Covered
  , Encoding "SLI_asimdshf_R" 0xbf80fc00 0x2f005400 Covered
  , Encoding "SM3PARTW1_VVV4_cryptosha512_3" 0xffe0fc00 0xce60c000 Covered
  , Encoding "SM3PARTW2_VVV4_cryptosha512_3" 0xffe0fc00 0xce60c400 Covered
  , Encoding "SM3SS1_VVV4_crypto4" 0xffe08000 0xce400000 Covered
  , Encoding "SM3TT1A_VVV4_crypto3_imm2" 0xffe0cc00 0xce408000 Covered
  , Encoding "SM3TT1B_VVV4_crypto3_imm2" 0xffe0cc00 0xce408400 Covered
  , Encoding "SM3TT2A_VVV4_crypto3_imm2" 0xffe0cc00 0xce408800 Covered
  , Encoding "SM3TT2B_VVV_crypto3_imm2" 0xffe0cc00 0xce408c00 Covered
  , Encoding "SM4E_VV4_cryptosha512_2" 0xfffffc00 0xcec08400 Covered
  , Encoding "SM4EKEY_VVV4_cryptosha512_3" 0xffe0fc00 0xce60c800 Covered
  , Encoding "SMADDL_64WA_dp_3src" 0xffe08000 0x9b200000 Covered
  , Encoding "SMAX_asimdsame_only" 0xbf20fc00 0x0e206400 Covered
  , Encoding "SMAX_32_minmax_imm" 0xfffc0000 0x11c00000 Covered
  , Encoding "SMAX_64_minmax_imm" 0xfffc0000 0x91c00000 Covered
  , Encoding "SMAX_32_dp_2src" 0xffe0fc00 0x1ac06000 Covered
  , Encoding "SMAX_64_dp_2src" 0xffe0fc00 0x9ac06000 Covered
  , Encoding "SMAXP_asimdsame_only" 0xbf20fc00 0x0e20a400 Covered
  , Encoding "SMAXV_asimdall_only" 0xbf3ffc00 0x0e30a800 Covered
  , Encoding "SMC_EX_exception" 0xffe0001f 0xd4000003 Control
  , Encoding "SMIN_asimdsame_only" 0xbf20fc00 0x0e206c00 Covered
  , Encoding "SMIN_32_minmax_imm" 0xfffc0000 0x11c80000 Covered
  , Encoding "SMIN_64_minmax_imm" 0xfffc0000 0x91c80000 Covered
  , Encoding "SMIN_32_dp_2src" 0xffe0fc00 0x1ac06800 Covered
  , Encoding "SMIN_64_dp_2src" 0xffe0fc00 0x9ac06800 Covered
  , Encoding "SMINP_asimdsame_only" 0xbf20fc00 0x0e20ac00 Covered
  , Encoding "SMINV_asimdall_only" 0xbf3ffc00 0x0e31a800 Covered
  , Encoding "SMLAL_asimdelem_L" 0xbf00f400 0x0f002000 Covered
  , Encoding "SMLAL_asimddiff_L" 0xbf20fc00 0x0e208000 Covered
  , Encoding "SMLSL_asimdelem_L" 0xbf00f400 0x0f006000 Covered
  , Encoding "SMLSL_asimddiff_L" 0xbf20fc00 0x0e20a000 Covered
  , Encoding "SMMLA_asimdsame2_G" 0xffe0fc00 0x4e80a400
      (Outside [(0, OpV), (5, OpV), (16, OpV)])
  , Encoding "SMOV_asimdins_W_w" 0xffe0fc00 0x0e002c00 Covered
  , Encoding "SMOV_asimdins_X_x" 0xffe0fc00 0x4e002c00 Covered
  , Encoding "SMSUBL_64WA_dp_3src" 0xffe08000 0x9b208000 Covered
  , Encoding "SMULH_64_dp_3src" 0xffe08000 0x9b400000 Covered
  , Encoding "SMULL_asimdelem_L" 0xbf00f400 0x0f00a000 Covered
  , Encoding "SMULL_asimddiff_L" 0xbf20fc00 0x0e20c000 Covered
  , Encoding "SQABS_asisdmisc_R" 0xff3ffc00 0x5e207800 (Outside [])
  , Encoding "SQABS_asimdmisc_R" 0xbf3ffc00 0x0e207800 (Outside [(5, OpV)])
  , Encoding "SQADD_asisdsame_only" 0xff20fc00 0x5e200c00 (Outside [])
  , Encoding "SQADD_asimdsame_only" 0xbf20fc00 0x0e200c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "SQDMLAL_asisdelem_L" 0xff00f400 0x5f003000 (Outside [])
  , Encoding "SQDMLAL_asimdelem_L" 0xbf00f400 0x0f003000 (Outside [(5, OpV)])
  , Encoding "SQDMLAL_asisddiff_only" 0xff20fc00 0x5e209000 (Outside [])
  , Encoding "SQDMLAL_asimddiff_L" 0xbf20fc00 0x0e209000
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "SQDMLSL_asisdelem_L" 0xff00f400 0x5f007000 (Outside [])
  , Encoding "SQDMLSL_asimdelem_L" 0xbf00f400 0x0f007000 (Outside [(5, OpV)])
  , Encoding "SQDMLSL_asisddiff_only" 0xff20fc00 0x5e20b000 (Outside [])
  , Encoding "SQDMLSL_asimddiff_L" 0xbf20fc00 0x0e20b000
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "SQDMULH_asisdelem_R" 0xff00f400 0x5f00c000 Covered
  , Encoding "SQDMULH_asimdelem_R" 0xbf00f400 0x0f00c000 Covered
  , Encoding "SQDMULH_asisdsame_only" 0xff20fc00 0x5e20b400 Covered
  , Encoding "SQDMULH_asimdsame_only" 0xbf20fc00 0x0e20b400 Covered
  , Encoding "SQDMULL_asisdelem_L" 0xff00f400 0x5f00b000 (Outside [])
  , Encoding "SQDMULL_asimdelem_L" 0xbf00f400 0x0f00b000 (Outside [(5, OpV)])
  , Encoding "SQDMULL_asisddiff_only" 0xff20fc00 0x5e20d000 (Outside [])
  , Encoding "SQDMULL_asimddiff_L" 0xbf20fc00 0x0e20d000
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "SQNEG_asisdmisc_R" 0xff3ffc00 0x7e207800 (Outside [])
  , Encoding "SQNEG_asimdmisc_R" 0xbf3ffc00 0x2e207800 (Outside [(5, OpV)])
  , Encoding "SQRDMLAH_asisdelem_R" 0xff00f400 0x7f00d000 Covered
  , Encoding "SQRDMLAH_asimdelem_R" 0xbf00f400 0x2f00d000 Covered
  , Encoding "SQRDMLAH_asisdsame2_only" 0xff20fc00 0x7e008400 Covered
  , Encoding "SQRDMLAH_asimdsame2_only" 0xbf20fc00 0x2e008400 Covered
  , Encoding "SQRDMLSH_asisdelem_R" 0xff00f400 0x7f00f000 (Outside [])
  , Encoding "SQRDMLSH_asimdelem_R" 0xbf00f400 0x2f00f000 (Outside [(5, OpV)])
  , Encoding "SQRDMLSH_asisdsame2_only" 0xff20fc00 0x7e008c00 (Outside [])
  , Encoding "SQRDMLSH_asimdsame2_only" 0xbf20fc00 0x2e008c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "SQRDMULH_asisdelem_R" 0xff00f400 0x5f00d000 Covered
  , Encoding "SQRDMULH_asimdelem_R" 0xbf00f400 0x0f00d000 Covered
  , Encoding "SQRDMULH_asisdsame_only" 0xff20fc00 0x7e20b400 Covered
  , Encoding "SQRDMULH_asimdsame_only" 0xbf20fc00 0x2e20b400 Covered
  , Encoding "SQRSHL_asisdsame_only" 0xff20fc00 0x5e205c00 (Outside [])
  , Encoding "SQRSHL_asimdsame_only" 0xbf20fc00 0x0e205c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "SQRSHRN_asisdshf_N" 0xff80fc00 0x5f009c00 (Outside [])
  , Encoding "SQRSHRN_asimdshf_N" 0xbf80fc00 0x0f009c00 (Outside [(5, OpV)])
  , Encoding "SQRSHRUN_asisdshf_N" 0xff80fc00 0x7f008c00 (Outside [])
  , Encoding "SQRSHRUN_asimdshf_N" 0xbf80fc00 0x2f008c00 (Outside [(5, OpV)])
  , Encoding "SQSHL_asisdshf_R" 0xff80fc00 0x5f007400 (Outside [])
  , Encoding "SQSHL_asimdshf_R" 0xbf80fc00 0x0f007400 (Outside [(5, OpV)])
  , Encoding "SQSHL_asisdsame_only" 0xff20fc00 0x5e204c00 (Outside [])
  , Encoding "SQSHL_asimdsame_only" 0xbf20fc00 0x0e204c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "SQSHLU_asisdshf_R" 0xff80fc00 0x7f006400 (Outside [])
  , Encoding "SQSHLU_asimdshf_R" 0xbf80fc00 0x2f006400 (Outside [(5, OpV)])
  , Encoding "SQSHRN_asisdshf_N" 0xff80fc00 0x5f009400 (Outside [])
  , Encoding "SQSHRN_asimdshf_N" 0xbf80fc00 0x0f009400 (Outside [(5, OpV)])
  , Encoding "SQSHRUN_asisdshf_N" 0xff80fc00 0x7f008400 (Outside [])
  , Encoding "SQSHRUN_asimdshf_N" 0xbf80fc00 0x2f008400 (Outside [(5, OpV)])
  , Encoding "SQSUB_asisdsame_only" 0xff20fc00 0x5e202c00 (Outside [])
  , Encoding "SQSUB_asimdsame_only" 0xbf20fc00 0x0e202c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "SQXTN_asisdmisc_N" 0xff3ffc00 0x5e214800 (Outside [])
  , Encoding "SQXTN_asimdmisc_N" 0xbf3ffc00 0x0e214800 (Outside [(5, OpV)])
  , Encoding "SQXTUN_asisdmisc_N" 0xff3ffc00 0x7e212800 (Outside [])
  , Encoding "SQXTUN_asimdmisc_N" 0xbf3ffc00 0x2e212800 (Outside [(5, OpV)])
  , Encoding "SRHADD_asimdsame_only" 0xbf20fc00 0x0e201400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "SRI_asisdshf_R" 0xff80fc00 0x7f004400 Covered
  , Encoding "SRI_asimdshf_R" 0xbf80fc00 0x2f004400 Covered
  , Encoding "SRSHL_asisdsame_only" 0xff20fc00 0x5e205400 (Outside [])
  , Encoding "SRSHL_asimdsame_only" 0xbf20fc00 0x0e205400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "SRSHR_asisdshf_R" 0xff80fc00 0x5f002400 (Outside [])
  , Encoding "SRSHR_asimdshf_R" 0xbf80fc00 0x0f002400 (Outside [(5, OpV)])
  , Encoding "SRSRA_asisdshf_R" 0xff80fc00 0x5f003400 (Outside [])
  , Encoding "SRSRA_asimdshf_R" 0xbf80fc00 0x0f003400 (Outside [(5, OpV)])
  , Encoding "SSHL_asisdsame_only" 0xff20fc00 0x5e204400 Covered
  , Encoding "SSHL_asimdsame_only" 0xbf20fc00 0x0e204400 Covered
  , Encoding "SSHLL_asimdshf_L" 0xbf80fc00 0x0f00a400 Covered
  , Encoding "SSHR_asisdshf_R" 0xff80fc00 0x5f000400 Covered
  , Encoding "SSHR_asimdshf_R" 0xbf80fc00 0x0f000400 Covered
  , Encoding "SSRA_asisdshf_R" 0xff80fc00 0x5f001400 Covered
  , Encoding "SSRA_asimdshf_R" 0xbf80fc00 0x0f001400 Covered
  , Encoding "SSUBL_asimddiff_L" 0xbf20fc00 0x0e202000 Covered
  , Encoding "SSUBW_asimddiff_W" 0xbf20fc00 0x0e203000 Covered
  , Encoding "ST1_asisdlse_R1_1v" 0xbfffd000 0x0c005000 Covered
  , Encoding "ST1_asisdlse_R2_2v" 0xbfffd000 0x0c008000 Covered
  , Encoding "ST1_asisdlse_R3_3v" 0xbfffd000 0x0c004000 Covered
  , Encoding "ST1_asisdlse_R4_4v" 0xbfffd000 0x0c000000 Covered
  , Encoding "ST1_asisdlsep_I1_i1" 0xbfffd000 0x0c9f5000 Covered
  , Encoding "ST1_asisdlsep_R1_r1" 0xbfe0d000 0x0c805000 Covered
  , Encoding "ST1_asisdlsep_I2_i2" 0xbfffd000 0x0c9f8000 Covered
  , Encoding "ST1_asisdlsep_R2_r2" 0xbfe0d000 0x0c808000 Covered
  , Encoding "ST1_asisdlsep_I3_i3" 0xbfffd000 0x0c9f4000 Covered
  , Encoding "ST1_asisdlsep_R3_r3" 0xbfe0d000 0x0c804000 Covered
  , Encoding "ST1_asisdlsep_I4_i4" 0xbfffd000 0x0c9f0000 Covered
  , Encoding "ST1_asisdlsep_R4_r4" 0xbfe0d000 0x0c800000 Covered
  , Encoding "ST1_asisdlso_B1_1b" 0xbfffc000 0x0d000000 Covered
  , Encoding "ST1_asisdlso_H1_1h" 0xbfffc400 0x0d004000 Covered
  , Encoding "ST1_asisdlso_S1_1s" 0xbfffcc00 0x0d008000 Covered
  , Encoding "ST1_asisdlso_D1_1d" 0xbfffdc00 0x0d008400 Covered
  , Encoding "ST1_asisdlsop_B1_i1b" 0xbfffc000 0x0d9f0000 Covered
  , Encoding "ST1_asisdlsop_BX1_r1b" 0xbfe0c000 0x0d800000 Covered
  , Encoding "ST1_asisdlsop_H1_i1h" 0xbfffc400 0x0d9f4000 Covered
  , Encoding "ST1_asisdlsop_HX1_r1h" 0xbfe0c400 0x0d804000 Covered
  , Encoding "ST1_asisdlsop_S1_i1s" 0xbfffcc00 0x0d9f8000 Covered
  , Encoding "ST1_asisdlsop_SX1_r1s" 0xbfe0cc00 0x0d808000 Covered
  , Encoding "ST1_asisdlsop_D1_i1d" 0xbfffdc00 0x0d9f8400 Covered
  , Encoding "ST1_asisdlsop_DX1_r1d" 0xbfe0dc00 0x0d808400 Covered
  , Encoding "ST2_asisdlse_R2" 0xbffff000 0x0c008000 Covered
  , Encoding "ST2_asisdlsep_I2_i" 0xbffff000 0x0c9f8000 Covered
  , Encoding "ST2_asisdlsep_R2_r" 0xbfe0f000 0x0c808000 Covered
  , Encoding "ST2_asisdlso_B2_2b" 0xbfffc000 0x0d200000 Covered
  , Encoding "ST2_asisdlso_H2_2h" 0xbfffc400 0x0d204000 Covered
  , Encoding "ST2_asisdlso_S2_2s" 0xbfffcc00 0x0d208000 Covered
  , Encoding "ST2_asisdlso_D2_2d" 0xbfffdc00 0x0d208400 Covered
  , Encoding "ST2_asisdlsop_B2_i2b" 0xbfffc000 0x0dbf0000 Covered
  , Encoding "ST2_asisdlsop_BX2_r2b" 0xbfe0c000 0x0da00000 Covered
  , Encoding "ST2_asisdlsop_H2_i2h" 0xbfffc400 0x0dbf4000 Covered
  , Encoding "ST2_asisdlsop_HX2_r2h" 0xbfe0c400 0x0da04000 Covered
  , Encoding "ST2_asisdlsop_S2_i2s" 0xbfffcc00 0x0dbf8000 Covered
  , Encoding "ST2_asisdlsop_SX2_r2s" 0xbfe0cc00 0x0da08000 Covered
  , Encoding "ST2_asisdlsop_D2_i2d" 0xbfffdc00 0x0dbf8400 Covered
  , Encoding "ST2_asisdlsop_DX2_r2d" 0xbfe0dc00 0x0da08400 Covered
  , Encoding "ST2G_64Spost_ldsttags" 0xffe00c00 0xd9a00400
      (Outside [(0, OpXSp)])
  , Encoding "ST2G_64Spre_ldsttags" 0xffe00c00 0xd9a00c00
      (Outside [(0, OpXSp)])
  , Encoding "ST2G_64Soffset_ldsttags" 0xffe00c00 0xd9a00800
      (Outside [(0, OpXSp)])
  , Encoding "ST3_asisdlse_R3" 0xbffff000 0x0c004000 Covered
  , Encoding "ST3_asisdlsep_I3_i" 0xbffff000 0x0c9f4000 Covered
  , Encoding "ST3_asisdlsep_R3_r" 0xbfe0f000 0x0c804000 Covered
  , Encoding "ST3_asisdlso_B3_3b" 0xbfffc000 0x0d000000 Covered
  , Encoding "ST3_asisdlso_H3_3h" 0xbfffc400 0x0d004000 Covered
  , Encoding "ST3_asisdlso_S3_3s" 0xbfffcc00 0x0d008000 Covered
  , Encoding "ST3_asisdlso_D3_3d" 0xbfffdc00 0x0d008400 Covered
  , Encoding "ST3_asisdlsop_B3_i3b" 0xbfffc000 0x0d9f0000 Covered
  , Encoding "ST3_asisdlsop_BX3_r3b" 0xbfe0c000 0x0d800000 Covered
  , Encoding "ST3_asisdlsop_H3_i3h" 0xbfffc400 0x0d9f4000 Covered
  , Encoding "ST3_asisdlsop_HX3_r3h" 0xbfe0c400 0x0d804000 Covered
  , Encoding "ST3_asisdlsop_S3_i3s" 0xbfffcc00 0x0d9f8000 Covered
  , Encoding "ST3_asisdlsop_SX3_r3s" 0xbfe0cc00 0x0d808000 Covered
  , Encoding "ST3_asisdlsop_D3_i3d" 0xbfffdc00 0x0d9f8400 Covered
  , Encoding "ST3_asisdlsop_DX3_r3d" 0xbfe0dc00 0x0d808400 Covered
  , Encoding "ST4_asisdlse_R4" 0xbffff000 0x0c000000 Covered
  , Encoding "ST4_asisdlsep_I4_i" 0xbffff000 0x0c9f0000 Covered
  , Encoding "ST4_asisdlsep_R4_r" 0xbfe0f000 0x0c800000 Covered
  , Encoding "ST4_asisdlso_B4_4b" 0xbfffc000 0x0d200000 Covered
  , Encoding "ST4_asisdlso_H4_4h" 0xbfffc400 0x0d204000 Covered
  , Encoding "ST4_asisdlso_S4_4s" 0xbfffcc00 0x0d208000 Covered
  , Encoding "ST4_asisdlso_D4_4d" 0xbfffdc00 0x0d208400 Covered
  , Encoding "ST4_asisdlsop_B4_i4b" 0xbfffc000 0x0dbf0000 Covered
  , Encoding "ST4_asisdlsop_BX4_r4b" 0xbfe0c000 0x0da00000 Covered
  , Encoding "ST4_asisdlsop_H4_i4h" 0xbfffc400 0x0dbf4000 Covered
  , Encoding "ST4_asisdlsop_HX4_r4h" 0xbfe0c400 0x0da04000 Covered
  , Encoding "ST4_asisdlsop_S4_i4s" 0xbfffcc00 0x0dbf8000 Covered
  , Encoding "ST4_asisdlsop_SX4_r4s" 0xbfe0cc00 0x0da08000 Covered
  , Encoding "ST4_asisdlsop_D4_i4d" 0xbfffdc00 0x0dbf8400 Covered
  , Encoding "ST4_asisdlsop_DX4_r4d" 0xbfe0dc00 0x0da08400 Covered
  , Encoding "ST64B_64L_memop" 0xfffffc00 0xf83f9000 (Outside [(0, OpX)])
  , Encoding "ST64BV_64_memop" 0xffe0fc00 0xf820b000
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "ST64BV0_64_memop" 0xffe0fc00 0xf820a000
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "STG_64Spost_ldsttags" 0xffe00c00 0xd9200400
      (Outside [(0, OpXSp)])
  , Encoding "STG_64Spre_ldsttags" 0xffe00c00 0xd9200c00 (Outside [(0, OpXSp)])
  , Encoding "STG_64Soffset_ldsttags" 0xffe00c00 0xd9200800
      (Outside [(0, OpXSp)])
  , Encoding "STGM_64bulk_ldsttags" 0xfffffc00 0xd9a00000 (Outside [(0, OpX)])
  , Encoding "STGP_64_ldstpair_post" 0xffc00000 0x68800000
      (Outside [(0, OpX), (10, OpX)])
  , Encoding "STGP_64_ldstpair_pre" 0xffc00000 0x69800000
      (Outside [(0, OpX), (10, OpX)])
  , Encoding "STGP_64_ldstpair_off" 0xffc00000 0x69000000
      (Outside [(0, OpX), (10, OpX)])
  , Encoding "STILP_32S_ldiappstilp" 0x7fe01c00 0x19001800 Covered
  , Encoding "STILP_32SE_ldiappstilp" 0x7fe01c00 0x19000800 Covered
  , Encoding "STILP_64S_ldiappstilp" 0x7fe01c00 0x59001800 Covered
  , Encoding "STILP_64SS_ldiappstilp" 0x7fe01c00 0x59000800 Covered
  , Encoding "STL1_asisdlso_D1" 0xbffffc00 0x0d018400 Covered
  , Encoding "STLLR_SL32_ldstord" 0x7fe08000 0x08800000 Covered
  , Encoding "STLLR_SL64_ldstord" 0x7fe08000 0x48800000 Covered
  , Encoding "STLLRB_SL32_ldstord" 0xffe08000 0x08800000 Covered
  , Encoding "STLLRH_SL32_ldstord" 0xffe08000 0x48800000 Covered
  , Encoding "STLR_SL32_ldstord" 0x7fe08000 0x08808000 Covered
  , Encoding "STLR_SL64_ldstord" 0x7fe08000 0x48808000 Covered
  , Encoding "STLR_32S_ldapstl_writeback" 0x7ffffc00 0x19800800 Covered
  , Encoding "STLR_64S_ldapstl_writeback" 0x7ffffc00 0x59800800 Covered
  , Encoding "STLRB_SL32_ldstord" 0xffe08000 0x08808000 Covered
  , Encoding "STLRH_SL32_ldstord" 0xffe08000 0x48808000 Covered
  , Encoding "STLUR_B_ldapstl_simd" 0xffa00c00 0x1d000800 Covered
  , Encoding "STLUR_H_ldapstl_simd" 0xffa00c00 0x5d000800 Covered
  , Encoding "STLUR_S_ldapstl_simd" 0xffa00c00 0x9d000800 Covered
  , Encoding "STLUR_D_ldapstl_simd" 0xffa00c00 0xdd000800 Covered
  , Encoding "STLUR_Q_ldapstl_simd" 0xffa00c00 0x1d800800 Covered
  , Encoding "STLUR_32_ldapstl_unscaled" 0x7fe00c00 0x19000000 Covered
  , Encoding "STLUR_64_ldapstl_unscaled" 0x7fe00c00 0x59000000 Covered
  , Encoding "STLURB_32_ldapstl_unscaled" 0xffe00c00 0x19000000 Covered
  , Encoding "STLURH_32_ldapstl_unscaled" 0xffe00c00 0x59000000 Covered
  , Encoding "STLXP_SP32_ldstexclp" 0xffe08000 0x88208000 Covered
  , Encoding "STLXP_SP64_ldstexclp" 0xffe08000 0xc8208000 Covered
  , Encoding "STLXR_SR32_ldstexclr" 0x7fe08000 0x08008000 Covered
  , Encoding "STLXR_SR64_ldstexclr" 0x7fe08000 0x48008000 Covered
  , Encoding "STLXRB_SR32_ldstexclr" 0xffe08000 0x08008000 Covered
  , Encoding "STLXRH_SR32_ldstexclr" 0xffe08000 0x48008000 Covered
  , Encoding "STNP_S_ldstnapair_offs" 0xffc00000 0x2c000000 Covered
  , Encoding "STNP_D_ldstnapair_offs" 0xffc00000 0x6c000000 Covered
  , Encoding "STNP_Q_ldstnapair_offs" 0xffc00000 0xac000000 Covered
  , Encoding "STNP_32_ldstnapair_offs" 0xbfc00000 0x28000000 Covered
  , Encoding "STNP_64_ldstnapair_offs" 0xbfc00000 0xa8000000 Covered
  , Encoding "STP_S_ldstpair_post" 0xffc00000 0x2c800000 Covered
  , Encoding "STP_D_ldstpair_post" 0xffc00000 0x6c800000 Covered
  , Encoding "STP_Q_ldstpair_post" 0xffc00000 0xac800000 Covered
  , Encoding "STP_S_ldstpair_pre" 0xffc00000 0x2d800000 Covered
  , Encoding "STP_D_ldstpair_pre" 0xffc00000 0x6d800000 Covered
  , Encoding "STP_Q_ldstpair_pre" 0xffc00000 0xad800000 Covered
  , Encoding "STP_S_ldstpair_off" 0xffc00000 0x2d000000 Covered
  , Encoding "STP_D_ldstpair_off" 0xffc00000 0x6d000000 Covered
  , Encoding "STP_Q_ldstpair_off" 0xffc00000 0xad000000 Covered
  , Encoding "STP_32_ldstpair_post" 0xbfc00000 0x28800000 Covered
  , Encoding "STP_64_ldstpair_post" 0xbfc00000 0xa8800000 Covered
  , Encoding "STP_32_ldstpair_pre" 0xbfc00000 0x29800000 Covered
  , Encoding "STP_64_ldstpair_pre" 0xbfc00000 0xa9800000 Covered
  , Encoding "STP_32_ldstpair_off" 0xbfc00000 0x29000000 Covered
  , Encoding "STP_64_ldstpair_off" 0xbfc00000 0xa9000000 Covered
  , Encoding "STR_B_ldst_immpost" 0xffa00c00 0x3c000400 Covered
  , Encoding "STR_H_ldst_immpost" 0xffa00c00 0x7c000400 Covered
  , Encoding "STR_S_ldst_immpost" 0xffa00c00 0xbc000400 Covered
  , Encoding "STR_D_ldst_immpost" 0xffa00c00 0xfc000400 Covered
  , Encoding "STR_Q_ldst_immpost" 0xffa00c00 0x3c800400 Covered
  , Encoding "STR_B_ldst_immpre" 0xffa00c00 0x3c000c00 Covered
  , Encoding "STR_H_ldst_immpre" 0xffa00c00 0x7c000c00 Covered
  , Encoding "STR_S_ldst_immpre" 0xffa00c00 0xbc000c00 Covered
  , Encoding "STR_D_ldst_immpre" 0xffa00c00 0xfc000c00 Covered
  , Encoding "STR_Q_ldst_immpre" 0xffa00c00 0x3c800c00 Covered
  , Encoding "STR_B_ldst_pos" 0xff800000 0x3d000000 Covered
  , Encoding "STR_H_ldst_pos" 0xff800000 0x7d000000 Covered
  , Encoding "STR_S_ldst_pos" 0xff800000 0xbd000000 Covered
  , Encoding "STR_D_ldst_pos" 0xff800000 0xfd000000 Covered
  , Encoding "STR_Q_ldst_pos" 0xff800000 0x3d800000 Covered
  , Encoding "STR_32_ldst_immpost" 0x7fe00c00 0x38000400 Covered
  , Encoding "STR_64_ldst_immpost" 0x7fe00c00 0x78000400 Covered
  , Encoding "STR_32_ldst_immpre" 0x7fe00c00 0x38000c00 Covered
  , Encoding "STR_64_ldst_immpre" 0x7fe00c00 0x78000c00 Covered
  , Encoding "STR_32_ldst_pos" 0x7fc00000 0x39000000 Covered
  , Encoding "STR_64_ldst_pos" 0x7fc00000 0x79000000 Covered
  , Encoding "STR_B_ldst_regoff" 0xffa00c00 0x3c200800 Covered
  , Encoding "STR_BL_ldst_regoff" 0xffa0ec00 0x3c206800 Covered
  , Encoding "STR_H_ldst_regoff" 0xffa00c00 0x7c200800 Covered
  , Encoding "STR_S_ldst_regoff" 0xffa00c00 0xbc200800 Covered
  , Encoding "STR_D_ldst_regoff" 0xffa00c00 0xfc200800 Covered
  , Encoding "STR_Q_ldst_regoff" 0xffa00c00 0x3ca00800 Covered
  , Encoding "STR_32_ldst_regoff" 0x7fe00c00 0x38200800 Covered
  , Encoding "STR_64_ldst_regoff" 0x7fe00c00 0x78200800 Covered
  , Encoding "STRB_32_ldst_immpost" 0xffe00c00 0x38000400 Covered
  , Encoding "STRB_32_ldst_immpre" 0xffe00c00 0x38000c00 Covered
  , Encoding "STRB_32_ldst_pos" 0xffc00000 0x39000000 Covered
  , Encoding "STRB_32B_ldst_regoff" 0xffe00c00 0x38200800 Covered
  , Encoding "STRB_32BL_ldst_regoff" 0xffe0ec00 0x38206800 Covered
  , Encoding "STRH_32_ldst_immpost" 0xffe00c00 0x78000400 Covered
  , Encoding "STRH_32_ldst_immpre" 0xffe00c00 0x78000c00 Covered
  , Encoding "STRH_32_ldst_pos" 0xffc00000 0x79000000 Covered
  , Encoding "STRH_32_ldst_regoff" 0xffe00c00 0x78200800 Covered
  , Encoding "STTR_32_ldst_unpriv" 0x7fe00c00 0x38000800 Covered
  , Encoding "STTR_64_ldst_unpriv" 0x7fe00c00 0x78000800 Covered
  , Encoding "STTRB_32_ldst_unpriv" 0xffe00c00 0x38000800 Covered
  , Encoding "STTRH_32_ldst_unpriv" 0xffe00c00 0x78000800 Covered
  , Encoding "STUR_B_ldst_unscaled" 0xffa00c00 0x3c000000 Covered
  , Encoding "STUR_H_ldst_unscaled" 0xffa00c00 0x7c000000 Covered
  , Encoding "STUR_S_ldst_unscaled" 0xffa00c00 0xbc000000 Covered
  , Encoding "STUR_D_ldst_unscaled" 0xffa00c00 0xfc000000 Covered
  , Encoding "STUR_Q_ldst_unscaled" 0xffa00c00 0x3c800000 Covered
  , Encoding "STUR_32_ldst_unscaled" 0x7fe00c00 0x38000000 Covered
  , Encoding "STUR_64_ldst_unscaled" 0x7fe00c00 0x78000000 Covered
  , Encoding "STURB_32_ldst_unscaled" 0xffe00c00 0x38000000 Covered
  , Encoding "STURH_32_ldst_unscaled" 0xffe00c00 0x78000000 Covered
  , Encoding "STXP_SP32_ldstexclp" 0xffe08000 0x88200000 Covered
  , Encoding "STXP_SP64_ldstexclp" 0xffe08000 0xc8200000 Covered
  , Encoding "STXR_SR32_ldstexclr" 0x7fe08000 0x08000000 Covered
  , Encoding "STXR_SR64_ldstexclr" 0x7fe08000 0x48000000 Covered
  , Encoding "STXRB_SR32_ldstexclr" 0xffe08000 0x08000000 Covered
  , Encoding "STXRH_SR32_ldstexclr" 0xffe08000 0x48000000 Covered
  , Encoding "STZ2G_64Spost_ldsttags" 0xffe00c00 0xd9e00400
      (Outside [(0, OpXSp)])
  , Encoding "STZ2G_64Spre_ldsttags" 0xffe00c00 0xd9e00c00
      (Outside [(0, OpXSp)])
  , Encoding "STZ2G_64Soffset_ldsttags" 0xffe00c00 0xd9e00800
      (Outside [(0, OpXSp)])
  , Encoding "STZG_64Spost_ldsttags" 0xffe00c00 0xd9600400
      (Outside [(0, OpXSp)])
  , Encoding "STZG_64Spre_ldsttags" 0xffe00c00 0xd9600c00
      (Outside [(0, OpXSp)])
  , Encoding "STZG_64Soffset_ldsttags" 0xffe00c00 0xd9600800
      (Outside [(0, OpXSp)])
  , Encoding "STZGM_64bulk_ldsttags" 0xfffffc00 0xd9200000 (Outside [(0, OpX)])
  , Encoding "SUB_32_addsub_ext" 0xffe00000 0x4b200000 Covered
  , Encoding "SUB_64_addsub_ext" 0xffe00000 0xcb200000 Covered
  , Encoding "SUB_32_addsub_imm" 0xff800000 0x51000000 Covered
  , Encoding "SUB_64_addsub_imm" 0xff800000 0xd1000000 Covered
  , Encoding "SUB_32_addsub_shift" 0xff200000 0x4b000000 Covered
  , Encoding "SUB_64_addsub_shift" 0xff200000 0xcb000000 Covered
  , Encoding "SUB_asisdsame_only" 0xff20fc00 0x7e208400 Covered
  , Encoding "SUB_asimdsame_only" 0xbf20fc00 0x2e208400 Covered
  , Encoding "SUBG_64_addsub_immtags" 0xffc00000 0xd1800000
      (Outside [(5, OpXSp)])
  , Encoding "SUBHN_asimddiff_N" 0xbf20fc00 0x0e206000 Covered
  , Encoding "SUBP_64S_dp_2src" 0xffe0fc00 0x9ac00000
      (Outside [(5, OpXSp), (16, OpXSp)])
  , Encoding "SUBPS_64S_dp_2src" 0xffe0fc00 0xbac00000
      (Outside [(5, OpXSp), (16, OpXSp)])
  , Encoding "SUBS_32S_addsub_ext" 0xffe00000 0x6b200000 Covered
  , Encoding "SUBS_64S_addsub_ext" 0xffe00000 0xeb200000 Covered
  , Encoding "SUBS_32S_addsub_imm" 0xff800000 0x71000000 Covered
  , Encoding "SUBS_64S_addsub_imm" 0xff800000 0xf1000000 Covered
  , Encoding "SUBS_32_addsub_shift" 0xff200000 0x6b000000 Covered
  , Encoding "SUBS_64_addsub_shift" 0xff200000 0xeb000000 Covered
  , Encoding "SUDOT_asimdelem_D" 0xbfc0f400 0x0f00f000
      (Outside [(0, OpV), (5, OpV)])
  , Encoding "SUQADD_asisdmisc_R" 0xff3ffc00 0x5e203800 (Outside [])
  , Encoding "SUQADD_asimdmisc_R" 0xbf3ffc00 0x0e203800 (Outside [(5, OpV)])
  , Encoding "SVC_EX_exception" 0xffe0001f 0xd4000001 Control
  , Encoding "SWP_32_memop" 0x7fe0fc00 0x38208000
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "SWPA_32_memop" 0x7fe0fc00 0x38a08000
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "SWPAL_32_memop" 0x7fe0fc00 0x38e08000
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "SWPL_32_memop" 0x7fe0fc00 0x38608000
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "SWP_64_memop" 0x7fe0fc00 0x78208000
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "SWPA_64_memop" 0x7fe0fc00 0x78a08000
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "SWPAL_64_memop" 0x7fe0fc00 0x78e08000
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "SWPL_64_memop" 0x7fe0fc00 0x78608000
      (Outside [(0, OpX), (16, OpX)])
  , Encoding "SWPAB_32_memop" 0xffe0fc00 0x38a08000
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "SWPALB_32_memop" 0xffe0fc00 0x38e08000
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "SWPB_32_memop" 0xffe0fc00 0x38208000
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "SWPLB_32_memop" 0xffe0fc00 0x38608000
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "SWPAH_32_memop" 0xffe0fc00 0x78a08000
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "SWPALH_32_memop" 0xffe0fc00 0x78e08000
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "SWPH_32_memop" 0xffe0fc00 0x78208000
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "SWPLH_32_memop" 0xffe0fc00 0x78608000
      (Outside [(0, OpW), (16, OpW)])
  , Encoding "SWPP_128_memop_128" 0xffe0fc00 0x19208000 Covered
  , Encoding "SWPPA_128_memop_128" 0xffe0fc00 0x19a08000 Covered
  , Encoding "SWPPAL_128_memop_128" 0xffe0fc00 0x19e08000 Covered
  , Encoding "SWPPL_128_memop_128" 0xffe0fc00 0x19608000 Covered
  , Encoding "SYS_CR_systeminstrs" 0xfff80000 0xd5080000 Control
  , Encoding "SYSL_RC_systeminstrs" 0xfff80000 0xd5280000 Control
  , Encoding "SYSP_CR_syspairinstrs" 0xfff80000 0xd5480000 Control
  , Encoding "TBL_asimdtbl_L2_2" 0xbfe0fc00 0x0e002000 Covered
  , Encoding "TBL_asimdtbl_L3_3" 0xbfe0fc00 0x0e004000 Covered
  , Encoding "TBL_asimdtbl_L4_4" 0xbfe0fc00 0x0e006000 Covered
  , Encoding "TBL_asimdtbl_L1_1" 0xbfe0fc00 0x0e000000 Covered
  , Encoding "TBNZ_only_testbranch" 0x7f000000 0x37000000 Control
  , Encoding "TBX_asimdtbl_L2_2" 0xbfe0fc00 0x0e003000 Covered
  , Encoding "TBX_asimdtbl_L3_3" 0xbfe0fc00 0x0e005000 Covered
  , Encoding "TBX_asimdtbl_L4_4" 0xbfe0fc00 0x0e007000 Covered
  , Encoding "TBX_asimdtbl_L1_1" 0xbfe0fc00 0x0e001000 Covered
  , Encoding "TBZ_only_testbranch" 0x7f000000 0x36000000 Control
  , Encoding "TCANCEL_EX_exception" 0xffe0001f 0xd4600000 Control
  , Encoding "TCOMMIT_only_barriers" 0xffffffff 0xd503307f Control
  , Encoding "TRN1_asimdperm_only" 0xbf20fc00 0x0e002800 Covered
  , Encoding "TRN2_asimdperm_only" 0xbf20fc00 0x0e006800 Covered
  , Encoding "TSB_HC_hints" 0xffffffff 0xd503225f Control
  , Encoding "TSTART_BR_systemresult" 0xffffffe0 0xd5233060 Control
  , Encoding "TTEST_BR_systemresult" 0xffffffe0 0xd5233160 Control
  , Encoding "UABA_asimdsame_only" 0xbf20fc00 0x2e207c00 Covered
  , Encoding "UABAL_asimddiff_L" 0xbf20fc00 0x2e205000 Covered
  , Encoding "UABD_asimdsame_only" 0xbf20fc00 0x2e207400 Covered
  , Encoding "UABDL_asimddiff_L" 0xbf20fc00 0x2e207000 Covered
  , Encoding "UADALP_asimdmisc_P" 0xbf3ffc00 0x2e206800 Covered
  , Encoding "UADDL_asimddiff_L" 0xbf20fc00 0x2e200000 Covered
  , Encoding "UADDLP_asimdmisc_P" 0xbf3ffc00 0x2e202800 Covered
  , Encoding "UADDLV_asimdall_only" 0xbf3ffc00 0x2e303800 Covered
  , Encoding "UADDW_asimddiff_W" 0xbf20fc00 0x2e201000 Covered
  , Encoding "UBFM_32M_bitfield" 0xffc00000 0x53000000 Covered
  , Encoding "UBFM_64M_bitfield" 0xffc00000 0xd3400000 Covered
  , Encoding "UCVTF_asisdshf_C" 0xff80fc00 0x7f00e400 (Outside [])
  , Encoding "UCVTF_asimdshf_C" 0xbf80fc00 0x2f00e400 (Outside [(5, OpV)])
  , Encoding "UCVTF_asisdmiscfp16_R" 0xfffffc00 0x7e79d800 (Outside [(5, OpH)])
  , Encoding "UCVTF_asisdmisc_R" 0xffbffc00 0x7e21d800 (Outside [])
  , Encoding "UCVTF_asimdmiscfp16_R" 0xbffffc00 0x2e79d800 (Outside [(5, OpV)])
  , Encoding "UCVTF_asimdmisc_R" 0xbfbffc00 0x2e21d800 (Outside [(5, OpV)])
  , Encoding "UCVTF_H32_float2fix" 0xffff0000 0x1ec30000 (Outside [(5, OpW)])
  , Encoding "UCVTF_S32_float2fix" 0xffff0000 0x1e030000 (Outside [(5, OpW)])
  , Encoding "UCVTF_D32_float2fix" 0xffff0000 0x1e430000 (Outside [(5, OpW)])
  , Encoding "UCVTF_H64_float2fix" 0xffff0000 0x9ec30000 (Outside [(5, OpX)])
  , Encoding "UCVTF_S64_float2fix" 0xffff0000 0x9e030000 (Outside [(5, OpX)])
  , Encoding "UCVTF_D64_float2fix" 0xffff0000 0x9e430000 (Outside [(5, OpX)])
  , Encoding "UCVTF_H32_float2int" 0xfffffc00 0x1ee30000 (Outside [(5, OpW)])
  , Encoding "UCVTF_S32_float2int" 0xfffffc00 0x1e230000 (Outside [(5, OpW)])
  , Encoding "UCVTF_D32_float2int" 0xfffffc00 0x1e630000 (Outside [(5, OpW)])
  , Encoding "UCVTF_H64_float2int" 0xfffffc00 0x9ee30000 (Outside [(5, OpX)])
  , Encoding "UCVTF_S64_float2int" 0xfffffc00 0x9e230000 (Outside [(5, OpX)])
  , Encoding "UCVTF_D64_float2int" 0xfffffc00 0x9e630000 (Outside [(5, OpX)])
  , Encoding "UDF_only_perm_undef" 0xffff0000 0x00000000 (Outside [])
  , Encoding "UDIV_32_dp_2src" 0xffe0fc00 0x1ac00800
      (Outside [(5, OpW), (16, OpW)])
  , Encoding "UDIV_64_dp_2src" 0xffe0fc00 0x9ac00800
      (Outside [(5, OpX), (16, OpX)])
  , Encoding "UDOT_asimdelem_D" 0xbf00f400 0x2f00e000
      (Outside [(0, OpV), (5, OpV)])
  , Encoding "UDOT_asimdsame2_D" 0xbf20fc00 0x2e009400
      (Outside [(0, OpV), (5, OpV), (16, OpV)])
  , Encoding "UHADD_asimdsame_only" 0xbf20fc00 0x2e200400 Covered
  , Encoding "UHSUB_asimdsame_only" 0xbf20fc00 0x2e202400 Covered
  , Encoding "UMADDL_64WA_dp_3src" 0xffe08000 0x9ba00000 Covered
  , Encoding "UMAX_asimdsame_only" 0xbf20fc00 0x2e206400 Covered
  , Encoding "UMAX_32U_minmax_imm" 0xfffc0000 0x11c40000 Covered
  , Encoding "UMAX_64U_minmax_imm" 0xfffc0000 0x91c40000 Covered
  , Encoding "UMAX_32_dp_2src" 0xffe0fc00 0x1ac06400 Covered
  , Encoding "UMAX_64_dp_2src" 0xffe0fc00 0x9ac06400 Covered
  , Encoding "UMAXP_asimdsame_only" 0xbf20fc00 0x2e20a400 Covered
  , Encoding "UMAXV_asimdall_only" 0xbf3ffc00 0x2e30a800 Covered
  , Encoding "UMIN_asimdsame_only" 0xbf20fc00 0x2e206c00 Covered
  , Encoding "UMIN_32U_minmax_imm" 0xfffc0000 0x11cc0000 Covered
  , Encoding "UMIN_64U_minmax_imm" 0xfffc0000 0x91cc0000 Covered
  , Encoding "UMIN_32_dp_2src" 0xffe0fc00 0x1ac06c00 Covered
  , Encoding "UMIN_64_dp_2src" 0xffe0fc00 0x9ac06c00 Covered
  , Encoding "UMINP_asimdsame_only" 0xbf20fc00 0x2e20ac00 Covered
  , Encoding "UMINV_asimdall_only" 0xbf3ffc00 0x2e31a800 Covered
  , Encoding "UMLAL_asimdelem_L" 0xbf00f400 0x2f002000 Covered
  , Encoding "UMLAL_asimddiff_L" 0xbf20fc00 0x2e208000 Covered
  , Encoding "UMLSL_asimdelem_L" 0xbf00f400 0x2f006000 Covered
  , Encoding "UMLSL_asimddiff_L" 0xbf20fc00 0x2e20a000 Covered
  , Encoding "UMMLA_asimdsame2_G" 0xffe0fc00 0x6e80a400
      (Outside [(0, OpV), (5, OpV), (16, OpV)])
  , Encoding "UMOV_asimdins_W_w" 0xffe0fc00 0x0e003c00 Covered
  , Encoding "UMOV_asimdins_X_x" 0xffeffc00 0x4e083c00 Covered
  , Encoding "UMSUBL_64WA_dp_3src" 0xffe08000 0x9ba08000 Covered
  , Encoding "UMULH_64_dp_3src" 0xffe08000 0x9bc00000 Covered
  , Encoding "UMULL_asimdelem_L" 0xbf00f400 0x2f00a000 Covered
  , Encoding "UMULL_asimddiff_L" 0xbf20fc00 0x2e20c000 Covered
  , Encoding "UQADD_asisdsame_only" 0xff20fc00 0x7e200c00 (Outside [])
  , Encoding "UQADD_asimdsame_only" 0xbf20fc00 0x2e200c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "UQRSHL_asisdsame_only" 0xff20fc00 0x7e205c00 (Outside [])
  , Encoding "UQRSHL_asimdsame_only" 0xbf20fc00 0x2e205c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "UQRSHRN_asisdshf_N" 0xff80fc00 0x7f009c00 (Outside [])
  , Encoding "UQRSHRN_asimdshf_N" 0xbf80fc00 0x2f009c00 (Outside [(5, OpV)])
  , Encoding "UQSHL_asisdshf_R" 0xff80fc00 0x7f007400 (Outside [])
  , Encoding "UQSHL_asimdshf_R" 0xbf80fc00 0x2f007400 (Outside [(5, OpV)])
  , Encoding "UQSHL_asisdsame_only" 0xff20fc00 0x7e204c00 (Outside [])
  , Encoding "UQSHL_asimdsame_only" 0xbf20fc00 0x2e204c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "UQSHRN_asisdshf_N" 0xff80fc00 0x7f009400 (Outside [])
  , Encoding "UQSHRN_asimdshf_N" 0xbf80fc00 0x2f009400 (Outside [(5, OpV)])
  , Encoding "UQSUB_asisdsame_only" 0xff20fc00 0x7e202c00 (Outside [])
  , Encoding "UQSUB_asimdsame_only" 0xbf20fc00 0x2e202c00
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "UQXTN_asisdmisc_N" 0xff3ffc00 0x7e214800 (Outside [])
  , Encoding "UQXTN_asimdmisc_N" 0xbf3ffc00 0x2e214800 (Outside [(5, OpV)])
  , Encoding "URECPE_asimdmisc_R" 0xbfbffc00 0x0ea1c800 (Outside [(5, OpV)])
  , Encoding "URHADD_asimdsame_only" 0xbf20fc00 0x2e201400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "URSHL_asisdsame_only" 0xff20fc00 0x7e205400 (Outside [])
  , Encoding "URSHL_asimdsame_only" 0xbf20fc00 0x2e205400
      (Outside [(5, OpV), (16, OpV)])
  , Encoding "URSHR_asisdshf_R" 0xff80fc00 0x7f002400 (Outside [])
  , Encoding "URSHR_asimdshf_R" 0xbf80fc00 0x2f002400 (Outside [(5, OpV)])
  , Encoding "URSQRTE_asimdmisc_R" 0xbfbffc00 0x2ea1c800 (Outside [(5, OpV)])
  , Encoding "URSRA_asisdshf_R" 0xff80fc00 0x7f003400 (Outside [])
  , Encoding "URSRA_asimdshf_R" 0xbf80fc00 0x2f003400 (Outside [(5, OpV)])
  , Encoding "USDOT_asimdelem_D" 0xbfc0f400 0x0f80f000
      (Outside [(0, OpV), (5, OpV)])
  , Encoding "USDOT_asimdsame2_D" 0xbfe0fc00 0x0e809c00
      (Outside [(0, OpV), (5, OpV), (16, OpV)])
  , Encoding "USHL_asisdsame_only" 0xff20fc00 0x7e204400 Covered
  , Encoding "USHL_asimdsame_only" 0xbf20fc00 0x2e204400 Covered
  , Encoding "USHLL_asimdshf_L" 0xbf80fc00 0x2f00a400 Covered
  , Encoding "USHR_asisdshf_R" 0xff80fc00 0x7f000400 Covered
  , Encoding "USHR_asimdshf_R" 0xbf80fc00 0x2f000400 Covered
  , Encoding "USMMLA_asimdsame2_G" 0xffe0fc00 0x4e80ac00
      (Outside [(0, OpV), (5, OpV), (16, OpV)])
  , Encoding "USQADD_asisdmisc_R" 0xff3ffc00 0x7e203800 (Outside [])
  , Encoding "USQADD_asimdmisc_R" 0xbf3ffc00 0x2e203800 (Outside [(5, OpV)])
  , Encoding "USRA_asisdshf_R" 0xff80fc00 0x7f001400 Covered
  , Encoding "USRA_asimdshf_R" 0xbf80fc00 0x2f001400 Covered
  , Encoding "USUBL_asimddiff_L" 0xbf20fc00 0x2e202000 Covered
  , Encoding "USUBW_asimddiff_W" 0xbf20fc00 0x2e203000 Covered
  , Encoding "UZP1_asimdperm_only" 0xbf20fc00 0x0e001800 Covered
  , Encoding "UZP2_asimdperm_only" 0xbf20fc00 0x0e005800 Covered
  , Encoding "WFE_HI_hints" 0xffffffff 0xd503205f Control
  , Encoding "WFET_only_systeminstrswithreg" 0xffffffe0 0xd5031000 Control
  , Encoding "WFI_HI_hints" 0xffffffff 0xd503207f Control
  , Encoding "WFIT_only_systeminstrswithreg" 0xffffffe0 0xd5031020 Control
  , Encoding "XAFLAG_M_pstate" 0xfffff0ff 0xd500403f Control
  , Encoding "XAR_VVV2_crypto3_imm6" 0xffe00000 0xce800000 Covered
  , Encoding "XPACD_64Z_dp_1src" 0xffffffe0 0xdac147e0 (Outside [])
  , Encoding "XPACI_64Z_dp_1src" 0xffffffe0 0xdac143e0 (Outside [])
  , Encoding "XPACLRI_HI_hints" 0xffffffff 0xd50320ff (Outside [])
  , Encoding "XTN_asimdmisc_N" 0xbf3ffc00 0x0e212800 Covered
  , Encoding "YIELD_HI_hints" 0xffffffff 0xd503203f Control
  , Encoding "ZIP1_asimdperm_only" 0xbf20fc00 0x0e003800 Covered
  , Encoding "ZIP2_asimdperm_only" 0xbf20fc00 0x0e007800 Covered
  ]
