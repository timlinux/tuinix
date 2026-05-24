# R36S SD Card Image Builder
# Creates a direct-flash SD card image for R36S (Allwinner A33)
#
# The image uses the stock boot infrastructure (U-Boot, kernel, initramfs)
# but replaces the SYSTEM squashfs with NixOS.
#
# Partition layout (matching stock):
#   - Bootloader region: 0-36MB (MBR + U-Boot + boot assets)
#   - sdb5 (16MB): U-Boot environment
#   - sdb6 (32MB): Android boot.img (kernel + initramfs)
#   - sdb7 (512MB): FAT32 with SYSTEM squashfs
#   - sdb8 (1GB+): ext4 storage partition
#
# IMPORTANT: Before building, you must extract firmware from a stock R36S SD card.
# See docs/r36s-build-notes.md for instructions.
#
{ config, lib, pkgs, ... }:

let
  # Stock firmware files extracted from EmuELEC
  # These must be extracted manually from a stock SD card
  # and placed in the firmware/r36s directory
  firmwareDir = ../../firmware/r36s;

  # Check if firmware exists (will fail at build time if not)
  firmwareExists = builtins.pathExists firmwareDir;

  # Build NixOS as a squashfs image
  nixosSquashfs =
    pkgs.callPackage ./r36s-squashfs.nix { inherit config lib pkgs; };

  # Build the complete SD image (only if firmware exists)
  sdImage = if firmwareExists then
    pkgs.callPackage ./r36s-build-image.nix {
      inherit config lib pkgs;
      inherit firmwareDir nixosSquashfs;
    }
  else
    pkgs.runCommand "r36s-sd-image-missing-firmware" { } ''
      echo "ERROR: R36S firmware not found at firmware/r36s/"
      echo ""
      echo "Please extract firmware from a stock R36S SD card:"
      echo "  sudo dd if=/dev/sdX of=firmware/r36s/bootloader-region.bin bs=512 count=73728"
      echo "  sudo dd if=/dev/sdX2 of=firmware/r36s/boot-assets.img bs=1M"
      echo "  sudo dd if=/dev/sdX5 of=firmware/r36s/uboot-env.bin bs=1M"
      echo "  sudo dd if=/dev/sdX6 of=firmware/r36s/boot.img bs=1M"
      echo "  mkdir -p firmware/r36s/modules"
      echo "  # Mount SYSTEM squashfs and copy .ko files to firmware/r36s/modules/"
      echo ""
      echo "See docs/r36s-build-notes.md for detailed instructions."
      exit 1
    '';

in {
  options.tuinix.r36s = {
    enable = lib.mkEnableOption "R36S SD image build support";

    storageSize = lib.mkOption {
      type = lib.types.str;
      default = "2G";
      description = "Size of the storage partition";
    };
  };

  config = lib.mkIf config.tuinix.r36s.enable {
    # Export the SD image for building
    system.build.sdImage = sdImage;

    # Include stock kernel modules
    boot.extraModulePackages = [ ];

    # The kernel modules will be loaded by a systemd service
    systemd.services.r36s-modules = {
      description = "Load R36S hardware modules";
      wantedBy = [ "sysinit.target" ];
      before = [ "systemd-udev-trigger.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "load-r36s-modules" ''
          #!/usr/bin/env bash
          # Load Allwinner A33 hardware modules
          # These are vendor modules for kernel 3.4.39

          MODULES_DIR=/lib/modules/vendor

          # Display subsystem
          insmod $MODULES_DIR/disp.ko 2>/dev/null || true
          insmod $MODULES_DIR/lcd.ko 2>/dev/null || true
          insmod $MODULES_DIR/mali.ko 2>/dev/null || true

          # GPIO and input
          insmod $MODULES_DIR/gpio-sunxi.ko 2>/dev/null || true
          insmod $MODULES_DIR/udt_joystick.ko 2>/dev/null || true

          # USB networking
          insmod $MODULES_DIR/cdc_ether.ko 2>/dev/null || true
        '';
      };
    };
  };
}
