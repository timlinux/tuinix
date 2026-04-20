#!/usr/bin/env bash
# Build x86_64 ISO with progress tracking
set -e

echo "=========================================="
echo "Building tuinix x86_64 ISO"
echo "=========================================="
echo "Started: $(date)"
echo ""

# Build the ISO
nix build .#nixosConfigurations.installer.config.system.build.isoImage \
    --out-link result-x86_64 \
    --log-format bar-with-logs \
    -j auto --cores 0

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="

# Show result
if [[ -L result-x86_64 ]]; then
    ISO_PATH=$(find "$(readlink -f result-x86_64)" -name "*.iso" | head -1)
    if [[ -n "$ISO_PATH" ]]; then
        SIZE=$(du -h "$ISO_PATH" | cut -f1)
        echo "ISO: $ISO_PATH"
        echo "Size: $SIZE"

        # Copy to release name
        cp "$ISO_PATH" tuinix.v0.7.0.x86_64.iso
        echo "Copied to: tuinix.v0.7.0.x86_64.iso"
    fi
fi

echo "Finished: $(date)"
