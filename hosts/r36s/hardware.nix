# R36S hardware configuration
# The R36S is an ARM-based handheld gaming device with Rockchip RK3326 SoC
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Minimal filesystem declarations for nix flake check.
  # On a real install, disko generates the actual layout.
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_ROOT";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  # Platform and CPU options - R36S uses ARM64
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # R36S has Rockchip RK3326 SoC with Mali-G31 GPU
  boot.kernelParams = [
    "console=ttyS2,1500000"
    "earlycon=uart8250,mmio32,0xff160000"
  ];

  # Enable Bluetooth (R36S has built-in Bluetooth)
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Hardware settings
  hardware = {
    # Enable firmware for Mali GPU and wireless
    enableAllFirmware = true;
  };

  # Power management for battery-powered device
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}
