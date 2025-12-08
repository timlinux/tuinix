# disk-layout.nix
{ lib, ... }:
let
  # Use by-id paths in your real setup
  d0 = "/dev/nvme0n1";
in
{
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = d0;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "5G";
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
                pool = "NIXROOT";
              };
            };
          };
        };
      };
    };

    zpool = {
      NIXROOT = {
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
        };

        # Encryption root: all children inherit (single unlock)
        datasets = {
          "root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options."com.sun:auto-snapshot" = "false";
          };

          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              "com.sun:auto-snapshot" = "false";
              quota = "250G";
            };
          };

          "home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {
              "com.sun:auto-snapshot" = "true";
            };
          };

          "overflow" = {
            type = "zfs_fs";
            mountpoint = "/overflow";
            options = {
              "com.sun:auto-snapshot" = "true";
            };
          };

          # Add atuin zvol (block device for XFS)
          "atuin" = {
            type = "zfs_volume";
            size = "50G";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/var/atuin";
              mountOptions = [
                "defaults"
                "nofail"
              ];
            };
          };
        };
      };
    };
  };
}