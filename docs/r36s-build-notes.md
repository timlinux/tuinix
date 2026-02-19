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

## Initramfs Analysis

The stock ramdisk is a gzip-compressed cpio archive containing a BusyBox-based init system.

### Ramdisk Structure

```
/
├── bin/           # BusyBox symlinks
├── dev/           # Device nodes
├── etc/           # Minimal config
├── functions      # Shell helper functions
├── init           # Main init script (43KB shell script)
├── lib/           # Minimal libraries
├── mnt/           # Mount points
├── proc/          # Proc mountpoint
├── root/          # Root home
├── sbin/          # System binaries
├── sys/           # Sysfs mountpoint
└── usr/           # Additional utilities
```

### Init Script Boot Flow

The `/init` script performs:

1. **Early mounts**: `/proc`, `/sys`, `/dev` (devtmpfs), `/run` (tmpfs)
2. **Parse cmdline**: Extracts `root=`, `disk=`, `init=` parameters
3. **Mount flash**: Mounts FAT partition (sdb7) to `/flash`
4. **Mount SYSTEM**: Loop-mounts `/flash/SYSTEM` squashfs to `/sysroot`
5. **Mount storage**: Mounts ext4 partition (sdb8) to `/sysroot/storage`
6. **Switch root**: `exec busybox switch_root /sysroot /usr/lib/systemd/systemd`

### Key Kernel Parameters (from cmdline)

| Parameter | Stock Value | Purpose |
|-----------|-------------|---------|
| `console` | `ttyS2,115200` | Serial debug console |
| `root` | `/dev/mmcblk0p7` | FAT partition with SYSTEM |
| `init` | `/init` | Ramdisk init script |
| `disk` | `/dev/mmcblk0p8` | Storage partition |
| `loglevel` | `0` | Quiet boot (no kernel messages) |

## SYSTEM Squashfs Analysis

### OS Information

```
NAME="EmuELEC"
VERSION="4.7-Nexus_devel_20251120145101"
VERSION_ID="4.7"
LIBREELEC_PROJECT="Allwinner"
COREELEC_DEVICE="A33"
```

### Filesystem Layout

```
/sysroot/                    # After switch_root becomes /
├── bin -> /usr/bin          # Symlink
├── lib -> /usr/lib          # Symlink
├── sbin -> /usr/sbin        # Symlink
├── usr/
│   ├── bin/                 # All binaries
│   ├── lib/
│   │   └── systemd/         # systemd 252
│   │       └── systemd      # PID 1 after switch_root
│   └── share/
├── etc/                     # Config (some symlinked to /storage)
├── storage/                 # Mountpoint for sdb8
├── flash/                   # Mountpoint for sdb7 (FAT with SYSTEM)
├── ee_arch                  # Contains "A33"
└── emuelec -> /storage/.config/emuelec
```

### Systemd Version

The SYSTEM uses **systemd 252** with standard service units.

## Required Kernel Modules

The stock SYSTEM includes these proprietary/vendor modules that must be loaded for hardware to work:

| Module | Size | Purpose | Vermagic |
|--------|------|---------|----------|
| `mali.ko` | 3.3MB | Mali-400 GPU driver | 3.4.39 SMP preempt ARMv7 |
| `disp.ko` | 4.9MB | Display driver (Allwinner) | 3.4.39 SMP preempt ARMv7 |
| `lcd.ko` | 1.5MB | LCD panel driver | 3.4.39 SMP preempt ARMv7 |
| `gpio-sunxi.ko` | 84KB | GPIO driver | 3.4.39 SMP preempt ARMv7 |
| `udt_joystick.ko` | 116KB | Joystick/gamepad driver | 3.4.39 SMP preempt ARMv7 |
| `cdc_ether.ko` | 181KB | USB CDC Ethernet | 3.4.39 SMP preempt ARMv7 |
| `meig_cdc_driver.ko` | 353KB | USB CDC driver | 3.4.39 SMP preempt ARMv7 |

### Module Loading

Modules are loaded by `/usr/bin/emuelec_autostart.sh`:

```bash
# Display modules (loaded by lsb_release script)
insmod /usr/lib/modules/disp.ko
insmod /usr/lib/modules/lcd.ko
insmod /usr/lib/modules/mali.ko

# Input/GPIO modules (loaded by autostart)
insmod /usr/lib/modules/gpio-sunxi.ko
insmod /usr/lib/modules/udt_joystick.ko
```

### Critical Note for NixOS

These modules have `vermagic=3.4.39 SMP preempt mod_unload modversions ARMv7 p2v8`.

**For NixOS to use these modules, we must:**
1. Copy the stock `.ko` files to NixOS
2. NOT build our own kernel modules (vermagic mismatch)
3. Use the stock kernel (boot.img) unmodified

## NixOS Integration Strategy

### Recommended: SYSTEM Squashfs Replacement

The cleanest approach is to replace the SYSTEM squashfs while keeping the boot infrastructure:

**Keep unchanged**:
- sdb2: Boot assets (bootlogo, fonts)
- sdb5: U-Boot environment
- sdb6: Android boot.img (vendor kernel 3.4.39)

**Replace**:
- sdb7: `/flash/SYSTEM` - Replace with NixOS squashfs

**Reuse**:
- sdb8: `/storage` - Can keep for persistent data

### NixOS Requirements for Compatibility

For NixOS to work as a SYSTEM replacement:

1. **Squashfs format**: Build NixOS as squashfs image
2. **Init location**: `/usr/lib/systemd/systemd` must be the init binary
3. **Architecture**: armv7l-linux (NOT aarch64)
4. **Kernel modules**: Must work with stock 3.4.39 kernel (may be problematic)

### Kernel Module Compatibility Issue

