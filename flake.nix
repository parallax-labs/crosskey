{
  description = "crosskey: a global key-overlay for highlighting Vim-style motions";

  inputs = {
    # 1) We need a recent nixpkgs with flakes enabled
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    # 2) flake-utils to iterate over systems
    flake-utils.url  = "github:numtide/flake-utils";
    # 3) oxalica/rust-overlay to get the latest Rust (stable, edition2024, etc.)
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        ############################################################################
        # (A) The only way to import the oxalica overlay is as a single function:
        #     (import rust-overlay).  That function will configure itself for the
        #     correct system internally.
        ############################################################################
        overlays = [ (import rust-overlay) ];

        ############################################################################
        # (B) Re-import nixpkgs, applying the oxalica/rust-overlay.  Now 'pkgs'
        #     has rustPlatform, rustc, cargo, etc., all at very latest stable.
        ############################################################################
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        ############################################################################
        # (C) Alias rustPlatform from the newly-overlayed pkgs
        ############################################################################
        rustPlatform = pkgs.rustPlatform;

        ############################################################################
        # (D) Define our crosskey buildRustPackage using that Rust ≥ 1.80.0
        ############################################################################
        crosskeyPackage = rustPlatform.buildRustPackage rec {
          pname   = "crosskey";
          version = "0.1.0";  # must match your Cargo.toml

          # (D.1) Source directory (auto-detects Cargo.toml & Cargo.lock)
          src = ./.;

          # (D.2) On first 'nix build .#crosskey', Nix will tell you the
          # cargoSha256 it expected. Paste that value here.
          cargoHash =  pkgs.lib.fakeSha256;
          # (D.3) If any dependencies (e.g. C libraries) require pkg-config, list them here:
          nativeBuildInputs = [ pkgs.pkg-config ];

          # (D.4) If you need X11/libxcb or other runtime libs, add them here:
          buildInputs = [ ];
        };
      in
      {
        ########################################################################
        # (E) Expose crosskey so 'nix build .#crosskey' works
        ########################################################################
        packages.crosskey = crosskeyPackage;

        ########################################################################
        # (F) Expose it as an 'app' so that 'nix run .#crosskey' just runs it
        ########################################################################
        apps.default = {
          type    = "app";
          program = "${crosskeyPackage}/bin/crosskey";
        };

        ########################################################################
        # (G) Expose a development shell.  'nix develop' will drop you into a
        #     shell with rustc, cargo, rustfmt, rust-analyzer, and pkg-config.
        ########################################################################
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.rustc
            pkgs.cargo
            pkgs.rustfmt
            pkgs.rust-analyzer
            pkgs.pkg-config
          ];

          shellHook = ''
            export RUST_SRC_PATH="${pkgs.rustc}/lib/rustlib/src/rust/library"
            echo "➡️  Entering crosskey devShell (rustc: $(rustc --version))"
          '';
        };
      }
    );
}
