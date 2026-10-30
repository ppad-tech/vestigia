# vestigia for one system: the command (with the valgrind, QEMU,
# plugin, and addr2line it runs baked in where they exist), the QEMU
# plugin, the harness-side headers, and the functions that run a
# harness under either instrument as a derivation.
#
# The flake applies it per system; a consumer pinning vestigia (as
# synthesis does) imports it with its own package set, so a trace is
# built by the same definitions wherever it is built.
{ pkgs, src ? ../. }:

let
  lib = pkgs.lib;

  hpkgs = pkgs.haskell.packages.ghc910.extend (new: old: {
    vestigia = new.callCabal2nix "vestigia" src { };
  });

  # memcheck runs on Linux only; elsewhere the command can still
  # read a run's XML. It reports an integer division's undefined
  # operands (memcheck-operand.patch)
  linux = pkgs.stdenv.hostPlatform.isLinux;
  valgrind = pkgs.valgrind.overrideAttrs (o: {
    patches = (o.patches or [ ]) ++ [ ./memcheck-operand.patch ];
  });

  # the QEMU plugin recording a run's leakage trace per
  # instruction, and the QEMU that runs a harness under it, for
  # either ISA, whatever the host's: user mode alone, its guest's
  # getrandom drawn from the generator -seed fixes
  # (qemu-getrandom.patch), and an Arm CPU without the cryptographic
  # extension to be had (crypto=off, qemu-crypto.patch)
  qemu = (pkgs.qemu.override {
    userOnly = true;
    hostCpuTargets = [ "x86_64-linux-user" "aarch64-linux-user" ];
  }).overrideAttrs (o: {
    patches = (o.patches or [ ]) ++ [
      ./qemu-getrandom.patch
      ./qemu-crypto.patch
    ];
  });
  plugin = pkgs.runCommandCC "vestigia-qemu-plugin" {
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.glib ];
  } ''
    mkdir -p $out/lib
    cc -O2 -shared -fPIC -Wall -Werror \
      $(pkg-config --cflags glib-2.0) -I${qemu}/include \
      -o $out/lib/libvestigia-qemu.so ${src}/plugin/vestigia-qemu.c
  '';
  # the harness-side header; a harness build also needs
  # valgrind's own (valgrindDev)
  include = pkgs.runCommand "vestigia-include" { } ''
    mkdir -p $out/include
    cp ${src}/include/vestigia.h $out/include/vestigia.h
    cp ${src}/include/vestigia.c $out/include/vestigia.c
  '';

  # the command, with the valgrind it was built against baked in,
  # and LLVM's addr2line, which reads either ISA's objects and names
  # inlined frames by their own functions (Vestigia.Symbol)
  vestigia = pkgs.runCommand "vestigia" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    mkdir -p $out/bin
    makeWrapper ${hpkgs.vestigia}/bin/vestigia $out/bin/vestigia \
      ${lib.optionalString linux (lib.concatStringsSep " " [
        "--set-default VESTIGIA_VALGRIND ${valgrind}/bin/valgrind"
        "--set-default VESTIGIA_QEMU_X86_64 ${qemu}/bin/qemu-x86_64"
        "--set-default VESTIGIA_QEMU_AARCH64 ${qemu}/bin/qemu-aarch64"
        "--set-default VESTIGIA_PLUGIN"
        "${plugin}/lib/libvestigia-qemu.so"
        "--set-default VESTIGIA_ADDR2LINE"
        "${pkgs.llvm}/bin/llvm-addr2line"
        "--set-default VESTIGIA_OBJDUMP"
        "${pkgs.llvm}/bin/llvm-objdump"
      ])}
    ln -s ${include}/include $out/include
  '';

  # runs of one harness under memcheck, as a derivation: each run
  # kept (run-K: memcheck's XML, the objects its harness reported,
  # its exit status, its own report), what each printed, and the
  # report over all of them. `runs` is a list of argument lists, the
  # secrets of the trace; memcheck sees only the path a run takes, so
  # each run adds the sites on its own. `objects` keeps sites in
  # objects whose path contains one of them. A harness that fails
  # still leaves a report of what ran; a run vestigia could not read
  # fails the build.
  traceOf = { name, harness, runs, objects ? [ ] }:
    pkgs.runCommand "vestigia-trace-${name}" { } ''
      mkdir -p $out
      start=$(date +%s%N)
      ${lib.concatImapStrings (k: args: ''
        set +e
        ${vestigia}/bin/vestigia run --dir $out/run-${toString k} \
          --out $out/run-${toString k}/trace.json \
          -- ${harness} ${lib.escapeShellArgs args} \
          > $out/stdout-${toString k} 2> $out/stderr-${toString k}
        echo $? > $out/status-${toString k}
        set -e
      '') runs}
      ${vestigia}/bin/vestigia read --out $out/trace.json \
        ${lib.concatMapStrings (o: "--object ${lib.escapeShellArg o} ")
          objects}${lib.concatImapStrings (k: _:
          "$out/run-${toString k} ") runs} 2> $out/summary || {
        cat $out/summary >&2
        exit 1
      }
      echo $(( ($(date +%s%N) - start) / 1000000 )) > $out/milliseconds
    '';

  # runs of one harness that differ only in a secret, each
  # recorded under QEMU, and where they diverge: the dumps, and
  # the report. `runs` is a list of argument lists; `objects`
  # keeps origins in objects whose path contains one of them. The
  # first run is repeated as a control, so that what differs
  # without the secret is set aside rather than taken for it.
  # `designed` runs, aimed at particular paths, are compared beside
  # them for control and coverage but not for addresses (vestigia
  # diff --designed). Under a `contract` (arm-dit or intel-doitm, the
  # harness's ISA's), every run also fingerprints the operands of the
  # instructions outside it in `objects`, listed once (vestigia watch,
  # kept as `watch`) for every run to read (record --watch). On a
  # `cpu`, every run is recorded with QEMU emulating that model (its
  # -cpu, properties and all), so that a harness choosing its code by
  # the CPU's features runs the code that model leads it to.
  # A run's own failure leaves its status; a dump vestigia cannot read
  # fails the build.
  diffOf = { name, harness, runs, objects ? [ ], designed ? [ ]
           , contract ? null, cpu ? null }:
    let
      model = lib.optionalString (cpu != null)
        "--cpu ${lib.escapeShellArg cpu} ";
      watch = lib.optionalString (contract != null)
        "--contract ${lib.escapeShellArg contract} --watch $out/watch ";
    in
    pkgs.runCommand "vestigia-diff-${name}" { } ''
      mkdir -p $out
      start=$(date +%s%N)
      ${lib.optionalString (contract != null) ''
        ${vestigia}/bin/vestigia watch --out $out/watch ${model}\
          --contract ${lib.escapeShellArg contract} \
          ${lib.concatMapStrings (o: "--object ${lib.escapeShellArg o} ")
              objects}-- ${harness} \
          ${lib.escapeShellArgs (builtins.head runs)}
      ''}
      ${lib.concatImapStrings (k: args: ''
        set +e
        ${vestigia}/bin/vestigia record --dump $out/dump-${toString k} \
          ${model}${watch}-- ${harness} ${lib.escapeShellArgs args} \
          > $out/stdout-${toString k} 2> $out/stderr-${toString k}
        echo $? > $out/status-${toString k}
        set -e
      '') runs}${lib.concatImapStrings (k: args: ''
        set +e
        ${vestigia}/bin/vestigia record \
          --dump $out/designed-${toString k} \
          ${model}${watch}-- ${harness} ${lib.escapeShellArgs args} \
          > $out/stdout-designed-${toString k} \
          2> $out/stderr-designed-${toString k}
        echo $? > $out/status-designed-${toString k}
        set -e
      '') designed}
      set +e
      ${vestigia}/bin/vestigia record --dump $out/control-1 \
        ${model}${watch}-- ${harness} \
        ${lib.escapeShellArgs (builtins.head runs)} \
        > $out/stdout-control-1 2> $out/stderr-control-1
      echo $? > $out/status-control-1
      set -e
      ${vestigia}/bin/vestigia diff --out $out/diff.json \
        ${lib.concatMapStrings (o: "--object ${lib.escapeShellArg o} ")
          objects}${lib.concatImapStrings (k: _:
          "--designed $out/designed-${toString k} ") designed} \
        --control $out/control-1 \
        ${lib.concatImapStrings (k: _: "$out/dump-${toString k} ")
          runs}2> $out/summary
      echo $(( ($(date +%s%N) - start) / 1000000 )) > $out/milliseconds
    '';
  # the version the cabal file declares, which the command reports
  version = builtins.head (builtins.match ".*\nversion: *([0-9.]+).*"
    (builtins.readFile (src + "/vestigia.cabal")));
in
{
  inherit hpkgs vestigia plugin include traceOf diffOf version;
  valgrindDev = valgrind.dev;
}
