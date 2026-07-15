# Minimal package set -- base terminal tools
# This is always installed regardless of package set selection
{ config, lib, pkgs, ... }:

with lib;

let
  # System menu launcher (shared with the flake's nix run .#menu app)
  tuinixMenu = import ./menu/wrapper.nix { inherit pkgs; };
in {
  options.tuinix.packages = {
    tui = mkEnableOption
      "TUI productivity suite (terminal apps for messaging, browsing, productivity)";
    pentest = mkEnableOption
      "Pentest tools (aircrack-ng, nmap, metasploit, wireshark, hashcat)";
    games = mkEnableOption
      "Terminal games (roguelikes, puzzles, classics, text adventures)";
    music = mkEnableOption
      "Sound and Music (wiremix, generators, MIDI, FluidSynth, live coding)";
    emergency =
      mkEnableOption "Emergency GUI (Brave browser in a minimal Wayland kiosk)";
  };

  config = {
    environment.systemPackages = with pkgs; [
      vim
      git
      curl
      wget
      htop
      tree
      tmux
      unzip
      file
      man-pages

      # Discoverability and hardware TUIs (always available)
      tuinixMenu # drill-down launcher for all installed TUI apps
      gum # TUI building blocks (used by tuinix-menu)
      bluetui # Bluetooth management TUI
      wiremix # PipeWire mixer TUI (default sound application)
      yazi # default file manager (alias: f)
      brightnessctl # screen backlight control (via tuinix-menu Utilities)
    ];

    # Default file manager shortcut
    environment.shellAliases.f = "yazi";

    # bluetui needs the bluetooth stack
    hardware.bluetooth.enable = true;

    # wiremix needs PipeWire (headless-friendly sound stack)
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    security.rtkit.enable = true;
  };
}
