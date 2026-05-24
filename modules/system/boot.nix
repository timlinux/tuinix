# Boot configuration
{ config, lib, pkgs, ... }:

let
  # Check if we're on x86_64 (desktop/laptop systems)
  isX86 = pkgs.stdenv.hostPlatform.isx86_64;
in {
  # Boot loader configuration - only for x86 systems
  boot = lib.mkIf isX86 {
    loader = {
      grub = {
        enable = lib.mkDefault true;
        device = "nodev";
        efiInstallAsRemovable = true;
        efiSupport = true;
        zfsSupport = lib.mkDefault config.tuinix.zfs.enable;
        useOSProber = true;
        configurationLimit = 10;
      };
      timeout = 5;
    };

    # Kernel configuration - use default LTS kernel for ZFS compatibility,
    # otherwise use the latest kernel for maximum performance
    kernelPackages = if config.tuinix.zfs.enable then
      pkgs.linuxPackages # Default LTS kernel, always ZFS-compatible
    else
      pkgs.linuxPackages_latest;

    # Clean /tmp on boot
    tmp.cleanOnBoot = true;

    # Enable Plymouth for boot splash
    plymouth.enable = false; # Keep minimal for terminal-only

    # Kernel modules for initrd (x86 specific)
    initrd.availableKernelModules = [
      "ahci"
      "xhci_pci"
      "sd_mod"
      "sr_mod"
      "nvme"
      "ehci_pci"
      "usbhid"
      "usb_storage"
      "rtsx_pci_sdmmc"
      "sdhci_pci"
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
    ];

    # Workaround for SuspendThenHibernate: https://lore.kernel.org/linux-kernel/20231106162310.85711-1-mario.limonciello@amd.com/
    kernelParams = lib.optionals
      (lib.versionOlder config.boot.kernelPackages.kernel.version "6.8")
      [ "rtc_cmos.use_acpi_alarm=1" ];
  };
}
