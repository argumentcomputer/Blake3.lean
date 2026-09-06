{
  description = "Blake3 Nix Flake";

  nixConfig = {
    extra-substituters = [
      "https://argumentcomputer.cachix.org"
    ];
    extra-trusted-public-keys = [
      "argumentcomputer.cachix.org-1:ovhbTx1V56BYDerOWInQvXKXl68LlhNwEA+n7EWk1m4="
    ];
  };

  inputs = {
    nixpkgs.follows = "lean4-nix/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    lean4-nix.url = "github:argumentcomputer/lean4-nix";
    blake3 = {
      url = "github:BLAKE3-team/BLAKE3?ref=refs/tags/1.8.7";
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

  outputs =
    inputs@{
      flake-parts,
      lean4-nix,
      blake3,
      fenix,
      crane,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem =
        {
          system,
          pkgs,
          ...
        }:
        let
          # Pins the Lean toolchain; a plain derivation, no overlay involved
          lean = lean4-nix.lib.${system}.fromToolchainFile ./lean-toolchain;

          lake2nix = pkgs.callPackage lean4-nix.lake { inherit lean; };

          # Filter out build directories
          lakeSrc = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter =
              path: type:
              let
                name = builtins.baseNameOf path;
              in
              name != "target" && name != ".lake" && name != "build";
          };

          # Lakefile patches for Nix builds
          disableGitClone = ''
            substituteInPlace lakefile.lean --replace-fail 'GitRepo.execGit' '--GitRepo.execGit'
          '';
          # Don't build the `blake3_rs` static lib with Lake, since we build it with Crane
          disableCargoBuild = ''
            substituteInPlace lakefile.lean --replace-fail 'proc { cmd := "cargo"' '--proc { cmd := "cargo"'
          '';
          # `-fn` so it overwrites the symlink rsynced in from a prior stage's `.lake`
          linkBlake3Src = ''
            mkdir -p .lake
            ln -sfn ${blake3.outPath} .lake/blake3-source
          '';
          # Copy the `blake3_rs` static lib from Crane to `target/release` so Lake can use it
          linkRustLib = ''
            mkdir -p rust/target/release
            ln -s ${rustPkg}/lib/libblake3_rs.a rust/target/release/
          '';

          # Pins the Rust toolchain
          rustToolchain = fenix.packages.${system}.fromToolchainFile {
            file = ./rust-toolchain.toml;
            sha256 = "sha256-p8h3Sl/YRByZfZTAKXdsvF6xEenXKrXSVvpphmZENH4=";
          };

          # Rust package
          craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
          craneArgs = {
            src = craneLib.cleanCargoSource ./rust;
            strictDeps = true;

            # `lean-ffi` uses `LEAN_SYSROOT` to locate `lean.h` for bindgen
            LEAN_SYSROOT = "${lean}";
            # bindgen needs libclang to parse C headers
            LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

            buildInputs =
              [ ]
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
                # Additional darwin specific inputs can be set here
                pkgs.libiconv
              ];
          };
          # Build dependencies once and share them across the package build and
          # the clippy check instead of recompiling them per consumer.
          cargoArtifacts = craneLib.buildDepsOnly craneArgs;
          # doCheck = false: the crate has no Rust unit tests, and the Lean
          # `blake3-test` check is where the suite runs.
          rustPkg = craneLib.buildPackage (
            craneArgs
            // {
              inherit cargoArtifacts;
              doCheck = false;
            }
          );

          blake3C = lake2nix.mkPackage {
            name = "Blake3C";
            src = lakeSrc;
            buildLibrary = true;
            postPatch = disableGitClone;
            preConfigure = linkBlake3Src;
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
        in
        {
          packages = {
            default = blake3C;
            rust = blake3Rust;
          };

          checks = {
            # Lint the Rust FFI crate; the lint set lives in rust/Cargo.toml and
            # CARGO_BUILD_WARNINGS promotes local-package warnings to errors.
            clippy = craneLib.cargoClippy (
              craneArgs
              // {
                inherit cargoArtifacts;
                CARGO_BUILD_WARNINGS = "deny";
                cargoClippyExtraArgs = "--all-targets";
              }
            );
            # Run the Lean test suite (exercises both the C and Rust backends)
            # at check time so it runs via `nix flake check`.
            blake3-test = pkgs.runCommand "blake3-test" { } ''
              ${blake3Test}/bin/Blake3Test
              touch $out
            '';
          };
          devShells.default = pkgs.mkShell {
            # Add libclang for FFI with rust-bindgen
            LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
            packages = with pkgs; [
              clang
              lean
              rustToolchain
              rust-analyzer
            ];
          };

          # The treefmt wrapper around `nixfmt`, so `nix fmt .` can take a
          # directory; bare `nixfmt` only accepts individual files.
          formatter = pkgs.nixfmt-tree;
        };
    };
}
