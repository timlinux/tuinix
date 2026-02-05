# tuinix installer ISO configuration
{ config, lib, pkgs, modulesPath, ... }:

let
  # Get version info from build-info.txt or use defaults
  buildInfo = builtins.readFile ./build-info.txt;
  versionLine = builtins.head (builtins.filter (l: builtins.match "Version:.*" l != null) (lib.splitString "\n" buildInfo));
  commitLine = builtins.head (builtins.filter (l: builtins.match "Commit:.*" l != null) (lib.splitString "\n" buildInfo));
  version = lib.removePrefix "Version: " versionLine;
  commit = lib.removePrefix "Commit: " (builtins.head (lib.splitString " " commitLine));
  versionString = "${version} (${commit})";

  # Build the Go TUI installer with version info
  tuinix-installer = pkgs.buildGoModule {
    pname = "tuinix-installer";
    version = "1.0.0";
    src = ./cmd/installer;
    vendorHash = null;
    ldflags = [ "-s" "-w" ];
    env = {
      CGO_ENABLED = "0";
    };
    preBuild = ''
      echo "${versionString}" > version.txt
    '';
  };
in
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
      target = "/tuinix/assets/LOGO.png";
    }
  ];

  # Packages for installation environment - minimal set, no X11/GUI deps
  environment.systemPackages = with pkgs; [
    tuinix-installer
    git
    vim
    nano
    curl
    wget
    parted
    gptfdisk
    e2fsprogs
    dosfstools
    xfsprogs
    zfs
    disko
    gum
    catimg
    bc
    nixos-install-tools
    mkpasswd
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

  # Disable unnecessary services for minimal ISO
  services.udisks2.enable = lib.mkForce false;
  security.polkit.enable = lib.mkForce false;

  # Disable documentation to save space
  documentation.enable = lib.mkForce false;
  documentation.man.enable = lib.mkForce false;
  documentation.nixos.enable = lib.mkForce false;

  # Disable fonts (terminal only)
  fonts.fontconfig.enable = lib.mkForce false;

  # Disable X11/Wayland completely - terminal only ISO
  services.xserver.enable = lib.mkForce false;

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
