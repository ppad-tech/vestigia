# Spike 1: Penumbra on x86_64-linux

Target: Penumbra's audit library (research/corpus/penumbra/harness),
the engagement's own build and the same build with line tables. The
harness calls each root on random secrets (`harness.c`). Ground
truth: elenchus's verdicts on the same roots (442 subjects; 79
leaks, 330 benign, 20 validation, 12 negligible, 1 unresolved; about
$32, then $16 more on the 887-subject x86 extension, unfinished).

## Cost

Every run is a derivation built on pollux.

- memcheck taint (`vestigia run`, four calls per root): about one
  second per root.
- Differential traces (`vestigia record` and `diff`, three
  processes of two calls each, differing only in the secrets): about
  two seconds per root.
- No model calls.

## What each instrument found

memcheck taint (12, 12, and 18 secret-dependent sites; none on an
address):

- `MontConfig::from_bigint` (montgomery_backend.rs:359) and the
  BigInt `cmp` / `ge` it reaches (mod.rs:565, 475): the modulus
  compares, in the secret's decoding and in `Fr::add` and `Fr::mul`
  when signing.
- `mul_projective`'s bit iterator (bits.rs:32, skip_while.rs:50):
  the double-and-add, about 245 secret-dependent iterations per
  scalar multiplication.
- `Fr::from_bytes_checked` (fr.rs:102): the secret's canonicality
  check.

Differential traces (44, 45, and 72 origins; about 1380
instructions downstream):

- The double-and-add (bits.rs:25, 32; skip_while.rs:50).
- The modulus compares inside every field operation on the point's
  coordinates: `Fq::mul`, `square`, `add`, `sub`, the projective
  `add_assign` and `double_in_place` (mod.rs:475, 565; group.rs:192;
  wrapper.rs).
- decaf377's `invsqrt` lookups (invsqrt.rs:113-152, through
  hashbrown's `get_inner`) as address origins.
- `vartime_compress_to_field` (sign.rs, mod.rs:702).
- `from_le_bytes_mod_order` and `Fr::add`.

## Against elenchus

elenchus's 79 leaks fall in thirteen functions: hashbrown
`get_inner` (17), projective `add_assign` (9), the encoding (9),
`double_in_place` (8), `from_bigint` (6), `Fr::add` (6), `Fr::mul`
(5), `Fq::mul` (5), `Fq::square` (4), `from_le_bytes_mod_order`
(3 + 3), `mul_projective` (2), `sqrt_ratio` (2). Each has a
vestigia site in the same function, with its source line; the
union of the two instruments covers all of them.

## What the two instruments are

- memcheck propagates secrecy through data, not control. After the
  double-and-add branches on secret bits, the point it builds from
  public multiples is defined, so nothing downstream of it is
  flagged: the field operations' compares and the `invsqrt` lookups
  go unseen. The first secret-dependent branch masks the leaks
  after it.
- Differential traces see what control flow does to data, but only
  what the chosen secrets vary: the canonicality check takes the
  same direction for every valid secret, so no two runs differ
  there, though its condition reads the secret.
- An origin is a branch whose outcomes differ in proportion between
  runs (a loop whose trip count the secret sets is one) or an
  instruction run equally often whose addresses differ. A
  count-only rule missed the double-and-add, whose loop runs a
  different number of times.

## Caveats

- The line-table build is not byte-identical to the audited one:
  the debug setting enters the crate's metadata hash, renaming
  symbols and shifting inlining in 16 of 546 functions. Both builds
  give the same findings by function; source lines come from the
  line-table build. The audited artifact should itself carry line
  tables.
- x86_64 only. QEMU runs aarch64 code on pollux too, for the
  differential traces; memcheck needs a native aarch64-linux host.
