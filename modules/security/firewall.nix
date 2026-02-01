# Firewall configuration
{ config, lib, ... }:

with lib;

{
  options.tuinix.security.firewall = {
    enable = mkEnableOption "Enable firewall";

    allowedTCPPorts = mkOption {
      type = types.listOf types.int;
      default = [ ];
      description = "List of allowed TCP ports";
    };

    allowedUDPPorts = mkOption {
      type = types.listOf types.int;
      default = [ ];
      description = "List of allowed UDP ports";
    };
  };

  config = mkIf config.tuinix.security.firewall.enable {
    networking.firewall = {
      enable = true;
      allowedTCPPorts = config.tuinix.security.firewall.allowedTCPPorts;
      allowedUDPPorts = config.tuinix.security.firewall.allowedUDPPorts;

      # Default deny policy
      rejectPackets = true;

      # Disable ping
      allowPing = false;
    };
  };
}
