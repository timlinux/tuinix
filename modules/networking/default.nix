# Networking configuration modules
{ lib, ... }:

{
  imports = [ ./wireless.nix ./ethernet.nix ./iphone-tethering.nix ];
}
