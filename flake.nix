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

        # the harness-side header; a harness build also needs
        # valgrind's own (valgrindDev)
        include = pkgs.runCommand "vestigia-include" { } ''
          mkdir -p $out/include
          cp ${./include/vestigia.h} $out/include/vestigia.h
        '';

        # the command, with the valgrind it was built against baked in
        vestigia = pkgs.runCommand "vestigia" {
          nativeBuildInputs = [ pkgs.makeWrapper ];
        } ''
          mkdir -p $out/bin
          makeWrapper ${hpkgs.vestigia}/bin/vestigia $out/bin/vestigia \
            ${lib.optionalString linux
              "--set-default VESTIGIA_VALGRIND ${valgrind}/bin/valgrind"}
          ln -s ${include}/include $out/include
        '';

        # one harness run under memcheck, as a derivation: its report,
        # memcheck's XML, and what the harness printed. A harness that
        # fails still leaves a report of what ran; a run vestigia could
        # not read fails the build.
        traceOf = { name, harness, args ? [ ] }:
          pkgs.runCommand "vestigia-trace-${name}" { } ''
            mkdir -p $out
            set +e
            ${vestigia}/bin/vestigia run \
              --xml $out/memcheck.xml --out $out/trace.json \
              -- ${harness} ${lib.escapeShellArgs args} \
              > $out/stdout 2> $out/stderr
            echo $? > $out/status
            set -e
            test -s $out/trace.json || {
              cat $out/stderr >&2
              exit 1
            }
          '';
      in
        {
          packages.default = vestigia;
          packages.include = include;

          lib = {
            inherit traceOf;
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
