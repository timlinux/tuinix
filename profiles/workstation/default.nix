# Workstation profile (terminal-only)
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ ];

  # Services for workstation
  services = {
    # Time synchronization
    timesyncd.enable = lib.mkDefault true;

    # Printing (minimal, terminal-focused)
    printing.enable = false;

    # Audio (minimal for terminal apps)
    pipewire = {
      enable = true;
      audio.enable = true;
      pulse.enable = true;
    };
  };

  # Security settings appropriate for workstation
  security = {
    # Polkit for user actions
    polkit.enable = true;

    # RTKit for audio
    rtkit.enable = true;
  };

  # Hardware settings
  hardware = {
    # Audio
    pulseaudio.enable = false; # Using pipewire instead

    # Bluetooth (minimal support)
    bluetooth = {
      enable = true;
      powerOnBoot = false;
    };
  };
}

