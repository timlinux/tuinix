# Installing in a Virtual Machine

This guide covers installing tuinix inside a virtual machine for testing, development, or daily use.

## VM Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU cores | 2 | 4 |
| RAM | 4 GB | 8 GB |
| Disk | 20 GB | 50 GB |
| Firmware | UEFI (no Secure Boot) | UEFI (no Secure Boot) |

!!! warning "UEFI required"
    Legacy BIOS (SeaBIOS) will **not** work. tuinix uses GPT
    partitioning with an EFI System Partition that requires UEFI
    firmware. ZFS kernel modules are unsigned, so
    **Secure Boot must be disabled**.

## Option A: Using the included run-vm.sh script (QEMU)

The repo ships a helper script that handles UEFI firmware, disk
serial numbers, and resource allocation automatically:

```bash
# 1. Build the ISO (if you haven't already)
./scripts/build-iso.sh

# 2. Boot the ISO in a VM and run the installer
./scripts/run-vm.sh iso

# 3. After installation completes, boot from the installed disk
./scripts/run-vm.sh harddrive

# 4. Clean up VM artifacts when done
./scripts/run-vm.sh clean
```

This is the easiest path and avoids all the manual configuration below.

## Option B: Using virt-manager / libvirt

If you prefer virt-manager, you must configure three things manually.
Getting any of these wrong will result in a non-booting system.

### 1. UEFI firmware without Secure Boot

When creating the VM in virt-manager:

- **Overview > Firmware**: select `UEFI x86_64: /usr/share/edk2/ovmf/OVMF_CODE.fd`
  - Use the **non-secure** variant (not `OVMF_CODE.secboot.fd`)

Or set the XML directly (`virsh edit <vmname>`):

```xml
<os firmware='efi'>
  <firmware>
    <feature enabled='no' name='enrolled-keys'/>
    <feature enabled='no' name='secure-boot'/>
  </firmware>
  <loader readonly='yes' secure='no' type='pflash' format='raw'>/run/libvirt/nix-ovmf/edk2-x86_64-code.fd</loader>
</os>
```

### 2. Disk serial number (critical for ZFS)

ZFS pool import scans `/dev/disk/by-id/`. Virtio disks in QEMU
**do not create `/dev/disk/by-id/` entries** unless a serial
number is configured. Without this, `zpool import` fails with
`no such pool available`.

virt-manager has no GUI for this. Edit the VM XML directly:

```xml
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2'/>
  <source file='/path/to/disk.qcow2'/>
  <target dev='vda' bus='virtio'/>
  <serial>tuinix-root</serial>
</disk>
```

This creates `/dev/disk/by-id/virtio-tuinix-root` inside the VM.

### 3. Virtio kernel modules in initrd

The initrd needs `virtio_blk`, `virtio_pci`, and `virtio_scsi`
to see the disk during early boot. These are already configured
in the tuinix flake. If you create a custom host configuration,
ensure they're in `boot.initrd.availableKernelModules`.

## Option C: Using VirtualBox

1. Create a new VM with type "Linux" / "Other Linux (64-bit)"
2. **System > Motherboard**: check "Enable EFI"
3. Allocate at least 4 GB RAM and 20 GB disk
4. Attach the ISO as a CD/DVD
5. Boot and run the installer

!!! note
    VirtualBox EFI support can be unreliable. QEMU/KVM (option A or B) is strongly recommended.

## How ZFS pool import works at boot

Understanding this helps debug boot failures:

1. GRUB loads from the EFI partition (`/boot`, vfat)
2. GRUB loads the kernel and initrd from `/boot/kernels/`
3. The initrd runs:
   - Sets `/etc/hostid` (baked at build time from `networking.hostId`)
   - Loads the `zfs` kernel module
   - Runs `zpool import -d /dev/disk/by-id -N -f NIXROOT`
   - Runs `zfs load-key -a` (prompts for your encryption passphrase)
   - Mounts `NIXROOT/root` on `/`
4. Stage 2 (systemd) takes over

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "no such pool available" | No `/dev/disk/by-id/` entry | Add a serial number to the disk |
| "last accessed by another system" | hostId mismatch | Reinstall with matching hostId, or use `forceImportRoot = true` |
| ZFS module loads but pool not found | Missing `virtio_blk` in initrd | Add virtio modules to `boot.initrd.availableKernelModules` |
| Black screen after GRUB | Secure Boot enabled | Switch to non-secure OVMF firmware |

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
