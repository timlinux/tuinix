# Installation Overview

tuinix ships as an ISO image that includes the installer, system configuration,
and all packages needed for a complete offline installation.

## Supported Architectures

| Architecture | Image Type | Target Devices |
|--------------|------------|----------------|
| x86_64 | ISO | Standard PCs, laptops, servers |
| aarch64 | ISO | ARM64 devices with UEFI boot |
| armv7l | SD Image | R36S handheld (Allwinner A33) |

## Installation Modes

### Offline Installation (Default)

The ISO includes the complete system closure - all packages required for
installation are pre-cached. No internet connection needed for standard
configurations.

!!! success "Fully Offline"
    The tuinix ISO can install a complete system without any network access.
    This is ideal for air-gapped environments or locations with poor connectivity.

### Online Installation

If your configuration adds packages beyond the standard set, an internet
connection may be required to fetch additional packages.

## Get the ISO

Download the latest ISO from the
[releases page]({{ iso.releases_url }}),
or build it yourself:

```bash
git clone https://github.com/timlinux/tuinix.git
cd tuinix

# Build for x86_64 (default)
./scripts/build-iso.sh

# Build for aarch64 (ARM64)
./scripts/build-iso.sh aarch64

# Build both architectures
./scripts/build-iso.sh both
```

## Choose your target

| Target | Guide |
|--------|-------|
| Physical machine | [Bare Metal Installation](bare-metal.md) |
| QEMU, virt-manager, VirtualBox | [VM Installation](vm.md) |
| R36S Handheld (Allwinner A33) | [R36S Installation](r36s.md) |

## Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | x86_64 or aarch64 | Modern multi-core |
| RAM | 4 GB | 8 GB+ |
| Storage | 20 GB | 50 GB+ SSD |
| Boot mode | UEFI | UEFI |

!!! warning "UEFI required"
    tuinix requires UEFI boot mode. Legacy BIOS is not supported.
    Secure Boot must be disabled because ZFS kernel modules are
    unsigned.

## Default Packages

Every tuinix installation includes:

**Networking:**

- NetworkManager with `nmtui` for easy WiFi/network configuration
- iPhone USB tethering support (libimobiledevice, usbmuxd)

**Core Tools:**

- vim, git, curl, wget, htop, tree

**ZFS Features (x86_64):**

- Full ZFS support with encryption, compression, and snapshots

See the [Specification](../SPECIFICATION.md) for complete package lists.