The stock kernel 3.4.39 was built with GCC 4.6.3. NixOS modules would be built with modern GCC.
This creates a **vermagic mismatch** - kernel will refuse to load NixOS-built modules.

**Solutions**:
1. Use only built-in kernel features (no loadable modules)
2. Build modules with matching toolchain (complex)
3. Use mainline kernel (lose some hardware support)

## Building the R36S SD Image

### Prerequisites

Before building, you must extract firmware from a stock R36S SD card:

```bash
# Insert stock R36S SD card (appears as /dev/sdX)
SD=/dev/sdX

# Create firmware directory
mkdir -p firmware/r36s/modules

# Extract bootloader region (MBR + U-Boot)
sudo dd if=$SD of=firmware/r36s/bootloader-region.bin bs=512 count=73728

# Extract boot assets partition
sudo dd if=${SD}2 of=firmware/r36s/boot-assets.img bs=1M

# Extract U-Boot environment
sudo dd if=${SD}5 of=firmware/r36s/uboot-env.bin bs=1M

# Extract kernel boot.img
sudo dd if=${SD}6 of=firmware/r36s/boot.img bs=1M

# Mount SYSTEM and extract kernel modules
sudo mkdir -p /mnt/r36s-system
sudo mount -o loop /mnt/r36s-emuelec/SYSTEM /mnt/r36s-system
sudo cp /mnt/r36s-system/usr/lib/modules/*.ko firmware/r36s/modules/
sudo umount /mnt/r36s-system
```

### Build Command

```bash
# Build the R36S SD card image
nix build .#sd-r36s

# The resulting image will be in result/
```

### Flashing the Image

```bash
# Flash to SD card (replace /dev/sdX with your SD card)
sudo dd if=result of=/dev/sdX bs=4M status=progress conv=fsync
```

## Setting Up the Development Host for Cross-Architecture Builds

Building tuinix images for different architectures (aarch64 for ISO, armv7l for R36S) requires QEMU binfmt emulation. This allows your x86_64 machine to transparently execute ARM binaries during the build process.

### Prerequisites

Your NixOS development machine needs two configurations:

#### 1. Enable binfmt Emulation

Add this to your NixOS configuration (e.g., in `profiles/common.nix` or your host configuration):

```nix
{
  # Enable QEMU binfmt emulation for cross-architecture builds
  boot.binfmt.emulatedSystems = [ "aarch64-linux" "armv7l-linux" ];
}
```

#### 2. Configure Nix to Build for Emulated Platforms

Also add this to your nix settings:

```nix
{
  nix.settings = {
    # Allow building for emulated architectures (via binfmt)
    extra-platforms = [ "aarch64-linux" "armv7l-linux" ];
  };
}
```

### Applying the Configuration

If you use the [kartoza/nix-config](https://github.com/timlinux/nix-config) repository:

1. The configuration is already added to `profiles/common.nix`
2. Rebuild your system:
   ```bash
   cd ~/dev/nix/nix-config
   ./utils/rebuild.sh
   ```

If you use a different NixOS configuration:

1. Add the settings above to your configuration
2. Rebuild:
   ```bash
   sudo nixos-rebuild switch
   ```

### Verifying the Setup

After rebuilding, verify binfmt is working:

```bash
# Check registered emulators
ls /proc/sys/fs/binfmt_misc/
# Should show: aarch64-linux  armv7l-linux  register  status

# Verify armv7l emulation
cat /proc/sys/fs/binfmt_misc/armv7l-linux
# Should show: enabled
```

### Building Tuinix Images

Once binfmt is enabled, you can build for any supported architecture:

```bash
# x86_64 ISO (native)
nix build .#installer

# aarch64 ISO (emulated)
nix build .#installer-aarch64

# R36S SD image (armv7l, emulated)
nix build .#sd-r36s
```

### Build Performance Notes

- **Native x86_64 builds**: Fast, uses binary cache
- **aarch64 builds**: Good cache coverage, moderate speed via emulation
- **armv7l builds**: Limited cache, may need to compile many packages from source
  - First build can take several hours due to bootstrap toolchain compilation
  - Subsequent builds are faster as packages are cached locally

### Troubleshooting

**Build hangs or fails immediately:**
- Ensure you rebuilt NixOS after adding binfmt configuration
- Check `/proc/sys/fs/binfmt_misc/armv7l-linux` exists and is enabled

**"cannot execute binary file" errors:**
- binfmt module not loaded - reboot or run: `sudo systemctl restart systemd-binfmt`

**Very slow builds:**
- This is expected for armv7l - no binary cache means compiling from source
- Consider using a build server or distributed builds for faster results

## Architecture Notes

- **System**: armv7l-linux (32-bit ARM)
- **Cross-compilation**: Building from x86_64 requires binfmt emulation
- **Build time**: First build may take several hours due to toolchain compilation

## Files Structure

```
firmware/r36s/
├── bootloader-region.bin  # MBR + U-Boot SPL + U-Boot (36MB)
├── boot-assets.img        # Boot logos, fonts (32MB)
├── uboot-env.bin          # U-Boot environment (16MB)
├── boot.img               # Android boot image with kernel (32MB)
└── modules/               # Vendor kernel modules
    ├── mali.ko           # GPU driver
    ├── disp.ko           # Display driver
    ├── lcd.ko            # LCD panel driver
    ├── gpio-sunxi.ko     # GPIO driver
    ├── udt_joystick.ko   # Gamepad driver
    └── cdc_ether.ko      # USB Ethernet

modules/images/
├── r36s-sd-image.nix     # Main SD image module
├── r36s-squashfs.nix     # NixOS squashfs builder
└── r36s-build-image.nix  # SD image assembler

hosts/r36s/
├── default.nix           # R36S NixOS configuration
└── hardware.nix          # Hardware-specific settings
```
