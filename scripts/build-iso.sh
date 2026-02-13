#!/usr/bin/env bash
# Build bootable ISO for tuinix
# Supports both x86_64 (laptop) and aarch64 (R36S) architectures

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Architecture selection - defaults to x86_64
# Options: x86_64, aarch64, both
ARCH="${1:-x86_64}"

# Version for ISO naming - defaults to latest git tag or 'dev'
VERSION="${TUINIX_VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo "dev")}"

# Validate architecture argument
case "$ARCH" in
  x86_64|aarch64|both)
    ;;
  *)
    echo "Usage: $0 [x86_64|aarch64|both]"
    echo "  x86_64  - Build ISO for x86_64 systems (laptop, default)"
    echo "  aarch64 - Build ISO for aarch64 systems (R36S)"
    echo "  both    - Build ISOs for both architectures"
    exit 1
    ;;
esac

# Check if gum is available
if ! command -v gum >/dev/null 2>&1; then
  echo "❌ gum is required for this script"
  echo "Install with: nix profile install nixpkgs#gum"
  exit 1
fi

gum style \
  --foreground="#e95420" \
  --border="rounded" \
  --margin="1" \
  --padding="1" \
  "🚀 tuinix ISO Builder" \
  "" \
  "Building bootable ISO with embedded flake" \
  "Working directory: $PROJECT_ROOT" \
  "Version: $VERSION" \
  "Architecture: $ARCH"

cd "$PROJECT_ROOT"

# Clean up previous build artifacts
gum style --foreground="#0066cc" "🧹 Cleaning up previous build artifacts..."

# Remove existing result symlink
if [[ -L "result" ]]; then
  rm result
  gum style --foreground="#00cc00" "  ✅ Removed previous build result"
fi

# Remove any existing ISO files
for iso_file in tuinix.*.iso; do
  if [[ -f "$iso_file" ]]; then
    rm "$iso_file"
    gum style --foreground="#00cc00" "  ✅ Removed previous ISO: $iso_file"
  fi
done

# Clean up any leftover validation mount points
if [[ -d "/tmp/tuinix-iso-validation" ]]; then
  sudo umount /tmp/tuinix-iso-validation 2>/dev/null || true
  sudo rmdir /tmp/tuinix-iso-validation 2>/dev/null || true
  gum style --foreground="#00cc00" "  ✅ Cleaned up validation mount point"
fi

echo ""

# Function to validate ISO contents
validate_iso() {
  local iso_file="$1"
  local mount_point="/tmp/tuinix-iso-validation"

  gum style --foreground="#0066cc" "🔍 Validating ISO contents..."

  # Create mount point
  sudo mkdir -p "$mount_point"

  # Mount ISO
  if ! sudo mount -o loop "$iso_file" "$mount_point" 2>/dev/null; then
    gum style --foreground="#ff0000" "❌ Failed to mount ISO for validation"
    return 1
  fi

  local validation_failed=0
  local validation_results=()

  # Check for flake configuration
  if [[ -f "$mount_point/tuinix/flake.nix" && -f "$mount_point/tuinix/flake.lock" ]]; then
    validation_results+=("✅ Flake configuration found")
  else
    validation_results+=("❌ Missing flake configuration")
    validation_failed=1
  fi

  # Check for host configurations
  if [[ -d "$mount_point/tuinix/hosts/laptop" ]]; then
    validation_results+=("✅ Laptop host configuration found")
  else
    validation_results+=("❌ Missing laptop host configuration")
    validation_failed=1
  fi

  # Check for user configurations
  if [[ -d "$mount_point/tuinix/users" ]]; then
    validation_results+=("✅ User configurations found")
  else
    validation_results+=("❌ Missing user configurations")
    validation_failed=1
  fi

  # Check for modules
  if [[ -d "$mount_point/tuinix/modules" ]]; then
    validation_results+=("✅ System modules found")
  else
    validation_results+=("❌ Missing system modules")
    validation_failed=1
  fi

  # Check for nix store
  if [[ -f "$mount_point/nix-store.squashfs" ]]; then
    validation_results+=("✅ Nix store found")
  else
    validation_results+=("❌ Missing nix store")
    validation_failed=1
  fi

  # Display validation results
  gum style \
    --border="rounded" \
    --padding="1" \
    --margin="1" \
    "${validation_results[@]}"

  # Unmount
  sudo umount "$mount_point"
  sudo rmdir "$mount_point"

  if [[ $validation_failed -eq 0 ]]; then
    gum style --foreground="#00cc00" "✅ ISO validation passed"
    return 0
  else
    gum style --foreground="#ff0000" "❌ ISO validation failed"
    return 1
  fi
}

# Generate build information
gum style --foreground="#0066cc" "📋 Generating build information..."
if [[ -x "$PROJECT_ROOT/scripts/build-version.sh" ]]; then
  cd "$PROJECT_ROOT"
  scripts/build-version.sh
  # Auto-commit build-info.txt so the git tree is clean for nix flake evaluation.
  # A dirty tree causes nix to produce a broken/truncated ISO.
  if git diff --quiet build-info.txt 2>/dev/null; then
    gum style --foreground="#00cc00" "  ✅ Build information unchanged"
  else
    git add build-info.txt && git commit -m "Update build-info for $VERSION" --quiet
    gum style --foreground="#00cc00" "  ✅ Build information generated and committed"
  fi
