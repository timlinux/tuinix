# R36S Handheld Gaming Console - MINIMAL NixOS Configuration
# SoC: Allwinner A33 (sun8i, ARMv7)
# Note: Uses stock vendor kernel from EmuELEC
#
# MINIMAL REQUIREMENTS:
# - Bootloader (stock U-Boot)
# - Kernel (stock vendor kernel)
# - systemd init
# - bash shell
# - nix package manager with flakes
# - busybox
# - NetworkManager + nmtui
# - iPhone tethering support
# - Framebuffer terminal output
#
{ config, lib, pkgs, inputs, hostname, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/images/r36s-sd-image.nix
  ];

  # Enable R36S SD image building
  tuinix.r36s.enable = true;

  networking.hostName = hostname;
  networking.hostId = "a3300001";

  # ============================================================
  # NETWORKING - Minimal networking with iPhone tethering
  # ============================================================
  # Use NetworkManager but disable heavy optional features
  networking.networkmanager = {
    enable = true;
    # Disable plugins that pull in heavy dependencies
    plugins = lib.mkForce [];
  };

  # iPhone USB tethering (minimal)
  services.usbmuxd.enable = true;

  # Minimal packages only - override default system packages
  environment.systemPackages = lib.mkForce (with pkgs; [
    # Required
    busybox
    networkmanager  # nmtui, nmcli
    libimobiledevice
    ifuse

    # Nix package management
    nix

    # Basic utilities
    bash
  ]);

  # Disable default packages we don't need
  environment.defaultPackages = lib.mkForce [];

  # Don't install NixOS tools on target (this is an appliance)
  system.disableInstallerTools = true;

  # ============================================================
  # USERS
  # ============================================================
  users.users.root.initialPassword = "nixos";

  users.users.tuinix = {
    isNormalUser = true;
    initialPassword = "tuinix";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # ============================================================
  # INIT SYSTEM - systemd (minimal)
  # ============================================================
  # Disable unnecessary systemd services
  systemd.services.systemd-journal-flush.enable = false;
  systemd.coredump.enable = false;

  # Auto-login on console
  services.getty.autologinUser = "root";

  # ============================================================
  # DISABLE HEAVY TUINIX MODULES
  # ============================================================
  tuinix.zfs.enable = lib.mkForce false;

  # ============================================================
  # DISABLE EVERYTHING ELSE
  # ============================================================

  # No documentation
  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;
  documentation.doc.enable = false;
  documentation.info.enable = false;

  # No fonts
  fonts.fontconfig.enable = false;

  # No X11/Wayland
  services.xserver.enable = false;

  # No sound (for now)
  services.pipewire.enable = lib.mkDefault false;
  services.pulseaudio.enable = false;

  # No printing
  services.printing.enable = false;

  # No bluetooth
  hardware.bluetooth.enable = false;

  # Disable heavy services
  services.udisks2.enable = false;
  security.polkit.enable = lib.mkForce false;
  programs.command-not-found.enable = false;

  # Disable firewall (not needed for handheld)
  networking.firewall.enable = false;

  # Disable SSH server
  services.openssh.enable = false;

  # Disable sound/audio
  security.rtkit.enable = false;

  # Disable MIME/desktop integration (no GUI)
  xdg.mime.enable = false;
  xdg.icons.enable = false;
  xdg.sounds.enable = false;

  # Disable sudo (use su instead)
  security.sudo.enable = lib.mkForce false;

  # No NixOS channels (we use flakes)
  nix.channel.enable = false;

  # Minimal nix settings for package management
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Reduce memory usage
    max-jobs = 2;
    cores = 2;
  };

  # ============================================================
  # CONSOLE OUTPUT - Framebuffer
  # ============================================================
  # Console on framebuffer for built-in display
  boot.kernelParams = [ "console=tty1" ];

  # Serial console for debugging
  systemd.services."serial-getty@ttyS0".enable = true;
  systemd.services."serial-getty@ttyS2".enable = true;

  system.stateVersion = "25.11";
}
