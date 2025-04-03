{
  pkgs,
  lean4-nix,
  blake3,
}: let
  blake3Flags = pkgs.lib.concatStringsSep " " [
    "-DBLAKE3_NO_SSE2"
    "-DBLAKE3_NO_SSE41"
    "-DBLAKE3_NO_AVX2"
    "-DBLAKE3_NO_AVX512"
    "-DBLAKE3_USE_NEON=0"
  ];
  blake3Files = [
    "blake3"
    "blake3_dispatch"
    "blake3_portable"
  ];
  buildSteps =
    builtins.map (file: "gcc -O3 -Wall -c ${blake3}/c/${file}.c -o ${file}.o ${blake3Flags}") blake3Files
    ++ [
      "gcc -O3 -Wall -c ffi.c -o ffi.o -I ${pkgs.lean4}/include -I ${blake3}/c"
      "ar rcs libblake3.a ${(builtins.concatStringsSep " " (builtins.map (str: "${str}.o") blake3Files))} ffi.o"
    ];
  # The `libblake3.a` static library is exposed as the `staticLib` package, as it must be explicitly linked against
  # in downstream lean4-nix packages.
  blake3-c = pkgs.stdenv.mkDerivation {
    name = "blake3-c";
    src = ./.;
    buildInputs = [pkgs.gcc pkgs.lean.lean-all];
    buildPhase = builtins.concatStringsSep "\n" buildSteps;
    installPhase = ''
      mkdir -p $out/lib $out/include
      cp libblake3.a $out/lib/
      cp ${blake3}/c/blake3.h $out/include/
    '';
  };
  # The Blake3 library is only used locally for development and to build the test package
  # Downstream users should import Blake3.lean in the lakefile and fetch it via `mkPackage`
  blake3-lib = pkgs.lean.buildLeanPackage {
    name = "blake3-lib";
    src = ./.;
    roots = ["Blake3"];
    staticLibDeps = [ "${blake3-c}/lib" ];
    groupStaticLibs = true;
  };

  lib = {
    inherit
      blake3-c
      blake3-lib
      ;
  };
in {
  inherit lib;
}
