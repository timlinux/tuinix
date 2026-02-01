#!/usr/bin/env bash
# tuinix Interactive Installer
# A comprehensive installer using gum for rich interactive UX

set -euo pipefail

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOSTNAME=""
DISK=""
HOST_ID=""
LOCALE="en_US.UTF-8"
KEYMAP="us"
SPACE_BOOT="5G"
SPACE_NIX="250G"
SPACE_HOME=""
SPACE_ATUIN="50G"
ZFS_POOL_NAME="NIXROOT"

# Check dependencies
check_dependencies() {
  local missing_deps=()

  for dep in gum disko nixos-generate-config nixos-install git; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      missing_deps+=("$dep")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    gum style --foreground="#DC3545" \
      "Missing dependencies: ${missing_deps[*]}" \
      "Please ensure you're running from the NixOS installer with this flake."
    exit 1
  fi
}

# Check root privileges
check_root() {
  if [[ $EUID -ne 0 ]]; then
    gum style --foreground="#DC3545" \
      "This script must be run as root" \
      "Use: sudo $0"
    exit 1
  fi
}

# Show build information
show_build_info() {
  if [[ -f "/iso/tuinix/build-info.txt" ]]; then
    echo ""
    gum style \
      --foreground="#28A745" \
      --border="rounded" \
      --padding="1" \
      --margin="1" \
      "$(cat /iso/tuinix/build-info.txt)"
    echo ""
  else
    echo "Build info not available"
  fi
}

# Welcome screen
show_welcome() {
  clear
  show_build_info

  gum style \
    --foreground="#e95420" \
    --border="rounded" \
    --margin="1" \
    --padding="1" \
    "🍃 tuinix Interactive Installer" \
    "" \
    "This installer will guide you through setting up" \
    "a complete NixOS system with ZFS encryption." \
    "" \
    "⚠️  WARNING: This will completely destroy all data" \
    "    on the selected disk!"

  echo ""
  if ! gum confirm "Do you want to continue?"; then
    gum style --foreground="#DC3545" "Installation cancelled."
    exit 0
  fi
}

# Generate unique ZFS host ID
generate_host_id() {
  # Generate 8-character hex string
  printf "%08x" $((RANDOM * RANDOM))
}

# Interpolate template variables
interpolate_template() {
  local template_file="$1"
  local output_file="$2"

  # Read template and substitute variables
  sed \
    -e "s|{{DISK_DEVICE}}|$DISK|g" \
    -e "s|{{HOSTNAME}}|$HOSTNAME|g" \
    -e "s|{{SPACE_BOOT}}|$SPACE_BOOT|g" \
    -e "s|{{SPACE_NIX}}|$SPACE_NIX|g" \
    -e "s|{{SPACE_ATUIN}}|$SPACE_ATUIN|g" \
    -e "s|{{ZFS_POOL_NAME}}|$ZFS_POOL_NAME|g" \
    "$template_file" >"$output_file"
}

# Get list of available disks
get_available_disks() {
  # Get list of disks, excluding loop devices and small disks
  lsblk -d -n -o NAME,SIZE,TYPE,MODEL |
  awk '$3 == "disk" && $2 !~ /^[0-9]+[MK]$/ {print "/dev/" $1 " (" $2 " - " $4 ")"}'
}

