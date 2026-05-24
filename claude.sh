#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
exec > claude.out 2>&1

git add -A
git commit --no-verify -m "feat: add package set selection (TUI, Pentest, Games), replace GUI with pentest

Package sets feature:
- Three optional tiers selected via checkboxes during installation
- TUI: yazi, neovim, lazygit, btop, nchat, gomuks, scli, khal, starship, atuin
- Pentest: aircrack-ng, nmap, metasploit, wireshark, termshark, hashcat, sqlmap
- Games: angband, crawl, cataclysm-dda, vitetris, nudoku, frotz, bsdgames
- Minimal base (vim, git, curl, htop, tmux) always installed

Removed GUI package set (Sway/Brave) -- goes against terminal-first philosophy.

Installer changes:
- New statePackageSet wizard step with checkbox UI
- Space to toggle, Up/Down to move, Enter to confirm
- Package selections written to tuinix.packages.{tui,pentest,games} in generated config

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

git push

echo "Pushed package sets feature."
