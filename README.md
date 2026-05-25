<div align="center">

<img src=".github/assets/LOGO.png" alt="tuinix mascot" width="200">

# tuinix

**A terminal-first Linux distribution built on NixOS.**

Reproducible, declarative, ZFS-encrypted. Choose your tools: productivity suite,
penetration testing, or retro terminal games -- all from a beautiful TUI installer.

[![Download ISO](https://img.shields.io/github/v/release/timlinux/tuinix?label=Download%20ISO&style=for-the-badge&logo=nixos&color=5277C3)](https://github.com/timlinux/tuinix/releases/latest)

[![CI](https://img.shields.io/github/actions/workflow/status/timlinux/tuinix/ci.yml?branch=main&label=CI&logo=github)](https://github.com/timlinux/tuinix/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/actions/workflow/status/timlinux/tuinix/release.yml?label=Release&logo=github)](https://github.com/timlinux/tuinix/actions/workflows/release.yml)
[![License](https://img.shields.io/github/license/timlinux/tuinix?color=yellow)](LICENSE)
[![Trivy](https://img.shields.io/badge/security-trivy-blue?logo=aquasecurity)](https://github.com/timlinux/tuinix/actions)
[![NixOS](https://img.shields.io/badge/NixOS-unstable-5277C3?logo=nixos)](https://nixos.org)
[![ZFS](https://img.shields.io/badge/ZFS-encrypted-orange)](https://openzfs.org)
[![Docs](https://img.shields.io/badge/docs-online-blue)](https://timlinux.github.io/tuinix/)

</div>

---

## Getting Started

1. **Download** the latest ISO from the [releases page](https://github.com/timlinux/tuinix/releases/latest)
2. **Flash** it to a USB drive and boot (UEFI required, Secure Boot off)
3. **Run** `sudo installer` and follow the TUI wizard

The installer guides you through account setup, disk selection (including
ZFS encryption and dual-boot), and package set selection. Full docs at
**[timlinux.github.io/tuinix](https://timlinux.github.io/tuinix/)**.

## Package Sets

During installation, choose which optional package sets to enable:

| | Minimal | TUI | Pentest | Games |
|---|---------|-----|---------|-------|
| Base tools (vim, git, curl, htop, tmux) | Always | Always | Always | Always |
| Terminal productivity (neovim, lazygit, btop, w3m, starship) | | Yes | | |
| Messaging (nchat, gomuks, scli, aerc) | | Yes | | |
| Calendar & contacts (khal, khard, todoman) | | Yes | | |
| Security auditing (aircrack-ng, nmap, metasploit, hashcat) | | | Yes | |
| Network analysis (wireshark, termshark, sqlmap) | | | Yes | |
| Roguelikes (angband, crawl, cataclysm-dda) | | | | Yes |
| Puzzles & classics (nudoku, vitetris, bsdgames, frotz) | | | | Yes |

## Features

- **NixOS + Flakes** -- Fully reproducible, declarative, instant rollbacks
- **ZFS encryption** -- AES-256-GCM, compression, snapshots, self-healing
- **Multi-disk** -- Stripe, raidz, raidz2 for redundancy
- **Dual-boot** -- XFS partition mode for existing setups
- **TUI installer** -- Beautiful Go-based wizard with live progress
- **CI/CD** -- Every PR builds an ISO with SBOM and CVE scan

## Documentation

| | |
|---|---|
| [Installation Guide](https://timlinux.github.io/tuinix/installation/) | Bare metal, VM, and dual-boot setup |
| [Post-Install Guide](https://timlinux.github.io/tuinix/usage/post-install/) | Package sets, daily usage, system updates |
| [ZFS Management](https://timlinux.github.io/tuinix/usage/zfs/) | Snapshots, scrubs, recovery |
| [Development Guide](https://timlinux.github.io/tuinix/contributing/development/) | Build, test, contribute |

## Contributing

- [Report a bug](https://github.com/timlinux/tuinix/issues/new?template=bug_report.yml)
- [Request a feature](https://github.com/timlinux/tuinix/issues/new?template=feature_request.yml)
- [Ask a question](https://github.com/timlinux/tuinix/issues/new?template=question.yml)

## License

MIT -- see [LICENSE](LICENSE).

---

<div align="center">

Made with :heart: by **[Kartoza](https://kartoza.com)**

[![Sponsor](https://img.shields.io/badge/Sponsor-timlinux-ea4aaa?logo=github-sponsors)](https://github.com/sponsors/timlinux)
[![Kartoza](https://img.shields.io/badge/Kartoza-kartoza.com-e95420)](https://kartoza.com)
[![GitHub](https://img.shields.io/badge/Source-GitHub-333?logo=github)](https://github.com/timlinux/tuinix)

</div>
