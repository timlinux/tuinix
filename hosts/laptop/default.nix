{ config, lib, pkgs, inputs, hostname, ... }:

{
  imports = [
    ./disks.nix
    ./hardware.nix
    ../../users/user.nix
  ];

  networking.hostName = hostname;
  system.stateVersion = "24.05";
}

