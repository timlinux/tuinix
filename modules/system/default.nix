# System-level configuration modules
{ lib, ... }:

{
  imports = [ ./boot.nix ./display.nix ./nix-settings.nix ./zfs.nix ];
}
