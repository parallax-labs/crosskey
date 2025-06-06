{
  description = "crosskey: a global key-overlay for highlighting Vim‐style motions";

  # 1. Inputs: pull in nixpkgs and flake-utils
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";  # or whichever branch/revision you prefer
    flake-utils.url = "github:numtide/flake-utils";
  };

  # 2. Outputs: build packages, apps, and a devShell.
  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # (you can override any Nixpkgs options here if needed)
        };

        # Use the “rustPlatform” from nixpkgs to build a Rust package:
        rust = pkgs.rust-bin.stable.default;

        # We’ll use buildRustPackage to turn Cargo.toml into a Nix derivation:
        crosskeyPackage = pkgs.rustPlatform.buildRustPackage rec {
          pname = "crosskey";
          version = "0.1.0";  # bump this if you tag a new version

          # 3. Tell Nix where to find the source:
          src = ./.;

          # 4. Point at Cargo.lock so that Nix can lock dependencies:
          cargoLock = ./Cargo.lock;

          # 5. Supply a placeholder cargoSha256; the first `nix build` will tell you the correct hash:
          cargoSha256 = "0000000000000000000000000000000000000000000000000000";

          # 6. If your project needs pkg-config (e.g. for linking against a C library),
          #    you can add it to nativeBuildInputs. If not, you can remove this.
          nativeBuildInputs = [ pkgs.pkg-config ];

          # 7. If crosskey needs any dynamic libraries at runtime (e.g. gtk, x11, etc.),
          #    add them to `buildInputs`. Often “rdev” works out of the box, but if you run
          #    into missing libraries, add them here. For a pure Rust-only crate, you can leave it empty.
          buildInputs = [];

          # 8. Example: If you do need `libxcb` or `libx11` on Linux, you might do:
          # buildInputs = [ pkgs.libX11 pkgs.libxcb ];

          # 9. You can override the default `cargoFetch` or `cargoSha256` usage if you want,
          #    but for most projects the boilerplate above is sufficient.
        };

      in
      {
        # 10. Expose “packages.crosskey” so that users can install via
        #      `nix profile install github:you/your-repo#crosskey`.
        packages.crosskey = crosskeyPackage;

        # 11. Optionally, expose it as an “app” so that flake‐apps can run it directly.
        #     On macOS, this will register a “.app” wrapper if possible; on Linux, it’s just a shell script.
        apps.default = {
          type = "app"; # a simple executable “app”
          program = "${crosskeyPackage}/bin/crosskey";
        };

        # 12. Provide a devShell for development (similar to your shell.nix but flakes-based).
        devShell = pkgs.mkShell {
          buildInputs = [
            # You’ll want rustc, cargo, rustfmt, and maybe rust-analyzer:
            pkgs.rust-bin.stable.default
            pkgs.rustfmt
            pkgs.rust-analyzer
            pkgs.pkg-config
          ];

          # Optional: if you need to set environment variables, do so here:
          shellHook = ''
            export RUST_SRC_PATH="${pkgs.rust-bin.stable.default}/lib/rustlib/src/rust/library"
            echo "Entering crosskey dev shell"
          '';
        };
      }
    );
}
