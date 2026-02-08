# Filesystem configuration for existing partition XFS install
# Does not use disko device management - uses NixOS fileSystems directly
# Variables to be interpolated:
# - {{ROOT_PARTITION}} - Root partition device (e.g., /dev/sda3)
# - {{BOOT_PARTITION}} - Boot/ESP partition device (e.g., /dev/sda1)

{ lib, ... }:
{
  fileSystems = {
    "/" = {
      device = "{{ROOT_PARTITION}}";
      fsType = "xfs";
    };
    "/boot" = {
      device = "{{BOOT_PARTITION}}";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
  };
}
