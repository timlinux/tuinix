# Security configuration modules
{ lib, ... }:

{
  imports = [ ./firewall.nix ./ssh.nix ./sudo.nix ];
}
