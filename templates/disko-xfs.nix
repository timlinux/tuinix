# Disko configuration template for tuinix - XFS unencrypted (maximum performance)
# Variables to be interpolated:
# - {{DISK_DEVICE}} - Target disk device (e.g., /dev/sda, /dev/nvme0n1, /dev/vda)
# - {{SPACE_BOOT}} - Boot partition size (default: 5G)

{ lib, ... }:
let disk = "{{DISK_DEVICE}}";
in {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "{{SPACE_BOOT}}";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
