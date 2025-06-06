{
  description = "crosskey: a global key-overlay for highlighting Vim-style motions";

  inputs = {
    # 1) Pin to a recent nixpkgs (you can swap nixos-unstable for any branch/commit).
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    # 2) flake-utils for eachDefaultSystem
    flake-utils.url  = "github:numtide/flake-utils";
    # 3) oxalica/rust-overlay to get a Rust toolchain with edition2024 support
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        #############################################
        # (A) Import “base” nixpkgs for this system
        #############################################
        pkgs = import nixpkgs { inherit system; };

        ###################################################
        # (B) Import rust-overlay, passing in our pkgs set
        #     so that “ro.overlay” actually exists.
        ###################################################
        ro = import rust-overlay {
          inherit system;
          nixpkgs = pkgs;
        };

        ############################################################
        # (C) Re-import nixpkgs, applying ro.overlay to override Rust
        ############################################################
        rustPkgs = import nixpkgs {
          inherit system;
          overlays = [ ro.overlay ];
        };

        rustPlatform = rustPkgs.rustPlatform;

        ####################################################
        # (D) Build the “crosskey” binary with buildRustPackage
        ####################################################
        crosskeyPackage = rustPlatform.buildRustPackage rec {
          pname   = "crosskey";
          version = "0.1.0";  # must match Cargo.toml

          # D.1) Source directory (auto-detects Cargo.toml & Cargo.lock)
          src = ./.;

          # D.2) Placeholder; run `nix build .#crosskey` once to get the real hash.
          cargoSha256 = "0000000000000000000000000000000000000000000000000000";

          # D.3) If your crate (rdev) needs pkg-config at build time, keep this:
          nativeBuildInputs = [ rustPkgs.pkg-config ];

          # D.4) At runtime, if crosskey needs X11/libxcb on Linux you can add them:
          buildInputs = [ ];
        };
      in
      {
        #################################################
        # (E) Expose the crosskey package for “nix build”
        #################################################
        packages.crosskey = crosskeyPackage;

        ###############################################
        # (F) Expose as an “app” for “nix run .#crosskey”
        ###############################################
        apps.default = {
          type    = "app";
          program = "${crosskeyPackage}/bin/crosskey";
        };

        #################################################################
        # (G) Expose a development shell under devShells.default so that
        #     `nix develop` drops you into a shell with cargo, rustc, etc.
        #################################################################
        devShells.default = rustPkgs.mkShell {
          buildInputs = [
            rustPkgs.rustc
            rustPkgs.cargo
            rustPkgs.rustfmt
            rustPkgs.rust-analyzer
            rustPkgs.pkg-config
          ];
          shellHook = ''
            export RUST_SRC_PATH="${rustPkgs.rustc}/lib/rustlib/src/rust/library"
            echo "Entering crosskey devShell (rustc: $(rustc --version))"
          '';
        };
      }
    );
}