else
  gum style --foreground="#ff0000" "  ❌ Build version script not found or not executable"
  exit 1
fi

# Function to build ISO for a specific architecture
build_iso_for_arch() {
  local target_arch="$1"
  local installer_name="installer-${target_arch}"
  local final_iso_name="tuinix.${VERSION}.${target_arch}.iso"

  gum style \
    --foreground="#e95420" \
    --border="rounded" \
    --padding="1" \
    "🏗️  tuinix ISO Build ($target_arch)" \
    "" \
    "Starting comprehensive build process..." \
    "This may take 10-30 minutes depending on your system"

  echo ""

  # Use gum's simple and reliable spinner
  if ! gum spin --spinner="dot" --title="Building $target_arch ISO image (this may take a while)..." --show-output -- nix build ".#nixosConfigurations.${installer_name}.config.system.build.isoImage"; then
    echo ""
    gum style --foreground="#ff0000" --border="rounded" --padding="1" "❌ ISO build failed for $target_arch!" "Check the output above for error details."
    return 1
  fi

  echo ""
  gum style --foreground="#00cc00" "🎉 ISO build completed successfully for $target_arch!"

  # Check if build was successful
  if [[ -L "result" && -d "result/iso" ]]; then
    # Find ISO file (either .iso or .iso.zst)
    ISO_PATH=$(find result/iso -name "*.iso" -o -name "*.iso.zst" | head -1)
    ISO_NAME=$(basename "$ISO_PATH")

    gum style \
      --foreground="#00cc00" \
      --border="rounded" \
      --padding="1" \
      "✅ ISO built successfully!" \
      "" \
      "📀 ISO location: $ISO_PATH" \
      "📁 ISO name: $ISO_NAME"

    # Remove existing ISO if present
    if [[ -f "./$final_iso_name" ]]; then
      gum style --foreground="#ffaa00" "⚠️  Removing existing ISO: ./$final_iso_name"
      sudo rm "./$final_iso_name"
    fi

    if [[ "$ISO_PATH" == *.zst ]]; then
      gum style --foreground="#0066cc" "📦 Decompressing ISO..."
      TEMP_ISO_NAME="${ISO_NAME%.zst}"
      gum spin --spinner="dot" --title="Decompressing..." -- zstd -d "$ISO_PATH" -o "./$TEMP_ISO_NAME"

      # Validate the decompressed ISO
      if validate_iso "./$TEMP_ISO_NAME"; then
        # Rename to final name
        mv "./$TEMP_ISO_NAME" "./$final_iso_name"
        gum style --foreground="#00cc00" "✅ ISO created and validated: ./$final_iso_name"
      else
        gum style --foreground="#ff0000" "❌ ISO validation failed - removing invalid ISO"
        rm -f "./$TEMP_ISO_NAME"
        return 1
      fi
    else
      gum style --foreground="#0066cc" "📋 Copying ISO..."
      gum spin --spinner="dot" --title="Copying..." -- cp "$ISO_PATH" "./$final_iso_name"

      # Validate the copied ISO
      if validate_iso "./$final_iso_name"; then
        gum style --foreground="#00cc00" "✅ ISO created and validated: ./$final_iso_name"
      else
        gum style --foreground="#ff0000" "❌ ISO validation failed - removing invalid ISO"
        rm -f "./$final_iso_name"
        return 1
      fi
    fi

    # Show final information
    ISO_SIZE=$(du -h "./$final_iso_name" | cut -f1)

    gum style \
      --foreground="#e95420" \
      --border="rounded" \
      --padding="1" \
      --margin="1" \
      "🎉 ISO Build Complete ($target_arch)!" \
      "" \
      "📊 ISO Information:" \
      "  📁 Name: $final_iso_name" \
      "  📏 Size: $ISO_SIZE" \
      "  🏷️  Version: $VERSION" \
      "" \
      "💾 To create a bootable USB:" \
      "  sudo dd if=./$final_iso_name of=/dev/sdX bs=4M status=progress" \
      "  (Replace /dev/sdX with your USB device)"

    # Clean up result symlink for next build
    rm -f result

    return 0
  else
    gum style --foreground="#ff0000" "❌ ISO build failed or result not found for $target_arch"
    return 1
  fi
}

# Build ISOs based on architecture selection
build_failed=0

case "$ARCH" in
  x86_64)
    build_iso_for_arch "x86_64" || build_failed=1
    ;;
  aarch64)
    build_iso_for_arch "aarch64" || build_failed=1
    ;;
  both)
    gum style --foreground="#0066cc" "Building ISOs for both architectures..."
    echo ""
    build_iso_for_arch "x86_64" || build_failed=1
    echo ""
    build_iso_for_arch "aarch64" || build_failed=1
    ;;
esac

if [[ $build_failed -eq 1 ]]; then
  gum style --foreground="#ff0000" "❌ One or more ISO builds failed"
  exit 1
fi

gum style \
  --foreground="#00cc00" \
  --border="rounded" \
  --padding="1" \
  "🎉 All ISO builds completed successfully!"
