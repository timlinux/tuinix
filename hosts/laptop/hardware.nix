# Laptop hardware configuration
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Minimal filesystem declarations for nix flake check.
  # On a real install, disko generates the actual ZFS layout.
  fileSystems."/" = {
    device = "NIXROOT/root";
    fsType = "zfs";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  # Framework 16-inch AMD display settings
  tuinix.display.resolution = "2560x1600";

  # AMD GPU panel self-refresh workaround
  # https://community.frame.work/t/fedora-kde-becomes-suddenly-slow/58459
  # https://gitlab.freedesktop.org/drm/amd/-/issues/3647
  boot.kernelParams = [ "amdgpu.dcdebugmask=0x10" ];

  # Load amdgpu early to avoid resolution switching during boot
  #boot.initrd.kernelModules = [ "amdgpu" ]; # or i915, nouveau, etc.

  # platform and cpu options
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # enable bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # AMD has better battery life with PPD over TLP:
  # https://community.frame.work/t/responded-amd-7040-sleep-states/38101/13
  services.power-profiles-daemon.enable = lib.mkDefault true;

  # Hardware settings
  hardware = {
    # Enable all firmware
    enableAllFirmware = true;

    # CPU microcode updates
    #cpu.intel.updateMicrocode = true;
    #cpu.amd.updateMicrocode = true;

  };

  # Power management
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
