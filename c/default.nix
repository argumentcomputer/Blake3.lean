{ pkgs, system, lean, blake3-c }:
let
  inherit (pkgs) stdenv;
  buildCLib = pkgs.lib.makeOverridable
    # Wrap object files in an archive for static linking
    ({ archive ? false
     , libExtension ? if archive then "a" else "so"
     , libName ? "libblake3.${libExtension}"
     , cc ? stdenv.cc
     , ccOptions ? [ ]
     , debug ? false
     }:
      let
        lib = pkgs.lib;
        name = libName;
        sourceFiles = "blake3-shim.c";
        staticLibDeps = [ blake3-c lean ];
        leanPkgs = lean.packages.${system};
        commonCCOptions = lib.concatStringsSep " " ([ "-Wall" "-O3" "-I${lean-bin-tools-unwrapped}/include" "-Iinclude" (if debug then "-ggdb" else "") ] ++ ccOptions);
        inherit (leanPkgs) lean-bin-tools-unwrapped;
        buildSteps =
          if archive then
            [
              "${cc}/bin/cc ${commonCCOptions} -c -o blake3.o ${sourceFiles}"
              "ar rcs ${libName} blake3.o"

            ] else
            [
              "${cc}/bin/cc ${commonCCOptions} -shared -o ${libName} ${sourceFiles}"
            ];
      in
      pkgs.stdenv.mkDerivation {
        inherit name system;
        buildInputs = with pkgs; [ cc clib ] ++ staticLibDeps;
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
  # Add additional properties
  cLib = args:
    let self = buildCLib args;
    in
    self // {
      debug = self.override { debug = true; };
    };
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
