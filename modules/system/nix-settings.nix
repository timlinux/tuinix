# Nix configuration and settings
{ config, lib, pkgs, ... }:

let
  # Only enable binfmt emulation on x86_64 host systems
  # This prevents circular configuration when building for ARM targets
  isX86Host = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
in {
  # Enable QEMU binfmt emulation for cross-architecture builds
  # This allows building aarch64 packages on x86_64
  # Only applies when the host is x86_64-linux
  boot.binfmt.emulatedSystems = lib.mkIf isX86Host [ "aarch64-linux" ];

  # Nix configuration
  nix = {
    settings = {
      # Enable flakes and new command
      experimental-features = [ "nix-command" "flakes" ];

      # Allow building for emulated architectures (via binfmt)
      # Only applies when the host is x86_64-linux
      extra-platforms = lib.mkIf isX86Host [ "aarch64-linux" ];

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
