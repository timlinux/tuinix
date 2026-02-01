# tuinix installer ISO configuration
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  # Include flake files and assets on the ISO
  isoImage.contents = [
    {
      source = ./flake.nix;
      target = "/tuinix/flake.nix";
    }
    {
      source = ./flake.lock;
      target = "/tuinix/flake.lock";
    }
    {
      source = ./hosts;
      target = "/tuinix/hosts";
    }
    {
      source = ./modules;
      target = "/tuinix/modules";
    }
    {
      source = ./users;
      target = "/tuinix/users";
    }
    {
      source = ./templates;
      target = "/tuinix/templates";
    }
    {
      source = ./scripts;
      target = "/tuinix/scripts";
    }
    {
      source = ./build-info.txt;
      target = "/tuinix/build-info.txt";
    }
    {
      source = ./.github/assets/LOGO.png;
      target = "/tuinix/.github/assets/LOGO.png";
    }
  ];

  # Packages for installation environment
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
    disko
    gum
    chafa
    bc
    nixos-install-tools
    util-linux
  ];

  # Enable SSH
  services.openssh.enable = true;

  # Set root password (override any defaults)
  users.users.root = {
    password = "nixos";
    initialHashedPassword = lib.mkForce null;
    hashedPassword = lib.mkForce null;
    hashedPasswordFile = lib.mkForce null;
    initialPassword = lib.mkForce null;
  };

  # Minimal network configuration (faster than NetworkManager)
  networking.useDHCP = lib.mkForce true;
  networking.firewall.enable = lib.mkForce false;

  # Enable flakes and nix-command for disko and nixos-install
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Symlink /iso/tuinix to /home/tuinix and set up welcome on login
  system.activationScripts.tuinix-home = ''
    mkdir -p /home
    ln -sfn /iso/tuinix /home/tuinix
  '';

  # Root profile: cd into tuinix dir and show welcome on interactive login
  programs.bash.loginShellInit = ''
    if [ -d /home/tuinix ]; then
      cd /home/tuinix
      if [ -f scripts/welcome.sh ]; then
        source scripts/welcome.sh
      fi
    fi
  '';

  system.stateVersion = "25.11";
}
