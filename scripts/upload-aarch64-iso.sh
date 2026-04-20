#!/usr/bin/env bash
# Upload aarch64 ISO to GitHub release
set -e

ISO_FILE="tuinix.v0.7.0.aarch64.iso"
RELEASE_TAG="v0.7.0"

echo "=========================================="
echo "Uploading aarch64 ISO to GitHub Release"
echo "=========================================="

if [[ ! -f "$ISO_FILE" ]]; then
    echo "ERROR: $ISO_FILE not found!"
    echo "Run scripts/build-aarch64-iso.sh first"
    exit 1
fi

SIZE=$(du -h "$ISO_FILE" | cut -f1)
echo "File: $ISO_FILE"
echo "Size: $SIZE"
echo "Release: $RELEASE_TAG"
echo ""
echo "Starting upload..."
echo "Started: $(date)"

gh release upload "$RELEASE_TAG" "$ISO_FILE" --clobber

echo ""
echo "=========================================="
echo "Upload complete!"
echo "=========================================="
echo "Finished: $(date)"

# Verify
echo ""
echo "Verifying upload..."
gh release view "$RELEASE_TAG" --json assets -q '.assets[] | select(.name == "'"$ISO_FILE"'") | "Uploaded: \(.name) (\(.size) bytes)"'
