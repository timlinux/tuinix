# R36S Build - Bill of Materials Analysis

This document analyzes the derivations required to build the R36S SD image, categorized by purpose.

## Summary

| Metric | Value |
|--------|-------|
| Total derivations (dry-run) | ~700 |
| Target runtime packages | <100 |
| Build-time vs Runtime | Most are build-time dependencies |
| LLVM/Clang | Removed (via `withLibBPF = false`) |

**Key Insight**: The 700 derivations include build-time dependencies (compilers, test frameworks, build systems). The actual runtime image contains far fewer packages. Getting to <100 *runtime* packages is achievable; getting to <100 *build derivations* requires fundamental architecture changes.

## Root Causes of Large Build

### 1. NetworkManager → GLib → Python/GObject-Introspection

NetworkManager is the primary dependency bloat driver:

```
NetworkManager
├── glib-2.86.1 (required)
│   ├── gobject-introspection (pulls in Python)
│   ├── meson (build system, needs Python)
│   └── gtk-doc (documentation)
├── dbus (required)
├── polkit (we disabled this)
└── wpa_supplicant
```

**Impact**: ~200+ derivations

### 2. Nix Package Manager → AWS SDK → Rust

The Nix package manager pulls in:

```
nix-2.31.2
├── aws-sdk-cpp (for S3 substituters)
│   ├── aws-c-* (many AWS libs)
│   └── curl, openssl, etc.
├── nix-util, nix-store, etc.
├── libblake3 (cryptography)
└── boost, nlohmann_json, etc.
```

**Impact**: ~100+ derivations

### 3. systemd → BPF Tools → LLVM/Clang

Full systemd build includes:

```
systemd-258.2
├── bpftools-6.16.7 (BPF support)
│   ├── llvm-21.1.2 (huge)
│   ├── clang-21.1.2
│   └── compiler-rt
├── cryptsetup (pulls in Rust via bcrypt)
├── tpm2-tss, swtpm (TPM support)
└── linux-pam, gnupg, etc.
```

**Impact**: ~150+ derivations

### 4. Linux Kernel (Still Being Built)

Despite using stock vendor kernel, NixOS still builds:

```
linux-6.12.60
├── linux-modules
├── linux-modules-shrunk
├── firmware
├── wireless-regdb
├── pahole (BTF tools)
└── dtc (device tree compiler)
```

**Impact**: ~50+ derivations

**Why?**: `boot.kernelPackages = pkgs.linuxPackages` still triggers kernel build. Need to investigate how to truly skip kernel.

### 5. Rust Toolchain

Required by nix (cargo-auditable), cryptsetup (bcrypt), and others:

```
rustc-1.91.1
├── cargo-1.91.1
├── cargo-auditable
├── maturin (Python-Rust bridge)
└── Many Rust crates
```

**Impact**: ~80+ derivations

### 6. Python Ecosystem (Build-Time)

Used by meson, sphinx, gobject-introspection:

```
python3-3.13.9
├── pytest, sphinx (testing/docs)
├── meson (build system)
├── cython, lxml, etc.
└── Dozens of python packages
```

**Impact**: ~100+ derivations

**Note**: This is mostly build-time; Python may not be needed at runtime.

## Current Optimizations Applied

| Optimization | Status | Impact |
|--------------|--------|--------|
| `documentation.enable = false` | ✅ Applied | Reduced docs |
| `fonts.fontconfig.enable = false` | ✅ Applied | No font stack |
| `security.polkit.enable = false` | ✅ Applied | No polkit |
| `services.udisks2.enable = false` | ✅ Applied | Removed |
| `security.sudo.enable = false` | ✅ Applied | Use su |
| `xdg.*.enable = false` | ✅ Applied | No XDG |
| `environment.defaultPackages = []` | ✅ Applied | No defaults |
| `system.disableInstallerTools = true` | ✅ Applied | No nixos-install |
| `hardware.enableRedistributableFirmware = false` | ✅ Applied | No firmware |
| `systemd.override { withLibBPF = false; ... }` | ✅ Applied | Removes LLVM/Clang |

### Systemd Optimization (via overlay)

Applied in `flake.nix` R36S overlay:

```nix
systemd = prev.systemd.override {
  withLibBPF = false;      # Removes LLVM/Clang dependency
  withCoredump = false;    # No coredump support
  withCryptsetup = false;  # No cryptsetup support
  withDocumentation = false;  # No docs
  withTpm2Tss = false;     # No TPM support
  withHomed = false;       # No homed
  withPortabled = false;   # No portabled
  withMachined = false;    # No machined
  withNspawn = false;      # No nspawn
  withImportd = false;     # No importd
  withRemote = false;      # No journal-remote
  withRepart = false;      # No repart
  withSysupdate = false;   # No sysupdate
  withVmspawn = false;     # No vmspawn
  withUkify = false;       # No ukify
  withFirstboot = false;   # No firstboot
  withBootloader = false;  # No systemd-boot
};
```

**Impact**: Removed ~18 derivations (including LLVM/Clang).

## Possible Further Reductions

### High Impact (Difficult)

1. **Replace NetworkManager with connman or dhcpcd**
   - connman: Lighter but less user-friendly
   - dhcpcd alone: Even lighter, no nmtui TUI
   - Impact: Could remove ~200 derivations

2. **Use nix-static or minimal nix**
   - Remove AWS SDK support
   - Disable S3 substituter
   - Impact: Could remove ~100 derivations

3. **Skip kernel build entirely**
   - Need `boot.kernelPackages = null` equivalent
   - Currently not supported by NixOS modules
   - Impact: Could remove ~50 derivations

### Medium Impact

4. **Disable BPF in systemd** ✅ DONE
   - Applied via overlay in `flake.nix`
   - Impact: Removed LLVM/Clang (~18 derivations)

5. **Use pkgsMusl for smaller binaries**
   - Static musl libc builds
   - May have compatibility issues

### Low Impact (Already Done)

6. All documentation disabled
7. All GUI/font features disabled
8. Minimal system packages list

## Realistic Expectations

**Getting <100 build derivations is NOT feasible with:**
- NixOS + NetworkManager + Nix + systemd

**Getting <100 runtime packages IS feasible:**
- The actual squashfs image will contain fewer packages
- Build derivations ≠ runtime packages

**Alternative architectures for <100 build derivations:**
- Use Alpine Linux with apk
- Use buildroot
- Use Yocto/OE
- Custom minimal init with busybox

## Conclusion

The R36S build has been stripped to essential features. The remaining 700 derivations are largely:
- Cross-compilation toolchain (unavoidable)
- Build-time dependencies (Python, meson, sphinx)
- NetworkManager dependency tree (GLib, dbus)
- Nix package manager (AWS SDK, Rust)
- Linux kernel (still built despite using stock vendor kernel)

**Optimizations Applied:**
- Disabled LLVM/Clang by removing BPF support from systemd
- Disabled TPM, cryptsetup, homed, portabled, machined, nspawn, etc.
- Stripped all documentation, fonts, GUI, and audio features

To get significantly below 700 derivations would require replacing core components (NetworkManager, Nix, or systemd) with lighter alternatives, which would impact functionality.
