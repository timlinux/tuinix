# R36S Handheld Gaming Console - NixOS Configuration
# SoC: Allwinner A33 (sun8i, ARMv7)
# Note: Uses stock vendor kernel from EmuELEC
{ config, lib, pkgs, inputs, hostname, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/images/r36s-sd-image.nix
  ];

  # Enable R36S SD image building
  tuinix.r36s.enable = true;

  networking.hostName = hostname;
  networking.hostId = "a3300001";  # 8 hex chars: a33 (Allwinner A33) + 00001

  # Minimal system for R36S
  # No ZFS (armv7l), no NetworkManager GUI needed
  tuinix.networking.networkmanager.enable = false;
  tuinix.networking.iphone-tethering.enable = false;

  # Basic networking via dhcpcd
  networking.useDHCP = true;

  # Root user with password for initial testing
  users.users.root = {
    initialPassword = "nixos";
  };

  # Create a regular user
  users.users.tuinix = {
    isNormalUser = true;
    initialPassword = "tuinix";
    extraGroups = [ "wheel" "video" "audio" "input" ];
  };

  # Essential packages for a minimal system
  environment.systemPackages = with pkgs; [
    vim
    htop
    usbutils
    # Note: pciutils not useful on this device (no PCI bus)
  ];

  # Enable serial console for debugging
  # R36S uses ttyS2 at 115200 baud
  systemd.services."serial-getty@ttyS2" = {
    enable = true;
    wantedBy = [ "getty.target" ];
  };

  # Also try ttyS0 in case serial is there
  systemd.services."serial-getty@ttyS0" = {
    enable = true;
    wantedBy = [ "getty.target" ];
  };

  # Enable all TTYs for maximum compatibility
  services.getty.autologinUser = lib.mkDefault "root";

  # Disable services that won't work without proper kernel support
  services.udisks2.enable = false;
  security.polkit.enable = false;

  # Minimal documentation to reduce size
  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

  # No fonts needed for serial console
  fonts.fontconfig.enable = false;

  # No X11/Wayland (framebuffer only via vendor drivers)
  services.xserver.enable = false;

  system.stateVersion = "25.11";
}
