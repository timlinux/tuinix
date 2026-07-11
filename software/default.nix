# Software package sets for tuinix
# Selected during installation via the package set chooser
{ lib, config, ... }:

{
  imports = [
    ./minimal.nix
    ./tui.nix
    ./pentest.nix
    ./games.nix
    ./music.nix
    ./emergency.nix
  ];
}
