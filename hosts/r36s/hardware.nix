# R36S Hardware Configuration
# Allwinner A33 (sun8i) - ARMv7
{ config, lib, pkgs, modulesPath, ... }:

{
  # Import the base ARM configuration
  imports = [
    # No standard NixOS hardware module for A33
  ];

  # The stock kernel boots via Android boot.img format
  # We don't control the kernel - it's provided by the bootloader
  # This configuration is for the NixOS userspace only

  # Disable NixOS bootloader management - stock U-Boot handles boot
  # Use mkForce to override any defaults from other modules
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.generic-extlinux-compatible.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce false;

  # The stock kernel will mount root and call /init
  # We need to provide a compatible init
  boot.isContainer = false;

  # Filesystem configuration
  # Stock boot process: kernel loads, initramfs mounts /flash/SYSTEM to /sysroot
  # For squashfs-based root, we don't specify a root filesystem here
  # The initramfs handles this
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "size=64M" "mode=755" ];
  };

  # Storage partition mounted by init
  fileSystems."/storage" = {
    device = "/dev/mmcblk0p8";
    fsType = "ext4";
    options = [ "noatime" "nodiratime" ];
  };

  # No swap on this device
  swapDevices = [ ];

  # Hardware settings for Allwinner A33
  hardware.enableRedistributableFirmware = lib.mkForce false;

  # CPU settings - Cortex-A7 quad-core
  nix.settings.max-jobs = 4;

  # Power management (may not work with vendor kernel)
  powerManagement.enable = false;

  # Disable kernel module building - we use stock vendor modules
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];
}
