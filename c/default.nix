{ pkgs, system, lean, blake3-c }:
let
  cLib = pkgs.lib.makeOverridable
    ({ name ? "blake3-shim"
       # Wrap object files in an archive for static linking
     , archive ? false
     , libExtension ? if archive then "a" else "so"
     , libName ? "lib${name}.${libExtension}"
     , gccOptions ? ""
     }:
      let
        sourceFiles = "lean-blake3.c";
        staticLibDeps = [ blake3-c lean ];
        leanPkgs = lean.packages.${system};
        inherit (lean) lean-bin-tools-unwrapped;
        buildSteps =
          if archive then
            [
              "gcc ${gccOptions} -c -Wall -O3 -I${lean-bin-tools-unwrapped}/include -Iinclude -o blake3.o ${sourceFiles}"               

              "ar rcs ${libName} blake3.o"

            ] else
            [
              "gcc ${gccOptions} -shared -Wall -O3 -o ${libName} ${sourceFiles}"
            ];
      in
      pkgs.stdenv.mkDerivation {
        inherit name system;
        buildInputs = with pkgs; [ gcc clib ] ++ staticLibDeps;
        NIX_DEBUG = 1;
        src = ./.;
        configurePhase = ''
          # mkdir include
          ln -s ${lean}/src/include/lean include
          ln -s ${blake3-c}/src/include/lean include
          # cat lean.h
          ls -alR
          ls -alR include
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
