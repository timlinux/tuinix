#!/usr/bin/env bash
# Upload R36S SD image to GitHub release
set -e

RELEASE_TAG="v0.6.0"

echo "=========================================="
echo "Uploading R36S SD Image to GitHub Release"
echo "=========================================="

# Find the R36S image file
SD_FILE=$(ls tuinix.v0.6.0.r36s.*.img* 2>/dev/null | head -1)

if [[ -z "$SD_FILE" ]]; then
    echo "ERROR: R36S SD image not found!"
    echo "Looking for: tuinix.v0.6.0.r36s.*.img*"
    echo "Run scripts/build-r36s-sd.sh first"
    exit 1
fi

SIZE=$(du -h "$SD_FILE" | cut -f1)
echo "File: $SD_FILE"
echo "Size: $SIZE"
echo "Release: $RELEASE_TAG"
echo ""
echo "Starting upload..."
echo "Started: $(date)"

gh release upload "$RELEASE_TAG" "$SD_FILE" --clobber

echo ""
echo "=========================================="
echo "Upload complete!"
echo "=========================================="
echo "Finished: $(date)"

# Verify
BASENAME=$(basename "$SD_FILE")
echo ""
echo "Verifying upload..."
gh release view "$RELEASE_TAG" --json assets -q '.assets[] | select(.name == "'"$BASENAME"'") | "Uploaded: \(.name) (\(.size) bytes)"'
