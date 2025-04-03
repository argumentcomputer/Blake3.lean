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

      perSystem = {
        system,
        pkgs,
        ...
      }: let
        lib = (import ./blake3.nix {inherit pkgs lean4-nix blake3;}).lib;
      in {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          overlays = [(lean4-nix.readToolchainFile ./lean-toolchain)];
        };

        packages = {
          default = ((lean4-nix.lake {inherit pkgs;}).mkPackage {
            src = ./.;
            roots = ["Blake3Test"];
            deps = [lib.blake3-lib];
            staticLibDeps = [ "${lib.blake3-c}/lib" ];
          })
          .executable;
          # Downstream lean4-nix packages must also link to the static lib using the `staticLibDeps` attribute.
          # See https://github.com/argumentcomputer/lean4-nix/blob/dev/templates/dependency/flake.nix for an example
          staticLib = lib.blake3-c;
        };
        devShells.default = pkgs.mkShell {
          packages = with pkgs.lean; [lean lean-all pkgs.gcc pkgs.clang];
        };

        formatter = pkgs.alejandra;
      };
    };
}
