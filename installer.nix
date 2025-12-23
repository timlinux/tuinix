# nixmywindows installer ISO configuration
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  # Include only essential flake files for installation
  isoImage.contents = [
    {
      source = ./flake.nix;
      target = "/nixmywindows/flake.nix";
    }
    {
      source = ./flake.lock;
      target = "/nixmywindows/flake.lock";
    }
    {
      source = ./hosts;
      target = "/nixmywindows/hosts";
    }
    {
      source = ./modules;
      target = "/nixmywindows/modules";
    }
    {
      source = ./users;
      target = "/nixmywindows/users";
    }
    {
      source = ./templates;
      target = "/nixmywindows/templates";
    }
    {
      source = ./scripts;
      target = "/nixmywindows/scripts";
    }
    {
      source = ./README.txt;
      target = "/nixmywindows/README.txt";
    }
    {
      source = ./build-info.txt;
      target = "/nixmywindows/build-info.txt";
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
    disko
    gum # For rich interactive UX in install script
    bc # For space calculations in install script
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

  # Auto-start the installer on boot
  systemd.services.nixmywindows-installer = {
    description = "nixmywindows automatic installer";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    script = ''
      # Wait for system to be ready
      sleep 5

      # Clear screen and show installer
      clear
      echo "🍃 nixmywindows Live Installer"
      echo ""
      echo "The installer script is located at /install.sh"
      echo "Run 'sudo /install.sh' to begin installation"
      echo ""
      echo "Or explore the system with:"
      echo "  • View available hosts: ls /nixmywindows/hosts/"
      echo "  • Manual installation: nixos-install --flake /nixmywindows#<hostname>"
      echo ""
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
    };
  };

  system.stateVersion = "25.11";
}

