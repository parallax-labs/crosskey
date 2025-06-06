{
  description = "crosskey: a global key-overlay for highlighting Vim-style motions";

  inputs = {
    # 1) We need a recent nixpkgs with flakes enabled
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";

    # 2) flake-utils to iterate over systems
    flake-utils.url  = "github:numtide/flake-utils";

    # 3) oxalica/rust-overlay to get the latest Rust toolchains
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        ############################################################################
        # (A) Import the oxalica overlay function: (import rust-overlay) yields
        #     an overlay that sets up a recent Rust toolchain on this `system`.
        ############################################################################
        overlays = [ (import rust-overlay) ];

        ############################################################################
        # (B) Re‐import nixpkgs with that overlay applied: `pkgs` now has a
        #     fresh Rust (≥1.80), Clippy, rustfmt, rust-analyzer, etc.
        ############################################################################
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        ############################################################################
        # (C) Alias “rustPlatform” so we can still build our package via
        #     `rustPlatform.buildRustPackage` (it uses the overlayed Rust).
        ############################################################################
        rustPlatform = pkgs.rustPlatform;

        ############################################################################
        # (D) Define crosskeyPackage using `buildRustPackage`.  Notice:
        #     • We keep `nativeBuildInputs = [ pkgs.pkg-config ]` so that
        #       `pkg-config` is present during the build.
        #     • We add `pkgs.xorg.libX11` to `buildInputs` so that an
        #       `x11.pc` file exists (from Nixpkgs) when the `x11` crate’s
        #       build.rs calls `pkg-config --cflags --libs x11`.
        ############################################################################
        crosskeyPackage = rustPlatform.buildRustPackage rec {
          pname   = "crosskey";
          version = "0.1.0";  # must match Cargo.toml

          # (D.1) Point at this directory (auto‐detects Cargo.toml & Cargo.lock).
          src = ./.;

          # (D.2) After the first `nix build .#crosskey`, Nix will complain
          #       if cargoHash is wrong; copy the recommended hash here.
          cargoHash = "sha256:7XokwlfLlVkY/gGh9uReSw8T06tYc3IVI01k3n1IAjg=";

          # (D.3) We still need `pkg-config` at build time for any crate
          #       whose build.rs invokes pkg-config (e.g. the `x11` crate).
          nativeBuildInputs = [ pkgs.pkg-config ];

          # (D.4) Add the X11 dev library so that `x11.pc` is found:
          #       “x11 >= 1.4.99.1” will resolve via this Nixpkgs attribute.
          buildInputs = [ pkgs.xorg.libX11 ];
        };
      in
      {
        ########################################################################
        # (E) Expose crosskey so that `nix build .#crosskey` works
        ########################################################################
        packages.crosskey = crosskeyPackage;

        ########################################################################
        # (F) Expose it as an “app” so that `nix run .#crosskey` simply runs it
        ########################################################################
        apps.default = {
          type    = "app";
          program = "${crosskeyPackage}/bin/crosskey";
        };

        ########################################################################
        # (G) Expose a development shell.  `nix develop` provides:
        #     • pkgs.rustc, pkgs.cargo, pkgs.rustfmt, pkgs.clippy, pkgs.rust-analyzer
        #     • pkgs.pkg-config
        #     • pkgs.xorg.libX11  (so that any `x11`‐dependent crate’s pkg-config
        #       check succeeds in `cargo test`, etc.)
        ########################################################################
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.rustc
            pkgs.cargo
            pkgs.rustfmt
            pkgs.clippy
            pkgs.rust-analyzer
            pkgs.pkg-config

            # ← This is crucial for the `x11` crate’s build.rs
            pkgs.xorg.libX11
          ];

          shellHook = ''
            export RUST_SRC_PATH="${pkgs.rustc}/lib/rustlib/src/rust/library"
            echo "➡️  Entering crosskey devShell (rustc: $(rustc --version))"
          '';
        };
      }
    );
}
