# R36S handheld device configuration
{ config, lib, pkgs, inputs, hostname, ... }:

{
  imports = [ ./hardware.nix ../../users/user.nix ../../users/admin.nix ];

  networking.hostName = hostname;
  # Required by ZFS - a unique 8-hex-digit ID for this host.
  # On a real install, generate with: head -c 8 /etc/machine-id
  networking.hostId = "36500001";

  # Enable iPhone USB tethering support
  tuinix.networking.iphone-tethering.enable = true;

  # R36S uses ext4 by default (ZFS not well suited for small eMMC/SD storage)
  tuinix.zfs.enable = false;

  system.stateVersion = "25.11";
}
