# The probe check: etc/probe/harness.c under both instruments, each
# site and origin it should show found where it should be, and
# nothing else in the harness. On an x86_64 host, the same harness
# built for aarch64 is traced differentially too, under QEMU; memcheck
# needs a native host.
{ pkgs, vestigia }:

let
  lib = pkgs.lib;

  # the harness, built by a package set's C compiler and linked at a
  # fixed address, where an instruction's address in the file is not
  # its offset there
  probeOf = ps: ps.runCommandCC "vestigia-probe" {
    hardeningDisable = [ "fortify" ];
  } ''
    mkdir -p $out/bin
    $CC -O0 -g -fno-pie -no-pie -I${vestigia.include}/include \
      -I${vestigia.valgrindDev}/include \
      -o $out/bin/probe ${../etc/probe/harness.c} \
      ${vestigia.include}/include/vestigia.c
    $READELF -h $out/bin/probe | grep -q 'Type: *EXEC'
  '';

  probe = probeOf pkgs;
  cross = probeOf pkgs.pkgsCross.aarch64-multiplatform;
  x86_64 = pkgs.stdenv.hostPlatform.isx86_64;

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

  diffOf = name: harness: vestigia.diffOf {
    inherit name objects;
    harness = "${harness}/bin/probe";
    runs = map (s: [ s ]) secrets;
  };
  diff = diffOf "probe" probe;
  diffCross = diffOf "probe-aarch64" cross;

  # each report's (class, function) pairs in the harness, sorted
  expected = {
    trace = [ [ "address" "lookup" ] [ "control" "branchy" ]
              [ "control" "calls" ] [ "operand" "divide" ]
              [ "operand" "divide_memory" ] ];
    diff = [ [ "address" "lookup" ] [ "control" "branchy" ]
             [ "control" "calls" ] [ "operand" "divide" ]
             [ "operand" "divide_memory" ] ];
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

  # both instruments name each instruction they both saw by one
  # address: a division memcheck reports where it divides, not at the
  # memory access before it
  check ${trace}/trace.json \
    '[.sites[] | select(.class == "operand") | .offset] | sort' \
    "$(jq -c '[.origins[] | select(.class == "operand") | .offset]
              | sort' ${diff}/diff.json)"
  ${lib.optionalString x86_64 ''
    check ${diffCross}/diff.json \
      '[.origins[] | [.class, .frames[0].function]] | unique' \
      '${builtins.toJSON expected.diff}'
  ''}

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
