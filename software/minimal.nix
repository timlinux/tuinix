# Minimal package set -- base terminal tools
# This is always installed regardless of package set selection
{ config, lib, pkgs, ... }:

with lib;

{
  options.tuinix.packages = {
    tui = mkEnableOption
      "TUI productivity suite (terminal apps for messaging, browsing, productivity)";
    gui = mkEnableOption "Minimal GUI (Sway, Brave browser, PipeWire audio)";
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
    ];
  };
}
