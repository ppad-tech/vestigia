# Spike 3: ppad-secp256k1 on x86_64-linux

Target: ppad-secp256k1 0.5.8 (fdb80d5), GHC 9.10.3 with LLVM, as
released and with the elenchus vector's mutants: S1 a direct,
secret-indexed window load in `mul_wnaf#`; S2 a branch on each
ladder scalar bit (GHC's compilation of a Bool-to-choice helper on
aarch64); S3 a zero-byte shortcut on the key in Schnorr's xor. The
harness derives a public key, signs (Schnorr and ECDSA, with and
without a precomputed context), and runs ECDH, under fresh secret
keys and auxiliary randomness.

## Cost

About 3.8 seconds per memcheck trace (two keys, every root) and
3.1 seconds per three-run diff, on pollux.

## Findings

- release: no differential origin in the harness binary. memcheck
  reports 17 sites, each a validation or declassification the
  vector labels as such: scalar range and result checks in `mul`,
  `mul_wnaf`, and the signers, `even_y_vartime` on points that
  become public, ECDH's `z == 0` result, and the harness's own case
  analysis of Maybe results.
- mutants:
  - S1: 24 address sites in `mul_wnaf`, by both instruments.
  - S2 and S3: absent, and rightly. `mul` has ten conditional
    jumps in both builds (the bit test compiled branch-free), and
    the Schnorr signer has fewer in the mutant than in release (185
    against 192: LLVM folded `if x == 0 then y else x ^ y` into the
    XOR it equals). Their leaks are in aarch64's machine code, where
    the vector was labelled, not x86's.

## What this says

vestigia judges the machine code built, as the audit must:
compiler-level leaks are per ISA. Seeing S2 and S3 needs aarch64
traces. QEMU runs aarch64 code on pollux, so differential traces
need only an aarch64-linux build of the harness; memcheck needs a
native aarch64-linux host.
