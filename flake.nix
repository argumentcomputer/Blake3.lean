{
  description = "BLAKE3 bindings for lean";

  inputs = {
    lean = {
      url = github:yatima-inc/lean4/acs/add-nix-ability-for-native-libs;
    };

    nixpkgs.url = github:nixos/nixpkgs/nixos-21.05;
    flake-utils = {
      url = github:numtide/flake-utils;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    blake3.url = github:yatima-inc/BLAKE3/acs/add-flake-setup;
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
        blake3-shim = import ./c/default.nix {
          inherit system pkgs blake3-c lean;
        };
        project = leanPkgs.buildLeanPackage {
          inherit name;
          src = ./src;
          debug = true;
          nativeSharedLibs = [ blake3-c.dynamicLib blake3-shim.sharedLib leanPkgs.sharedLib (leanPkgs.leanshared // { name = "libleanshared.so"; }) ];
          staticLibDeps = [ blake3-c.staticLib blake3-shim.staticLib ];
        };
        tests = leanPkgs.buildLeanPackage {
          name = "Tests";
          src = ./tests;
          debug = true;
          deps = [ leanPkgs.Lean leanPkgs.Leanpkg project ];
          nativeSharedLibs = [ project.sharedLib ];
        };
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
          LEAN_PATH = "${leanPkgs.Lean.modRoot}";
          CPATH = "${leanPkgs.Lean.modRoot}";
        };
      });
}
