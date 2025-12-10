#!/usr/bin/env bash
# Build bootable ISO for nixmywindows laptop profile

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Version for ISO naming
VERSION="${NIXMYWINDOWS_VERSION:-v1}"

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
    "🚀 nixmywindows ISO Builder" \
    "" \
    "Building bootable ISO with embedded flake" \
    "Working directory: $PROJECT_ROOT" \
    "Version: $VERSION"

cd "$PROJECT_ROOT"

# Function to validate ISO contents
validate_iso() {
  local iso_file="$1"
  local mount_point="/tmp/nixmywindows-iso-validation"

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
  if [[ -f "$mount_point/nixmywindows/flake.nix" && -f "$mount_point/nixmywindows/flake.lock" ]]; then
    validation_results+=("✅ Flake configuration found")
  else
    validation_results+=("❌ Missing flake configuration")
    validation_failed=1
  fi

  # Check for host configurations
  if [[ -d "$mount_point/nixmywindows/hosts/laptop" ]]; then
    validation_results+=("✅ Laptop host configuration found")
  else
    validation_results+=("❌ Missing laptop host configuration")
    validation_failed=1
  fi

  # Check for user configurations
  if [[ -d "$mount_point/nixmywindows/users" ]]; then
    validation_results+=("✅ User configurations found")
  else
    validation_results+=("❌ Missing user configurations")
    validation_failed=1
  fi

  # Check for modules
  if [[ -d "$mount_point/nixmywindows/modules" ]]; then
    validation_results+=("✅ System modules found")
  else
    validation_results+=("❌ Missing system modules")
    validation_failed=1
  fi

  # Check for installation README
  if [[ -f "$mount_point/README.txt" ]]; then
    validation_results+=("✅ Installation README found")
  else
    validation_results+=("❌ Missing installation README")
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

# Build the ISO
gum style \
    --foreground="#e95420" \
    --border="rounded" \
    --padding="1" \
    "🏗️  nixmywindows ISO Build" \
    "" \
    "Starting comprehensive build process..." \
    "This may take 10-30 minutes depending on your system"

echo ""

# Use gum's simple and reliable spinner
if ! gum spin --spinner="dot" --title="Building ISO image (this may take a while)..." --show-output -- nix build .#nixosConfigurations.installer.config.system.build.isoImage; then
    echo ""
    gum style --foreground="#ff0000" --border="rounded" --padding="1" "❌ ISO build failed!" "Check the output above for error details."
    exit 1
fi

echo ""
gum style --foreground="#00cc00" "🎉 ISO build completed successfully!"

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

  # Determine final ISO name
  FINAL_ISO_NAME="nixmywindows.${VERSION}.iso"
  if [[ -f "./$FINAL_ISO_NAME" ]]; then
    gum style --foreground="#ffaa00" "⚠️  Removing existing ISO: ./$FINAL_ISO_NAME"
    sudo rm "./$FINAL_ISO_NAME"
  fi

  if [[ "$ISO_PATH" == *.zst ]]; then
    gum style --foreground="#0066cc" "📦 Decompressing ISO..."
    TEMP_ISO_NAME="${ISO_NAME%.zst}"
    gum spin --spinner="dot" --title="Decompressing..." -- zstd -d "$ISO_PATH" -o "./$TEMP_ISO_NAME"

    # Validate the decompressed ISO
    if validate_iso "./$TEMP_ISO_NAME"; then
      # Rename to final name
      mv "./$TEMP_ISO_NAME" "./$FINAL_ISO_NAME"
      gum style --foreground="#00cc00" "✅ ISO created and validated: ./$FINAL_ISO_NAME"
    else
      gum style --foreground="#ff0000" "❌ ISO validation failed - removing invalid ISO"
      rm -f "./$TEMP_ISO_NAME"
      exit 1
    fi
  else
    gum style --foreground="#0066cc" "📋 Copying ISO..."
    gum spin --spinner="dot" --title="Copying..." -- cp "$ISO_PATH" "./$FINAL_ISO_NAME"

    # Validate the copied ISO
    if validate_iso "./$FINAL_ISO_NAME"; then
      gum style --foreground="#00cc00" "✅ ISO created and validated: ./$FINAL_ISO_NAME"
    else
      gum style --foreground="#ff0000" "❌ ISO validation failed - removing invalid ISO"
      rm -f "./$FINAL_ISO_NAME"
      exit 1
    fi
  fi

  # Show final information
  ISO_SIZE=$(du -h "./$FINAL_ISO_NAME" | cut -f1)
  
  gum style \
    --foreground="#e95420" \
    --border="rounded" \
    --padding="1" \
    --margin="1" \
    "🎉 ISO Build Complete!" \
    "" \
    "📊 ISO Information:" \
    "  📁 Name: $FINAL_ISO_NAME" \
    "  📏 Size: $ISO_SIZE" \
    "  🏷️  Version: $VERSION" \
    "" \
    "💾 To create a bootable USB:" \
    "  sudo dd if=./$FINAL_ISO_NAME of=/dev/sdX bs=4M status=progress" \
    "  (Replace /dev/sdX with your USB device)"
else
  gum style --foreground="#ff0000" "❌ ISO build failed or result not found"
  exit 1
fi

