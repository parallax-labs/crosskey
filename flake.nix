{
  description = "crosskey: a global key‐overlay for highlighting Vim‐style motions";

  inputs = {
    # We pin to a recent nixpkgs, but also pull in rust-overlay for a newer Rust toolchain.
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url  = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # 1) Import nixpkgs with the rust-overlay applied
        overlayedPkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay { inherit system; }).overlay ];
        };

        rustPkgs     = overlayedPkgs;
        rustPlatform = rustPkgs.rustPlatform;

        # 2) Build the crosskey Rust package using the newer Rust
        crosskeyPackage = rustPlatform.buildRustPackage rec {
          pname    = "crosskey";
          version  = "0.1.0";  # match your Cargo.toml

          src         = ./.;   # point at the directory containing Cargo.toml & Cargo.lock
          cargoSha256 = "0000000000000000000000000000000000000000000000000000";  
                         # placeholder: replace with the hash from the first `nix build` run

          nativeBuildInputs = [ rustPkgs.pkg-config ];
          buildInputs       = [ ];
        };
      in
      {
        ### 3) Expose the package so people can do:
        ###     nix profile install .#crosskey
        packages.crosskey = crosskeyPackage;

        ### 4) Expose it as an “app” so people can run:
        ###     nix run .#crosskey
        apps.default = {
          type    = "app";
          program = "${crosskeyPackage}/bin/crosskey";
        };

        ### 5) Export a development shell under `devShells.<system>.default`
        ###    instead of a top‐level `devShell = …`; this fixes the “expected a set but found a function” error.
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