# Collect all user input upfront
collect_user_input() {
  gum style --foreground="#5277C3" "📝 System Configuration"
  echo ""

  # Hostname
  HOSTNAME=$(gum input --placeholder="Enter hostname (e.g., laptop, desktop, server)")
  while [[ -z "$HOSTNAME" || ! "$HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]]; do
    gum style --foreground="#DC3545" "Invalid hostname. Use only letters, numbers, and hyphens."
    HOSTNAME=$(gum input --placeholder="Enter hostname (e.g., laptop, desktop, server)")
  done

  # Disk selection
  echo ""
  gum style --foreground="#5277C3" "💾 Available Disks:"

  # Show disk information
  gum style --border="rounded" --padding="1" \
    "$(lsblk -d -o NAME,SIZE,TYPE,MODEL | head -1)" \
    "$(lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk || echo 'No disks found')"

  # Get available disks for selection
  mapfile -t disk_options < <(get_available_disks)

  if [[ ${#disk_options[@]} -eq 0 ]]; then
    gum style --foreground="#DC3545" "No suitable disks found!"
    exit 1
  fi

  selected_disk=$(gum choose "${disk_options[@]}")
  DISK=$(echo "$selected_disk" | awk '{print $1}')

  # Generate host ID
  HOST_ID=$(generate_host_id)
  gum style --foreground="#28A745" "Generated ZFS Host ID: $HOST_ID"

  # Get disk size for space calculations
  echo ""
  gum style --foreground="#5277C3" "📊 Calculating Disk Space Allocation"

  local disk_size_bytes
  disk_size_bytes=$(lsblk -d -n -b -o SIZE "$DISK")
  local disk_size_gb=$((disk_size_bytes / 1024 / 1024 / 1024))

  gum style --foreground="#28A745" "Disk size: ${disk_size_gb}GB"

  # Calculate space allocation based on percentages
  local boot_gb=5                              # Fixed 5GB for boot
  local nix_gb=$((disk_size_gb * 5 / 100))     # 5% of disk for /nix
  local atuin_gb=$((disk_size_gb * 5 / 10000)) # 0.05% of disk for /var/atuin (minimum 1GB)

  # Ensure minimum sizes
  if [[ $nix_gb -lt 20 ]]; then
    nix_gb=20 # Minimum 20GB for /nix
  fi
  if [[ $atuin_gb -lt 1 ]]; then
    atuin_gb=1 # Minimum 1GB for atuin
  fi

  # Home gets the rest
  local home_gb=$((disk_size_gb - boot_gb - nix_gb - atuin_gb))

  # Set global variables
  SPACE_BOOT="${boot_gb}G"
  SPACE_NIX="${nix_gb}G"
  SPACE_ATUIN="${atuin_gb}G"
  SPACE_HOME="${home_gb}G"

  gum style --foreground="#654321" \
    "Automatic space allocation:" \
    "  /boot: $SPACE_BOOT (fixed)" \
    "  /nix: $SPACE_NIX (5% of disk)" \
    "  /var/atuin: $SPACE_ATUIN (0.05% of disk)" \
    "  /home: $SPACE_HOME (remaining space)"

  # Locale and keyboard
  echo ""
  gum style --foreground="#5277C3" "🌍 Localization"

  # Locale selection
  local locale_options=(
    "en_US.UTF-8"
    "en_GB.UTF-8"
    "de_DE.UTF-8"
    "fr_FR.UTF-8"
    "es_ES.UTF-8"
    "other"
  )

  selected_locale=$(gum choose --header="Select locale:" "${locale_options[@]}")
  if [[ "$selected_locale" == "other" ]]; then
    LOCALE=$(gum input --placeholder="en_US.UTF-8" --prompt="Enter locale: ")
  else
    LOCALE="$selected_locale"
  fi

  # Keyboard layout
  local keymap_options=(
    "us"
    "uk"
    "de"
    "fr"
    "es"
    "other"
  )

  selected_keymap=$(gum choose --header="Select keyboard layout:" "${keymap_options[@]}")
  if [[ "$selected_keymap" == "other" ]]; then
    KEYMAP=$(gum input --placeholder="us" --prompt="Enter keymap: ")
  else
    KEYMAP="$selected_keymap"
  fi

}

# Show configuration summary
show_summary() {
  echo ""
  gum style --foreground="#5277C3" "📋 Configuration Summary"

  gum style \
    --border="rounded" \
    --padding="1" \
    --margin="1" \
    "Hostname: $HOSTNAME" \
    "Disk: $DISK" \
    "ZFS Host ID: $HOST_ID" \
    "Locale: $LOCALE" \
    "Keyboard: $KEYMAP" \
    "" \
    "Space allocation:" \
    "  /boot: $SPACE_BOOT (EFI)" \
    "  /nix: $SPACE_NIX" \
    "  /home: $SPACE_HOME" \
    "  /var/atuin: $SPACE_ATUIN (XFS on ZFS volume)" \
    "" \
    "🔥 THIS WILL DESTROY ALL DATA ON $DISK"

  echo ""
  if ! gum confirm "Proceed with installation?"; then
    gum style --foreground="#DC3545" "Installation cancelled."
    exit 0
  fi

  echo ""
  gum style --foreground="#DC3545" "FINAL WARNING!"
  local confirmation
  confirmation=$(gum input --placeholder="Type 'DESTROY' to confirm")
  if [[ "$confirmation" != "DESTROY" ]]; then
    gum style --foreground="#DC3545" "Installation cancelled."
    exit 0
  fi
}

# Generate host configuration
generate_host_config() {
  # Copy flake to writable location first
  local work_dir="/tmp/tuinix-install"
  gum style --foreground="#5277C3" "📁 Copying flake to writable location: $work_dir"

  rm -rf "$work_dir"
  cp -r "$PROJECT_ROOT" "$work_dir"

  # Update PROJECT_ROOT to point to writable copy
  PROJECT_ROOT="$work_dir"

  local host_dir="$PROJECT_ROOT/hosts/$HOSTNAME"

  gum style --foreground="#5277C3" "📁 Generating host configuration in $host_dir"

  mkdir -p "$host_dir"

  # Generate default.nix
  cat >"$host_dir/default.nix" <<EOF
{ config, lib, pkgs, inputs, hostname, ... }:

{
  imports = [
    ./disks.nix
    ./hardware.nix
    ../../users/user.nix
    ../../users/admin.nix
  ];

  networking.hostName = hostname;
  system.stateVersion = "25.11";

  # Enable ZFS support
  tuinix.zfs.enable = true;
  tuinix.zfs.encryption = true;

  # Locale configuration
  i18n.defaultLocale = "$LOCALE";

  # Keyboard configuration
  services.xserver.xkb.layout = "$KEYMAP";
  console.keyMap = "$KEYMAP";
}
EOF

  # Generate disks.nix from template
  local template_file="$PROJECT_ROOT/templates/disko-template.nix"

  if [[ ! -f "$template_file" ]]; then
    gum style --foreground="#DC3545" "❌ Disko template not found: $template_file"
    exit 1
  fi

  interpolate_template "$template_file" "$host_dir/disks.nix"

  # Generate initial hardware.nix (will be updated by nixos-generate-config)
  cat >"$host_dir/hardware.nix" <<EOF
# Auto-generated hardware configuration for $HOSTNAME
{ config, lib, pkgs, modulesPath, ... }:

{
  networking.hostId = "$HOST_ID";
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Hardware configuration will be updated by nixos-generate-config
  boot = {
    initrd = {
      availableKernelModules = [
        "ahci" "xhci_pci" "virtio_pci" "virtio_scsi"
        "sd_mod" "sr_mod" "nvme" "ehci_pci" "usbhid"
        "usb_storage" "sdhci_pci"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" "kvm-amd" ];
    extraModulePackages = [ ];
  };

  hardware = {
    enableAllFirmware = true;
    cpu.intel.updateMicrocode = lib.mkDefault true;
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
EOF

  gum style --foreground="#28A745" "✅ Host configuration generated"
}

# Format disk with disko
format_disk() {
  local host_dir="$PROJECT_ROOT/hosts/$HOSTNAME"
  local disko_config="$host_dir/disks.nix"

  gum style --foreground="#5277C3" "💾 Formatting disk $DISK with ZFS"

  # Set the hostId on the live system BEFORE creating the ZFS pool
  # so the pool is stamped with the same hostId the installed system will use.
  # On NixOS live ISOs, /etc/hostid may be a symlink into the read-only nix store.
  rm -f /etc/hostid 2>/dev/null || true
  zgenhostid "$HOST_ID"

  # Unmount any existing partitions
  gum style --foreground="#FFC107" "Unmounting existing partitions..."
  for partition in $(lsblk -nr -o NAME "$DISK" | tail -n +2 2>/dev/null || true); do
    partition_path="/dev/$partition"
    if mount | grep -q "^$partition_path"; then
      umount "$partition_path" 2>/dev/null || true
    fi
  done

  # Export any existing ZFS pools
  if command -v zpool >/dev/null 2>&1; then
    zpool export -a 2>/dev/null || true
  fi

  # Run disko
  gum style --foreground="#FFC107" "Running disko (this may take a few minutes)..."

  # ZFS encryption will prompt for passphrase during disko

  if ! disko --mode disko "$disko_config"; then
    gum style --foreground="#DC3545" "❌ Disk formatting failed!"
    exit 1
  fi

  gum style --foreground="#28A745" "✅ Disk formatting completed"
}

# Generate hardware configuration
generate_hardware_config() {
  local host_dir="$PROJECT_ROOT/hosts/$HOSTNAME"

  gum style --foreground="#5277C3" "🔧 Generating hardware configuration"

  # Generate hardware configuration
  nixos-generate-config --root /mnt --dir /tmp/nixos-config

  # Merge the generated hardware with our template, preserving hostId and ZFS settings
  if [[ -f "/tmp/nixos-config/hardware-configuration.nix" ]]; then
    # Extract hardware-specific parts and merge with our template
    cat >"$host_dir/hardware.nix" <<EOF
# Hardware configuration for $HOSTNAME
{ config, lib, pkgs, modulesPath, ... }:

{
  networking.hostId = "$HOST_ID";
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # ZFS support - Critical boot configuration
  boot = {
    supportedFilesystems = [ "zfs" ];
    zfs = {
      requestEncryptionCredentials = true;
      forceImportRoot = true;
    };
    initrd = {
      availableKernelModules = [
        "ahci" "xhci_pci" "virtio_pci" "virtio_blk" "virtio_scsi"
        "sd_mod" "sr_mod" "nvme" "ehci_pci" "usbhid"
        "usb_storage" "sdhci_pci"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" "kvm-amd" ];
    extraModulePackages = [ ];
  };

$(sed -n '/hardware\./,/};/p' /tmp/nixos-config/hardware-configuration.nix | sed 's/^/  /' || echo '  hardware = {
    enableAllFirmware = true;
    cpu.intel.updateMicrocode = lib.mkDefault true;
  };')

$(sed -n '/powerManagement\./p' /tmp/nixos-config/hardware-configuration.nix | sed 's/^/  /' || echo '  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";')

  # ZFS services
  services.zfs.autoScrub.enable = true;
}
EOF
  fi

  gum style --foreground="#28A745" "✅ Hardware configuration generated"
}

# Install NixOS
install_nixos() {
  gum style --foreground="#5277C3" "🚀 Installing NixOS (this will take a while)"

  # Set up Nix configuration for better performance
  export NIX_CONFIG="
        extra-substituters = https://cache.nixos.org/
        extra-trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
        max-jobs = auto
        cores = 0
        keep-outputs = true
        keep-derivations = true
    "

  # Run installation
  if ! nixos-install --flake "$PROJECT_ROOT#$HOSTNAME" --no-root-passwd; then
    gum style --foreground="#DC3545" "❌ NixOS installation failed!"
    exit 1
  fi

  gum style --foreground="#28A745" "✅ NixOS installation completed"
}

# Configure ZFS bootfs property
configure_zfs_boot() {
  gum style --foreground="#5277C3" "🔧 Configuring ZFS boot properties"

  # Set the bootfs property on the ZFS pool
  zpool set bootfs="$ZFS_POOL_NAME/root" "$ZFS_POOL_NAME"

  # Verify the bootfs property is set correctly
  local bootfs_prop
  bootfs_prop=$(zpool get -H -o value bootfs "$ZFS_POOL_NAME")
  if [[ "$bootfs_prop" == "$ZFS_POOL_NAME/root" ]]; then
    gum style --foreground="#28A745" "✅ ZFS bootfs property set to: $bootfs_prop"
  else
    gum style --foreground="#DC3545" "❌ Failed to set ZFS bootfs property!"
    exit 1
  fi

  gum style --foreground="#28A745" "✅ ZFS boot configuration completed"
}

# Finalize ZFS pool - export and re-import to stamp correct hostId
finalize_zfs_pool() {
  gum style --foreground="#5277C3" "🔧 Finalizing ZFS pool (export/re-import for hostId)..."

  umount -R /mnt 2>/dev/null || true
  zpool export "$ZFS_POOL_NAME"
  zpool import -f "$ZFS_POOL_NAME"
  zpool export "$ZFS_POOL_NAME"

  gum style --foreground="#28A745" "✅ ZFS pool finalized and exported cleanly"
}

# Copy flake to new system
copy_flake() {
  gum style --foreground="#5277C3" "📦 Copying flake to new system"

  local target_dir="/mnt/etc/tuinix"
  mkdir -p "$target_dir"

  # Copy entire flake including the new host config
  cp -r "$PROJECT_ROOT"/* "$target_dir/"

  # Set proper ownership
  chown -R root:root "$target_dir"

  gum style --foreground="#28A745" "✅ Flake copied to new system"
}

# Set up user flake as a git repo with upstream tracking
setup_user_flake() {
  gum style --foreground="#5277C3" "📦 Setting up user flake from upstream repo"

  local user_dir="/mnt/home/user/tuinix"
  local host_dir="$PROJECT_ROOT/hosts/$HOSTNAME"
  local repo_url="https://github.com/timlinux/tuinix.git"

  # Shallow clone the upstream repo (depth=1 for just HEAD)
  gum style --foreground="#FFC107" "Cloning upstream tuinix repo (shallow)..."
  rm -rf "$user_dir"
  git clone --depth 1 "$repo_url" "$user_dir"

  # Copy the generated host configuration into the clone
  gum style --foreground="#FFC107" "Grafting host configuration for '$HOSTNAME'..."
  cp -r "$host_dir" "$user_dir/hosts/$HOSTNAME"

  # Register the new host in git and commit
  git -C "$user_dir" add "hosts/$HOSTNAME"
  git -C "$user_dir" commit -m "Add host configuration for $HOSTNAME

Generated by tuinix installer on $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Host ID: $HOST_ID
Disk: $DISK
Locale: $LOCALE
Keymap: $KEYMAP"

  # Set proper ownership for the user (uid/gid 1000)
  chown -R 1000:1000 "$user_dir"

  # Create a convenience symlink
  nixos-enter --root /mnt --command "ln -sf /home/user/tuinix /etc/tuinix-user"

  gum style --foreground="#28A745" "✅ User flake ready at /home/user/tuinix"
  gum style --foreground="#654321" \
    "  • Upstream: $repo_url" \
    "  • Host config committed: hosts/$HOSTNAME/" \
    "  • Rebuild with: sudo nixos-rebuild switch --flake /home/user/tuinix#$HOSTNAME"
}

# Setup root password
setup_root_password() {
  gum style --foreground="#5277C3" "🔑 Setting up root password"

  nixos-enter --root /mnt --command "passwd root"

  gum style --foreground="#28A745" "✅ Root password configured"
}

# Completion and reboot
complete_installation() {
  gum style \
    --foreground="#28A745" \
    --border="rounded" \
    --padding="1" \
    --margin="1" \
    "🎉 Installation Complete!" \
    "" \
    "Your tuinix system '$HOSTNAME' is ready!" \
    "" \
    "Your personal flake is at: /home/user/tuinix" \
    "  Rebuild: sudo nixos-rebuild switch --flake /home/user/tuinix#$HOSTNAME" \
    "  Update:  cd ~/tuinix && git pull && sudo nixos-rebuild switch --flake .#$HOSTNAME" \
    "" \
    "You can now remove the installation media."

  echo ""
  if gum confirm "Reboot now?"; then
    gum style --foreground="#5277C3" "Rebooting..."
    reboot
  else
    gum style --foreground="#5277C3" "Remember to reboot when ready!"
  fi
}

# Main installation function
main() {
  check_dependencies
  check_root

  show_welcome
  collect_user_input
  show_summary

  # Installation phases with progress tracking
  generate_host_config
  format_disk
  generate_hardware_config
  install_nixos
  configure_zfs_boot
  copy_flake
  setup_user_flake
  setup_root_password
  finalize_zfs_pool

  complete_installation
}

# Trap to cleanup on exit
trap 'gum style --foreground="#DC3545" "Installation interrupted!"' INT TERM

# Run main function
main "$@"
