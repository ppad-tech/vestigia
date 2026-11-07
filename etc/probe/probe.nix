# memcheck's XML for a known program, captured on x86_64-linux
let
  f = builtins.getFlake (toString ../..);
  pkgs = import f.inputs.nixpkgs { system = "x86_64-linux"; };
in
pkgs.runCommandCC "vestigia-probe" {
  nativeBuildInputs = [ pkgs.valgrind ];
  buildInputs = [ pkgs.valgrind.dev ];
} ''
  mkdir -p $out
  cc -O2 -g -o probe ${./probe.c}
  valgrind --tool=memcheck --xml=yes --xml-file=$out/memcheck.xml \
    --track-origins=yes --error-limit=no --num-callers=12 \
    --expensive-definedness-checks=yes ./probe > $out/stdout 2> $out/stderr
  echo $? > $out/exit
  objdump -d probe > $out/probe.dis
''
