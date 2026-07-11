# TUI package set -- terminal applications for daily productivity
# Messaging, browsing, file management, system monitoring, and more
{ config, lib, pkgs, inputs, ... }:

with lib;

let system = pkgs.stdenv.hostPlatform.system;
in {
  config = mkIf config.tuinix.packages.tui {
    environment.systemPackages = with pkgs;
      [
        # File management
        yazi
        lf
        fzf
        ripgrep
        fd
        bat
        eza
        zoxide
        duf

        # Text editing
        neovim
        helix

        # System monitoring
        btop
        bottom
        ncdu
        bandwhich

        # Networking
        nmap
        dig
        whois
        mtr

        # Terminal multiplexer
        zellij

        # Shell enhancements
        starship
        direnv
        atuin

        # Development tools
        lazygit
        delta
        jq
        yq

        # Communication -- multi-protocol terminal clients
        nchat # Telegram and WhatsApp
        iamb # Matrix (vodozemac crypto; gomuks was dropped: insecure libolm)
        scli # Signal (via signal-cli)
        signal-cli
        aerc # Email

        # Web browsing
        w3m
        lynx

        # Documents and markdown
        glow
        mdcat

        # Calendar, contacts, and tasks (CardDAV/CalDAV)
        khal # Calendar
        khard # Contacts
        todoman # Todo lists
        vdirsyncer # Sync with CalDAV/CardDAV servers
        taskwarrior3

        # File transfer
        rsync
        rclone
      ]
      # Kartoza / timlinux tools (from flake inputs)
      ++ lib.optionals (inputs ? baboon)
      [ inputs.baboon.packages.${system}.default ]
      ++ lib.optionals (inputs ? cheetah)
      [ inputs.cheetah.packages.${system}.default ]
      ++ lib.optionals (inputs ? geotui)
      [ inputs.geotui.packages.${system}.default ]
      ++ lib.optionals (inputs ? timvim)
      [ inputs.timvim.packages.${system}.default ]
      ++ lib.optionals (inputs ? zfs-backup)
      [ inputs.zfs-backup.packages.${system}.default ];

    # Shell integrations
    programs.bash.interactiveShellInit = ''
      if command -v atuin &>/dev/null; then
        eval "$(atuin init bash)"
      fi
      if command -v starship &>/dev/null; then
        eval "$(starship init bash)"
      fi
      if command -v zoxide &>/dev/null; then
        eval "$(zoxide init bash)"
      fi
    '';
  };
}
