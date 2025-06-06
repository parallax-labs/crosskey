{
  description = "crosskey: a global key-overlay for highlighting Vim-style motions";

  inputs = {
    # 1) Pin nixpkgs to a recent/unstable channel
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    # 2) flake-utils for cross-platform boilerplate
    flake-utils.url  = "github:numtide/flake-utils";
    # 3) oxalica/rust-overlay to pull in a Rust that supports edition2024
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        ######################################################
        # 1) Import the “base” nixpkgs for this system
        ######################################################
        pkgs = import nixpkgs { inherit system; };

        ######################################################
        # 2) Import rust-overlay as a Nix expression
        #    (Note: no `nixpkgs = pkgs` argument here!)
        #    This makes `ro` itself be an overlay function.
        ######################################################
        ro = import rust-overlay { };

        #################################################################
        # 3) Re‐import nixpkgs, but apply the `ro` overlay so that
        #    our Rust tools (rustc, cargo, buildRustPackage, etc.)
        #    come from the overlay (i.e. a modern toolchain).
        #################################################################
        rustPkgs = import nixpkgs {
          inherit system;
          overlays = [ ro ];
        };

        ################################################
        # 4) Alias the Rust platform from rust-overlay
        ################################################
        rustPlatform = rustPkgs.rustPlatform;

        ###########################################################
        # 5) Build the “crosskey” Rust package (edition2024-capable)
        ###########################################################
        crosskeyPackage = rustPlatform.buildRustPackage rec {
          pname   = "crosskey";
          version = "0.1.0";  # Must match Cargo.toml

          # 5a) Point at this directory; Nix will auto-find Cargo.toml & Cargo.lock
          src = ./.;

          # 5b) Placeholder hash. After the first build fails, copy the “got …” hash here.
          cargoSha256 = "0000000000000000000000000000000000000000000000000000";

          # 5c) If your crate uses `rdev` (or any C‐linked crate), keep pkg-config:
          nativeBuildInputs = [ rustPkgs.pkg-config ];

          # 5d) If at runtime you need X11/libxcb on Linux, add them here:
          buildInputs = [ ];
        };
      in
      {
        #######################################################
        # 6) Expose the “crosskey” package for `nix build .#crosskey`
        #######################################################
        packages.crosskey = crosskeyPackage;

        #######################################################
        # 7) Expose as an “app” so `nix run .#crosskey` works:
        #######################################################
        apps.default = {
          type    = "app";
          program = "${crosskeyPackage}/bin/crosskey";
        };

        #####################################################################
        # 8) Expose a development shell under `devShells.${system}.default`:
        #    `nix develop` will give you a shell with `rustc`, `cargo`, etc.
        #####################################################################
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
