# R36S NixOS Build Notes

This document captures the research and context needed to create a direct-flash SD card image for the R36S handheld gaming device.

## Device Overview

!!! warning "Multiple SoC Variants"
    R36S devices ship with different SoCs. Your device may have:
    - **Allwinner A33** (ARM Cortex-A7 quad-core) - This is the variant we have
    - **Rockchip RK3326** (ARM Cortex-A35 quad-core) - Different boot process

### Our Device (Allwinner A33)

- **Device**: R36S handheld gaming console
- **SoC**: Allwinner A33 (sun8i family)
- **Architecture**: ARMv7 (ARM Cortex-A7 quad-core) - **NOT aarch64!**
- **Storage**: SD card slots (TF1 and TF2)
- **Display**: 3.5" IPS screen
- **Stock OS**: EmuELEC 4.7-Nexus (OdroidGoAdvance.aarch64 label is misleading)
- **Serial Console**: `ttyS2,115200`
- **Stock Kernel**: Linux 3.4.39 (old vendor kernel, GCC 4.6.3)
- **Config Format**: Allwinner script.bin (not DTB!)

## Stock SD Card Analysis

Analysis of the stock EmuELEC SD card image from our R36S device.

### Partition Layout

```
Device     Boot   Start       End  Sectors  Size Id Type
/dev/sdb1       3383336 102397950 99014615 47,2G  b W95 FAT32    # ROMs/Games
/dev/sdb2  *      73728    139263    65536   32M  6 FAT16       # Boot assets
/dev/sdb3             1   3383336  3383336  1,6G 85 Linux ext   # Extended
/dev/sdb5        139264    172031    32768   16M 83 Linux       # U-Boot env
/dev/sdb6        172032    237567    65536   32M 83 Linux       # Kernel (boot.img)
/dev/sdb7        237568   1286143  1048576  512M 83 Linux       # SYSTEM (squashfs)
/dev/sdb8       1286144   3383335  2097192    1G 83 Linux       # Storage (ext4)
```

### Partition Contents

| Partition | Mount Point | Content |
|-----------|-------------|---------|
| sdb1 (FAT32) | /storage/roms | ROMs and games storage |
| sdb2 (FAT16, boot flag) | /flash | Boot assets: `bootlogo.bmp`, fonts, `magic.bin`, battery BMPs |
| sdb5 (16MB) | - | U-Boot environment (bootcmd, bootargs, etc.) |
| sdb6 (32MB) | - | Android boot.img format (kernel + DTB + initramfs) |
| sdb7 (FAT32, EMUELEC) | - | `SYSTEM` squashfs image (406MB), `low_pwr.bmp` |
| sdb8 (ext4) | /storage | User data: RetroArch cores, configs, saves |

### Boot Process (Allwinner A33)

1. **BootROM** (on-chip) loads SPL from SD card
2. **U-Boot SPL** (at 8KB offset) initializes DRAM
3. **U-Boot** loads environment from sdb5, executes bootcmd
4. **Kernel** loaded from Android boot.img on sdb6
5. **Init** mounts SYSTEM squashfs from sdb7, storage from sdb8

### U-Boot Environment (extracted from sdb5)

```
bootdelay=0
bootcmd=run setargs_mmc boot_normal
console=ttyS2,115200
mmc_root=/dev/mmcblk0p7
init=/init
disk=/dev/mmcblk0p8
loglevel=0
setargs_mmc=setenv bootargs console=${console} root=${mmc_root} init=${init} disk=${disk} ...
```

### SYSTEM Squashfs Image

- **Format**: Squashfs 4.0, LZO compressed
- **Size**: 425MB
- **OS**: EmuELEC 4.7-Nexus (based on LibreELEC/CoreELEC)
- **Architecture ID**: `A33` (in `/ee_arch`)
- **Platform**: OdroidGoAdvance.aarch64

### Key Files in SYSTEM

```
/                     # Standard Linux root structure
├── usr/              # All binaries and libraries
│   ├── lib/kernel/install.conf
│   └── share/bootloader/
│       ├── overlays/     # DTB overlays (sun8i-*, sun50i-*)
│       └── update.sh     # U-Boot update script
├── ee_arch           # Contains "A33"
└── etc/os-release    # EmuELEC version info
```

