# tuinix installer ISO configuration
# This is a curried module: first call with { system } to get the actual module
{ system ? "x86_64-linux" }:
{ config, lib, pkgs, modulesPath, offlineSystemClosure ? null, ... }:

let
  # Get version info from build-info.txt or use defaults
  buildInfo = builtins.readFile ./build-info.txt;
  versionLine = builtins.head
    (builtins.filter (l: builtins.match "Version:.*" l != null)
      (lib.splitString "\n" buildInfo));
  commitLine = builtins.head
    (builtins.filter (l: builtins.match "Commit:.*" l != null)
      (lib.splitString "\n" buildInfo));
  version = lib.removePrefix "Version: " versionLine;
  commit = lib.removePrefix "Commit: "
    (builtins.head (lib.splitString " " commitLine));
  versionString = "${version} (${commit})";

  # Build the Go TUI installer with version info
  tuinix-installer = pkgs.buildGoModule {
    pname = "tuinix-installer";
    version = "1.0.0";
    src = ./cmd/installer;
    vendorHash = "sha256-PLBuZeKhfuwcln0eOFwwLag4y+tr9PQj0zvYuCtMO/c=";
    ldflags = [ "-s" "-w" ];
    env = { CGO_ENABLED = "0"; };
    preBuild = ''
      echo "${versionString}" > version.txt
    '';
  };
in {
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  # No extra pre-cached store contents beyond what the live system needs.
  # The base module automatically includes the system closure in the squashfs.
  # Packages needed at install time come from environment.systemPackages only.
  isoImage.storeContents = [ ];

  # Better squashfs compression for smaller ISO
  isoImage.squashfsCompression = "zstd -Xcompression-level 19";

  # Don't include build dependencies
  system.includeBuildDependencies = false;

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

  # Minimal package set - only what the installer actually needs
  environment.systemPackages = with pkgs;
    [
      tuinix-installer
      git
      vim
      curl
      parted
      gptfdisk
      e2fsprogs
      dosfstools
      disko
      nixos-install-tools
      mkpasswd
      util-linux
      # iPhone USB tethering support
      libimobiledevice
      ifuse
      usbmuxd
    ]
    # ZFS only available on x86_64
    ++ lib.optionals (system == "x86_64-linux") [ zfs ];

  # Enable SSH
  services.openssh.enable = true;

  # Enable iPhone USB tethering support
  services.usbmuxd.enable = true;

  # Disable ModemManager - not needed for terminal installer
  systemd.services.ModemManager.enable = lib.mkForce false;

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

  # Disable everything not needed for a terminal installer
  services.udisks2.enable = lib.mkForce false;
  security.polkit.enable = lib.mkForce false;
  documentation.enable = lib.mkForce false;
  documentation.man.enable = lib.mkForce false;
  documentation.nixos.enable = lib.mkForce false;
  fonts.fontconfig.enable = lib.mkForce false;
  services.xserver.enable = lib.mkForce false;
  hardware.bluetooth.enable = lib.mkForce false;
  services.printing.enable = lib.mkForce false;
  programs.nano.enable = lib.mkForce false;
  xdg.mime.enable = lib.mkForce false;
  xdg.icons.enable = lib.mkForce false;

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
