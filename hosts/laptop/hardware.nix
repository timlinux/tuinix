# Laptop hardware configuration
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Disk configuration handled by disks.nix
  # No filesystem definitions here - let disks.nix handle ZFS layout

  # Boot configuration
  boot = {
    initrd = {
      availableKernelModules = [ 
        "xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  # Hardware settings
  hardware = {
    # Enable all firmware
    enableAllFirmware = true;
    
    # CPU microcode updates
    cpu.intel.updateMicrocode = true;
  };

  # Power management
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}