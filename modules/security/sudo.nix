# Sudo configuration
{ config, lib, ... }:

with lib;

{
  options.tuinix.security.sudo = {
    wheelNeedsPassword = mkOption {
      type = types.bool;
      default = true;
      description = "Whether users in wheel group need password for sudo";
    };
  };

  config = {
    # Security settings
    security = {
      sudo = {
        enable = true;
        wheelNeedsPassword = config.tuinix.security.sudo.wheelNeedsPassword;
      };

      # Prevent non-wheel users from running sudo
      doas.enable = false;
    };
  };
}
