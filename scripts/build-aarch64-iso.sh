#!/usr/bin/env bash
# Build aarch64 ISO with progress tracking
set -e

cd "$(dirname "${BASH_SOURCE[0]}")/.."
VERSION="v$(tr -d '[:space:]' <VERSION)"

# Works both in CI (features preconfigured) and on stock nix installs
export NIX_CONFIG="experimental-features = nix-command flakes"

echo "=========================================="
echo "Building tuinix $VERSION aarch64 ISO"
echo "=========================================="
echo "Started: $(date)"
echo ""

# Refresh build provenance from the VERSION file (single point of truth)
./scripts/build-version.sh

# Build the ISO
nix build .#nixosConfigurations.installer-aarch64.config.system.build.isoImage \
    --out-link result-aarch64 \
    --log-format bar-with-logs \
    -j auto --cores 0

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="

# Show result
if [[ -L result-aarch64 ]]; then
    ISO_PATH=$(find "$(readlink -f result-aarch64)" -name "*.iso" | head -1)
    if [[ -n "$ISO_PATH" ]]; then
        SIZE=$(du -h "$ISO_PATH" | cut -f1)
        echo "ISO: $ISO_PATH"
        echo "Size: $SIZE"

        # Copy out under its canonical name (tuinix-<arch>-<version>.iso)
        # and generate a matching .md5 checksum
        ISO_NAME=$(basename "$ISO_PATH")
        cp "$ISO_PATH" "./$ISO_NAME"
        md5sum "$ISO_NAME" >"${ISO_NAME%.iso}.md5"
        echo "Copied to:  ./$ISO_NAME"
        echo "Checksum:   ./${ISO_NAME%.iso}.md5"
    fi
fi

echo "Finished: $(date)"
