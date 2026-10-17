# Spike 1: Penumbra's audit library under vestigia, on x86_64-linux.
#
#   nix build --impure -f etc/spike/penumbra traces
#
# Two builds are traced. `audited` is the engagement's own library:
# the exact machine code audited, whose sites carry function names
# but no source lines. `lines` is the same build with line tables
# kept, so its sites name source lines. Keeping them perturbs the
# crate's symbol hashes and a few inlining decisions (16 of 546
# functions differ once names and addresses are normalised), so the
# two are compared by function.
let
  system = "x86_64-linux";
  vestigia = builtins.getFlake (toString ../../..);
  penumbra = builtins.getFlake
    "path:/Users/jtobin/src/ppad/research/corpus/penumbra/harness";
  pkgs = import vestigia.inputs.nixpkgs { inherit system; };

  audited = penumbra.packages.${system}.audit;

  lines = audited.overrideAttrs (o: {
    pname = "penumbra-audit-lines";
    CARGO_PROFILE_RELEASE_DEBUG = "line-tables-only";
    dontStrip = true;
  });

  harnessFor = lib: pkgs.runCommandCC "penumbra-vestigia-harness" { } ''
    mkdir -p $out/bin
    cc -O2 -g -o $out/bin/harness ${./harness.c} \
      ${vestigia.packages.${system}.include}/include/vestigia.c \
      -I${vestigia.packages.${system}.include}/include \
      -I${vestigia.lib.${system}.valgrindDev}/include \
      -L${lib}/lib -lpenumbra_audit -Wl,-rpath,${lib}/lib
  '';

  traceOf = build: lib: root: vestigia.lib.${system}.traceOf {
    name = "penumbra-${build}-${root}";
    harness = "${harnessFor lib}/bin/harness";
    args = [ root "4" ];
  };

  roots = [ "public_key" "key_agreement" "spend_auth_sign" ];

  # three processes of two calls each, differing only in the secrets
  seeds = [ "0000000000000001" "0000000000000002" "0000000000000003" ];
  diffOf = build: lib: root: vestigia.lib.${system}.diffOf {
    name = "penumbra-${build}-${root}";
    harness = "${harnessFor lib}/bin/harness";
    runs = map (s: [ root "2" s ]) seeds;
    objects = [ "libpenumbra_audit" ];
  };
in
{
  inherit audited lines;

  diffs = pkgs.linkFarm "penumbra-diffs" (
    map (r: { name = "lines/${r}"; path = diffOf "lines" lines r; })
      roots);

  traces = pkgs.linkFarm "penumbra-traces" (
    map (r: { name = "audited/${r}"; path = traceOf "audited" audited r; })
      roots
    ++ map (r: { name = "lines/${r}"; path = traceOf "lines" lines r; })
      roots);
}
