# tuinix Specification

This document provides a comprehensive specification of the tuinix project - a pure terminal-based Linux experience built on NixOS.

## Overview

tuinix is a NixOS-based distribution designed for users who prefer a terminal-only computing environment. It provides a reproducible, declarative system with ZFS encryption, offline installation support, and multi-architecture builds.

## Supported Architectures

| Architecture | Image Type | Target Devices | Status |
|--------------|------------|----------------|--------|
| x86_64-linux | ISO | Standard PCs, laptops, servers | Fully supported |
| aarch64-linux | ISO | ARM64 laptops, servers, SBCs with UEFI | Supported |

### Architecture Notes

- **x86_64**: Primary development platform. Includes ZFS support.
- **aarch64**: Supports UEFI-capable ARM64 devices. ZFS excluded due to compatibility.

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

### Display

| Feature | Module | Default |
|---------|--------|---------|
| Console Resolution | `tuinix.display.resolution` | null (auto-detect) |

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

WiFi:
- iwd + impala (WiFi management TUI; replaces wpa_supplicant/NetworkManager)

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
- tmux, unzip, file, man-pages
- yazi (default file manager, alias: f)
- tuinix-menu (gum launcher with drill-down app categories)
- gum (TUI building blocks)

Sound and Bluetooth (base):
- wiremix (PipeWire mixer TUI, default sound application)
- bluetui (Bluetooth management TUI)
- brightnessctl (screen backlight control)
- PipeWire with ALSA/Pulse shims; Bluetooth enabled

Networking:
- networkmanager (nmtui, nmcli)
- libimobiledevice, ifuse, usbmuxd (iPhone tethering)

Home Manager:
- Git configuration (user name, email)
- Default shell configuration
```

### Optional Package Collections

Selected during installation (checkboxes on the Package Sets step) and
toggled later via `tuinix.packages.*` options:

| Collection | Option | Contents |
|------------|--------|----------|
| TUI productivity suite | `tuinix.packages.tui` | neovim, helix, lazygit, btop, zellij, starship, atuin, nchat, iamb, scli, aerc, w3m, khal, taskwarrior, ... |
| Pentest tools | `tuinix.packages.pentest` | aircrack-ng, nmap, metasploit, termshark, hashcat, sqlmap |
| Terminal games | `tuinix.packages.games` | angband, crawl, cataclysm-dda, vitetris, nudoku, frotz, bsdgames, ... |
| Sound and Music | `tuinix.packages.music` | tuinix-music-menu, elevator music generators, MIDI composer, fluidsynth, timidity, sox, csound, chuck, orca, abcmidi |
| Emergency GUI | `tuinix.packages.emergency` | tuinix-emergency-gui: Brave in a cage Wayland kiosk, incognito, profile on tmpfs, bubblewrap-sandboxed (home folders hidden, no writes to ZFS) |

### Installer Wizard Navigation

Every wizard step shows a button bar pinned to the bottom of the TUI:
Previous/Cancel bottom-left and the context-aware primary action
(Next, Continue, Install!) bottom-right. Tab/Shift+Tab cycle focus
between the step content and the buttons; Enter activates the focused
button. The Previous button walks back through visited steps with
earlier answers preserved for editing (secrets are always re-entered).

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

### Quick Test

```bash
nix run .#test-install    # Build ISO and launch QEMU VM for testing
```

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

Artifacts are placed in the project root, named
`tuinix-<architecture>-<version>` (same for local and CI builds):

- `tuinix-x86_64-VERSION.iso` + `tuinix-x86_64-VERSION.md5`
- `tuinix-aarch64-VERSION.iso` + `tuinix-aarch64-VERSION.md5`

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
│   ├── system/            # Boot, display, nix settings, ZFS
│   ├── networking/        # NetworkManager, WiFi, iPhone tethering
│   └── security/          # SSH, firewall
├── hosts/                 # Host configurations
│   └── laptop/            # Example laptop host
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
| `installer` | x86_64 installation ISO |
| `installer-aarch64` | aarch64 installation ISO |

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

### tuinix.display

```nix
tuinix.display = {
  resolution = "1920x1080";  # Set framebuffer console resolution (null = auto-detect)
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
| `~/tuinix` | User's flake (single source of truth, owned by user) |
| `/etc/tuinix` | Symlink to `~/tuinix` |
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
