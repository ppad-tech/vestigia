# The probe check: etc/probe/harness.c under both instruments, each
# site and origin it should show found where it should be, and
# nothing else in the harness.
{ pkgs, vestigia }:

let
  lib = pkgs.lib;

  probe = pkgs.runCommandCC "vestigia-probe" {
    buildInputs = [ vestigia.valgrindDev ];
  } ''
    mkdir -p $out/bin
    cc -O0 -g -fPIE -pie -I${vestigia.include}/include \
      -o $out/bin/probe ${../etc/probe/harness.c} \
      ${vestigia.include}/include/vestigia.c
  '';

  secrets = [ "00000005" "0000003a" "000000c3" ];
  objects = [ "/bin/probe" ];

  trace = vestigia.traceOf {
    name = "probe";
    harness = "${probe}/bin/probe";
    args = [ (builtins.head secrets) ];
    inherit objects;
  };

  diff = vestigia.diffOf {
    name = "probe";
    harness = "${probe}/bin/probe";
    runs = map (s: [ s ]) secrets;
    inherit objects;
  };

  # each report's (class, function) pairs in the harness, sorted
  expected = {
    trace = [ [ "address" "lookup" ] [ "control" "branchy" ] ];
    diff = [ [ "address" "lookup" ] [ "control" "branchy" ] ];
  };
in
pkgs.runCommand "vestigia-probe-check" {
  nativeBuildInputs = [ pkgs.jq ];
} ''
  check() {
    got=$(jq -c "$2" "$1")
    if [ "$got" != "$3" ]; then
      echo "probe: $1: expected $3, got $got" >&2
      exit 1
    fi
  }
  check ${trace}/trace.json \
    '[.sites[] | [.class, .function]] | unique' \
    '${builtins.toJSON expected.trace}'
  check ${diff}/diff.json \
    '[.origins[] | [.class, .frames[0].function]] | unique' \
    '${builtins.toJSON expected.diff}'
  touch $out
''
