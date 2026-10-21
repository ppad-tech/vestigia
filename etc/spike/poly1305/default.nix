# Spike 2: ppad-poly1305 under vestigia, on x86_64-linux: the
# release (173e478) and the elenchus vectors' two mutant sets.
#
#   nix build --impure -f etc/spike/poly1305 all
let
  system = "x86_64-linux";
  vestigia = builtins.getFlake (toString ../../..);
  poly = builtins.getFlake ("git+file:///Users/jtobin/src/ppad/poly1305"
    + "?rev=173e478290ecf9d639f0c85ae625da474a62a6b2");
  pkgs = import vestigia.inputs.nixpkgs { inherit system; };
  hlib = pkgs.haskell.lib;
  llvm = pkgs.llvmPackages_19.llvm;
  clang = pkgs.llvmPackages_19.clang;
  withLlvm = p: hlib.addBuildTools (hlib.enableCabalFlag p "llvm")
    [ llvm clang ];

  variant = name: patches:
    let
      hpkgs = pkgs.haskell.packages.ghc910.extend (new: old: {
        ppad-base16 =
          withLlvm poly.inputs.ppad-base16.packages.${system}.default;
        ppad-fixed =
          withLlvm poly.inputs.ppad-fixed.packages.${system}.default;
        ppad-poly1305 = withLlvm (hlib.dontCheck (hlib.appendPatches
          (new.callCabal2nix "ppad-poly1305" poly.outPath { })
          patches));
      });
      ghc = hpkgs.ghcWithPackages (p: [ p.ppad-poly1305 ]);
      harness = pkgs.runCommandCC "poly1305-${name}-harness" {
        nativeBuildInputs = [ ghc llvm clang ];
      } ''
        mkdir -p $out/bin build
        cp ${./Harness.hs} build/Harness.hs
        cp ${vestigia.packages.${system}.include}/include/vestigia.c build/marks.c
        cd build
        # a small address-space reservation, since memcheck pays for
        # the runtime's default terabyte on every run, and no
        # interval timer, so runs that differ only in their keys
        # schedule alike
        ghc -O2 -rtsopts '-with-rtsopts=-xr1G -V0' Harness.hs marks.c \
          -I${vestigia.packages.${system}.include}/include \
          -I${vestigia.lib.${system}.valgrindDev}/include \
          -o $out/bin/harness
      '';
      bin = "${harness}/bin/harness";
      seeds = [ "1" "2" "3" ];
    in pkgs.linkFarm "poly1305-${name}" [
      { name = "trace";
        path = vestigia.lib.${system}.traceOf {
          name = "poly1305-${name}";
          harness = bin;
          runs = [ [ "4" "1" ] ];
        }; }
      { name = "diff";
        path = vestigia.lib.${system}.diffOf {
          name = "poly1305-${name}";
          harness = bin;
          runs = map (s: [ "2" s ]) seeds;
        }; }
    ];
in
{
  all = pkgs.linkFarm "poly1305-spike" [
    { name = "release"; path = variant "release" [ ]; }
    { name = "mutants-1"; path = variant "mutants-1" [ ./mutants-1.patch ]; }
    { name = "mutants-2"; path = variant "mutants-2" [ ./mutants-2.patch ]; }
  ];
}
