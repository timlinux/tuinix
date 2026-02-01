{ config, lib, pkgs, inputs, hostname, ... }:

{
  imports = [ ./hardware.nix ../../users/user.nix ../../users/admin.nix ];

  networking.hostName = hostname;
  # Required by ZFS - a unique 8-hex-digit ID for this host.
  # On a real install, generate with: head -c 8 /etc/machine-id
  networking.hostId = "a1b2c3d4";
  system.stateVersion = "25.11";
}

