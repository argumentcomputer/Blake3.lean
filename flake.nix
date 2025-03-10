{
  description = "Blake3 Nix Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    lean4-nix = {
      url = "github:argumentcomputer/lean4-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    blake3 = {
      url = "github:BLAKE3-team/BLAKE3";
      flake = false;
    };
  };

  outputs = inputs @ {
    nixpkgs,
    flake-parts,
    lean4-nix,
    blake3,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      flake = {
        lib = import ./blake3.nix;
        inputs.blake3 = blake3;
      };

      perSystem = {
        system,
        pkgs,
        ...
      }: 
      let
        lib = (import ./blake3.nix { inherit pkgs lean4-nix blake3; }).lib;
      in
      {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          overlays = [(lean4-nix.readToolchainFile ./lean-toolchain)];
        };

        packages = {
          test = lib.blake3-test.executable;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs.lean; [lean lean-all pkgs.gcc pkgs.clang ];
        };
      };
    };
}
