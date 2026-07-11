# Emergency GUI package set -- Wayland kiosk running only Brave
# For emergencies when you absolutely must have a GUI. Run
# `tuinix-emergency-gui` from any TTY; the cage compositor starts a
# single-app kiosk session with the Brave browser and nothing else.
# Brave runs in incognito inside a bubblewrap sandbox with its profile
# on tmpfs: no browsing data reaches the (snapshotted) ZFS datasets and
# the user's home folders are never exposed to the browser.
{ config, lib, pkgs, ... }:

with lib;

let
  # Kiosk launcher (shared with the flake's nix run .#emergency-gui app)
  emergencyGui = import ./emergency/wrapper.nix pkgs;
in {
  config = mkIf config.tuinix.packages.emergency {
    environment.systemPackages = [ emergencyGui ];

    # GPU acceleration for the compositor and browser
    hardware.graphics.enable = true;

    # Minimal font set so web pages render
    fonts.packages = with pkgs; [
      dejavu_fonts
      noto-fonts
      noto-fonts-color-emoji
    ];
  };
}
