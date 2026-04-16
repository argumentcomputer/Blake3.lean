{
  description = "Blake3 Nix Flake";

  inputs = {
    nixpkgs.follows = "lean4-nix/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    lean4-nix.url = "github:lenianiva/lean4-nix";
    blake3 = {
      url = "github:BLAKE3-team/BLAKE3?ref=refs/tags/1.8.4";
      flake = false;
    };
    # Rust-related inputs
    fenix = {
      url = "github:nix-community/fenix";
      # Follow lean4-nix nixpkgs so we stay in sync
      inputs.nixpkgs.follows = "lean4-nix/nixpkgs";
    };

    crane.url = "github:ipetkov/crane";
  };

  outputs = inputs @ {
    nixpkgs,
    flake-parts,
    lean4-nix,
    blake3,
    fenix,
    crane,
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

        # Filter out build directories
        lakeSrc = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = path: type: let
            name = builtins.baseNameOf path;
          in
            name
            != "target"
            && name != ".lake"
            && name
            != "build";
        };

        # Lakefile patches for Nix builds
        disableGitClone = ''
          substituteInPlace lakefile.lean --replace-fail 'GitRepo.execGit' '--GitRepo.execGit'
        '';
        # Don't build the `blake3_rs` static lib with Lake, since we build it with Crane
        disableCargoBuild = ''
          substituteInPlace lakefile.lean --replace-fail 'proc { cmd := "cargo"' '--proc { cmd := "cargo"'
        '';
        linkBlake3Src = ''
          ln -s ${blake3.outPath} ./blake3
        '';
        # Copy the `blake3_rs` static lib from Crane to `target/release` so Lake can use it
        linkRustLib = ''
          mkdir -p rust/target/release
          ln -s ${rustPkg}/lib/libblake3_rs.a rust/target/release/
        '';

        # Pins the Rust toolchain
        rustToolchain = fenix.packages.${system}.fromToolchainFile {
          file = ./rust-toolchain.toml;
          sha256 = "sha256-sqSWJDUxc+zaz1nBWMAJKTAGBuGWP25GCftIOlCEAtA=";
        };

        # Rust package
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        rustPkg = craneLib.buildPackage {
          src = craneLib.cleanCargoSource ./rust;
          strictDeps = true;

          # `lean-ffi` uses `LEAN_SYSROOT` to locate `lean.h` for bindgen
          LEAN_SYSROOT = "${pkgs.lean.lean-all}";
          # bindgen needs libclang to parse C headers
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

          buildInputs =
            []
            ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              # Additional darwin specific inputs can be set here
              pkgs.libiconv
            ];
        };

        blake3C = lake2nix.mkPackage {
          name = "Blake3C";
          src = lakeSrc;
          buildLibrary = true;
          postPatch = disableGitClone;
          preConfigure = linkBlake3Src;
          postInstall = ''
            cp -rP ./blake3 $out
          '';
        };

        blake3Rust = lake2nix.mkPackage {
          name = "Blake3Rust";
          src = lakeSrc;
          postPatch = disableCargoBuild;
          postConfigure = linkRustLib;
          postInstall = ''
            cp -rP rust/target/ $out/rust/target/
          '';
        };

        blake3Test = lake2nix.mkPackage {
          name = "Blake3Test";
          src = lakeSrc;
          installArtifacts = false;
          # Merge .lake artifacts from both C and Rust library builds
          prePatch = ''
            rsync -a ${blake3C}/.lake/ .lake/
            rsync -a ${blake3Rust}/.lake/ .lake/
            chmod -R +w .lake
          '';
          postPatch = disableGitClone + disableCargoBuild;
          preConfigure = linkBlake3Src;
          postConfigure = linkRustLib;
        };
      in {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          overlays = [(lean4-nix.readToolchainFile ./lean-toolchain)];
        };

        packages = {
          default = blake3C;
          rust = blake3Rust;
          test = blake3Test;
        };
        devShells.default = pkgs.mkShell {
          # Add libclang for FFI with rust-bindgen
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
          packages = with pkgs; [
            clang
            lean.lean-all
            rustToolchain
            rust-analyzer
          ];
        };

        formatter = pkgs.alejandra;
      };
    };
}
