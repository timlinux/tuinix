# iPhone USB tethering support
{ config, lib, pkgs, ... }:

with lib;

{
  options.tuinix.networking.iphone-tethering = {
    enable = mkEnableOption "Enable iPhone USB tethering support";
  };

  config = mkIf config.tuinix.networking.iphone-tethering.enable {
    # Enable usbmuxd service for iPhone USB communication
    services.usbmuxd.enable = true;

    # Install iPhone tethering packages
    environment.systemPackages = with pkgs; [ libimobiledevice ifuse usbmuxd ];
  };
}
