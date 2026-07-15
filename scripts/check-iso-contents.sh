#!/usr/bin/env bash

# Verify the flake evaluates using ONLY the files shipped on the
# installer ISO (the isoImage.contents list in installer.nix).
#
# This catches the "works in the repo, fails during install" class of
# bug where flake.nix or a module references a directory that never
# made it onto the ISO (e.g. software/ or profiles/ missing from
# isoImage.contents caused nixos-install to fail with
# "path '...-source/software' does not exist").
#
# It also evaluates the config with ALL package collections enabled so
# a package that fails to evaluate (renamed, insecure, removed) is
# caught in CI instead of on a user's machine at install time.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Works both in CI (features preconfigured) and on stock nix installs
export NIX_CONFIG="experimental-features = nix-command flakes"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Extract the ./ source paths from isoImage.contents in installer.nix
mapfile -t sources < <(sed -n 's|^ *source = \./\(.*\);$|\1|p' installer.nix)

if [[ ${#sources[@]} -eq 0 ]]; then
    echo "ERROR: could not extract isoImage.contents sources from installer.nix" >&2
    exit 1
fi

echo "Staging ISO-equivalent flake subset (${#sources[@]} entries):"
for src in "${sources[@]}"; do
    echo "  - $src"
    mkdir -p "$tmp/$(dirname "$src")"
    cp -rL "$src" "$tmp/$src"
done

echo
echo "Evaluating host config from the ISO subset (as nixos-install would)..."
nix eval "path:$tmp#nixosConfigurations.laptop.config.system.build.toplevel.drvPath" \
    --apply 'x: "ok"'

echo "Evaluating with ALL package collections enabled..."
nix eval --impure --expr "
  let f = builtins.getFlake \"path:$tmp\";
  in (f.nixosConfigurations.laptop.extendModules {
    modules = [{
      tuinix.packages = {
        tui = true;
        pentest = true;
        games = true;
        music = true;
        emergency = true;
      };
    }];
  }).config.system.build.toplevel.drvPath" --apply 'x: "ok"'

echo
echo "OK: the ISO ships everything the flake needs."
