{
  description = "Blake3 Nix Flake";

  inputs = {
    nixpkgs.follows = "lean4-nix/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    lean4-nix.url = "github:lenianiva/lean4-nix";
    blake3 = {
      url = "github:BLAKE3-team/BLAKE3?ref=refs/tags/1.8.2";
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
        lake2nix = pkgs.callPackage lean4-nix.lake {};
        commonArgs = {
          src = ./.;
          postPatch = ''
            substituteInPlace lakefile.lean --replace-fail 'GitRepo.execGit' '--GitRepo.execGit'
          '';
          preConfigure = ''
            ln -s ${blake3.outPath} ./blake3
          '';
        };
        blake3Lib = lake2nix.mkPackage (commonArgs
          // {
            name = "Blake3";
            buildLibrary = true;
            postInstall = ''
              cp -P ./blake3 $out
            '';
          });
        blake3Test = lake2nix.mkPackage (commonArgs
          // {
            name = "Blake3Test";
            lakeArtifacts = blake3Lib;
            installArtifacts = false;
          });
      in {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          overlays = [(lean4-nix.readToolchainFile ./lean-toolchain)];
        };

        packages = {
          default = blake3Lib;
          test = blake3Test;
        };
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            lean.lean-all
          ];
        };

        formatter = pkgs.alejandra;
      };
    };
}
