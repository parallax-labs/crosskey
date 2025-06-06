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
        # (A) Import the oxalica overlay function:
        #     (import rust-overlay) returns the overlay for this system.
        ############################################################################
        overlays = [ (import rust-overlay) ];

        ############################################################################
        # (B) Re-import nixpkgs with that overlay applied.
        ############################################################################
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        ############################################################################
        # (C) Alias rustPlatform so we can still build our package with `buildRustPackage`.
        ############################################################################
        rustPlatform = pkgs.rustPlatform;

        ############################################################################
        # (D) Define crosskeyPackage via `buildRustPackage` (Rust ≥1.80.0).
        ############################################################################
        crosskeyPackage = rustPlatform.buildRustPackage rec {
          pname   = "crosskey";
          version = "0.1.0";  # must match Cargo.toml

          # (D.1) Point at this directory (auto‐detects Cargo.toml & Cargo.lock).
          src = ./.;

          # (D.2) After the first `nix build .#crosskey`, Nix tells you the expected cargoSha256.
          cargoHash = "sha256:7XokwlfLlVkY/gGh9uReSw8T06tYc3IVI01k3n1IAjg=";

          # (D.3) If your crate’s build.rs uses pkg-config, list it here:
          nativeBuildInputs = [ pkgs.pkg-config ];

          # (D.4) If you need X11/libxcb at runtime, add them here. (Often unnecessary
          #       if you only link dynamically and the user has X11 installed.)
          buildInputs = [ ];
        };
      in
      {
        ########################################################################
        # (E) Expose crosskey so `nix build .#crosskey` works.
        ########################################################################
        packages.crosskey = crosskeyPackage;

        ########################################################################
        # (F) Expose it as an “app” so `nix run .#crosskey` simply executes it.
        ########################################################################
        apps.default = {
          type    = "app";
          program = "${crosskeyPackage}/bin/crosskey";
        };

        ########################################################################
        # (G) Expose a development shell (“nix develop”) with fmt, clippy, test.
        #
        #     We no longer pull `rustPlatform.rustc`—instead use `pkgs.rustc` etc.
        #     because the overlay has injected those into `pkgs`.
        ########################################################################
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.rustc
            pkgs.cargo
            pkgs.rustfmt
            pkgs.clippy
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
