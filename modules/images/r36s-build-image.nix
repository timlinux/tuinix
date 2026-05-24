# R36S SD Card Image Builder
# Assembles a complete SD card image from:
#   - Stock bootloader region (U-Boot)
#   - Stock boot assets
#   - Stock U-Boot environment
#   - Stock boot.img (kernel + initramfs)
#   - NixOS SYSTEM squashfs
#   - Empty storage partition
#
{ config, lib, pkgs, firmwareDir, nixosSquashfs, ... }:

let
  # Stock partition layout (in 512-byte sectors)
  # Extracted from: sudo fdisk -l /dev/sdb
  partitions = {
    # sdb1 (ROMs) - we skip this, user can add their own data
    # sdb2 (boot assets) - at sector 73728, 65536 sectors (32MB)
    bootAssets = {
      start = 73728;
      size = 65536;
    };
    # sdb3 (extended) - container, at sector 1
    # sdb5 (u-boot env) - at sector 139264, 32768 sectors (16MB)
    ubootEnv = {
      start = 139264;
      size = 32768;
    };
    # sdb6 (boot.img) - at sector 172032, 65536 sectors (32MB)
    bootImg = {
      start = 172032;
      size = 65536;
    };
    # sdb7 (EMUELEC/SYSTEM) - at sector 237568, 1048576 sectors (512MB)
    system = {
      start = 237568;
      size = 1048576;
    };
    # sdb8 (storage) - at sector 1286144, 2097192 sectors (~1GB)
    storage = {
      start = 1286144;
      size = 2097192;
    };
  };

  # Total image size (up to end of storage partition)
  totalSectors = partitions.storage.start + partitions.storage.size;
  imageSizeMB = (totalSectors * 512) / (1024 * 1024);

  # Build SYSTEM FAT32 image with SYSTEM squashfs inside
  systemFatImage = pkgs.callPackage ({ runCommand, dosfstools, mtools }:
    runCommand "r36s-system.fat" {
      nativeBuildInputs = [ dosfstools mtools ];
    } ''
      # Create a FAT32 image of the right size
      truncate -s ${toString (partitions.system.size * 512)} $out
      mkfs.vfat -F 32 -n EMUELEC $out

      # Copy SYSTEM squashfs using mtools (no mount needed)
      mcopy -i $out ${nixosSquashfs} ::SYSTEM
    '') { };

  # Build storage ext4 image
  storageExt4Image = pkgs.callPackage ({ runCommand, e2fsprogs }:
    runCommand "r36s-storage.ext4" { nativeBuildInputs = [ e2fsprogs ]; } ''
      # Create ext4 image
      truncate -s ${toString (partitions.storage.size * 512)} $out
      mkfs.ext4 -L storage -F $out
    '') { };

in pkgs.runCommand "tuinix-r36s.img" {
  nativeBuildInputs = with pkgs; [ coreutils ];
} ''
  # Create empty image
  echo "Creating ${toString imageSizeMB}MB SD card image..."
  truncate -s ${toString imageSizeMB}M $out

  # Write the bootloader region (includes MBR, U-Boot SPL, U-Boot)
  echo "Writing bootloader region..."
  dd if=${firmwareDir}/bootloader-region.bin of=$out bs=512 conv=notrunc status=none

  # Write boot assets partition (sdb2)
  echo "Writing boot assets..."
  dd if=${firmwareDir}/boot-assets.img of=$out bs=512 seek=${
    toString partitions.bootAssets.start
  } conv=notrunc status=none

  # Write U-Boot environment (sdb5)
  echo "Writing U-Boot environment..."
  dd if=${firmwareDir}/uboot-env.bin of=$out bs=512 seek=${
    toString partitions.ubootEnv.start
  } conv=notrunc status=none

  # Write boot.img (sdb6)
  echo "Writing kernel boot.img..."
  dd if=${firmwareDir}/boot.img of=$out bs=512 seek=${
    toString partitions.bootImg.start
  } conv=notrunc status=none

  # Write SYSTEM partition (sdb7)
  echo "Writing SYSTEM partition with NixOS..."
  dd if=${systemFatImage} of=$out bs=512 seek=${
    toString partitions.system.start
  } conv=notrunc status=none

  # Write storage partition (sdb8)
  echo "Writing storage partition..."
  dd if=${storageExt4Image} of=$out bs=512 seek=${
    toString partitions.storage.start
  } conv=notrunc status=none

  echo "R36S SD image created successfully!"
  echo "Size: $(du -h $out | cut -f1)"
''
