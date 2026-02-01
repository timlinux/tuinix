# Boot configuration
{ config, lib, pkgs, ... }:

{
  # Boot loader configuration
  boot = {
    loader = {
      grub = {
        enable = true;
        device = "nodev";
        efiInstallAsRemovable = true;
        efiSupport = true;
        zfsSupport = true;
        useOSProber = true;
        configurationLimit = 10;
      };
      timeout = 5;
    };

    # Kernel configuration - use latest ZFS-compatible kernel
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

    # Clean /tmp on boot
    tmp.cleanOnBoot = true;

    # Enable Plymouth for boot splash
    plymouth.enable = false; # Keep minimal for terminal-only

    # Kernel modules for initrd
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

    # Settings from https://github.com/NixOS/nixos-hardware/blob/master/framework/16-inch/common/amd.nix
    kernelParams = [
      # Next line also to prevent plymouth resolution changes
      "video=2560x1600"
      # There seems to be an issue with panel self-refresh (PSR) that
      # causes hangs for users.
      #
      # https://community.frame.work/t/fedora-kde-becomes-suddenly-slow/58459
      # https://gitlab.freedesktop.org/drm/amd/-/issues/3647
      "amdgpu.dcdebugmask=0x10"
    ]
    # Workaround for SuspendThenHibernate: https://lore.kernel.org/linux-kernel/20231106162310.85711-1-mario.limonciello@amd.com/
      ++ lib.optionals
      (lib.versionOlder config.boot.kernelPackages.kernel.version "6.8")
      [ "rtc_cmos.use_acpi_alarm=1" ];
  };
}