## Why ISO Won't Work

The standard aarch64 ISO requires UEFI boot support. The R36S/Allwinner A33 uses a custom boot flow:

1. **BootROM** looks for U-Boot at 8KB offset on SD card
2. **Android boot.img** format for kernel (not standard zImage/vmlinuz)
3. **No UEFI** - uses U-Boot with custom boot commands
4. **Squashfs root** - immutable system image

## Required Components for NixOS

### 1. U-Boot Bootloader

For Allwinner A33:
- U-Boot SPL must be written at 8KB (sector 16) offset
- `u-boot-sunxi-with-spl.bin` is the standard Allwinner U-Boot image

### 2. Kernel + DTB

The stock image uses Android boot.img format containing:
- Kernel (for sun8i A33)
- Device tree blob
- Initramfs

### 3. Root Filesystem

Options:
- Squashfs (like stock) - immutable, compressed
- ext4 - standard Linux, mutable

## SD Card Layout (Proposed for NixOS)

```
Offset (bytes)    | Content
------------------|------------------
0-8KB             | Reserved (MBR at 0)
8KB               | u-boot-sunxi-with-spl.bin (~1MB)
1MB               | Reserved
Boot partition    | FAT32 - kernel, DTB, extlinux.conf or boot.scr
Root partition    | ext4 - NixOS root filesystem
```

## Implementation Plan

### Step 1: Extract Stock Image Components

We have the stock SD card mounted. Let's extract the key components:

```bash
# The stock image is at /dev/sdb

# Extract the bootloader region (first 8MB contains U-Boot)
sudo dd if=/dev/sdb of=firmware/r36s/bootloader.bin bs=1k count=8192

# Extract the Android boot.img (kernel + DTB)
sudo dd if=/dev/sdb6 of=firmware/r36s/boot.img bs=512

# The SYSTEM squashfs is at /mnt/r36s-emuelec/SYSTEM
# The boot assets are at /mnt/r36s-boot/
```

### Step 2: Create NixOS SD Image Module

```nix
# modules/images/r36s-sd-image.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    "${pkgs.path}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
  ];

  # Use extlinux bootloader (not GRUB)
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Allwinner A33 / sun8i device tree
  hardware.deviceTree.enable = true;
  hardware.deviceTree.name = "sun8i-a33-*.dtb";  # TBD: exact DTB name

  # Serial console for debugging (from stock U-Boot env)
  boot.kernelParams = [
    "console=ttyS2,115200"
    "root=/dev/mmcblk0p2"
    "rootwait"
    "loglevel=4"
  ];

  # SD image settings
  sdImage = {
    compressImage = false;
    imageBaseName = "tuinix-r36s";

    # Write U-Boot to 8KB offset (Allwinner convention)
    postBuildCommands = ''
      # Write u-boot-sunxi-with-spl.bin at 8KB offset
      dd if=${./firmware/r36s/u-boot-sunxi-with-spl.bin} of=$img bs=1k seek=8 conv=notrunc
    '';
  };
}
```

### Step 3: Add to Flake

```nix
# In flake.nix
nixosConfigurations.r36s-sd = nixpkgs.lib.nixosSystem {
  system = "aarch64-linux";
  modules = [
    ./modules/images/r36s-sd-image.nix
    ./hosts/r36s
  ];
};

# Build with:
# nix build .#nixosConfigurations.r36s-sd.config.system.build.sdImage
```

### Step 4: Build Script

Create `scripts/build-sd-image.sh`:

```bash
#!/usr/bin/env bash
# Build R36S SD card image

set -euo pipefail

VERSION=$(git describe --tags --always 2>/dev/null || echo "dev")

echo "Building R36S SD image..."
nix build .#nixosConfigurations.r36s-sd.config.system.build.sdImage

# Copy to project root
cp result/sd-image/*.img "./tuinix.${VERSION}.r36s.img"
echo "Created: tuinix.${VERSION}.r36s.img"
```

## Files to Create

