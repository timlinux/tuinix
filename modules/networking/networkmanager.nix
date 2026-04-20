# NetworkManager configuration with nmtui
{ config, lib, pkgs, ... }:

with lib;

{
  options.tuinix.networking.networkmanager = {
    enable = mkEnableOption "Enable NetworkManager for network management";
  };

  config = mkIf config.tuinix.networking.networkmanager.enable {
    # Enable NetworkManager
    networking.networkmanager = {
      enable = true;
      wifi.powersave = true;
    };

    # Disable conflicting network services
    networking.useDHCP = lib.mkDefault false;

    # NetworkManager tools (terminal only - no GUI applet)
    environment.systemPackages = with pkgs; [
      networkmanager # includes nmtui, nmcli
    ];

    # Add users to networkmanager group
    users.groups.networkmanager = { };
  };
}
