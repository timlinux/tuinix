# Simple installer ISO configuration
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  # Include the nixmywindows flake for installation
  isoImage.contents = [
    {
      source = ./.;
      target = "/nixmywindows";
    }
  ];

  # Basic packages for installation
  environment.systemPackages = with pkgs; [
    git
    vim
    nano
    curl
    wget
    parted
    gptfdisk
    e2fsprogs
    dosfstools
    zfs
  ];

  # Enable SSH
  services.openssh.enable = true;
  users.users.root.password = "nixos";
  
  # Network configuration
  networking.useDHCP = lib.mkForce true;
  networking.networkmanager.enable = lib.mkForce true;
  networking.firewall.enable = lib.mkForce false;
  
  system.stateVersion = "24.05";
}