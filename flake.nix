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
        # (D) Gather all X11‐related dev libraries into one variable so we can
        #     reference them in both `crosskeyPackage.buildInputs` and
        #     `devShells.default.buildInputs` without duplication.
        ############################################################################
        x11Libs = [
          pkgs.xorg.libX11
          pkgs.xorg.libXi
          pkgs.xorg.libXtst
        ];

        ############################################################################
        # (E) Define crosskeyPackage using `buildRustPackage`.  Notice:
        #     • We keep `nativeBuildInputs = [ pkgs.pkg-config ]` so that
        #       pkg-config is present during the build.
        #     • We add `x11Libs` to `buildInputs` so that all required `.pc`
        #       files (`x11.pc`, `xi.pc`, `xtst.pc`) are available.
        ############################################################################
        crosskeyPackage = rustPlatform.buildRustPackage rec {
          pname   = "crosskey";
          version = "0.1.1";  # must match Cargo.toml

          # (E.1) Point at this directory (auto‐detects Cargo.toml & Cargo.lock).
          src = ./.;

          # (E.2) After the first `nix build .#crosskey`, Nix will complain
          #       if cargoHash is wrong; copy the recommended hash here.
          cargoHash = "sha256-D3cG89b9+mATFUK0MBnTbzRMzLtkMymFrZlsfw3V5p8=";

          # (E.3) We still need `pkg-config` at build time for any crate
          #       whose build.rs invokes pkg-config (e.g. the `x11` crate).
          nativeBuildInputs = [ pkgs.pkg-config ];

          # (E.4) Add all the X11 dev libraries so that `x11.pc`, `xi.pc`,
          #       and `xtst.pc` are found automatically.
          buildInputs = x11Libs;
        };
      in
      {
        ########################################################################
        # (F) Expose crosskey so that `nix build .#crosskey` works
        ########################################################################
        packages.crosskey = crosskeyPackage;

        ########################################################################
        # (G) Expose it as an “app” so that `nix run .#crosskey` simply runs it
        ########################################################################
        apps.default = {
          type    = "app";
          program = "${crosskeyPackage}/bin/crosskey";
        };

        ########################################################################
        # (H) Expose a development shell.  `nix develop` provides:
        #     • pkgs.rustc, pkgs.cargo, pkgs.rustfmt, pkgs.clippy, pkgs.rust-analyzer
        #     • pkgs.pkg-config
        #     • all X11 dev libs in `x11Libs` (so that any x11‐dependent crate
        #       passes its pkg-config checks, e.g. for xi.pc and xtst.pc)
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
