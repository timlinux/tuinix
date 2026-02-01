# System-level configuration modules
{ lib, ... }:

{
  imports = [ ./boot.nix ./nix-settings.nix ./zfs.nix ];
}
