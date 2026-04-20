{ config, lib, pkgs, ... }:

{
  # VM-specific overrides for faster builds
  # ZFS is left enabled so the full install flow can be tested
  tuinix.networking.iphone-tethering.enable = lib.mkForce false;

  # Disable Bluetooth in VM
  hardware.bluetooth.enable = lib.mkForce false;
}
