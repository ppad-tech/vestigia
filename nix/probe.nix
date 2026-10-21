# The probe check: etc/probe/harness.c under both instruments, each
# site and origin it should show found where it should be, and
# nothing else in the harness.
{ pkgs, vestigia }:

let
  lib = pkgs.lib;

  # linked at a fixed address, where an instruction's address in the
  # file is not its offset there
  probe = pkgs.runCommandCC "vestigia-probe" {
    buildInputs = [ vestigia.valgrindDev ];
    hardeningDisable = [ "fortify" ];
  } ''
    mkdir -p $out/bin
    cc -O0 -g -fno-pie -no-pie -I${vestigia.include}/include \
      -o $out/bin/probe ${../etc/probe/harness.c} \
      ${vestigia.include}/include/vestigia.c
    readelf -h $out/bin/probe | grep -q 'Type: *EXEC'
  '';

  threads = pkgs.runCommandCC "vestigia-probe-threads" { } ''
    mkdir -p $out/bin
    cc -O0 -pthread -o $out/bin/threads ${../etc/probe/threads.c}
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

  # each run as it was made: the declared, then the control
  check ${diff}/diff.json \
    '[.runs[] | [.kind, .arguments[1], .status]]' \
    '${builtins.toJSON (map (s: [ "declared" s 0 ]) secrets
                       ++ [ [ "control" (builtins.head secrets) 0 ] ])}'

  v=${vestigia.vestigia}/bin/vestigia

  # a control must repeat the run it controls, and every run must lay
  # out as the first: its arguments of one number and length
  $v record --dump a -- ${probe}/bin/probe 00000005
  $v record --dump b -- ${probe}/bin/probe 0000003a
  $v record --dump c -- ${probe}/bin/probe 000000003a
  if $v diff --control b a a 2> refusal; then
    echo "probe: a control repeating another secret was taken" >&2
    exit 1
  fi
  grep -q 'does not repeat' refusal
  if $v diff a c 2> refusal; then
    echo "probe: a run with a longer argument was compared" >&2
    exit 1
  fi
  grep -q 'number or length' refusal

  # a guest that starts a second thread is stopped, and its dump
  # refused
  if $v record --dump threads -- ${threads}/bin/threads; then
    echo "probe: a guest's second thread was recorded" >&2
    exit 1
  fi
  if $v diff threads threads 2> refusal; then
    echo "probe: a stopped guest's dump was compared" >&2
    exit 1
  fi
  grep -q 'second thread' refusal
  touch $out
''
