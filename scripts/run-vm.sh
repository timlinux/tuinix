#!/usr/bin/env bash

# QEMU VM runner for TuiNix
# Usage: ./run-vm.sh [install|run]
#   install - Boot from ISO for installation
#   run     - Boot from disk (after installation)

set -e

VM_NAME="tuinix"
DEFAULT_DISK_SIZE="50G"
DEFAULT_MEMORY="8G"
ENABLE_ENHANCED_VIRTUALIZATION="${ENABLE_ENHANCED_VIRTUALIZATION:-true}"
DISK_FILE="$VM_NAME.qcow2"
ISO_FILE="tuinix.v1.iso"
CONFIG_DIR="$HOME/.config/tuinix"
MEMORY_CONFIG="$CONFIG_DIR/memory"
DISK_CONFIG="$CONFIG_DIR/disk_size"
OVMF_VARS_FILE="$CONFIG_DIR/OVMF_VARS.fd"

# Check if nix is available for gum
if ! command -v nix &>/dev/null; then
  echo "Error: nix is not available"
  echo "This script requires nix to run gum"
  exit 1
fi

# Function to run gum via nix or fallback
gum() {
  # Try to use gum from nix first
  if command -v gum &>/dev/null || nix shell nixpkgs#gum -c gum --help &>/dev/null; then
    if command -v gum &>/dev/null; then
      command gum "$@"
    else
      nix shell nixpkgs#gum -c gum "$@"
    fi
  else
    # Fallback for non-interactive environments
    case "$1" in
      "confirm")
        echo "Using default: yes"
        return 0
        ;;
      "choose")
        # Extract first option from arguments
        shift 1
        while [[ "$1" == --* ]]; do
          shift 2 2>/dev/null || shift 1
        done
        echo "$1"  # Return first non-flag option
        ;;
      "input")
        shift
        while [[ "$1" == --* ]]; do
          shift 2 2>/dev/null || shift 1
        done
        echo "${1:-$DEFAULT_MEMORY}"  # Return value or default
        ;;
    esac
  fi
}

# Function to save configuration
save_config() {
  mkdir -p "$CONFIG_DIR"
  echo "$MEMORY" > "$MEMORY_CONFIG"
  echo "$DISK_SIZE" > "$DISK_CONFIG"
}

# Function to load configuration
load_config() {
  if [ -f "$MEMORY_CONFIG" ] && [ -f "$DISK_CONFIG" ]; then
    MEMORY=$(cat "$MEMORY_CONFIG")
    DISK_SIZE=$(cat "$DISK_CONFIG")
    return 0
  fi
  return 1
}

# Clean function to remove disk and config
clean_vm() {
  echo "🧹 Cleaning VM data..."

  if [ -f "$DISK_FILE" ]; then
    if gum confirm "Remove disk image '$DISK_FILE'?"; then
      rm -f "$DISK_FILE"
      echo "✓ Removed disk image"
    fi
  fi

  if [ -d "$CONFIG_DIR" ]; then
    if gum confirm "Remove configuration cache (includes UEFI variables)?"; then
      rm -rf "$CONFIG_DIR"
      echo "✓ Removed configuration cache and UEFI variables"
    fi
  fi

  echo "VM cleanup complete"
  exit 0
}

# Inspect disk contents to debug boot issues
inspect_disk() {
  echo "🔍 Inspecting disk contents..."

  # Create temporary mount point
  local mount_point="/tmp/tuinix-inspect"
  sudo mkdir -p "$mount_point"

  # Try to mount the disk as a loop device
  echo "Attempting to analyze disk partitions..."

  # Use qemu-nbd to expose the qcow2 as a block device
  if command -v qemu-nbd >/dev/null 2>&1; then
    echo "Using qemu-nbd to inspect disk..."

    # Load nbd module if not loaded
    sudo modprobe nbd 2>/dev/null || true

    # Connect the qcow2 image
    sudo qemu-nbd -c /dev/nbd0 "$DISK_FILE"

    # List partitions
    echo "Partitions found:"
    sudo fdisk -l /dev/nbd0 2>/dev/null || echo "No valid partition table found"

    # Try to mount the root partition (usually nbd0p2 for EFI+ZFS setup)
    echo ""
    echo "Checking for boot files..."

    # Check EFI partition (usually nbd0p1)
    if sudo mount /dev/nbd0p1 "$mount_point" 2>/dev/null; then
      echo "✓ EFI partition mounted:"
      ls -la "$mount_point" 2>/dev/null || echo "  (empty or unreadable)"
      sudo umount "$mount_point"
    else
      echo "❌ Could not mount EFI partition"
    fi

    # Disconnect
    sudo qemu-nbd -d /dev/nbd0

    echo ""
    echo "If no boot files found, installation likely incomplete."
    echo "Suggestion: Boot from ISO and complete/redo installation."

  else
    echo "qemu-nbd not available - cannot inspect disk contents"
    echo "Suggestion: Install qemu-utils or try reinstalling"
  fi

  sudo rmdir "$mount_point" 2>/dev/null || true
}


