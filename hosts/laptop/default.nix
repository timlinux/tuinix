{ config, lib, pkgs, inputs, hostname, ... }:

{
  imports = [ ./hardware.nix ../../users/user.nix ../../users/admin.nix ];

  networking.hostName = hostname;
  system.stateVersion = "25.11";
}

