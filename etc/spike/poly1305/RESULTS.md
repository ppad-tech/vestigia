# Spike 2: ppad-poly1305 on x86_64-linux

Target: ppad-poly1305 0.4.6 (173e478), GHC 9.10.3 with LLVM, as
released and with each of the elenchus vectors' mutant sets
(`mutants-1.patch`, `mutants-2.patch`). The harness MACs ten public
messages (empty, short final chunks, exact blocks) under fresh
secret keys and compares each tag with a public candidate. Sites
are named by the harness binary's symbols (no line tables).

## Cost

About 1.6 seconds per memcheck trace (four keys) and 1.9 seconds
per three-run diff, on pollux.

## Findings

- release: one memcheck site, the harness's branch on the result of
  `(==)` (whether the tag matched: public by intent). Nothing in
  the library; no differential origin in the harness binary.
- mutants-1:
  - L3, the key-indexed nibble table in clamp: an address site in
    `$wmac_slow`, x144 (four key bytes, nine non-empty messages,
    four keys); also a differential address origin.
  - L1, the variable-time compare in `reduce_full`: control sites
    in `$wmac`.
  - L2, the early-exit tag compare: one site where release has its
    result branch. memcheck alone cannot tell the two apart; the
    explain step must. The differential traces cannot see L2 at
    all with random candidates, which mismatch at byte 0 every
    time: it needs a designed input (a candidate sharing a prefix
    with the true tag).
  - D1 and D2, the decoys on the public message: not flagged.
- mutants-2:
  - X2, the skip-multiply branch: control sites in `$wmac`.
  - `(==)` without its barrier: stayed constant time, as on
    aarch64 (the same result branch as release).

## Lessons for GHC harnesses

- The runtime's default terabyte address-space reservation makes
  memcheck crawl (ten seconds for a trivial program, apparent hangs
  for real ones). `-with-rtsopts=-xr1G` fixes it.
- `-V0` (no interval timer) keeps the scheduler deterministic for
  differential runs.
- Address-space randomisation made identical runs differ at 2183
  places; `vestigia record` now turns it off for itself and QEMU.
- A seed passed as an argument is decoded by libc, which shows as
  origins in libc; differential origins are filtered to the
  harness binary, which holds the whole Haskell program.
