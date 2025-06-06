{ pkgs ? import <nixpkgs> {
    overlays = [
      (import (builtins.fetchTarball "https://github.com/oxalica/rust-overlay/archive/master.tar.gz"))
    ];
  }
}:

let
  rustToolchain = pkgs.rust-bin.stable.latest.default.override {
    extensions = [ "rust-src" "rust-analyzer" ];
  };
in

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    rustToolchain
    rustfmt
    lua-language-server
    nodejs
    typescript
    openssl
    pkg-config
    jq
    nodePackages.nodemon
    yarn
    docker
    docker-compose
  ];

  shellHook = ''
    export RUST_SRC_PATH="${rustToolchain}/lib/rustlib/src/rust/library"
    echo 'Development environment initialized.'
  '';
}
