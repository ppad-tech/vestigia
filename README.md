# vestigia

![](https://img.shields.io/badge/license-MIT-brightgreen)

A Haskell tool that finds where a program's execution depended on a
secret, by running it.

vestigia executes a harness, reports every instruction that branched
on the secret, computed an address from it, or divided by or into
it, and names each by function and source line.

A clean report is not a proof of constant-time execution. It
covers only the paths the harness drove, and the discipline
rather than the hardware: a leak through a prefetcher or a
variable-latency multiplier is for a timing instrument such as ppad's
[censor](https://github.com/ppad-tech/censor).

## Usage

### Marking the secret

A harness marks the secret before calling the code under audit, and
what the call is meant to reveal after it:

```c
#include "vestigia.h"

uint8_t ws[64];
fill_random_scalar(ws);
vestigia_secret(ws, 32);          /* the secret key */
penumbra_audit_public_key(ws);
vestigia_public(ws + 32, 32);     /* the public key it derives */
```

Compile `include/vestigia.c` beside it, or reach it through a foreign
function interface. Outside valgrind the marks are no-ops, so censor
can time the same harness. A run that marks nothing is refused.

### Taint: `vestigia run`

`run` executes the harness under valgrind's memcheck with the marked
bytes undefined, and reports every branch, address, and integer
division operand that descends from them (memcheck reports the last
through vestigia's patch, `nix/memcheck-operand.patch`):

```
$ vestigia run --out trace.json -- ./harness public_key 4
control  0x4875cd2  MontConfig::from_bigint      montgomery_backend.rs:359  x8
control  0x4875cf9  cmp<4>                       mod.rs:565  x4
...
control  0x4878d4d  next<&[u64]>                 bits.rs:32  x982
12 secret-dependent site(s) over 1 run(s); 0 unrelated; 0 fault(s)
```

memcheck sees only the path a run takes, so trace a harness on
several secrets: `run --dir DIR` keeps a run (memcheck's XML, where
the harness's objects loaded, its exit status), and `vestigia read
DIR...` reports on such runs as one, each site with the runs that
reached it. `read` takes a memcheck XML file made elsewhere too.
`--object TEXT` keeps the sites in objects whose path contains TEXT.

### Differential traces: `vestigia record` and `vestigia diff`

`record` runs the harness under QEMU with a plugin that summarises,
per instruction, how often it ran, where it branched, which addresses
it touched, and, for an integer division, which operands it divided.
Record several runs differing only in the secret, and `diff` reports
where they diverge:

```
$ for s in 1 2 3; do
>   vestigia record --dump run-$s -- ./harness public_key 2 $s
> done
$ vestigia record --dump control -- ./harness public_key 2 1
$ vestigia diff --object libpenumbra_audit --control control \
>   --out diff.json run-*
control  0xe9d6   Element::vartime_compress_to_field  sign.rs:11      ...
address  0x152c8  Fq::sqrt_ratio_zeta                 invsqrt.rs:113  ...
...
44 origin(s) over 3 run(s); 1383 instruction(s) downstream; 0 unsteady ...
```

An *origin* is a branch whose outcomes differ between runs, in
proportion or in order (`control`), an instruction whose addresses
differ (`address`), or a division, whose time depends on its
operands, on other operands (`operand`). Each names the runs that
behaved alike there. Instructions that
merely ran a different number of times are listed as downstream, as
are returns whose targets differ, which go where their calls sent
them; and every instruction some run executed is listed as coverage.

* `--control DUMP` repeats the first run's secret; whatever differs
  between the two is *unsteady* and kept out of the origins.
* `--designed DUMP` is a run whose secret was chosen to reach a
  particular path. It counts toward control origins and coverage,
  never toward address or operand origins.
* `--object TEXT` keeps the report to matching objects.

`record` disables address-space randomisation and seeds the guest's
entropy, `getrandom` included (`nix/qemu-getrandom.patch`), so runs
lay memory out alike. QEMU maps the guest wherever its own
allocations leave room, which under load can differ between runs, so
`record` keeps QEMU's allocations off the guest's mappings (one malloc
arena, large blocks from the heap), and `diff` refuses runs that
loaded an object at different addresses. A guest reading
`/dev/urandom` still reads the host's.

`record` appends to its dump how the run was made: the program and
its arguments, the size of the guest's environment, and the exit
status, which the report gives for each run. `diff` refuses a run of
another program, or with arguments of another number or length, or an
environment of another size, than the first run's, each of which lays
the guest's stack out apart; and a control that does not repeat the
first run's arguments.

### As derivations

The flake's `lib.<system>` holds `traceOf` and `diffOf`, which run
either instrument as a derivation over a list of runs; an
`x86_64-linux` run executes on any builder for that system, and its
report is cached. `diffOf` repeats the first run as its control.
`nix/lib.nix` holds the same for a consumer's own nixpkgs, beside
`version`.

```nix
vestigia.lib.x86_64-linux.diffOf {
  name = "penumbra-public_key";
  harness = "${harness}/bin/harness";
  runs = map (s: [ "public_key" "2" s ]) [ "1" "2" "3" ];
  objects = [ "libpenumbra_audit" ];
}
```

The output holds `trace.json` (`vestigia/trace-v2`) or `diff.json`
(`vestigia/diff-v3`), the runs kept or the plugin's dumps, what the
harness printed, and the wall time.

## Two instruments

memcheck propagates secrecy through data, not control: what a
program builds from public data on either arm of a secret branch
counts as public, so leaks downstream of it go unseen. Differential
traces see those, but only where the chosen secrets made execution
differ: a check that every valid secret passes looks alike in every
run. Run both; `etc/spike/*/RESULTS.md` compares them on Penumbra,
ppad-poly1305, and ppad-secp256k1.

## Caveats

* Coverage is the harness's. An early-exit tag comparison is
  invisible to random candidate tags, which all mismatch at the
  first byte.
* What a function is meant to reveal (a comparison's result, a
  public key) must be marked public, or it is reported.
* valgrind and QEMU's user mode run on Linux; elsewhere vestigia only
  reads their reports. `record` runs an x86_64 or aarch64 harness on
  either host, choosing QEMU by the program's ELF header, but
  memcheck needs a native host.
* The plugin records one guest thread: a guest that starts a second
  is stopped, and its dump refused. Runs compared by `diff` must
  differ only in the secret; it checks their arguments and
  environments, not what the harness reads beyond them.
* A GHC harness wants `-with-rtsopts=-xr1G -V0`, against the
  runtime's terabyte reservation and its interval timer.
* Source lines need line tables.

## Development

You'll require [Nix][nixos] with [flake][flake] support enabled.
Enter a development shell with `nix develop`, then `cabal build` and
`cabal test`. The spikes under `etc/spike` run on an `x86_64-linux`
builder:

```
$ nix build --impure -f etc/spike/penumbra traces
```

[nixos]: https://nixos.org/
[flake]: https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-flake.html
