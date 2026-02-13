# Installation Overview

tuinix ships as ISO images that include the installer and system
configuration. An internet connection is required during installation
to fetch packages.

## Supported Platforms

tuinix supports two architectures:

| Platform | Architecture | Example Devices |
|----------|--------------|-----------------|
| x86_64 | AMD64/Intel | Laptops, desktops, servers |
| aarch64 | ARM64 | R36S handheld, Raspberry Pi 4/5, ARM servers |

## Get the ISO

Download the latest ISO for your architecture from the
[releases page]({{ iso.releases_url }}) ({{ iso.version }}),
or build it yourself:

```bash
git clone https://github.com/timlinux/tuinix.git
cd tuinix

# Build for x86_64 (default)
./scripts/build-iso.sh

# Build for aarch64 (R36S, ARM devices)
./scripts/build-iso.sh aarch64

# Build for both architectures
./scripts/build-iso.sh both
```

## Choose your target

| Target | Guide |
|--------|-------|
| Physical machine | [Bare Metal Installation](bare-metal.md) |
| QEMU, virt-manager, VirtualBox | [VM Installation](vm.md) |

## Requirements

### x86_64 Systems

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | x86_64 | Modern x86_64 |
| RAM | 4 GB | 8 GB+ |
| Storage | 20 GB | 50 GB+ |
| Boot mode | UEFI | UEFI |

### aarch64 Systems (R36S, ARM)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | ARM64 | Cortex-A53 or better |
| RAM | 1 GB | 2 GB+ |
| Storage | 8 GB | 32 GB+ |
| Boot mode | UEFI | UEFI |

!!! warning "UEFI required"
    tuinix requires UEFI boot mode. Legacy BIOS is not supported.
    On x86_64 systems with ZFS, Secure Boot must be disabled because
    ZFS kernel modules are unsigned.
