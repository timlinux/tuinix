<div align="center">
  <img src=".github/assets/LOGO.png" alt="tuinix logo" width="120" height="120">

# TUINIX

A Pure Terminal Based Linux Experience

<!-- CI/CD Status -->
![CI](https://github.com/timlinux/tuinix/workflows/CI/badge.svg)
![Release](https://github.com/timlinux/tuinix/workflows/Release/badge.svg)

<!-- Quality -->
[![Pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)
[![Nix Format](https://img.shields.io/badge/nix-fmt-blue.svg)](https://nixos.org/)
[![Shell Check](https://img.shields.io/badge/shell-check-green.svg)](https://www.shellcheck.net/)

<!-- Security -->
[![Security: Trivy](https://img.shields.io/badge/security-trivy-blue.svg)](https://github.com/aquasecurity/trivy)
[![Secrets: Detection](https://img.shields.io/badge/secrets-detection-red.svg)](https://github.com/Yelp/detect-secrets)

<!-- Project Info -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Nix](https://img.shields.io/badge/built%20with-nix-blue.svg)](https://nixos.org/)
[![ZFS](https://img.shields.io/badge/filesystem-ZFS-orange.svg)](https://openzfs.org/)

<!-- Documentation -->
[![Docs](https://img.shields.io/badge/docs-timlinux.github.io%2Ftuinix-blue.svg)](https://timlinux.github.io/tuinix/)

<!-- Community -->
[![Contributors](https://img.shields.io/github/contributors/timlinux/tuinix.svg)](https://github.com/timlinux/tuinix/graphs/contributors)
[![Issues](https://img.shields.io/github/issues/timlinux/tuinix.svg)](https://github.com/timlinux/tuinix/issues)
[![Pull Requests](https://img.shields.io/github/issues-pr/tuinix.svg)](https://github.com/timlinux/tuinix/pulls)

</div>

A terminal-centric Linux distribution built on NixOS with ZFS
encryption. No desktop environment, no window manager -- just a
carefully curated set of terminal tools on a reproducible,
declarative foundation.

---

> <img src=".github/assets/LOGO.png" width="24">
> **Ready to install? Jump straight to the
> [Installation Guide](https://timlinux.github.io/tuinix/installation/).**

---

## Three Environments

tuinix has three distinct contexts. Pick the one that matches
where you are right now.

### 1. Development Environment

*You're a contributor working on the tuinix flake, building ISOs,
or hacking on modules.*

This is where the NixOS configuration, installer scripts, and ISO
builder live. You work here on your existing machine (NixOS or any
system with Nix installed) to build, test, and iterate.

**What you can do here:**

- Build the installer ISO
- Test in a VM
- Add or modify NixOS modules
- Run quality checks

```bash
git clone https://github.com/timlinux/tuinix.git
cd tuinix
./scripts/build-iso.sh          # Build the ISO
./scripts/run-vm.sh iso         # Test in a VM
nix flake check                 # Validate the flake
```

> <img src=".github/assets/LOGO.png" width="20">
> Full details:
> [Development Guide](https://timlinux.github.io/tuinix/contributing/development/)

---

### 2. Installation Environment

*You have the ISO and want to install tuinix on a machine.*

The ISO includes the installer and system configuration. An
internet connection is required during installation.

**Choose your target:**

#### Virtual Machine

Best for testing or trying tuinix without touching your hardware.
Key requirements:

- UEFI firmware (**not** legacy BIOS)
- Secure Boot **disabled** (ZFS modules are unsigned)
- Disk serial number configured (for ZFS pool import)
- At least 4 GB RAM and 20 GB disk

> <img src=".github/assets/LOGO.png" width="20">
> Full details:
> [VM Installation Guide](https://timlinux.github.io/tuinix/installation/vm/)

#### Bare Metal

Install directly on a physical machine. You'll need:

- A USB drive (4 GB+) flashed with the ISO
- UEFI boot mode enabled, Secure Boot disabled
- At least 4 GB RAM and 20 GB storage

Flash the ISO:

```bash
sudo dd if=tuinix.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Boot from USB -- you'll land in `/home/tuinix` with a welcome
message. Run:

```bash
sudo installer
```

> <img src=".github/assets/LOGO.png" width="20">
> Full details:
> [Bare Metal Guide](https://timlinux.github.io/tuinix/installation/bare-metal/)

---

### 3. Post-Install Environment

*You've installed tuinix and are booting into it for the first
time.*

After installation you'll have a pure terminal environment with:

- ZFS-encrypted root filesystem with snapshot support
- Pre-configured shell, multiplexer, and editor
- System monitoring and networking tools
- Your tuinix flake at `~/tuinix` for further customization

Customize your system:

```bash
cd ~/tuinix
# Make changes to the configuration
./scripts/rebuild.sh
```

> <img src=".github/assets/LOGO.png" width="20">
> Full details:
> [Post-Install Guide](https://timlinux.github.io/tuinix/usage/post-install/)

---

## Features

- **NixOS + Flakes** -- Fully reproducible, declarative
  system configuration with instant rollbacks
- **ZFS with encryption** -- Advanced filesystem with
  compression, checksums, and snapshots
- **Terminal only** -- No X11, no Wayland. Minimal resource
  usage, maximum productivity
- **Interactive TUI installer** -- Go-based wizard with
  account setup, disk selection, encryption, and locale configuration

## Contributing

We welcome contributions. See the
[Contributing Guide](.github/CONTRIBUTING.md) for details.

- [Report a bug](https://github.com/timlinux/tuinix/issues/new?template=bug_report.yml)
- [Request a feature](https://github.com/timlinux/tuinix/issues/new?template=feature_request.yml)
- [Ask a question](https://github.com/timlinux/tuinix/issues/new?template=question.yml)

## Documentation

Full documentation is available at
**[timlinux.github.io/tuinix](https://timlinux.github.io/tuinix/)**.

| Document | Description |
|----------|-------------|
| [Installation Guide][inst] | Bare metal and VM installation |
| [Post-Install Guide][post] | First boot and daily usage |
| [ZFS Management][zfs] | Snapshots, scrubs, and recovery |
| [Development Guide][dev] | Building, testing, contributing |
| [AI/LLM Policy][ai] | Tool-assisted contribution guidelines |

[inst]: https://timlinux.github.io/tuinix/installation/
[post]: https://timlinux.github.io/tuinix/usage/post-install/
[zfs]: https://timlinux.github.io/tuinix/usage/zfs/
[dev]: https://timlinux.github.io/tuinix/contributing/development/
[ai]: https://timlinux.github.io/tuinix/contributing/ai-policy/

## License

MIT -- see [LICENSE](LICENSE).

---

**Built by [Tim Sutton](https://github.com/timlinux) and the
tuinix community.**
