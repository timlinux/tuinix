# R36S Hardware Configuration
# Allwinner A33 (sun8i) - ARMv7
# MINIMAL configuration - stock vendor kernel/bootloader
{ config, lib, pkgs, modulesPath, ... }:

{
  # ============================================================
  # BOOTLOADER - Stock U-Boot (we don't manage this)
  # ============================================================
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.generic-extlinux-compatible.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce false;

  # ============================================================
  # KERNEL - Stock vendor kernel (we don't build one)
  # ============================================================
  # The stock kernel (3.4.39) boots via Android boot.img format
  # We only provide NixOS userspace, not the kernel
  boot.isContainer = false;

  # Use a standard kernel package to satisfy NixOS, but we won't actually
  # use it - the stock vendor kernel in boot.img is what boots the device
  # Using latest to minimize build dependencies (no kernel build needed if cached)
  boot.kernelPackages = pkgs.linuxPackages;
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # ============================================================
  # FILESYSTEMS
  # ============================================================
  # Root is tmpfs - actual system is in squashfs overlay
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "size=64M" "mode=755" ];
  };

  # Persistent storage partition
  fileSystems."/storage" = {
    device = "/dev/mmcblk0p8";
    fsType = "ext4";
    options = [ "noatime" "nodiratime" ];
  };

  # No swap
  swapDevices = [ ];

  # ============================================================
  # HARDWARE
  # ============================================================
  # No firmware needed - vendor kernel has it built-in
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.enableAllFirmware = lib.mkForce false;

  # Disable power management (vendor kernel doesn't support it)
  powerManagement.enable = false;
}
