#!/usr/bin/env bash
# tuinix rebuild script - rebuilds the system from the local flake
# Usage: ./scripts/rebuild.sh [switch|boot|test]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"
HOSTNAME="$(hostname)"
ACTION="${1:-switch}"

case "$ACTION" in
  switch|boot|test)
    ;;
  *)
    echo "Usage: $0 [switch|boot|test]"
    echo "  switch - Build and activate immediately (default)"
    echo "  boot   - Build and activate on next boot"
    echo "  test   - Build and activate, but don't add to boot menu"
    exit 1
    ;;
esac

if [ ! -f "$FLAKE_DIR/flake.nix" ]; then
  echo "Error: flake.nix not found in $FLAKE_DIR"
  exit 1
fi

cd "$FLAKE_DIR"

echo "Rebuilding NixOS from $FLAKE_DIR for host $HOSTNAME..."
echo "Action: $ACTION"
echo ""

if sudo nixos-rebuild "$ACTION" --fast --flake ".#$HOSTNAME" --option max-jobs auto; then
  echo "Rebuild completed successfully!"

  read -rp "Clean up old generations and run garbage collection? [y/N] " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Cleaning up old generations (keeping last 10)..."
    sudo nix-env --delete-generations +10 --profile /nix/var/nix/profiles/system

    if command -v home-manager >/dev/null 2>&1; then
      echo "Cleaning up home-manager generations (keeping last 10)..."
      home-manager expire-generations '-10'
    fi

    echo "Running garbage collection..."
    sudo nix-collect-garbage
    echo "Cleanup completed!"
  else
    echo "Skipping cleanup."
  fi
else
  echo "Rebuild failed! Skipping cleanup for safety."
  exit 1
fi
