{
  description = "BLAKE3 bindings for lean";

  inputs = {
    lean = {
      url = github:leanprover/lean4;
    };

    nixpkgs.url = github:nixos/nixpkgs/nixos-21.05;
    flake-utils = {
      url = github:numtide/flake-utils;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    blake3 = {
      url = github:yatima-inc/BLAKE3/acs/add-flake-setup;    
    };
  };

  outputs = { self, lean, flake-utils, nixpkgs, blake3 }:
    let
      supportedSystems = [
        # "aarch64-linux"
        # "aarch64-darwin"
        "i686-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
    in
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        leanPkgs = lean.packages.${system};
        blake3-c = blake3.packages.${system}.BLAKE3-c;
        pkgs = import nixpkgs { inherit system; };
        name = "Blake3";
        debug = false;
        blake3-shim = import ./c/default.nix {
          inherit system pkgs blake3 lean;
        };
        BinaryTools = leanPkgs.buildLeanPackage {
          inherit debug;
          name = "BinaryTools";
          src = ./src;
        };
        project = leanPkgs.buildLeanPackage {
          inherit name debug;
          src = ./src;
          deps = [ BinaryTools ];
          nativeSharedLibs = [ (blake3-c.dynamicLib // { linkName = "blake3"; }) blake3-shim.sharedLib ];
        };
        tests = leanPkgs.buildLeanPackage {
          inherit debug;
          name = "Tests";
          src = ./tests;
          deps = [ project ];
        };
        joinDepsDerivationns = getSubDrv:
          pkgs.lib.concatStringsSep ":" (map (d: "${getSubDrv d}") ([ project tests BinaryTools ] ++ project.allExternalDeps));
      in
      {
        inherit project tests;
        packages = {
          inherit blake3-shim;
          inherit (project) modRoot sharedLib staticLib;
          inherit (leanPkgs) lean;
          tests = tests.executable;
        };

        checks.tests = tests;

        defaultPackage = project.modRoot;
        devShell = pkgs.mkShell {
          buildInputs = [ leanPkgs.lean ];
          LEAN_PATH = joinDepsDerivationns (d: d.modRoot);
          LEAN_SRC_PATH = joinDepsDerivationns (d: d.src);
        };
      });
}
