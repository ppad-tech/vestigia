# The probe check: etc/probe/harness.c under both instruments, each
# site and origin it should show found where it should be, and
# nothing else in the harness. On an x86_64 host, the same harness
# built for aarch64 is traced differentially too, under QEMU; memcheck
# needs a native host. Each differential trace is repeated under its
# ISA's data-independent-timing contract, which finds the floating-
# point division outside it and changes no origin.
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

  clock = pkgs.runCommandCC "vestigia-probe-clock" { } ''
    mkdir -p $out/bin
    cc -O0 -o $out/bin/clock ${../etc/probe/clock.c}
  '';

  pid = pkgs.runCommandCC "vestigia-probe-pid" { } ''
    mkdir -p $out/bin
    cc -O0 -o $out/bin/pid ${../etc/probe/pid.c}
    cc -O0 -DABORT -o $out/bin/abort ${../etc/probe/pid.c}
  '';

  secrets = [ "00000005" "0000003a" "000000c3" ];
  objects = [ "/bin/probe" ];

  trace = vestigia.traceOf {
    name = "probe";
    harness = "${probe}/bin/probe";
    runs = map (s: [ s ]) secrets;
    inherit objects;
  };

  diffOf = name: harness: contract: vestigia.diffOf {
    inherit name objects contract;
    harness = "${harness}/bin/probe";
    runs = map (s: [ s ]) secrets;
  };
  native = if x86_64 then "intel-doitm" else "arm-dit";
  diff = diffOf "probe" probe null;
  diffCross = diffOf "probe-aarch64" cross null;
  diffContract = diffOf "probe-contract" probe native;
  diffCrossContract = diffOf "probe-aarch64-contract" cross "arm-dit";

  # each report's (class, function) pairs in the harness, sorted
  expected = {
    trace = [ [ "address" "lookup" ] [ "address" "rare" ]
              [ "control" "branchy" ] [ "control" "calls" ]
              [ "control" "rare" ] [ "operand" "divide" ]
              [ "operand" "divide_memory" ] ];
    diff = [ [ "address" "lookup" ] [ "control" "branchy" ]
             [ "control" "calls" ] [ "control" "rare" ]
             [ "operand" "divide" ] [ "operand" "divide_memory" ] ];
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

  # every secret is traced under taint, and the table index on the
  # third secret's path is that run's alone
  check ${trace}/trace.json '[.runs[] | .exit]' '[0,0,0]'
  check ${trace}/trace.json \
    '[.sites[] | select(.function == "rare" and .class == "address")
      | .runs]' \
    '[["run-3"]]'

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

  # under a contract, the floating-point division is outside it, and
  # the origins are those found without one
  for d in ${diffContract} ${lib.optionalString x86_64
             "${diffCrossContract}"}; do
    check $d/diff.json '[.outside[] | .frames[0].function] | unique' \
      '["fpdivide"]'
    check $d/diff.json \
      '[.origins[] | [.class, .frames[0].function]] | unique' \
      '${builtins.toJSON expected.diff}'
    check $d/diff.json '.summary.watched > 0' 'true'
    check $d/diff.json '[.outside[] | .instruction | type] | unique' \
      '["string"]'
  done
  check ${diffContract}/diff.json '[.contract.name, .isa]' \
    '${builtins.toJSON [ native (if x86_64 then "x86_64" else "aarch64") ]}'
  check ${diff}/diff.json '.contract' 'null'
  ${lib.optionalString x86_64 ''
    check ${diffCrossContract}/diff.json '[.contract.name, .isa]' \
      '["arm-dit","aarch64"]'
  ''}

  # each origin's stack runs from its own function to the call in
  # main that reached it
  for d in ${diff} ${lib.optionalString x86_64 "${diffCross}"}; do
    check $d/diff.json \
      '[.origins[] | [.stacks[0][0].function, .stacks[0][1].function]
        | .[1]] | unique' \
      '["main"]'
  done

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

  # every run sees one pid, its own namespace's second: two runs of a
  # guest that branches on its pid differ nowhere in it
  $v record --dump pid-1 -- ${pid}/bin/pid
  $v record --dump pid-2 -- ${pid}/bin/pid
  $v diff --object /bin/pid --out pid.json pid-1 pid-2
  check pid.json '.origins | length' '0'

  # a guest a signal ends ends its run as the signal does, recorded
  set +e
  $v record --dump abort -- ${pid}/bin/abort
  ended=$?
  set -e
  if [ "$ended" != 134 ]; then
    echo "probe: an aborted guest's run ended $ended, not 134" >&2
    exit 1
  fi

  # a guest that starts a second thread is recorded on its own
  # thread alone: the second's spinning, which the host's scheduling
  # varies, is in neither dump, and the report says two threads ran
  $v record --dump threads-1 -- ${threads}/bin/threads
  $v record --dump threads-2 -- ${threads}/bin/threads
  $v diff --object /bin/threads --out threads.json threads-1 threads-2
  check threads.json '.origins | length' '0'
  check threads.json '.threads' '2'

  # a guest that spins until a millisecond has passed spins alike in
  # every run: its clock advances by its own readings
  $v record --dump clock-1 -- ${clock}/bin/clock
  $v record --dump clock-2 -- ${clock}/bin/clock
  $v diff --object /bin/clock --out clock.json clock-1 clock-2
  check clock.json '.origins | length' '0'
  touch $out
''
