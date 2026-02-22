#!/usr/bin/env bash
# Build R36S SD image with progress tracking
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Building tuinix R36S SD Image (armv7l)"
echo "=========================================="
echo "Started: $(date)"
echo "Note: This build requires cross-compilation and may take a long time"
echo ""

# Get number of CPU cores for maximum parallelism
CORES=$(nproc)
echo "Using $CORES cores for compilation"
echo ""

cd "$PROJECT_DIR"

# Build the main SD image with maximum parallelism and cache
nix build .#sd-r36s \
    --out-link result-r36s \
    --log-format bar-with-logs \
    --option cores "$CORES" \
    --option max-jobs "$CORES" \
    --option substituters "https://cache.nixos.org https://nix-community.cachix.org" \
    --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" \
    --keep-going \
    -L

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="

# Show result
if [[ -L result-r36s ]]; then
    RESULT_PATH=$(readlink -f result-r36s)
    # Check for SD image file
    SD_IMG=$(find "$RESULT_PATH" -name "*.img" -o -name "*.img.zst" 2>/dev/null | head -1)
    if [[ -n "$SD_IMG" ]]; then
        SIZE=$(du -h "$SD_IMG" | cut -f1)
        echo "SD Image: $SD_IMG"
        echo "Size: $SIZE"

        # Copy to release name
        BASENAME=$(basename "$SD_IMG")
        cp "$SD_IMG" "tuinix.v0.6.0.r36s.$BASENAME"
        echo "Copied to: tuinix.v0.6.0.r36s.$BASENAME"
    else
        echo "Result path: $RESULT_PATH"
        ls -la "$RESULT_PATH"
    fi
fi

echo "Finished: $(date)"
