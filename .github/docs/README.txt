tuinix Installation ISO

This ISO contains the tuinix NixOS configuration for laptop installations.

QUICK INSTALLATION (Recommended):
  sudo /tuinix/scripts/install.sh

This automated script will guide you through:
- Disk selection and formatting with ZFS
- System installation
- Root password setup
- Automatic reboot

MANUAL INSTALLATION:
1. Boot from this ISO
2. Connect to the internet (wifi-connect or ethernet)  
3. Run: sudo disko --mode disko /iso/tuinix/hosts/laptop/disks.nix --arg device '"/dev/sdX"'
4. Run: sudo nixos-install --flake /iso/tuinix#laptop
5. Set root password when prompted
6. Reboot

Default root password for ISO: nixos
SSH is enabled for remote installation

INSTALLATION WORKFLOW:

                   tuinix Installation Workflow
                   ===================================

    ┌─────────────────┐
    │     START       │ Check dependencies (gum, disko, nixos-*)
    └─────┬───────────┘ Check root privileges
          │
          ▼
    ┌─────────────────┐
    │   WELCOME       │ Show build info
    │   SCREEN        │ Display warning about data destruction
    └─────┬───────────┘ Get user confirmation to continue
          │
          ▼
    ┌─────────────────┐
    │  COLLECT USER   │ • Enter hostname
    │     INPUT       │ • Select disk from available disks
    │                 │ • Generate ZFS host ID
    └─────┬───────────┘ • Calculate space allocation
          │             • Select locale and keyboard layout
          ▼
    ┌─────────────────┐
    │ SHOW SUMMARY &  │ • Display all configuration details
    │ FINAL CONFIRM   │ • Get confirmation to proceed
    └─────┬───────────┘ • Require typing "DESTROY" for safety
          │
          ▼
    ┌─────────────────┐
    │ GENERATE HOST   │ • Copy flake to /tmp/tuinix-install
    │ CONFIGURATION   │ • Create hosts/$HOSTNAME/default.nix
    └─────┬───────────┘ • Generate disks.nix from template
          │             • Create initial hardware.nix
          ▼
    ┌─────────────────┐
    │  FORMAT DISK    │ • Unmount existing partitions
    │   (DISKO)       │ • Export existing ZFS pools
    └─────┬───────────┘ • Run disko with ZFS encryption
          │             • Create encrypted ZFS datasets
          ▼
    ┌─────────────────┐
    │ GENERATE HW     │ • Run nixos-generate-config
    │ CONFIGURATION   │ • Merge with ZFS-specific settings
    └─────┬───────────┘ • Set hostId and ZFS boot config
          │
          ▼
    ┌─────────────────┐
    │ INSTALL NIXOS   │ • Set Nix config for performance
    └─────┬───────────┘ • Run nixos-install --flake
          │
          ▼
    ┌─────────────────┐
    │ CONFIGURE ZFS   │ • Set bootfs property on ZFS pool
    │     BOOT        │ • Install GRUB with ZFS support
    └─────┬───────────┘ • Generate GRUB configuration
          │
          ▼
    ┌─────────────────┐
    │   COPY FLAKE    │ • Copy flake to /mnt/etc/tuinix
    │   TO SYSTEM     │ • Copy flake to /mnt/home/user/tuinix
    └─────┬───────────┘ • Set proper ownership and permissions
          │
          ▼
    ┌─────────────────┐
    │ SETUP ROOT      │ • Run passwd root in chroot
    │   PASSWORD      │
    └─────┬───────────┘
          │
          ▼
    ┌─────────────────┐
    │   COMPLETION    │ • Display success message
    │ & REBOOT PROMPT │ • Offer to reboot system
    └─────┬───────────┘
          │
          ▼
    ┌─────────────────┐
    │      END        │
    └─────────────────┘

Key Components:
• Uses gum for rich interactive CLI experience
• ZFS encryption with automatic space allocation
• Disko for declarative disk partitioning
• Flake-based NixOS installation
• Comprehensive hardware detection and configuration

For more information, see the flake configuration in /tuinix/