# Locate OVMF UEFI firmware (required for EFI boot)
find_ovmf() {
  local ovmf_code=""
  # Common OVMF locations across distros and nix
  for candidate in \
    "/run/libvirt/nix-ovmf/OVMF_CODE.fd" \
    "/usr/share/OVMF/OVMF_CODE.fd" \
    "/usr/share/edk2/ovmf/OVMF_CODE.fd" \
    "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd" \
    "/usr/share/qemu/OVMF_CODE.fd"; do
    if [ -f "$candidate" ]; then
      ovmf_code="$candidate"
      break
    fi
  done

  # Try nix store lookup if not found
  if [ -z "$ovmf_code" ]; then
    ovmf_code=$(nix build --print-out-paths --no-link nixpkgs#OVMF.fd 2>/dev/null)/FV/OVMF_CODE.fd || true
  fi

  if [ -z "$ovmf_code" ] || [ ! -f "$ovmf_code" ]; then
    echo "Error: OVMF UEFI firmware not found."
    echo "Install it with: nix-env -iA nixpkgs.OVMF"
    echo "Or on your distro: apt install ovmf / dnf install edk2-ovmf"
    exit 1
  fi

  OVMF_CODE="$ovmf_code"

  # Create a writable copy of OVMF_VARS for this VM (stores EFI variables)
  if [ ! -f "$OVMF_VARS_FILE" ]; then
    local ovmf_vars_src="${ovmf_code%OVMF_CODE.fd}OVMF_VARS.fd"
    if [ -f "$ovmf_vars_src" ]; then
      mkdir -p "$CONFIG_DIR"
      cp "$ovmf_vars_src" "$OVMF_VARS_FILE"
    else
      echo "Error: OVMF_VARS.fd not found alongside OVMF_CODE.fd"
      exit 1
    fi
  fi
}

# Check if qemu-system-x86_64 is available
if ! command -v qemu-system-x86_64 &>/dev/null; then
  echo "Error: qemu-system-x86_64 is not installed"
  echo "Please install QEMU first"
  exit 1
fi

# Check if ISO file exists
if [ ! -f "$ISO_FILE" ]; then
  echo "Error: ISO file '$ISO_FILE' not found"
  echo "You may need to build the ISO first using: ./build-iso.sh"
  exit 1
fi

# Locate UEFI firmware (required for EFI boot)
find_ovmf
echo "Using UEFI firmware: $OVMF_CODE"

# Handle help command
if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 [iso|harddrive|clean|help]"
  echo ""
  echo "Boot modes:"
  echo "  iso       - Boot from ISO (for installation)"
  echo "  harddrive - Boot from VM disk (after installation)"
  echo "  clean     - Remove VM disk and configuration"
  echo "  help      - Show this help message"
  echo ""
  echo "If no argument provided, script will ask interactively."
  echo "Default settings: Memory: $DEFAULT_MEMORY, Disk: $DEFAULT_DISK_SIZE"
  exit 0
fi

if [ "$1" = "clean" ]; then
  clean_vm
fi

# Simple boot mode selection
if [ $# -eq 0 ]; then
  echo "🖥️  TuiNix VM Launcher"
  echo ""

  # Check if disk exists
  if [ -f "$DISK_FILE" ]; then
    echo "Found existing VM disk: $DISK_FILE"
  else
    echo "No VM disk found - will create new one"
  fi

  echo ""
  BOOT_MODE=$(gum choose "harddrive" "iso" "clean" --header "How do you want to boot?")
else
  case "$1" in
    "iso"|"install")
      BOOT_MODE="iso"
      ;;
    "run"|"harddrive"|"hd")
      BOOT_MODE="harddrive"
      ;;
    "clean")
      BOOT_MODE="clean"
      ;;
    *)
      echo "Error: Unknown option '$1'"
      echo "Use: $0 [iso|harddrive|clean]"
      exit 1
      ;;
  esac
fi

# Handle clean mode
if [ "$BOOT_MODE" = "clean" ]; then
  clean_vm
fi

# VM Configuration
echo ""
echo "🖥️  VM Configuration"

# Try to load existing config first, otherwise use defaults
if load_config 2>/dev/null; then
  echo "Using saved configuration:"
  echo "  Memory: $MEMORY"
  echo "  Disk: $DISK_SIZE"
else
  echo "Using default configuration:"
  MEMORY="$DEFAULT_MEMORY"
  DISK_SIZE="$DEFAULT_DISK_SIZE"
  echo "  Memory: $MEMORY"
  echo "  Disk: $DISK_SIZE"
  save_config
fi

echo ""
echo "VM Configuration:"
echo "  Memory: $MEMORY"
echo "  Disk: $DISK_SIZE"
echo "  ISO: $ISO_FILE"
echo ""

# Create disk image if it doesn't exist
if [ ! -f "$DISK_FILE" ]; then
  echo "Creating virtual disk: $DISK_FILE ($DISK_SIZE)"
  qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"
