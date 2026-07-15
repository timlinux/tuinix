# Shared tuinix-emergency-gui wrapper
# Used by both the emergency.nix NixOS module and the flake app
# (nix run .#emergency-gui), so the launcher is defined once.
pkgs:
pkgs.writeShellScriptBin "tuinix-emergency-gui" ''
  export CAGE_BIN="${pkgs.cage}/bin/cage"
  export BRAVE_BIN="${pkgs.brave}/bin/brave"
  export BWRAP_BIN="${pkgs.bubblewrap}/bin/bwrap"
  exec ${pkgs.bash}/bin/bash ${./emergency-gui.sh} "$@"
''
