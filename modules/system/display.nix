# Display configuration module
{ config, lib, pkgs, ... }:

with lib;

{
  options.tuinix.display = {
    resolution = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "2560x1600";
      description = ''
        Set the framebuffer console resolution via the kernel `video=` parameter.
        When null (default), the kernel auto-detects the best resolution for the
        connected display. Set this to a specific resolution string (e.g.
        "1920x1080") to override auto-detection.
      '';
    };
  };

  config = mkIf (config.tuinix.display.resolution != null) {
    boot.kernelParams = [ "video=${config.tuinix.display.resolution}" ];
  };
}
