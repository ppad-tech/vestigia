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
  # read a run's XML
  linux = pkgs.stdenv.hostPlatform.isLinux;
  valgrind = pkgs.valgrind;

  # the QEMU plugin recording a run's leakage trace per
  # instruction, and the QEMU that runs a harness of this
  # system's ISA under it: user mode alone, its guest's getrandom
  # drawn from the generator -seed fixes (qemu-getrandom.patch)
  qemu = (pkgs.qemu.override {
    userOnly = true;
    hostCpuTargets = [ "x86_64-linux-user" "aarch64-linux-user" ];
  }).overrideAttrs (o: {
    patches = (o.patches or [ ]) ++ [ ./qemu-getrandom.patch ];
  });
  qemuFor = {
    x86_64 = "${qemu}/bin/qemu-x86_64";
    aarch64 = "${qemu}/bin/qemu-aarch64";
  };
  plugin = pkgs.runCommandCC "vestigia-qemu-plugin" {
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.glib ];
  } ''
    mkdir -p $out/lib
    cc -O2 -shared -fPIC -Wall -Werror \
      $(pkg-config --cflags glib-2.0) -I${qemu}/include \
      -o $out/lib/libvestigia-qemu.so ${src}/plugin/vestigia-qemu.c
  '';
  isa = builtins.head
    (lib.splitString "-" pkgs.stdenv.hostPlatform.system);

  # the harness-side header; a harness build also needs
  # valgrind's own (valgrindDev)
  include = pkgs.runCommand "vestigia-include" { } ''
    mkdir -p $out/include
    cp ${src}/include/vestigia.h $out/include/vestigia.h
    cp ${src}/include/vestigia.c $out/include/vestigia.c
  '';

  # the command, with the valgrind it was built against baked in
  vestigia = pkgs.runCommand "vestigia" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    mkdir -p $out/bin
    makeWrapper ${hpkgs.vestigia}/bin/vestigia $out/bin/vestigia \
      ${lib.optionalString linux (lib.concatStringsSep " " [
        "--set-default VESTIGIA_VALGRIND ${valgrind}/bin/valgrind"
        "--set-default VESTIGIA_QEMU ${qemuFor.${isa}}"
        "--set-default VESTIGIA_PLUGIN"
        "${plugin}/lib/libvestigia-qemu.so"
        "--set-default VESTIGIA_ADDR2LINE"
        "${pkgs.binutils-unwrapped}/bin/addr2line"
      ])}
    ln -s ${include}/include $out/include
  '';

  # one harness run under memcheck, as a derivation: its report,
  # memcheck's XML, and what the harness printed. `objects` keeps
  # sites in objects whose path contains one of them. A harness that
  # fails still leaves a report of what ran; a run vestigia could
  # not read fails the build.
  traceOf = { name, harness, args ? [ ], objects ? [ ] }:
    pkgs.runCommand "vestigia-trace-${name}" { } ''
      mkdir -p $out
      start=$(date +%s%N)
      set +e
      ${vestigia}/bin/vestigia run \
        --xml $out/memcheck.xml --out $out/trace.json \
        ${lib.concatMapStrings (o: "--object ${lib.escapeShellArg o} ")
          objects}-- ${harness} ${lib.escapeShellArgs args} \
        > $out/stdout 2> $out/stderr
      echo $? > $out/status
      set -e
      echo $(( ($(date +%s%N) - start) / 1000000 )) > $out/milliseconds
      test -s $out/trace.json || {
        cat $out/stderr >&2
        exit 1
      }
    '';

  # runs of one harness that differ only in a secret, each
  # recorded under QEMU, and where they diverge: the dumps, and
  # the report. `runs` is a list of argument lists; `objects`
  # keeps origins in objects whose path contains one of them. The
  # first run is repeated as a control, so that what differs
  # without the secret is set aside rather than taken for it.
  # `designed` runs, aimed at particular paths, are compared beside
  # them for control and coverage but not for addresses (vestigia
  # diff --designed). A run's own failure leaves its status; a dump
  # vestigia cannot read fails the build.
  diffOf = { name, harness, runs, objects ? [ ], designed ? [ ] }:
    pkgs.runCommand "vestigia-diff-${name}" { } ''
      mkdir -p $out
      start=$(date +%s%N)
      ${lib.concatImapStrings (k: args: ''
        set +e
        ${vestigia}/bin/vestigia record --dump $out/dump-${toString k} \
          -- ${harness} ${lib.escapeShellArgs args} \
          > $out/stdout-${toString k} 2> $out/stderr-${toString k}
        echo $? > $out/status-${toString k}
        set -e
      '') runs}${lib.concatImapStrings (k: args: ''
        set +e
        ${vestigia}/bin/vestigia record \
          --dump $out/designed-${toString k} \
          -- ${harness} ${lib.escapeShellArgs args} \
          > $out/stdout-designed-${toString k} \
          2> $out/stderr-designed-${toString k}
        echo $? > $out/status-designed-${toString k}
        set -e
      '') designed}
      set +e
      ${vestigia}/bin/vestigia record --dump $out/control-1 \
        -- ${harness} ${lib.escapeShellArgs (builtins.head runs)} \
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
