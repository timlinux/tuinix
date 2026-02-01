# Nix configuration and settings
{ config, lib, pkgs, ... }:

{
  # Nix configuration
  nix = {
    settings = {
      # Enable flakes and new command
      experimental-features = [ "nix-command" "flakes" ];

      # Binary cache configuration
      substituters =
        [ "https://cache.nixos.org/" "https://nix-community.cachix.org" ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      # Auto-optimise store
      auto-optimise-store = true;
    };

    # Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # Package management
    package = pkgs.nix;
  };

  # Allow unfree packages and broken packages if needed
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
  };
}
