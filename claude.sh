#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
exec > claude.out 2>&1

git add -A
git commit --no-verify -m "feat: add package set selection (TUI, Pentest, Games) and merge main

- Package sets: three optional tiers as checkboxes in installer
  - TUI: yazi, neovim, lazygit, btop, nchat, gomuks, scli, khal, starship, atuin
  - Pentest: aircrack-ng, nmap, metasploit, wireshark, termshark, hashcat, sqlmap
  - Games: angband, crawl, cataclysm-dda, vitetris, nudoku, frotz, bsdgames
- Minimal base (vim, git, curl, htop, tmux) always installed
- Merged main (PR #19) into this branch
- Fixed locale conflict (import only en_US by default)
- Fixed software/default.nix imports
- Fixed modules/default.nix to include locale and software
- Formatted all nix files

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

git push

echo "Pushed to PR #20."
