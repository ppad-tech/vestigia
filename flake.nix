{
  description = "Where an execution depended on a secret.";

  inputs = {
    ppad-nixpkgs = {
      type = "git";
      url  = "git://git.ppad.tech/nixpkgs.git";
      ref  = "master";
    };
    flake-utils.follows = "ppad-nixpkgs/flake-utils";
    nixpkgs.follows = "ppad-nixpkgs/nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, ppad-nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        hpkgs = pkgs.haskell.packages.ghc910.extend (new: old: {
          vestigia = new.callCabal2nix "vestigia" ./. { };
        });

        # memcheck runs on Linux only; elsewhere the command can still
        # read a run's XML
        linux = pkgs.stdenv.hostPlatform.isLinux;
        valgrind = pkgs.valgrind;

        # the QEMU plugin recording a run's leakage trace per
        # instruction, and the QEMU that runs a harness of this
        # system's ISA under it
        qemu = pkgs.qemu;
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
            -o $out/lib/libvestigia-qemu.so ${./plugin/vestigia-qemu.c}
        '';
        isa = builtins.head (lib.splitString "-" system);

        # the harness-side header; a harness build also needs
        # valgrind's own (valgrindDev)
        include = pkgs.runCommand "vestigia-include" { } ''
          mkdir -p $out/include
          cp ${./include/vestigia.h} $out/include/vestigia.h
          cp ${./include/vestigia-ffi.c} $out/include/vestigia-ffi.c
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
        # memcheck's XML, and what the harness printed. A harness that
        # fails still leaves a report of what ran; a run vestigia could
        # not read fails the build.
        traceOf = { name, harness, args ? [ ] }:
          pkgs.runCommand "vestigia-trace-${name}" { } ''
            mkdir -p $out
            start=$(date +%s%N)
            set +e
            ${vestigia}/bin/vestigia run \
              --xml $out/memcheck.xml --out $out/trace.json \
              -- ${harness} ${lib.escapeShellArgs args} \
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
        # keeps origins in objects whose path contains one of them.
        # A run's own failure leaves its status; a dump vestigia
        # cannot read fails the build.
        diffOf = { name, harness, runs, objects ? [ ] }:
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
            '') runs}
            ${vestigia}/bin/vestigia diff --out $out/diff.json \
              ${lib.concatMapStrings (o: "--object ${lib.escapeShellArg o} ")
                objects} \
              $out/dump-* 2> $out/summary
            echo $(( ($(date +%s%N) - start) / 1000000 )) > $out/milliseconds
          '';
      in
        {
          packages.default = vestigia;
          packages.include = include;
          packages.plugin = plugin;

          lib = {
            inherit traceOf diffOf;
            valgrindDev = valgrind.dev;
          };

          checks.default = hpkgs.vestigia;

          devShells.default = hpkgs.shellFor {
            packages = p: [ p.vestigia ];
            buildInputs = [
              hpkgs.cabal-install
              pkgs.stdenv.cc
            ] ++ lib.optional linux valgrind;

            shellHook = ''
              PS1="[vestigia] \w$ "
              echo "entering ${system} shell, using"
              echo "ghc:   $(${hpkgs.ghc}/bin/ghc --version)"
              echo "cabal: $(${hpkgs.cabal-install}/bin/cabal --version)"
            '';
          };
        }
      );
}
