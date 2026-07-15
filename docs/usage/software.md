# Software Collections

tuinix ships a lean base system and lets you opt into curated
collections during installation. Every collection is a NixOS module, so
you can also enable or disable them later by editing
`/etc/tuinix/hosts/<hostname>/default.nix` and running
`sudo nixos-rebuild switch --flake /etc/tuinix#<hostname>`.

## Finding your apps: the tuinix menu

Terminal apps can be hard to discover, so every tuinix system includes
`tuinix-menu` — a gum-powered launcher with drill-down categories
(files, monitoring, editors, network, communication, games, sound and
music, utilities, and more). Only apps that are actually installed are
shown, so the menu adapts to the collections you selected.

```bash
tuinix-menu
```

The Utilities category includes a screen-brightness picker
(`brightnessctl` under the hood) — handy on laptops.

## Base system (always installed)

| Tool | Purpose |
|------|---------|
| vim, git, curl, wget, htop, tree, tmux | Core terminal tools |
| `yazi` | Default file manager — just type `f` |
| `wiremix` | PipeWire mixer TUI — the default sound application |
| `bluetui` | Bluetooth management TUI |
| `brightnessctl` | Screen backlight control |
| `tuinix-menu` | The drill-down app launcher |

The base system also enables PipeWire (with ALSA and PulseAudio shims)
and Bluetooth.

## Optional collections

### TUI productivity suite

Terminal apps for daily work: neovim, helix, lazygit, btop, w3m,
starship, atuin, zellij, yazi extras, plus messaging clients — nchat
(Telegram/WhatsApp), iamb (Matrix), scli (Signal) and aerc (email).

### Pentest tools

Security auditing: aircrack-ng, nmap, metasploit, termshark, hashcat,
sqlmap.

### Terminal games

Roguelikes, puzzles, arcade classics and text adventures: angband,
crawl, cataclysm-dda, vitetris, nudoku, frotz, bsdgames and more.

### Sound and Music

A console-only music creation studio:

- `tuinix-music-menu` — gum menu for the whole studio
- Elevator music generators (simple and enhanced polyphonic)
- MIDI composition (`generate_midi.py` via the menu) with a
  compose → render (FluidSynth) → master (sox) workflow
- Terminal live-coding tools: csound, chuck, orca
- abcmidi, timidity, ffmpeg, sox, lame

Generated audio is written to `~/Music`. GUI music tools are
deliberately excluded to keep with the TUI theme.

### Emergency GUI

For those emergencies when you absolutely must have a GUI:

```bash
tuinix-emergency-gui [optional-url]
```

This starts the [cage](https://github.com/cage-kiosk/cage) Wayland
compositor in kiosk mode running only the Brave browser. Privacy is
part of the design:

- Brave runs in **incognito** with its profile on a **tmpfs** — nothing
  is written to your ZFS datasets, so snapshots keep no browsing audit
  trail.
- Brave runs inside a **bubblewrap sandbox**: your home folders are
  replaced with an empty tmpfs and are never visible to the browser.
  Only the Nix store, DNS/TLS configuration, fonts and the GPU are
  exposed.

Close the browser to return to the console; everything the session
wrote evaporates.

## WiFi on the live installer ISO

The live installer environment uses
[impala](https://github.com/pythops/impala), a WiFi TUI backed by
`iwd`. Run `impala`, pick your network, and DHCP is handled
automatically. (`iwctl` is available too.) Installed systems use
NetworkManager with `nmtui` as before.

---

Made with 💗 by [Kartoza](https://kartoza.com) |
[Donate!](https://github.com/sponsors/timlinux) |
[GitHub](https://github.com/timlinux/tuinix)
