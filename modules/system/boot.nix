# Boot configuration
{ config, lib, pkgs, ... }:

{
  # Boot loader configuration
  boot = {
    loader = {
      grub = {
        enable = lib.mkDefault true;
        efiSupport = lib.mkDefault true;
        efiInstallAsRemovable = lib.mkDefault true;
        device = lib.mkDefault "nodev";
        configurationLimit = 10;
      };
      timeout = lib.mkDefault 5;
    };
    
    # Kernel configuration
    kernelPackages = lib.mkDefault pkgs.linuxPackages_6_6;
    
    # Clean /tmp on boot
    tmp.cleanOnBoot = true;
    
    # Enable Plymouth for boot splash
    plymouth.enable = false; # Keep minimal for terminal-only
  };
}