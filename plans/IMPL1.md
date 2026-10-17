# IMPL1: vestigia, the leakage trace in act

## End

Decide, for an execution of an audited function, which of its
instructions branched on a secret or computed an address from one,
and say where each sits in the source. This is the constant-time
discipline read off a running program: exact on the paths executed,
free of timing noise, and localised to the instruction. (synthesis
`plans/REDESIGN.md` gives the reasons.)

## Means

valgrind's memcheck already tracks, bit by bit, which values are
defined. A harness marks the secret's bytes undefined before calling
the function (`VALGRIND_MAKE_MEM_UNDEFINED`, a no-op outside
valgrind) and marks its outputs defined after. memcheck then reports
every conditional branch whose condition, and every load or store
whose address, depends on a marked byte, and `--track-origins` names
the client request as the origin. This is the ctgrind technique.

vestigia supplies:

- `include/vestigia.h`: `vestigia_secret` and `vestigia_public`, the
  two marks, for harness writers.
- `vestigia run -- PROGRAM ARGS`: runs the harness under memcheck
  with fixed settings and writes a report.
- `vestigia read FILE.xml`: the same report from memcheck's XML.
- The report (`vestigia/trace-v1`, JSON): secret-dependent sites,
  one per instruction and class (`control`, `address`, `syscall`),
  with function, file, line, count, and caller stacks; errors whose
  origin is not a secret, kept apart; and the run's provenance.
- A nix function that runs a harness as a derivation, so a trace
  for x86_64-linux runs on whatever builds for it.

## Spikes

The tool earns its place only if it reproduces known results:

1. Penumbra on x86_64-linux: the audit library rebuilt with line
   tables (its `.text` checked identical to the audited build), a C
   harness calling the three roots on random secrets. Do the
   findings cover elenchus's leaks (ark-ff modulus compares,
   decaf377 invsqrt table lookups, the double-and-add)?
2. ppad-poly1305 with the planted mutants, and ppad-secp256k1 as a
   constant-time control: are the planted leaks found, and does
   the GHC runtime stay quiet once origins are filtered?

## Constraints

- Haskell2010, boot libraries only (base, bytestring, containers,
  text, process, directory, filepath); tasty for tests.
- memcheck XML is parsed by a small reader of our own; JSON is
  written by a small encoder of our own.
- valgrind enters through nix as a tool. It does not run on Darwin;
  traces there need a Linux cell.
