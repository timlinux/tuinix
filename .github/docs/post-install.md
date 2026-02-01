<div align="center">
  <img src="../assets/LOGO.png" alt="tuinix logo" width="80" height="80">

  # Post-Installation Guide
</div>

Welcome to your new tuinix system! This guide covers what to expect after your first boot.

## First boot

After installation and reboot:

1. GRUB loads automatically
2. You'll be prompted for your ZFS encryption passphrase
3. The system boots to a terminal login prompt
4. Log in as `root` (with the password you set during installation)

## Your environment

tuinix is a terminal-only system. There is no desktop environment, no window manager, and no graphical login screen. Everything is done from the command line.

Your system includes:

- **Shell**: A modern shell with intelligent completions
- **Multiplexer**: Terminal multiplexer for managing multiple sessions
- **Editor**: Terminal-based text editors
- **File manager**: Terminal file browser
- **System monitoring**: Resource monitoring tools
- **Networking**: WiFi and ethernet management tools
- **Development**: Git and common development utilities

## System configuration

Your tuinix flake is available in two locations:

| Path | Purpose |
|------|---------|
| `/etc/tuinix` | System reference copy (read-only for non-root) |
| `~/tuinix` | Your working copy for making changes |

### Making changes

```bash
cd ~/tuinix
# Edit files as needed
sudo nixos-rebuild switch --flake .#$(hostname)
```

### Rolling back

NixOS keeps previous system generations. To roll back:

```bash
# List available generations
sudo nix-env --list-generations -p /nix/var/nix/profiles/system

# Switch to a previous generation at next boot
sudo nixos-rebuild boot --flake .#$(hostname) --rollback
```

Or select a previous generation from the GRUB boot menu.

## ZFS management

### Snapshots

```bash
# Create a snapshot
sudo zfs snapshot NIXROOT/root@before-change

# List snapshots
zfs list -t snapshot

# Rollback to a snapshot
sudo zfs rollback NIXROOT/root@before-change
```

### Pool status

```bash
zpool status NIXROOT
zfs list
```

## Networking

### Ethernet

Wired connections should work automatically via DHCP.

### WiFi

```bash
# Scan for networks
nmcli device wifi list

# Connect to a network
nmcli device wifi connect "SSID" password "password"
```

## Updating the system

```bash
cd ~/tuinix
nix flake update
sudo nixos-rebuild switch --flake .#$(hostname)
```

## Getting help

- [Project documentation](https://github.com/timlinux/tuinix)
- [Issue tracker](https://github.com/timlinux/tuinix/issues)
