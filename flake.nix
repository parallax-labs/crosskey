{
  description = "crosskey: a global key-overlay for highlighting Vim-style motions";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url  = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        ############################################################################
        # (A) Import the oxalica overlay so that `pkgs` has the latest Rust toolchain
        ############################################################################
        overlays = [ (import rust-overlay) ];
        pkgs     = import nixpkgs { inherit system overlays; };
        rustPkgs = pkgs.rustPlatform;

        ############################################################################
        # (B) Parse Cargo.toml to extract `package.version` exactly once
        ############################################################################
        cargoMeta = builtins.fromTOML (builtins.readFile ./Cargo.toml);
        version   = cargoMeta.package.version;  # e.g. "0.2.3"

        ############################################################################
        # (C) Consolidate all the X11‐related native libraries into one list
        ############################################################################
        x11Libs = [
          pkgs.xorg.libX11
          pkgs.xorg.libXi
          pkgs.xorg.libXtst
        ];

        ############################################################################
        # (D) Define crosskeyPackage using buildRustPackage with a manual cargoHash.
        #     • “version” is read from Cargo.toml
        #     • “cargoHash” must be replaced once (by running `nix build .#crosskey`)
        #     • “nativeBuildInputs” contains pkg-config so that any crate’s build.rs
        #       invoking pkg-config still works (x11 crate, etc.)
        #     • “buildInputs” includes the X11 dev libraries so x11.pc, xi.pc, xtst.pc
        #       are present in the Nix build environment.
        ############################################################################
        crosskeyPackage = rustPkgs.buildRustPackage rec {
          pname   = "crosskey";
          inherit version;

          # (D.1) Point at this directory (auto‐discovers Cargo.toml & Cargo.lock).
          src = ./.;

          # (D.2) This must match “cargo build --release”’s expectations. On first
          #       run, replace the “AAAAAAAA…” with the “got: sha256-…” you see.
          cargoHash = "sha256:vOntn8Y771WreK+TJny1YQBrlUPzwxUA9fkesOdiZkI=";

          # (D.3) We still need pkg-config at build time for any crate whose
          #       build.rs invokes pkg-config (notably the `x11` crate).
          nativeBuildInputs = [ pkgs.pkg-config ];

          # (D.4) Add the X11 dev libraries so that x11.pc, xi.pc, and xtst.pc
          #       exist in the environment, satisfying any pkg-config checks.
          buildInputs = x11Libs;
        };
      in
      {
        ########################################################################
        # (E) Expose crosskey so that `nix build .#crosskey` works.
        ########################################################################
        packages.crosskey = crosskeyPackage;

        ########################################################################
        # (F) Expose it as an “app” so that `nix run .#crosskey` just executes it.
        ########################################################################
        apps.default = {
          type    = "app";
          program = "${crosskeyPackage}/bin/crosskey";
        };

        ########################################################################
        # (G) Expose a development shell. `nix develop` will drop you into a
        #     shell with:
        #       • rustc, cargo, rustfmt, clippy, rust-analyzer
        #       • pkg-config
        #       • x11 dev libraries (libX11, libXi, libXtst)
        #     so that `cargo fmt`, `cargo clippy`, and `cargo test` “just work.”
        ########################################################################
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.rustc
            pkgs.cargo
            pkgs.rustfmt
            pkgs.clippy
            pkgs.rust-analyzer
            pkgs.pkg-config
          ] ++ x11Libs;

          shellHook = ''
            export RUST_SRC_PATH="${pkgs.rustc}/lib/rustlib/src/rust/library"
            echo "➡️  Entering crosskey devShell (rustc: $(rustc --version))"
          '';
        };
      }
    );
}
