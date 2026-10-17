let
  f = builtins.getFlake "/Users/jtobin/src/ppad/vestigia";
  pkgs = import f.inputs.nixpkgs { system = "x86_64-linux"; };
  plugin = pkgs.runCommandCC "vestigia-qemu-plugin" {
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.glib ];
  } ''
    mkdir -p $out/lib
    cc -O2 -shared -fPIC -Wall -Werror \
      $(pkg-config --cflags glib-2.0) -I${pkgs.qemu}/include \
      -o $out/lib/libvestigia-qemu.so ${../../plugin/vestigia-qemu.c}
  '';
in pkgs.runCommandCC "vestigia-diffprobe" { } ''
  mkdir -p $out
  cc -O2 -g -o probe ${./diffprobe.c}
  for s in 03 05; do
    ${pkgs.qemu}/bin/qemu-x86_64 \
      -plugin ${plugin}/lib/libvestigia-qemu.so,out=$out/dump-$s \
      ./probe $s > $out/stdout-$s
  done
  objdump -d probe > $out/probe.dis
  cp probe $out/
''
