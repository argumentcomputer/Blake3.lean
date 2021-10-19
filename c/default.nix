{ pkgs, system, lean, blake3-c }:
let
  cLib = pkgs.lib.makeOverridable
    # Wrap object files in an archive for static linking
    ({ archive ? false
     , libExtension ? if archive then "a" else "so"
     , libName ? "libblake3.${libExtension}"
     , gccOptions ? ""
     }:
      let
        name = libName;
        sourceFiles = "blake3-shim.c";
        staticLibDeps = [ blake3-c lean ];
        leanPkgs = lean.packages.${system};
        commonGccOptions = "-Wall -O3 -I${lean-bin-tools-unwrapped}/include -Iinclude ${gccOptions}";
        inherit (leanPkgs) lean-bin-tools-unwrapped;
        buildSteps =
          if archive then
            [
              "gcc ${commonGccOptions} -c -o blake3.o ${sourceFiles}"
              "ar rcs ${libName} blake3.o"

            ] else
            [
              "gcc ${commonGccOptions} -shared -Wall -O3 -o ${libName} ${sourceFiles}"
            ];
      in
      pkgs.stdenv.mkDerivation {
        inherit name system;
        buildInputs = with pkgs; [ gcc clib ] ++ staticLibDeps;
        NIX_DEBUG = 1;
        src = ./.;
        configurePhase = ''
          mkdir include
          ln -s ${blake3-c.headerFile} include/blake3.h
        '';
        buildPhase = pkgs.lib.concatStringsSep "\n" buildSteps;
        installPhase = ''
          mkdir -p $out
          cp ${libName} $out
        '';
      });
  staticLib = cLib {
    archive = true;
  };
  dynamicLib = cLib {
    archive = false;
  };
in
staticLib // {
  inherit cLib dynamicLib staticLib;
}
