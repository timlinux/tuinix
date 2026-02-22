# tuinix Specification

This document provides a comprehensive specification of the tuinix project - a pure terminal-based Linux experience built on NixOS.

## Overview

tuinix is a NixOS-based distribution designed for users who prefer a terminal-only computing environment. It provides a reproducible, declarative system with ZFS encryption, offline installation support, and multi-architecture builds.

## Supported Architectures

| Architecture | Image Type | Target Devices | Status |
|--------------|------------|----------------|--------|
| x86_64-linux | ISO | Standard PCs, laptops, servers | Fully supported |
| aarch64-linux | ISO | ARM64 laptops, servers, SBCs with UEFI | Supported |
| armv7l-linux | SD Image | R36S handheld (Allwinner A33) | Supported |

### Architecture Notes

- **x86_64**: Primary development platform. Includes ZFS support.
- **aarch64**: Supports UEFI-capable ARM64 devices. ZFS excluded due to compatibility.
- **armv7l/R36S**: Uses stock vendor kernel (3.4.39) with NixOS userspace. See `docs/r36s-build-notes.md`

### R36S Minimal Requirements

The R36S build is stripped to the absolute minimum for a functional terminal device:

| Component | Description |
|-----------|-------------|
| **Bootloader** | Stock U-Boot (from vendor firmware) |
| **Kernel** | Stock vendor kernel 3.4.39 (from boot.img) |
| **Init System** | systemd (minimal configuration) |
| **Shell** | bash |
| **Package Manager** | Nix with flakes support |
| **Core Utilities** | busybox |
| **Networking** | NetworkManager + nmtui |
| **Tethering** | iPhone USB tethering (libimobiledevice, usbmuxd, ifuse) |
| **Display** | Framebuffer terminal output to built-in display |

**Explicitly Disabled:**
- ZFS
- Polkit
- Documentation (man pages, info, NixOS docs)
- Fonts/fontconfig
- X11/Wayland
- Sound (pipewire, pulseaudio)
- Bluetooth
- Printing
- Firewall
- udisks2
- NixOS channels (flakes only)

## Installation Modes

### Online Installation
- Standard installation requiring network access
- Downloads packages from cache.nixos.org during install
- Smaller ISO size (~800MB)

### Offline Installation
- Full system closure included in ISO
- No network required for standard configurations
- Larger ISO size (~2-5GB)
- Pre-cached packages include all tuinix features

## System Features

### Networking

| Feature | Module | Default |
|---------|--------|---------|
| NetworkManager | `tuinix.networking.networkmanager` | Enabled |
| iPhone USB Tethering | `tuinix.networking.iphone-tethering` | Enabled |
| Wireless (wpa_supplicant) | `tuinix.networking.wireless` | Disabled |
| Ethernet (systemd-networkd) | `tuinix.networking.ethernet` | Disabled |

### Storage

| Feature | Module | Default |
|---------|--------|---------|
| ZFS Support | `tuinix.zfs` | Enabled (x86_64) |
| ZFS Encryption | `tuinix.zfs.encryption` | Enabled |

### Security

| Feature | Module | Default |
|---------|--------|---------|
| SSH Server | `tuinix.security.ssh` | Disabled |
| Firewall | `tuinix.security.firewall` | Disabled |

### System

| Feature | Module | Default |
|---------|--------|---------|
| Cross-arch Emulation | `tuinix.emulation` | Disabled |

## Default Packages

### Live ISO Environment

The installation ISO includes these packages:

```
Core Tools:
- vim, nano (editors)
- git (version control)
- curl, wget (network utilities)

Disk Management:
- parted, gptfdisk (partitioning)
- e2fsprogs, dosfstools, xfsprogs (filesystems)
- zfs (ZFS tools, x86_64 only)
- disko (declarative disk management)

Installation:
- nixos-install-tools
- mkpasswd (password hashing)

TUI:
- gum (interactive prompts)
- catimg (image display)
- tuinix-installer (custom TUI installer)

iPhone Tethering:
- libimobiledevice
- ifuse
- usbmuxd
```

### Installed System

Systems installed via the tuinix installer include:

```
Core Tools:
- vim (editor)
- git (version control)
- curl, wget (network utilities)
- htop (process viewer)
- tree (directory listing)

Networking:
- networkmanager (nmtui, nmcli)
- libimobiledevice, ifuse, usbmuxd (iPhone tethering)

Home Manager:
- Git configuration (user name, email)
- Default shell configuration
```

## Storage Modes

### Single Disk Options

| Mode | Filesystem | Encryption | Features |
|------|------------|------------|----------|
| Encrypted ZFS | ZFS | AES-256-GCM | Compression, snapshots, checksums |
| XFS Unencrypted | XFS | None | Maximum performance, latest kernel |

### Multi-Disk Options (ZFS)

| Mode | Redundancy | Min Disks | Fault Tolerance |
|------|------------|-----------|-----------------|
| Stripe | None | 2 | 0 disks |
| RAIDZ | Single parity | 3 | 1 disk |
| RAIDZ2 | Double parity | 4 | 2 disks |

### ZFS Dataset Layout

