# Cross-architecture emulation support
# Enables building aarch64 packages/ISOs on x86_64 systems via QEMU
{ config, lib, pkgs, ... }:

let cfg = config.tuinix.emulation;
in {
  options.tuinix.emulation = {
    enable = lib.mkEnableOption "cross-architecture emulation via QEMU binfmt";

    aarch64 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable aarch64-linux emulation (for R36S and ARM builds)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable binfmt emulation for specified architectures
    boot.binfmt.emulatedSystems =
      lib.optionals cfg.aarch64 [ "aarch64-linux" ];

    # Add aarch64-linux to extra platforms so nix can build for it
    nix.settings.extra-platforms =
      lib.optionals cfg.aarch64 [ "aarch64-linux" ];
  };
}
