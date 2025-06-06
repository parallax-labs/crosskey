#!/usr/bin/env bash
set -euo pipefail

################################################################################
# bump-version.sh
#
# Usage:
#   ./bump-version.sh <new-version>
#
# Example:
#   ./bump-version.sh 0.2.2
#
# This script will:
#   1) Update Cargo.toml’s version = "<new-version>"
#   2) Update flake.nix’s version = "<new-version>"
#   3) Clear out flake.nix’s cargoHash temporarily
#   4) Run `nix build .#crosskey --no-link` to compute the new hash
#   5) Parse the new hash from the “got:    sha256-…” line
#   6) Rewrite flake.nix with cargoHash = "sha256:<new-hash>"
#
# At the end, Cargo.toml and flake.nix will be in sync.
################################################################################

if [ $# -ne 1 ]; then
  echo "Usage: $0 <new-version>"
  exit 1
fi

newver="$1"
echo "→ Bumping version to $newver …"

# 1) Update Cargo.toml’s version
if grep -q '^version = ' Cargo.toml; then
  sed -E -i.bak "s/^version = \".*\"/version = \"${newver}\"/" Cargo.toml
  rm Cargo.toml.bak
  echo "  • Cargo.toml → version = \"${newver}\""
else
  echo "✖️  Could not find 'version = \"…\"' in Cargo.toml"
  exit 1
fi

# 2) Update flake.nix’s version = "<…>"
if grep -q '^[[:space:]]*version = ' flake.nix; then
  sed -E -i.bak "s/^[[:space:]]*version = \".*\"/  version = \"${newver}\"/" flake.nix
  rm flake.nix.bak
  echo "  • flake.nix → version = \"${newver}\""
else
  echo "✖️  Could not find a 'version = \"…\"' line in flake.nix"
  exit 1
fi

# 3) Clear out the old cargoHash so Nix will recompute
if grep -q '^[[:space:]]*cargoHash = ' flake.nix; then
  sed -E -i.bak "s/^[[:space:]]*cargoHash = \".*\"/  cargoHash = \"\"/" flake.nix
  rm flake.nix.bak
  echo "  • flake.nix → cleared cargoHash (to force recomputation)"
else
  echo "✖️  Could not find a 'cargoHash = \"…\"' line in flake.nix"
  exit 1
fi

# 4) Run `nix build .#crosskey --no-link` to force recomputation of the hash
echo "  • Running 'nix build .#crosskey --no-link' to compute new cargoSha256 …"
build_err="$(nix build .#crosskey --no-link 2>&1 || true)"

# 5) Extract the new hash from a line like:
#       got:    sha256-JErbK1DMpLNk4mw4veYNgDsQaF+WmrDdTFnLIGYeW+Q=
#    We grep for “got:” and then use sed to pull out the characters after “sha256-”
if echo "$build_err" | grep -q 'got:'; then
  newhash="$(echo "$build_err" \
    | grep 'got:' \
    | head -n1 \
    | sed -E 's/.*got:\s*sha256-([A-Za-z0-9+/=]+).*/\1/')"

  if [ -z "$newhash" ]; then
    echo
    echo "✖️  Failed to parse new hash from Nix output."
    exit 1
  fi

  echo "  • Computed new cargoHash = \"$newhash\""
else
  echo
  echo "✖️  Unexpected output from nix build. Could not find a 'got:    sha256-…' line."
  echo "Nix stderr:"
  echo "------------------------------------------------------"
  echo "$build_err"
  echo "------------------------------------------------------"
  exit 1
fi

# 6) Rewrite flake.nix, replacing the blank cargoHash with the new one.
#    Use '|' as the sed delimiter so that any '/' in $newhash does not break the expression.
sed -E -i.bak "s|^[[:space:]]*cargoHash = \"\"|  cargoHash = \"sha256:${newhash}\"|" flake.nix
rm flake.nix.bak
echo "  • flake.nix → updated cargoHash to \"sha256:${newhash}\""

echo
echo "✅  Bumped version to ${newver} and updated cargoHash in flake.nix."
