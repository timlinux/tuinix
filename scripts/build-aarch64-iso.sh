#!/usr/bin/env bash
# Build aarch64 ISO with progress tracking
set -e

echo "=========================================="
echo "Building tuinix aarch64 ISO"
echo "=========================================="
echo "Started: $(date)"
echo ""

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

        # Copy to release name
        cp "$ISO_PATH" tuinix.v0.7.0.aarch64.iso
        echo "Copied to: tuinix.v0.7.0.aarch64.iso"
    fi
fi

echo "Finished: $(date)"
