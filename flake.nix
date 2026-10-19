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
        v = import ./nix/lib.nix { inherit pkgs; src = ./.; };
        hpkgs = v.hpkgs;
        linux = pkgs.stdenv.hostPlatform.isLinux;
      in
        {
          packages = {
            default = v.vestigia;
            include = v.include;
          }
          # the plugin and the QEMU it loads run Linux guests' user
          # mode, which exists on Linux alone
          // lib.optionalAttrs linux {
            plugin = v.plugin;
          };

          lib = {
            inherit (v) traceOf diffOf valgrindDev;
          };

          checks.default = hpkgs.vestigia;

          devShells.default = hpkgs.shellFor {
            packages = p: [ p.vestigia ];
            buildInputs = [
              hpkgs.cabal-install
              pkgs.stdenv.cc
            ] ++ lib.optional linux pkgs.valgrind;

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
