# vestigia

![](https://img.shields.io/badge/license-MIT-brightgreen)

A Haskell tool that finds where a program's execution depended on a
secret, by running it.

Constant-time code is held to a discipline: no branch, memory
address, or variable-latency operand may depend on a secret. Whether
a program keeps it is a fact about its *leakage trace* (the
instructions it executes and the addresses it touches), and a
running program has that trace in full: concrete values, concrete
addresses, the path actually taken. vestigia reads it off the
execution of a harness, reports every instruction that branched on
the secret or computed an address from it, and names each by its
function and source line. It is exact on the paths executed, needs
no timing statistics, and judges the machine code as built, so a
branch the compiler introduced is found and one it removed is not.

A clean report is not a proof of constant-time execution. It covers
the paths the harness drove the program down, under the inputs it
chose, and the discipline rather than the hardware: a leak through a
data-dependent prefetcher or a variable-latency multiplier is for a
timing instrument such as ppad's censor to find.

## Usage

### Marking the secret

A harness calls the code under audit, marks the secret's bytes
before the call, and marks what the call is meant to reveal (a
signature, a public key) after it:

```c
#include "vestigia.h"

uint8_t ws[64];
fill_random_scalar(ws);
vestigia_secret(ws, 32);          /* the secret key */
penumbra_audit_public_key(ws);
vestigia_public(ws + 32, 32);     /* the public key it derives */
```

The harness compiles `include/vestigia.c` beside it, which defines
the marks; a harness that reaches them through a foreign function
interface (a Haskell `foreign import ccall`) compiles the same file.
Outside valgrind the marks are no-ops, so the same harness can be
timed by censor unchanged. On Linux the first secret mark of any
bytes also writes where the loader put each object, for `vestigia
run` to name every site by its object and its address in it. A run
that marked nothing found nothing because nothing was secret, and
`run` refuses it.

### Taint: `vestigia run`

`run` executes the harness under valgrind's memcheck with the marked
bytes made undefined. memcheck tracks definedness bit by bit, so
every branch whose condition, and every load or store whose address,
descends from a marked byte is reported, with the mark as its
origin; everything else memcheck says is kept apart. Penumbra's
public-key derivation, on x86-64 (function names shortened):

```
$ vestigia run --out trace.json -- ./harness public_key 4
control  0x4875cd2  MontConfig::from_bigint      montgomery_backend.rs:359  x8
control  0x4875cf9  cmp<4>                       mod.rs:565  x4
control  0x4875d42  ge<BigInt<4>, BigInt<4>>     mod.rs:475  x4
...
control  0x486ffbd  Fr::from_bytes_checked       fr.rs:102  x4
control  0x4878d7a  without_leading_zeros        skip_while.rs:50  x42
control  0x4878d4d  next<&[u64]>                 bits.rs:32  x982
12 secret-dependent site(s); 0 unrelated; 0 fault(s)
```

Here the modulus compares in decoding the secret scalar, its
canonicality check, and the double-and-add of the scalar
multiplication, which iterates about 245 times per call on the
secret's bits. `vestigia read FILE.xml` gives the same report from a
memcheck run made elsewhere. `--object TEXT` keeps the sites in
objects whose path contains the given text, as it keeps a
differential run's origins.

### Differential traces: `vestigia record` and `vestigia diff`

`record` runs the harness under QEMU with vestigia's plugin, which
summarises the leakage trace per instruction: how often it ran, how
often it transferred to each target, and a fingerprint of the
addresses it touched. Run the harness several times, differing only
in the secret, and `diff` reports where the runs diverge:

```
$ for s in 1 2 3; do
>   vestigia record --dump run-$s -- ./harness public_key 2 $s
> done
$ vestigia record --dump control -- ./harness public_key 2 1
$ vestigia diff --object libpenumbra_audit --control control \
>   --out diff.json run-*
control  0xe9d6   Element::vartime_compress_to_field  sign.rs:11      ...
address  0x152c8  Fq::sqrt_ratio_zeta                 invsqrt.rs:113  ...
address  0x152eb  Fq::sqrt_ratio_zeta                 invsqrt.rs:117  ...
...
44 origin(s) over 3 run(s); 1383 instruction(s) downstream; 0 unsteady ...
```

An *origin* is a branch whose outcomes differ in proportion between
runs (a loop whose trip count the secret sets is one), a branch
taking the same outcomes as often in another order, or an
instruction run equally often whose addresses differ. Each origin
names the runs that behaved alike there, grouped, and the runs that
never reached it, each run by its dump's file name: which secrets
the execution told apart. Instructions that merely ran a different
number of times sit where control had already diverged, and are
listed per object as downstream. The report also lists, per
object, the offset of every instruction some run executed: what the
chosen secrets exercised, to set against what the code could
execute. `--object` keeps origins, what ran downstream, and what
was executed, to objects whose path contains the given text.

`--designed DUMP` names a run aimed at a particular path: the same
harness with the same arguments, differing from the others only in a
secret chosen to reach that path. A run whose public inputs differ
is not designed but another experiment, and its differences say
nothing about the secret. A designed run counts toward the control
origins (a branch whose outcomes shift under it chose by the
secret) and what was executed, never toward the address origins:
it goes where the others do not, so an instruction's addresses
differing in it need not mean an address computed from the secret.

A difference means the secret only if nothing else differs between
runs. `record` turns address-space randomisation off for itself and
QEMU, refusing to run where it cannot, and seeds the guest's
entropy, so runs lay memory out alike and a hash table seeded from
the system's randomness is laid out alike too. The pinned QEMU
fills the guest's `getrandom` from that seeded generator, the host
still checking its flags and choosing its length
(`nix/qemu-getrandom.patch`); a guest reading `/dev/urandom` still
reads the host's. `--control DUMP` names a run repeating the first run's
secret: whatever differs between the two (a clock read, a
scheduler's choice) is *unsteady*, counted and kept out of the
origins.

### As derivations

The flake's `lib.<system>` holds `traceOf` and `diffOf`, which run a
harness under either instrument as a derivation: a run for
`x86_64-linux` then executes on whatever builds for that system, and
its report is cached like any other output. Either takes `objects`,
the texts `--object` is given. `diffOf` repeats the first run as its
control. `nix/lib.nix` holds the same definitions for one package
set, for a consumer that pins vestigia and builds traces with its own
nixpkgs, beside `version`, the version the command reports.

```nix
vestigia.lib.x86_64-linux.diffOf {
  name = "penumbra-public_key";
  harness = "${harness}/bin/harness";
  runs = map (s: [ "public_key" "2" s ]) [ "1" "2" "3" ];
  objects = [ "libpenumbra_audit" ];
}
```

Each run's report is `trace.json` (`vestigia/trace-v1`) or
`diff.json` (`vestigia/diff-v2`), beside the raw memcheck XML or
plugin dumps, what the harness printed, and the run's wall time.

## Two instruments

Each sees what the other cannot:

* memcheck propagates secrecy through data, not control. Once a
  program branches on a secret, what it builds from public data on
  either arm is defined, so the leaks downstream of the first
  secret-dependent branch go unseen. On Penumbra it found the
  double-and-add but not the field operations on the point it
  builds, nor decaf377's table lookups on that point.
* Differential traces see what control does to data, since a value
  chosen by a secret branch differs between runs. But they see only
  what the chosen secrets actually varied: a validity check that
  every valid secret passes takes the same direction in every run,
  though its condition reads the secret.

Run both. On Penumbra their union covers every function in which
elenchus found a leak; see `etc/spike/*/RESULTS.md` for Penumbra,
ppad-poly1305's planted mutants, and ppad-secp256k1.

## Caveats

Coverage is the harness's. Only the paths its inputs drive are
traced, and a differential trace sees a leak only where its secrets
make the execution differ: an early-exit tag comparison is invisible
to random candidate tags, which all mismatch at the first byte, and
plain to candidates sharing a prefix with the true tag.

What a function is meant to reveal must be marked public, or it is
reported: a comparison's result, a validity check, a public key
before it is serialised. Telling those from leaks is a reading of
the code, not a measurement.

valgrind and QEMU's user mode run on Linux; elsewhere vestigia only
reads reports made there. The differential traces run any ISA QEMU
emulates, so an aarch64 build is traced on an x86-64 host, but
memcheck needs a native one. The plugin assumes a single-threaded
guest, and runs compared by `diff` must differ in nothing but the
secret, including the length of their arguments.

A GHC harness wants `-with-rtsopts=-xr1G -V0`: the runtime's default
terabyte address-space reservation makes memcheck crawl, and its
interval timer makes runs schedule differently.

Source lines need line tables in the code under audit, and sites are
named on the assumption that an object's executable file offsets are
its virtual addresses, as GNU ld and lld emit them.

## Development

You'll require [Nix][nixos] with [flake][flake] support enabled.
Enter a development shell with:

```
$ nix develop
```

Then do e.g.:

```
$ cabal build
$ cabal test
```

The spikes under `etc/spike` build their targets and run on an
`x86_64-linux` builder:

```
$ nix build --impure -f etc/spike/penumbra traces
```

[nixos]: https://nixos.org/
[flake]: https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-flake.html