```
NIXROOT/
├── root      (/)           - Root filesystem
├── nix       (/nix)        - Nix store (5% of disk, min 20GB)
├── home      (/home)       - User data
├── overflow  (/overflow)   - Extra storage
└── atuin     (/var/atuin)  - Shell history (XFS zvol)
```

## Boot Requirements

| Requirement | Value |
|-------------|-------|
| Boot Mode | UEFI only |
| Secure Boot | Must be disabled (unsigned ZFS modules) |
| Boot Partition | 5GB FAT32 EFI System Partition |

## Hardware Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | x86_64 or aarch64 | Modern multi-core |
| RAM | 4 GB | 8 GB+ |
| Storage | 20 GB | 50 GB+ SSD |
| Boot Mode | UEFI | UEFI |

## ISO Build System

### Build Command

```bash
./scripts/build-iso.sh [architecture]
```

| Argument | Description |
|----------|-------------|
| (none) | Build x86_64 ISO (default) |
| `x86_64` | Build x86_64 ISO |
| `aarch64` | Build aarch64 ISO |
| `both` | Build both architectures |

### Output

ISOs are placed in the project root:
- `tuinix.VERSION.x86_64.iso`
- `tuinix.VERSION.aarch64.iso`

### Build Requirements

- Nix with flakes enabled
- `gum` package (provided by dev shell)
- ~10GB disk space for x86_64 build
- ~8GB disk space for aarch64 build
- For aarch64 on x86_64: QEMU binfmt emulation enabled

## Flake Structure

```
tuinix/
├── flake.nix              # Main flake definition
├── flake.lock             # Locked dependencies
├── installer.nix          # ISO installer configuration
├── modules/               # NixOS modules
│   ├── system/            # Boot, nix settings, ZFS, emulation
│   ├── networking/        # NetworkManager, WiFi, iPhone tethering
│   └── security/          # SSH, firewall
├── hosts/                 # Host configurations
│   ├── laptop/            # Example laptop host
│   └── r36s/              # R36S handheld (planned)
├── users/                 # User configurations
├── profiles/              # System profiles (VM, workstation)
├── templates/             # Disko templates
├── scripts/               # Build and utility scripts
└── docs/                  # MkDocs documentation
```

## NixOS Configurations

| Configuration | Description |
|---------------|-------------|
| `laptop` | Example laptop with ZFS, NetworkManager |
| `r36s` | R36S handheld (armv7l, stock kernel, SD image) |
| `installer` | x86_64 installation ISO |
| `installer-aarch64` | aarch64 installation ISO |

### R36S SD Image Build

```bash
# Build the R36S SD card image
nix build .#sd-r36s

# Flash to SD card
sudo dd if=result of=/dev/sdX bs=4M status=progress conv=fsync
```

Requires extracted stock firmware. See `docs/installation/r36s.md` for details.

## Module Options

### tuinix.networking.networkmanager

```nix
tuinix.networking.networkmanager = {
  enable = true;  # Enable NetworkManager (provides nmtui)
};
```

### tuinix.networking.iphone-tethering

```nix
tuinix.networking.iphone-tethering = {
  enable = true;  # Enable iPhone USB tethering support
};
```

### tuinix.zfs

```nix
tuinix.zfs = {
  enable = true;       # Enable ZFS support
  encryption = true;   # Request encryption credentials at boot
};
```

### tuinix.security.ssh

```nix
tuinix.security.ssh = {
  enable = true;  # Enable OpenSSH server
};
```

### tuinix.security.firewall

```nix
tuinix.security.firewall = {
  enable = true;  # Enable firewall with SSH port open
};
```

### tuinix.emulation

```nix
tuinix.emulation = {
  enable = true;    # Enable cross-architecture emulation
  aarch64 = true;   # Specifically enable aarch64 emulation
};
```

## Installer Workflow

1. **Network Check** - Verify connectivity (can be skipped for offline)
2. **User Setup** - Username, full name, email, password
3. **System Setup** - Hostname, storage mode, disk selection
4. **Encryption** - ZFS passphrase (if applicable)
5. **Locale** - Language, keyboard layout
6. **SSH** - Optional SSH server with GitHub key import
7. **Confirmation** - Review and type `DESTROY` to proceed
8. **Installation** - Disko partitioning, nixos-install, flake copy

## Post-Installation

### File Locations

| Path | Description |
|------|-------------|
| `/etc/tuinix` | System reference copy of flake |
| `~/tuinix` | User's working copy (git repo) |
| `~/tuinix-install.log` | Installation log |

### First Boot

1. Remove USB drive
2. Select tuinix from GRUB
3. Enter ZFS encryption passphrase (if applicable)
4. Log in with configured credentials

### System Updates

```bash
cd ~/tuinix
git pull                                    # Get upstream changes
sudo nixos-rebuild switch --flake .#hostname
```

## Version Information

- **NixOS Base**: nixos-unstable
- **Nix Features**: flakes, nix-command
- **State Version**: 25.11

## Dependencies

### Flake Inputs

| Input | Description |
|-------|-------------|
| nixpkgs | NixOS packages (nixos-unstable) |
| nixos-hardware | Hardware-specific configurations |
| disko | Declarative disk partitioning |
| home-manager | User environment management |
| flake-utils | Flake helper utilities |

## License

tuinix is open source software. See the repository for license details.
