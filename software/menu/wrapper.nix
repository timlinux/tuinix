# Shared tuinix-menu wrapper
# Used by both the minimal.nix NixOS module and the flake app
# (nix run .#menu). extraTools are prepended to PATH so the flake app
# can offer launchers (e.g. the emergency GUI) that are not installed
# system-wide on the host.
{ pkgs, extraTools ? [ ] }:
pkgs.writeShellScriptBin "tuinix-menu" ''
  export PATH="${pkgs.lib.makeBinPath ([ pkgs.gum ] ++ extraTools)}:$PATH"
  exec ${pkgs.bash}/bin/bash ${./tuinix-menu.sh} "$@"
''
