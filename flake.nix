{
  description = "crosskey: a global key‐overlay for highlighting Vim‐style motions";

  inputs = {
    # Pin to a recent nixpkgs that definitely has `rustc` and `cargo`.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05"; 
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Import nixpkgs for this system
        pkgs = import nixpkgs {
          inherit system;
        };

        # For building the Rust package, use the standard Rust Platform
        rustPlatform = pkgs.rustPlatform;
        crosskeyPackage = rustPlatform.buildRustPackage rec {
          pname = "crosskey";
          version = "0.1.0";  # match your Cargo.toml version

          # Source is the current directory
          src = ./.;

          # Use your Cargo.lock for reproducible builds
          cargoLock = ./Cargo.lock;
          
          # The first time you run `nix build .#crosskey` you will see
          # a hash mismatch error. Copy the “got …” hash into cargoSha256
          cargoSha256 = "0000000000000000000000000000000000000000000000000000";

          # If your crate calls pkg-config or links to native libraries,
          # put pkg-config (or the needed -dev packages) here. Otherwise, you can leave it empty.
          nativeBuildInputs = [ pkgs.pkg-config ];

          # At runtime, if you depend on X11 or other C libraries, add them here.
          # For a pure cross-platform Rust-only crate with `rdev`, you might need
          # `libX11` or `libxcb` on Linux. If you run into run-time errors, add them here.
          buildInputs = [];
        };

      in
      {
        ### 1) Expose the `crosskey` package so that users can do:
        ###      nix profile install github:you/your-repo#crosskey
        packages.crosskey = crosskeyPackage;

        ### 2) Expose it as an “app” so people can run:
        ###      nix run github:you/your-repo#crosskey
        apps.default = {
          type = "app";
          program = "${crosskeyPackage}/bin/crosskey";
        };

        ### 3) A development shell (replacing your old shell.nix)
        devShell = pkgs.mkShell {
          buildInputs = [
            # Rust compiler and Cargo
            pkgs.rustc
            pkgs.cargo

            # Formatters / analyzers you may want
            pkgs.rustfmt
            pkgs.rust-analyzer

            # pkg-config in case `rdev` or another crate needs to find C libs
            pkgs.pkg-config
          ];

          # If you need environment variables for Rust access, set them here:
          shellHook = ''
            # If you want to point RUST_SRC_PATH to the standard library source:
            export RUST_SRC_PATH="${pkgs.rustc}/lib/rustlib/src/rust/library"
            echo "Entering crosskey devShell"
          '';
        };
      }
    );
}
