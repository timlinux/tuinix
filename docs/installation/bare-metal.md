# Installing on Bare Metal

This guide covers installing tuinix on a real physical machine.

## Hardware Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | x86_64 | Modern x86_64 (AMD Ryzen / Intel Core) |
| RAM | 4 GB | 8 GB+ |
| Storage | 20 GB | 50 GB+ (SSD strongly recommended) |
| Boot mode | UEFI | UEFI |

!!! warning "UEFI and Secure Boot"
    tuinix requires UEFI boot. Legacy BIOS is not supported.
    Secure Boot must be disabled because ZFS kernel modules
    are unsigned.

## Step 1: Get the ISO

Download the latest ISO from the
[releases page]({{ iso.releases_url }}) ({{ iso.version }}),
or build it yourself:

```bash
git clone https://github.com/timlinux/tuinix.git
cd tuinix
./scripts/build-iso.sh
```

The ISO includes the installer and system configuration. An internet
connection is required during installation to fetch packages.

## Step 2: Flash the ISO to a USB drive

You need a USB drive of at least 4 GB. **All data on the drive will be destroyed.**

=== "Linux"

    ```bash
    # Identify your USB device (check with lsblk first!)
    sudo dd if={{ iso.filename }} of=/dev/sdX bs=4M status=progress oflag=sync
    ```

    Replace `/dev/sdX` with your actual USB device (e.g. `/dev/sdb`). **Triple-check** you have the right device -- `dd` will happily overwrite your main disk.

=== "macOS"

    ```bash
    # Find the disk number with diskutil list
    diskutil unmountDisk /dev/diskX
    sudo dd if={{ iso.filename }} of=/dev/rdiskX bs=4m
    diskutil eject /dev/diskX
    ```

=== "Windows"

    Use one of these tools:

    - [Rufus](https://rufus.ie/) -- select "DD Image" mode
    - [balenaEtcher](https://www.balena.io/etcher/) -- works out of the box

## Step 3: Configure BIOS/UEFI

Before booting from USB, enter your BIOS/UEFI settings (typically by pressing F2, F12, DEL, or ESC during POST):

1. **Boot mode**: Set to UEFI (disable CSM/Legacy if present)
2. **Secure Boot**: Disable it
3. **Boot order**: Set USB as first boot device, or use the one-time boot menu

!!! tip
    Many machines have a one-time boot menu (often F12) that lets you select the USB without changing permanent settings.

## Step 4: Run the installer

Once the USB boots, you'll land in `/home/tuinix` with a welcome message showing the mascot and install instructions. Run:

```bash
sudo installer
```

The interactive TUI installer will guide you through:

1. **Username** -- enter your login username
2. **Full name** -- your display name (used in git config)
3. **Email** -- your email address (used in git config)
4. **Password** -- set your login password (entered twice to confirm)
5. **Hostname** -- name your machine
6. **Disk selection** -- choose the target disk (the installer shows all available disks)
7. **ZFS encryption passphrase** -- set a passphrase for full-disk encryption (entered twice to confirm)
8. **Locale and keyboard** -- select your region and layout
9. **Confirmation** -- review the summary, type `DESTROY` to confirm
10. **Installation** -- partitioning, formatting, and NixOS install run automatically

## Step 5: First boot

1. Remove the USB drive
2. Reboot
3. At the GRUB menu, select tuinix
4. Enter your ZFS encryption passphrase when prompted
5. Log in with the username and password you set during installation

## Disk layout

The installer creates this partition layout:

| Partition | Size | Filesystem | Purpose |
|-----------|------|------------|---------|
| ESP | 512 MB | FAT32 | EFI System Partition (`/boot`) |
| ZFS | Remainder | ZFS (encrypted) | Root pool `NIXROOT` |

ZFS datasets created:

| Dataset | Mountpoint | Notes |
|---------|------------|-------|
| `NIXROOT/root` | `/` | Root filesystem |
| `NIXROOT/nix` | `/nix` | Nix store |
| `NIXROOT/home` | `/home` | User data |

## Post-installation

After installation, the flake is copied to two locations:

- `/etc/tuinix` -- system reference copy
- `/home/<username>/tuinix` -- your working copy (a git repo tracking upstream)

Your user configuration is at `users/<username>.nix` and includes:

- User account settings
- Home-manager git configuration with your name and email
- Default groups (wheel, networkmanager, audio, video, docker)

To make changes to your system configuration:

```bash
cd ~/tuinix
# Edit configuration files
sudo nixos-rebuild switch --flake .#<hostname>
```

To pull upstream changes:

```bash
cd ~/tuinix
git pull
sudo nixos-rebuild switch --flake .#<hostname>
```

See the [Post-Install Guide](../usage/post-install.md) for more about your new environment.

## Recovery

If your system won't boot:

1. Boot from the installation USB again
2. Import and unlock your ZFS pool:
   ```bash
   sudo zpool import -f NIXROOT
   sudo zfs load-key -a
   sudo zfs mount -a
   ```
3. Chroot in:
   ```bash
   sudo nixos-enter --root /mnt
   ```
4. Fix and rebuild:
   ```bash
   nixos-rebuild boot --flake /etc/tuinix#<hostname>
   ```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| USB doesn't boot | BIOS in Legacy mode | Switch to UEFI, disable CSM |
| Black screen after GRUB | Secure Boot enabled | Disable Secure Boot in BIOS |
| "no such pool available" | Disk has no `/dev/disk/by-id/` entry | Rare on real hardware; check disk WWN with `ls -la /dev/disk/by-id/` |
| Installation fails | Not enough disk space | Need at least 20 GB free |
| Can't type passphrase | Wrong keyboard layout in initrd | Reinstall with correct keyboard layout |
