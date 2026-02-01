# SSH configuration
{ config, lib, ... }:

with lib;

{
  options.tuinix.security.ssh = {
    enable = mkEnableOption "Enable SSH server";

    port = mkOption {
      type = types.int;
      default = 22;
      description = "SSH port";
    };

    permitRootLogin = mkOption {
      type = types.enum [ "yes" "no" "prohibit-password" ];
      default = "prohibit-password";
      description = "Permit root login";
    };

    passwordAuthentication = mkOption {
      type = types.bool;
      default = false;
      description = "Allow password authentication";
    };
  };

  config = mkIf config.tuinix.security.ssh.enable {
    services.openssh = {
      enable = true;
      ports = [ config.tuinix.security.ssh.port ];

      settings = {
        PermitRootLogin = config.tuinix.security.ssh.permitRootLogin;
        PasswordAuthentication =
          config.tuinix.security.ssh.passwordAuthentication;

        # Security hardening
        Protocol = 2;
        X11Forwarding = false;
        AllowAgentForwarding = false;
        AllowTcpForwarding = false;
        GatewayPorts = "no";
      };
    };

    # Add SSH port to firewall if enabled
    tuinix.security.firewall.allowedTCPPorts =
      mkIf config.tuinix.security.firewall.enable
      [ config.tuinix.security.ssh.port ];
  };
}
