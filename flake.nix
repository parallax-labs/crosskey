{
  description = "crosskey: a global key-overlay for highlighting Vim-style motions";

  inputs = {
    # We pin to a recent nixpkgs so that buildRustPackage still works,
    # but we want a newer Rust too (for edition2024).
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url  = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Import nixpkgs for this system, with rust-overlay overlaid:
        overlayedPkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay { inherit system; }).overlay ];
        };

        # Now the overlayedPkgs has a modern rustPlatform, rustc, cargo, etc.
        rustPkgs = overlayedPkgs;
        rustPlatform = rustPkgs.rustPlatform;

        # Build the crosskey Rust package:
        crosskeyPackage = rustPlatform.buildRustPackage rec {
          pname = "crosskey";
          version = "0.1.0"; # match your Cargo.toml

          src = ./.;  # this directory (contains Cargo.toml & Cargo.lock)

          # Do not specify cargoLock = ...; newer buildRustPackage auto-detects it.
          cargoSha256 = "0000000000000000000000000000000000000000000000000000";

          nativeBuildInputs = [ rustPkgs.pkg-config ];
          buildInputs       = [ ];

          # If you need X11 at runtime (Linux), you could add:
          # buildInputs = [ rustPkgs.libX11 rustPkgs.libxcb ];
        };
      in
      {
        # Expose the package so that people can do:
        #    nix profile install .#crosskey
        packages = {
          crosskey = crosskeyPackage;
        };

        # Expose it as an “app” so people can run:
        #    nix run .#crosskey
        apps = {
          default = {
            type = "app";
            program = "${crosskeyPackage}/bin/crosskey";
          };
        };

        # Expose a development shell under `devShells.${system}.default`
        devShells = {
          default = rustPkgs.mkShell {
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
        };
      }
    );
}
