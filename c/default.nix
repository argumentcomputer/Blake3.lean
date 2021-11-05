{ pkgs, system, lean, blake3 }:
let
  inherit (pkgs) stdenv lib;
  inspect = e: builtins.trace e e;
  joinOpts = lib.concatStringsSep " ";
  blake3-c = blake3.packages.${system}.BLAKE3-c;
  buildCLib = lib.makeOverridable
    # Wrap object files in an archive for static linking
    ({ archive ? false
     , libExtension ? if archive then "a" else "so"
     , baseName ? "leanblake3"
     , libName ? "lib${baseName}.${libExtension}"
     , cc ? stdenv.cc
     , ccOptions ? [ ]
     , sharedLibDeps ? [ ]
     , debug ? false
     }:
      let
        name = libName;
        sourceFiles = "blake3-shim.c";
        leanPkgs = lean.packages.${system};
        staticLibDeps = [ blake3-c.staticLib ];
        sharedLibDeps = [ leanPkgs.sharedLib (leanPkgs.leanshared // { name = "libleanshared.so"; }) ];
        inherit (leanPkgs) lean-bin-tools-unwrapped;
        commonCCOptions = [ "-Wall" "-O3" "-fPIC" "-I${lean-bin-tools-unwrapped}/include" "-I${blake3}/c" ] ++ (if debug then [ "-ggdb" "-DDEBUG" ] else [ ]) ++ ccOptions;
        objectFile = "blake3-shim.o";
        libs = map (drv: "${drv}/${drv.name}") staticLibDeps;
        linkerOpts = map (drv: "-L${drv}") sharedLibDeps;
        buildSteps =
          if archive then
            [
              "${cc}/bin/cc ${joinOpts commonCCOptions} -c -o ${objectFile} ${sourceFiles}"
              "ar rcs ${libName} ${objectFile}"

            ] else
            [
              "${cc}/bin/cc ${joinOpts commonCCOptions} -c -o ${objectFile} ${sourceFiles}"
              "${cc}/bin/cc -shared  -Wl,--whole-archive ${joinOpts libs} ${objectFile} -Wl,--no-whole-archive ${joinOpts linkerOpts} -o ${libName}"
            ];
      in
      stdenv.mkDerivation {
        inherit name system libName;
        linkName = baseName;
        buildInputs = with pkgs; [ cc clib ];
        NIX_DEBUG = 1;
        src = ./.;
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
  sharedLib = cLib {
    archive = false;
  };
in
staticLib // {
  inherit cLib sharedLib staticLib;
}