1. `modules/images/r36s-sd-image.nix` - SD image configuration
2. `firmware/r36s/u-boot-sunxi-with-spl.bin` - U-Boot for Allwinner A33
3. `firmware/r36s/boot.img` - Extracted Android boot image (kernel+DTB)
4. `hosts/r36s/default.nix` - R36S host configuration
5. `scripts/build-sd-image.sh` - Build script for SD images

## Reference Projects

- [AW-Some/sun8i](https://github.com/AW-Some/sun8i-a33) - Allwinner A33 resources
- [linux-sunxi](https://linux-sunxi.org/A33) - Allwinner A33 wiki
- [EmuELEC](https://github.com/EmuELEC/EmuELEC) - Stock OS source
- [JELOS](https://github.com/JustEnoughLinuxOS/distribution) - R36S-compatible Linux distro
- [ArkOS](https://github.com/christianhaitian/arkos) - Another R36S Linux option

## Debugging

### Serial Console

R36S (Allwinner A33) uses UART2 at 115200 baud:
```
console=ttyS2,115200
```

### Common Issues

1. **Black screen**: Wrong DTB for display panel or missing display driver
2. **No boot**: U-Boot at wrong offset (should be 8KB for Allwinner)
3. **Kernel panic**: Missing drivers or wrong root= parameter
4. **No SD card detected**: Need sun8i MMC driver in kernel

## Extracted Information

From the stock SD card we have:

| Item | Location | Notes |
|------|----------|-------|
| U-Boot env | sdb5 | Contains boot commands and kernel args |
| Kernel | sdb6 | Android boot.img format |
| Root FS | sdb7 | Squashfs SYSTEM image |
| Architecture | ee_arch | `A33` |
| OS Version | os-release | EmuELEC 4.7-Nexus |
| Serial | U-Boot env | `ttyS2,115200` |

## Extracted Kernel Analysis

From the stock boot.img:

```
Boot image header:
- boot magic: ANDROID!
- kernel_size: 13213848 bytes (~12.6MB)
- kernel load address: 0x40008000
- ramdisk size: 3040904 bytes (~2.9MB)
- ramdisk load address: 0x41000000
- page size: 2048
- product name: sun8i

Kernel version: Linux 3.4.39
Build: Mon Aug 18 10:47:18 CST 2025
Compiler: GCC 4.6.3 (Linaro crosstool-NG)
Architecture: ARMv7 (32-bit ARM, NOT aarch64!)
Config: Uses Allwinner script.bin (not Device Tree)
```

## Critical Findings

1. **Architecture Mismatch**: The R36S with Allwinner A33 is **ARMv7 (32-bit)**, not aarch64.
   This means we need `armv7l-linux` NixOS, not `aarch64-linux`.

2. **Old Vendor Kernel**: Stock uses Linux 3.4.39 (ancient). Mainline support for A33 exists
   but display/audio drivers may be problematic.

3. **No Device Tree**: Uses Allwinner's legacy script.bin format instead of modern DTB.
   Mainline kernel would need proper sun8i-a33 device tree.

4. **Android Boot Format**: Kernel is packaged as Android boot.img, not standard zImage.

## Options for NixOS on R36S (Allwinner A33)

### Option 1: Use Stock Kernel (Simplest)
- Keep the vendor 3.4.39 kernel and boot.img
- Replace only the rootfs
- Pros: Display, audio, input all work
- Cons: Old kernel, security issues, limited features

### Option 2: Mainline Kernel (Challenging)
- Build mainline Linux with sun8i-a33 device tree
- Requires proper DTB for R36S display panel
- Pros: Modern kernel, proper hardware support path
- Cons: Display driver may need work, unknown panel variant

### Option 3: Community Kernel (Middle Ground)
- Use kernel from JELOS/ArkOS/Batocera
- These projects may have R36S-specific patches
- Check: https://github.com/JustEnoughLinuxOS/distribution

## Next Steps

1. **Verify architecture**: Confirm if NixOS armv7l is feasible on this device
2. **Research mainline support**: Check linux-sunxi wiki for A33 status
3. **Extract/document script.bin**: May contain display panel info
4. **Test with stock kernel**: Try booting NixOS rootfs with vendor kernel first
5. **Find R36S DTB**: Search community projects for device tree
