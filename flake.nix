{
  description = "BLAKE3 bindings for lean";

  inputs = {
    lean = {
      url = github:leanprover/lean4;
    };

    nixpkgs.url = github:nixos/nixpkgs/nixpkgs-unstable;
    flake-utils = {
      url = github:numtide/flake-utils;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    blake3.url = github:yatima-inc/BLAKE3/acs/add-flake-setup;
  };

  outputs = { self, lean, flake-utils, nixpkgs, blake3 }: flake-utils.lib.eachDefaultSystem (system:
    let
      leanPkgs = lean.packages.${system};
      blake3-c = blake3.packages.${system}.BLAKE3-c;
      pkgs = import nixpkgs { inherit system; };
      name = "Blake3";
      project = leanPkgs.buildLeanPackage {
        inherit name;
        src = ./src;
        debug = true;
        linkFlags = [ "-lblake3" ];
        staticLibDeps = [ blake3-c ];
      };
    in
    {
      inherit project;
      packages = {
        inherit (project) modRoot Blake3;
        inherit (leanPkgs) lean;
      };

      defaultApp = self.apps.${system}.${name};

      defaultPackage = project.modRoot;
      devShell = pkgs.mkShell {
        buildInputs = [ leanPkgs.lean ];
        LEAN_PATH = "${leanPkgs.Lean.modRoot}";
        CPATH = "${leanPkgs.Lean.modRoot}";
      };
    });
}
