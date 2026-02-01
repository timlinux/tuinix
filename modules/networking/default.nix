# Networking configuration modules
{ lib, ... }:

{
  imports = [ ./wireless.nix ./ethernet.nix ];
}
