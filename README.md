# vestigia

![](https://img.shields.io/badge/license-MIT-brightgreen)
[![](https://img.shields.io/badge/haddock-vestigia-lightblue)](https://docs.ppad.tech/vestigia)

Finds where a program's execution depended on a secret, by running
it.

vestigia runs a harness and reports every instruction that branched
on the secret, computed an address from it, or divided by or into it,
naming each by function and source line. It has two instruments:
taint tracking under valgrind's memcheck, and differential traces
under QEMU.

A clean report is not a proof of constant-time execution. It covers
only the paths the harness drove, and the program rather than the
hardware: a leak through a prefetcher or a variable-latency
multiplier is for a timing instrument such as
[censor](https://github.com/ppad-tech/censor).

## Marking the secret

A harness marks the secret before the call under audit, and what the
call is meant to reveal after it:

```c
#include "vestigia.h"

vestigia_secret(key, 32);
derive_public_key(pub, key);
vestigia_public(pub, 33);
```

Compile `include/vestigia.c` beside it, or call it through an FFI.
Outside valgrind the marks are no-ops. A run that marks nothing is
refused.

## Taint: `run` and `read`

`run` executes the harness under memcheck with the secret's bytes
undefined, and reports each branch, address, and division operand
derived from them:

```
$ vestigia run --out trace.json -- ./harness
control  0x40011a2  branchy  harness.c:26  x8
address  0x400134b  lookup   harness.c:31  x1
...
3 secret-dependent site(s) over 1 run(s); 0 unrelated; 0 fault(s)
```

memcheck sees only the path a run takes, so trace several secrets:
`run --dir DIR` keeps a run, and `read DIR...` reports on several as
one. `read` also accepts memcheck XML made elsewhere.

## Differential: `record` and `diff`

`record` runs the harness under QEMU with a plugin that summarises
each instruction's execution: counts, branch outcomes, addresses
touched, and division operands. `diff` compares runs that differ only
in the secret and reports where they diverge:

```
$ for s in 1 2 3; do
>   vestigia record --dump run-$s -- ./harness $s
> done
$ vestigia record --dump control -- ./harness 1
$ vestigia diff --control control --out diff.json run-*
control  0x11a2  branchy  harness.c:26  ...
address  0x134b  lookup   harness.c:31  ...
...
```

An *origin* is a branch whose outcomes differ between runs
(`control`), an instruction whose addresses differ (`address`), or a
division on differing operands (`operand`). Each lists the runs that
agreed there and its callers. Instructions that merely ran a
different number of times are reported as downstream.

* `--control DUMP` repeats the first run's secret; what differs
  between the two is *unsteady* and excluded from the origins.
* `--designed DUMP` is a run whose secret was chosen to reach a
  particular path; it never counts toward address or operand
  origins.
* `--object TEXT` restricts the report to matching objects (also for
  `run` and `read`).

`record` disables address-space randomisation and seeds the guest's
entropy so that runs lay memory out alike. `diff` refuses runs whose
program, argument shape, environment size, or object layout differ.

### Contracts

`record --contract arm-dit` (or `intel-doitm`) additionally
fingerprints the operands of every instruction outside that ISA's
data-independent-timing contract, in objects matching `--object`.
`diff` reports any such instruction seen on differing operands under
`outside`, apart from the origins. `vestigia watch` computes the list
of such instructions once, for `record --watch FILE` to reuse.

## Nix

The flake's `lib.<system>` provides `traceOf` and `diffOf`, which run
either instrument as a derivation over a list of runs:

```nix
vestigia.lib.x86_64-linux.diffOf {
  name = "example";
  harness = "${harness}/bin/harness";
  runs = map (s: [ s ]) [ "1" "2" "3" ];
  objects = [ "libexample" ];
}
```

`nix/lib.nix` provides the same for a consumer's own nixpkgs.

## Caveats

* Coverage is the harness's. A path no chosen secret reaches is
  unseen.
* Outputs the call is meant to reveal must be marked public, or they
  are reported.
* memcheck propagates secrecy through data, not control; differential
  traces see only where the chosen secrets made execution differ.
  Use both.
* valgrind and QEMU user mode run on Linux only. `record` runs x86_64
  or aarch64 harnesses on either host; memcheck needs a native one.
* `record` stops a guest that starts a second thread.
* A guest reading `/dev/urandom` reads the host's.
* An address origin may be a layout moved by an earlier secret
  branch, rather than an address computed from the secret.
* A contract is the ISA's statement, not a given core's.
* GHC harnesses want `-with-rtsopts=-xr1G -V0`. GHC's calls and
  returns are jumps, so its origins have no callers.
* Source lines need line tables.

## Development

You'll require [Nix][nixos] with [flake][flake] support enabled.
Enter a development shell with `nix develop`, then `cabal build` and
`cabal test`. The probe check runs both instruments over
`etc/probe/harness.c` on an `x86_64-linux` builder:

```
$ nix build .#checks.x86_64-linux.probe
```

[nixos]: https://nixos.org/
[flake]: https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-flake.html
