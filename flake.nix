{
  description = "BLAKE3 bindings for lean";

  inputs = {
    lean = {
      url = github:leanprover/lean4;
      # inputs.flake-utils.follows = "flake-utils";
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
          # debug = true;
          # linkFlags = [ blake3-shim ];
          # staticLibDeps = [ blake3-shim ];
          pluginDeps = [ blake3-shim.dynamicLib ];
        };
        tests = leanPkgs.buildLeanPackage {
          name = "Tests";
          src = ./tests;
          debug = true;
          deps = [ project ];
          pluginDeps = [ blake3-shim ];
          staticLibDeps = [ blake3-shim ];
        };
      in
      {
        inherit project;
        packages = {
          inherit blake3-shim;
          inherit (project) modRoot executable;
          inherit (leanPkgs) lean;
          tests = tests.modRoot;
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