fi

echo ""
if ! gum confirm "Start the VM now?"; then
  echo "VM startup cancelled."
  exit 0
fi

# Get base QEMU arguments (without drive, we'll add that separately)
get_base_qemu_args() {
  # UEFI firmware (required for EFI boot)
  local uefi_args="-drive if=pflash,format=raw,readonly=on,file=$OVMF_CODE \
-drive if=pflash,format=raw,file=$OVMF_VARS_FILE"

  if [ "$ENABLE_ENHANCED_VIRTUALIZATION" = "true" ]; then
    echo "$uefi_args \
-cpu host,+x2apic,+tsc-deadline,+hypervisor,+tsc_adjust,+umip,+md-clear,+stibp,+arch-capabilities,+ssbd,+xsaves \
-machine q35,accel=kvm,kernel_irqchip=on \
-smp 4,cores=2,threads=2 \
-netdev user,id=net0 \
-device virtio-net-pci,netdev=net0 \
-display sdl \
-usb \
-device qemu-xhci \
-device usb-tablet \
-rtc base=localtime \
-global kvm-pit.lost_tick_policy=delay"
  else
    echo "$uefi_args \
-cpu host \
-smp 4 \
-netdev user,id=net0 \
-device virtio-net-pci,netdev=net0 \
-display sdl \
-usb \
-device usb-tablet"
  fi
}

BASE_QEMU_ARGS=$(get_base_qemu_args)

# Launch VM based on boot mode
case "$BOOT_MODE" in
  "iso")
    echo ""
    echo "🚀 Starting VM - booting from ISO"
    echo ""

    qemu-system-x86_64 \
      -enable-kvm \
      -m "$MEMORY" \
      $BASE_QEMU_ARGS \
      -drive file="$DISK_FILE",format=qcow2,if=virtio,cache=writethrough,serial=tuinix-root \
      -cdrom "$ISO_FILE" \
      -boot order=dc,menu=on \
      -name "TuiNix (ISO Boot)"
    ;;

  "harddrive")
    echo ""
    echo "🚀 Starting VM - booting from hard drive"
    echo ""

    # Check if disk exists and has reasonable size
    if [ ! -f "$DISK_FILE" ]; then
      echo "❌ No disk image found! Boot from ISO first to install."
      exit 1
    fi

    # Show disk info for debugging
    echo "Disk information:"
    qemu-img info "$DISK_FILE" | head -8
    echo ""

    # Check if disk seems to have been properly installed
    disk_size_used=$(qemu-img info "$DISK_FILE" | grep "disk size" | awk '{print $3}')
    disk_size_num=$(echo "$disk_size_used" | sed 's/[^0-9.]//g')

    # Convert to integer for comparison (3.3 -> 3, etc.)
    disk_size_int=${disk_size_num%.*}

    if [ "$disk_size_int" -lt 2 ]; then
      echo ""
      echo "⚠️  WARNING: Disk only uses ${disk_size_used} - installation appears incomplete!"
      echo "   Even a minimal NixOS installation should use 2GB+"
      echo ""
      if gum confirm "The installation seems incomplete. Boot from ISO to reinstall instead?"; then
        BOOT_MODE="iso"
      else
        echo "Proceeding with possibly incomplete installation..."
      fi
    else
      echo "✓ Disk usage ${disk_size_used} looks reasonable for minimal install"
    fi

    # If we're still booting from hard drive after the check
    if [ "$BOOT_MODE" = "harddrive" ]; then
      # Use the same configuration as ISO boot but without the CD
      # This ensures consistency between installation and running
      echo "Booting from disk (same config as installation)..."

      # Try offering boot menu first to see what's available
      echo "Starting with boot menu - you may need to select boot device manually..."

      # Try different boot approaches
      if gum confirm "Try simple boot mode? (if advanced mode fails)"; then
        echo "Using simple boot configuration..."
        qemu-system-x86_64 \
          -enable-kvm \
          -m "$MEMORY" \
          -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
          -drive if=pflash,format=raw,file="$OVMF_VARS_FILE" \
          -cpu host \
          -smp 2 \
          -drive file="$DISK_FILE",format=qcow2,if=virtio,serial=tuinix-root \
          -netdev user,id=net0 \
          -device e1000,netdev=net0 \
          -display sdl \
          -boot c \
          -name "TuiNix (Simple)"
      else
        echo "Using advanced boot configuration..."
        qemu-system-x86_64 \
          -enable-kvm \
          -m "$MEMORY" \
          $BASE_QEMU_ARGS \
          -drive file="$DISK_FILE",format=qcow2,if=virtio,cache=writethrough,serial=tuinix-root \
          -boot order=c,menu=on \
          -name "TuiNix" \
          -serial stdio \
          -no-reboot
      fi
    else
      # Boot mode was changed to ISO during the check, fall through to ISO case
      echo "Switching to ISO boot..."
    fi
    ;;

  *)
    echo "Error: Unknown boot mode '$BOOT_MODE'"
    exit 1
    ;;
esac
