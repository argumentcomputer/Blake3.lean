{pkgs, lean4-nix, blake3}:
let
  blake3Flags = pkgs.lib.concatStringsSep " " ([
    "-DBLAKE3_NO_SSE2"
    "-DBLAKE3_NO_SSE41"
    "-DBLAKE3_NO_AVX2"
    "-DBLAKE3_NO_AVX512"
    "-DBLAKE3_USE_NEON=0"
  ]);
  #blake3Files = [
  #  "blake3"
  #  "blake3_dispatch"
  #  "blake3_portable"
  #];
  blake3-c = pkgs.stdenv.mkDerivation {
    name = "blake3-c";
    src = ./.;
    buildInputs = [ pkgs.gcc pkgs.lean.lean-all ];
    buildPhase = ''
      lean --version
      gcc -O3 -Wall -c ${blake3}/c/blake3.c -o blake3.o ${blake3Flags}
      gcc -O3 -Wall -c ${blake3}/c/blake3_dispatch.c -o blake3_dispatch.o ${blake3Flags}
      gcc -O3 -Wall -c ${blake3}/c/blake3_portable.c -o blake3_portable.o ${blake3Flags}
      gcc -O3 -Wall -c ffi.c -o ffi.o -I ${pkgs.lean4}/include -I ${blake3}/c
      ar rcs libblake3.a blake3.o blake3_dispatch.o blake3_portable.o ffi.o
    '';
    installPhase = ''
      mkdir -p $out/lib $out/include
      cp libblake3.a $out/lib/
      cp ${blake3}/c/blake3.h $out/include/
    '';
  };
  blake3-lib = (pkgs.lean.buildLeanPackage {
    name = "blake3-lib";
    src = ./.;
    roots = [ "Blake3" ];
    staticLibDeps = [ blake3-c ];
    linkFlags = [ "-L${blake3-c}/lib" "-lblake3" ];
  });

  blake3-test = (pkgs.lean.buildLeanPackage {
    name = "blake3-test";
    src = ./.;
    roots = ["Blake3Test"];
    deps = [ blake3-lib ];
    staticLibDeps = [ blake3-c ];
    linkFlags = [ "-L${blake3-c}/lib" "-lblake3" ];
  });

  lib = {
    inherit
      blake3-c
      blake3-lib
      blake3-test;
  };
in
{
  inherit lib;
}
