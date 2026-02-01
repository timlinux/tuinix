# Disko configuration template for tuinix
# Variables to be interpolated:
# - {{DISK_DEVICE}} - Target disk device (e.g., /dev/sda, /dev/nvme0n1, /dev/vda)
# - {{HOSTNAME}} - System hostname
# - {{SPACE_BOOT}} - Boot partition size (default: 5G)
# - {{SPACE_NIX}} - /nix partition quota
# - {{SPACE_ATUIN}} - /var/atuin volume size
# - {{ZFS_POOL_NAME}} - ZFS pool name (default: NIXROOT)

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
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "{{ZFS_POOL_NAME}}";
              };
            };
          };
        };
      };
    };

    zpool = {
      "{{ZFS_POOL_NAME}}" = {
        type = "zpool";
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          relatime = "on";
          mountpoint = "none";
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "prompt";
          "com.sun:auto-snapshot" = "false";
        };

        datasets = {
          "root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              "com.sun:auto-snapshot" = "false";
              mountpoint = "/";
            };
            postCreateHook = ''
              zfs snapshot {{ZFS_POOL_NAME}}/root@blank
            '';
          };

          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              "com.sun:auto-snapshot" = "false";
              quota = "{{SPACE_NIX}}";
            };
          };

          "home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = { "com.sun:auto-snapshot" = "true"; };
          };

          "overflow" = {
            type = "zfs_fs";
            mountpoint = "/overflow";
            options = { "com.sun:auto-snapshot" = "true"; };
          };

          "atuin" = {
            type = "zfs_volume";
            size = "{{SPACE_ATUIN}}";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/var/atuin";
              mountOptions = [ "defaults" "nofail" ];
            };
          };
        };
      };
    };
  };
}
