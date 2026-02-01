# Installation Overview

tuinix ships as an ISO image that includes the installer and system
configuration. An internet connection is required during installation
to fetch packages.

## Get the ISO

Download the latest ISO from the
[releases page]({{ iso.releases_url }}) ({{ iso.version }}),
or build it yourself:

```bash
git clone https://github.com/timlinux/tuinix.git
cd tuinix
./scripts/build-iso.sh
```

## Choose your target

| Target | Guide |
|--------|-------|
| Physical machine | [Bare Metal Installation](bare-metal.md) |
| QEMU, virt-manager, VirtualBox | [VM Installation](vm.md) |

## Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | x86_64 | Modern x86_64 |
| RAM | 4 GB | 8 GB+ |
| Storage | 20 GB | 50 GB+ |
| Boot mode | UEFI | UEFI |

!!! warning "UEFI required"
    tuinix requires UEFI boot mode. Legacy BIOS is not supported.
    Secure Boot must be disabled because ZFS kernel modules are
    unsigned.
