# Spike 3: ppad-secp256k1 under vestigia, on x86_64-linux: the
# release (fdb80d5), a constant-time control, and the elenchus
# vector's mutants (S1 a secret-indexed window load, S2 a branch on
# each ladder bit, S3 a zero-byte shortcut on the key in Schnorr).
#
#   nix build --impure -f etc/spike/secp256k1 all
let
  system = "x86_64-linux";
  vestigia = builtins.getFlake (toString ../../..);
  secp = builtins.getFlake ("git+file:///Users/jtobin/src/ppad/secp256k1"
    + "?rev=fdb80d54b86c61bd1a15e2e8db351091d02c89ee");
  pkgs = import vestigia.inputs.nixpkgs { inherit system; };
  hlib = pkgs.haskell.lib;
  llvm = pkgs.llvmPackages_19.llvm;
  clang = pkgs.llvmPackages_19.clang;
  withLlvm = p: hlib.addBuildTools (hlib.enableCabalFlag p "llvm")
    [ llvm clang ];
  input = n: withLlvm secp.inputs.${n}.packages.${system}.default;

  variant = name: patches:
    let
      hpkgs = pkgs.haskell.packages.ghc910.extend (new: old: {
        ppad-base16 = input "ppad-base16";
        ppad-sha256 = input "ppad-sha256";
        ppad-hmac-drbg = input "ppad-hmac-drbg";
        ppad-fixed = input "ppad-fixed";
        ppad-secp256k1 = withLlvm (hlib.dontCheck (hlib.dontBenchmark
          (hlib.appendPatches
            (new.callCabal2nix "ppad-secp256k1" secp.outPath {
              ppad-base16 = new.ppad-base16;
              ppad-sha256 = new.ppad-sha256;
              ppad-hmac-drbg = new.ppad-hmac-drbg;
              ppad-fixed = new.ppad-fixed;
            })
            patches)));
      });
      ghc = hpkgs.ghcWithPackages (p: [ p.ppad-secp256k1 ]);
      harness = pkgs.runCommandCC "secp256k1-${name}-harness" {
        nativeBuildInputs = [ ghc llvm clang ];
      } ''
        mkdir -p $out/bin build
        cp ${./Harness.hs} build/Harness.hs
        cp ${vestigia.packages.${system}.include}/include/vestigia-ffi.c build/marks.c
        cd build
        ghc -O2 -rtsopts '-with-rtsopts=-xr1G -V0' Harness.hs marks.c \
          -I${vestigia.packages.${system}.include}/include \
          -I${vestigia.lib.${system}.valgrindDev}/include \
          -o $out/bin/harness
      '';
      bin = "${harness}/bin/harness";
    in pkgs.linkFarm "secp256k1-${name}" [
      { name = "trace";
        path = vestigia.lib.${system}.traceOf {
          name = "secp256k1-${name}";
          harness = bin;
          args = [ "2" "1" ];
        }; }
      { name = "diff";
        path = vestigia.lib.${system}.diffOf {
          name = "secp256k1-${name}";
          harness = bin;
          runs = map (s: [ "1" s ]) [ "1" "2" "3" ];
          objects = [ "harness" ];
        }; }
    ];
in
{
  all = pkgs.linkFarm "secp256k1-spike" [
    { name = "release"; path = variant "release" [ ]; }
    { name = "mutants"; path = variant "mutants" [ ./mutants.patch ]; }
  ];
}
