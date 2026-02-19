# R36S NixOS Squashfs Builder
# Creates a squashfs image compatible with the stock EmuELEC boot process
#
# The stock initramfs expects:
#   - Root filesystem as squashfs at /flash/SYSTEM
#   - Init at /usr/lib/systemd/systemd
#   - Standard Linux filesystem layout
#
{ config, lib, pkgs, ... }:

let
  # The NixOS system closure
  systemClosure = config.system.build.toplevel;

  # Vendor kernel modules (from stock EmuELEC)
  vendorModules = ../../firmware/r36s/modules;

in pkgs.runCommand "r36s-nixos-system.squashfs" {
  nativeBuildInputs = [ pkgs.squashfsTools ];
  closureInfo = pkgs.closureInfo { rootPaths = [ systemClosure ]; };
} ''
  # Create the squashfs root structure
  mkdir -p root/{bin,sbin,lib,usr/{bin,sbin,lib},etc,var,tmp,proc,sys,dev,run}
  mkdir -p root/{flash,storage,nix}

  # Create standard Linux symlinks
  ln -sf /usr/bin root/bin
  ln -sf /usr/sbin root/sbin
  ln -sf /usr/lib root/lib

  # Copy the entire Nix store
  mkdir -p root/nix/store
  while read path; do
    cp -a "$path" root/nix/store/
  done < $closureInfo/store-paths

  # Create the init symlink that stock initramfs expects
  # Stock calls: exec busybox switch_root /sysroot /usr/lib/systemd/systemd
  mkdir -p root/usr/lib/systemd
  ln -sf ${systemClosure}/sw/bin/init root/usr/lib/systemd/systemd

  # Also create standard init paths
  ln -sf ${systemClosure}/sw/bin/init root/init
  ln -sf ${systemClosure}/sw/bin/init root/sbin/init

  # Create NixOS activation script runner
  mkdir -p root/etc
  cat > root/etc/nixos-enter <<NIXOS_ENTER
#!/bin/sh
# Initialize NixOS on first boot
exec ${systemClosure}/activate
NIXOS_ENTER
  chmod +x root/etc/nixos-enter

  # Copy vendor kernel modules
  mkdir -p root/lib/modules/vendor
  cp -a ${vendorModules}/*.ko root/lib/modules/vendor/ 2>/dev/null || true

  # Create /etc/os-release for compatibility
  cat > root/etc/os-release <<EOF
  NAME="NixOS"
  ID=nixos
  VERSION="${config.system.nixos.version}"
  VERSION_ID="${config.system.nixos.version}"
  PRETTY_NAME="NixOS ${config.system.nixos.version} (tuinix R36S)"
  HOME_URL="https://nixos.org"
  EOF

  # Create the squashfs image with LZO compression (like stock)
  mksquashfs root $out \
    -comp lzo \
    -b 524288 \
    -no-xattrs \
    -all-root
''
