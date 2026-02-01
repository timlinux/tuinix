# tuinix Installation Guide

This guide will help you install tuinix on your system using the provided ISO image.

## Prerequisites

- A computer with x86_64 architecture
- At least 8GB RAM recommended
- 50GB+ free disk space
- USB drive (8GB+) for creating bootable media

## Step 1: Create Bootable USB

### On Linux:
```bash
sudo dd if=tuinix.v1.iso of=/dev/sdX bs=4M status=progress
```
Replace `/dev/sdX` with your USB device (check with `lsblk`).

### On Windows:
Use [Rufus](https://rufus.ie/) or [Balena Etcher](https://www.balena.io/etcher/) to write the ISO to your USB drive.

### On macOS:
```bash
sudo dd if=tuinix.v1.iso of=/dev/diskX bs=4m
```
Replace `/dev/diskX` with your USB device (check with `diskutil list`).

## Step 2: Boot from USB

1. Insert the USB drive into your target computer
2. Boot from USB (usually F12, F2, or DEL during startup to access boot menu)
3. Select the tuinix installer from the boot menu
4. Wait for the system to boot to the installer environment

## Step 3: Run the Interactive Installer

The ISO includes an interactive installer that handles disk partitioning, ZFS setup, and NixOS installation:

```bash
sudo /install.sh
```

The installer will guide you through:
1. Hostname selection
2. Disk selection and space allocation
3. ZFS encrypted pool creation (you will set a passphrase)
4. Locale and keyboard configuration
5. NixOS installation
6. Root password setup

## Step 4: First Boot

1. Remove the USB drive
2. Reboot your system
3. Boot into your new tuinix installation
4. Log in with the credentials configured in the system

## Configuration Details

Your tuinix system includes:

- **Terminal-focused environment** - Pure terminal-based Linux experience
- **ZFS filesystem** - Advanced filesystem with snapshots and compression
- **Security hardened** - Firewall, SSH hardening, and security modules
- **Development tools** - Pre-configured development environment
- **User accounts** - Configured users with appropriate permissions

## Testing in a VM

### Using run-vm.sh (QEMU direct)

The included `run-vm.sh` script handles UEFI firmware and disk serial
configuration automatically:

```bash
# Build the ISO
./scripts/build-iso.sh

# Boot from ISO to install
./scripts/run-vm.sh iso

# After installation, boot from disk
./scripts/run-vm.sh harddrive

# Clean up VM data
./scripts/run-vm.sh clean
```

### Using virt-manager / libvirt

If you use virt-manager instead of the run-vm.sh script, the VM must be
configured correctly for ZFS boot to work. There are three critical
requirements:

#### 1. UEFI firmware without Secure Boot

The VM must use UEFI (OVMF) firmware, **not** legacy BIOS (SeaBIOS). The
entire disk layout uses GPT with an EFI System Partition — SeaBIOS cannot
read it.

ZFS is an out-of-tree kernel module and is not signed, so **Secure Boot
must be disabled**. In virt-manager:

- Overview > Firmware: select `UEFI x86_64: /usr/share/edk2/ovmf/OVMF_CODE.fd`
  (the non-secure variant, not `OVMF_CODE.secboot.fd`)

Or in the XML:
```xml
<os firmware='efi'>
  <firmware>
    <feature enabled='no' name='enrolled-keys'/>
    <feature enabled='no' name='secure-boot'/>
  </firmware>
  <loader readonly='yes' secure='no' type='pflash' format='raw'>/run/libvirt/nix-ovmf/edk2-x86_64-code.fd</loader>
</os>
```

#### 2. Disk serial number (critical for ZFS)

NixOS ZFS boot imports pools by scanning `/dev/disk/by-id/`. Virtio disks
in QEMU **do not create `/dev/disk/by-id/` entries** unless the disk has a
serial number configured. Without this, `zpool import` sees an empty
directory and fails with `no such pool available` even though the pool
exists on the disk.

In virt-manager, you cannot set this through the GUI. Edit the VM XML
directly (`virsh edit <vmname>`) and add a `<serial>` element to the disk:

```xml
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2'/>
  <source file='/path/to/disk.qcow2'/>
  <target dev='vda' bus='virtio'/>
  <serial>tuinix-root</serial>
</disk>
```

This creates `/dev/disk/by-id/virtio-tuinix-root` inside the VM,
which is what `zpool import -d /dev/disk/by-id` needs to find the pool.

#### 3. Virtio block driver in initrd

The initrd must include `virtio_blk`, `virtio_pci`, and `virtio_scsi`
kernel modules so the disk is visible during early boot. These are already
configured in `boot.nix` and the installer's hardware template. If you
create a custom host configuration, ensure these modules are in
`boot.initrd.availableKernelModules`.

### ZFS pool import at boot — how it works

Understanding the boot sequence helps diagnose issues:

1. GRUB loads from the EFI partition (`/boot`, vfat)
2. GRUB loads the kernel and initrd from `/boot/kernels/`
3. The initrd's stage-1-init.sh runs:
   - Sets `/etc/hostid` (baked into the initrd at build time from
     `networking.hostId` in hardware.nix)
   - Loads `zfs` kernel module
   - Runs `zpool import -d /dev/disk/by-id -N -f NIXROOT`
   - Runs `zfs load-key -a` (prompts for encryption passphrase)
   - Mounts `NIXROOT/root` on `/`
4. Stage 2 (systemd) takes over

Common failure modes:
- **"no such pool available"**: The disk has no `/dev/disk/by-id/` entry.
  Add a serial number to the disk (see above).
- **"last accessed by another system"**: hostId mismatch between the system
  that created the pool and the installed system. The installer sets the
  live ISO's hostId to match the installed system before creating the pool.
  `forceImportRoot = true` is also set as a safety net.
- **ZFS module loads but pool not found after timeout**: The `virtio_blk`
  module is missing from the initrd, so `/dev/vda` doesn't exist.

## Customization

After installation, the flake is copied to `/etc/tuinix` and `/home/user/tuinix`. To make changes:

- Edit the flake in `/home/user/tuinix`
- Rebuild with `sudo nixos-rebuild switch --flake /home/user/tuinix#<hostname>`

## Troubleshooting

### Boot Issues
- Disable Secure Boot in BIOS/UEFI (ZFS modules are unsigned)
- Ensure UEFI boot mode, not legacy BIOS
- In VMs: ensure the disk has a serial number (see VM section above)

### Installation Failures
- Ensure sufficient disk space (50GB minimum)
- Check network connectivity for package downloads
- If `/etc/hostid: Read-only file system` appears, the installer handles
  this by removing the nix-store symlink before writing

### ZFS Boot Failures
- **"no such pool available"**: Check `/dev/disk/by-id/` — if empty, the
  disk needs a serial number (VM) or has no WWN/serial (hardware)
- **"last accessed by another system"**: hostId mismatch. The installer
  sets `forceImportRoot = true` to handle this, but a reinstall with
  matching hostId is the clean fix
- **Pool found but datasets won't mount**: Encryption key not loaded.
  Check that `boot.zfs.requestEncryptionCredentials = true` is set

### Verifying ZFS boot readiness

From the live ISO after installation, before rebooting:
```bash
# Check the pool exists and is healthy
zpool status NIXROOT

# Check bootfs property is set
zpool get bootfs NIXROOT

# Check /dev/disk/by-id has an entry for your disk
ls -la /dev/disk/by-id/

# Check the installed initrd has virtio modules
lsinitrd /mnt/boot/kernels/*-initrd 2>/dev/null | grep virtio
```

## Recovery

If you need to recover your system:
1. Boot from the installation USB
2. Import your ZFS pool: `sudo zpool import -f NIXROOT`
3. Load encryption keys: `sudo zfs load-key -a`
4. Mount: `sudo zfs mount -a`
5. Chroot: `sudo nixos-enter --root /mnt`
6. Rebuild: `nixos-rebuild boot --flake /etc/tuinix#<hostname>`

---

**Note**: This installation will completely replace any existing operating system on the target disk. Make sure to backup important data before proceeding.