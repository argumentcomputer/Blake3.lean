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
      url = github:BLAKE3-team/BLAKE3;
      flake = false;
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
        pkgs = nixpkgs.legacyPackages.${system};
        name = "Blake3";
        debug = false;
        blake3-shim = import ./c/default.nix {
          inherit system pkgs blake3 lean;
        };
        project = leanPkgs.buildLeanPackage {
          inherit name debug;
          src = ./src;
          nativeSharedLibs = [ blake3-shim.sharedLib ];
        };
        tests = leanPkgs.buildLeanPackage {
          inherit debug;
          name = "Tests";
          src = ./tests;
          deps = [ project ];
        };
        joinDepsDerivations = getSubDrv:
          pkgs.lib.concatStringsSep ":" (map (d: "${getSubDrv d}") ([ project tests ] ++ project.allExternalDeps));
      in
      {
        inherit project tests;
        packages = {
          inherit blake3-shim;
          inherit (project) modRoot sharedLib staticLib;
          inherit (leanPkgs) lean;
          tests = tests.executable;
        };

        checks.tests = tests.executable;

        defaultPackage = project.modRoot;
        devShell = pkgs.mkShell {
          buildInputs = [ leanPkgs.lean ];
          LEAN_PATH = joinDepsDerivations (d: d.modRoot);
          LEAN_SRC_PATH = joinDepsDerivations (d: d.src);
        };
      });
}
