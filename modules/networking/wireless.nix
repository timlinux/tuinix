# Wireless networking configuration
{ config, lib, pkgs, ... }:

with lib;

{
  options.tuinix.networking.wireless = {
    enable = mkEnableOption "Enable wireless networking";
  };

  config = mkIf config.tuinix.networking.wireless.enable {
    # Wireless networking
    networking.wireless = {
      enable = true;
      userControlled.enable = true;
    };

    # Alternative: NetworkManager (comment out wireless above if using this)
    # networking.networkmanager.enable = true;

    # Wireless tools
    environment.systemPackages = with pkgs; [ wpa_supplicant wirelesstools iw ];
  };
}
