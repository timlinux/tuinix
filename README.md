# NIX MY WINDOWS

![CI](https://github.com/timlinux/nixmywindows/workflows/CI/badge.svg)
![Release](https://github.com/timlinux/nixmywindows/workflows/Release/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Nix](https://img.shields.io/badge/built%20with-nix-blue.svg)](https://nixos.org/)
[![ZFS](https://img.shields.io/badge/filesystem-ZFS-orange.svg)](https://openzfs.org/)
[![Contributors](https://img.shields.io/github/contributors/timlinux/nixmywindows.svg)](https://github.com/timlinux/nixmywindows/graphs/contributors)
[![Issues](https://img.shields.io/github/issues/timlinux/nixmywindows.svg)](https://github.com/timlinux/nixmywindows/issues)
[![Pull Requests](https://img.shields.io/github/issues-pr/timlinux/nixmywindows.svg)](https://github.com/timlinux/nixmywindows/pulls)
[![Last Commit](https://img.shields.io/github/last-commit/timlinux/nixmywindows.svg)](https://github.com/timlinux/nixmywindows/commits/main)

## A Pure Terminal Based Linux Experience

This project creates a useable, user-friendly, terminal-centric Linux experience based on NixOS. Experience the power of a purely functional operating system with modern terminal tools, all without the complexity of graphical desktop environments.

## ✨ Features

### 🏗️ **NixOS Foundation**
- **Reproducible Builds**: Based on NixOS and Nix Flakes for 100% reproducible system configurations
- **Declarative Configuration**: Everything is code - no hidden state or manual configuration drift
- **Rollback Support**: Instant rollbacks to previous system generations

### 💾 **ZFS with Encryption**
- **Advanced File System**: ZFS as the underlying filesystem with built-in compression and checksums
- **Full Disk Encryption**: Secure your data with LUKS encryption
- **Snapshots & Rollbacks**: Point-in-time recovery and system snapshots

### 🖥️ **Terminal-Only Experience**
- **No Desktop Environment**: Pure terminal interface - no Wayland or X11
- **Optimized Workflow**: Carefully curated terminal tools and utilities
- **Performance**: Minimal resource usage with maximum productivity

### 🛠️ **Modern Terminal Stack**
- Advanced shell with intelligent completions
- Modern terminal multiplexer
- Efficient text editors and development tools
- System monitoring and management utilities

## 🚀 Quick Start

### Prerequisites
- A computer with UEFI boot support
- At least 4GB RAM (8GB recommended)
- 20GB+ storage space
- Basic familiarity with terminal/command line

### Installation

1. **Download the latest ISO**
   ```bash
   # Download from releases
   wget https://github.com/timlinux/nixmywindows/releases/latest/download/nixmywindows.iso
   ```

2. **Create bootable media**
   ```bash
   # Flash to USB drive (replace /dev/sdX with your USB device)
   sudo dd if=nixmywindows.iso of=/dev/sdX bs=4M status=progress
   ```

3. **Boot and install**
   - Boot from the USB drive
   - Follow the installation prompts
   - Configure ZFS encryption when prompted
   - Reboot into your new system

### Development Setup

```bash
# Clone the repository
git clone https://github.com/timlinux/nixmywindows.git
cd nixmywindows

# Build the system
nix build .#nixosConfigurations.nixmywindows.config.system.build.toplevel

# Build ISO image for testing
nix build .#nixosConfigurations.nixmywindows.config.system.build.isoImage

# Test in a virtual machine
nix run .#vm
```

## 📖 Documentation

- [Installation Guide](./.github/docs/installation.md)
- [Configuration Reference](./.github/docs/configuration.md)
- [Terminal Tools Guide](./.github/docs/terminal-tools.md)
- [ZFS Management](./.github/docs/zfs.md)
- [Troubleshooting](./.github/docs/troubleshooting.md)

## 🏗️ Architecture

```
nixmywindows/
├── flake.nix              # Main Nix flake configuration
├── configuration.nix      # System configuration
├── hardware/              # Hardware-specific configurations
├── modules/               # Custom NixOS modules
├── packages/              # Custom package definitions
└── profiles/              # User profile configurations
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Ways to Contribute
- 🐛 [Report bugs](https://github.com/timlinux/nixmywindows/issues/new?template=bug_report.yml)
- 💡 [Request features](https://github.com/timlinux/nixmywindows/issues/new?template=feature_request.yml)
- 📖 Improve documentation
- 🔧 Submit pull requests
- ❓ [Ask questions](https://github.com/timlinux/nixmywindows/issues/new?template=question.yml)

### Development Workflow
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📋 Requirements

### Minimum System Requirements
- **CPU**: x86_64 or ARM64
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 20GB minimum, 50GB recommended
- **Boot**: UEFI support required

### Supported Hardware
- Most modern x86_64 systems
- ARM64 systems (experimental)
- Virtual machines (VMware, VirtualBox, QEMU/KVM)

## 🔒 Security

Security is a top priority. We implement:
- Full disk encryption by default
- Minimal attack surface (no GUI)
- Regular security updates via NixOS channels
- Reproducible builds for supply chain security

Please report security vulnerabilities privately to [security@example.com].

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **NixOS Community** - For creating an amazing functional operating system
- **ZFS Community** - For the most advanced filesystem
- **Terminal Tool Maintainers** - For building exceptional CLI tools

## 📊 Project Status

- ✅ **Active Development** - Regular updates and improvements
- 🧪 **Beta Quality** - Suitable for testing and development
- 📈 **Growing Community** - New contributors welcome

## 🔗 Related Projects

- [NixOS](https://nixos.org/) - The functional operating system
- [Home Manager](https://github.com/nix-community/home-manager) - Nix-based user environment management
- [nix-darwin](https://github.com/LnL7/nix-darwin) - Nix modules for Darwin/macOS

## 📞 Support

- 📚 [Documentation](./.github/docs/)
- 💬 [Discussions](https://github.com/timlinux/nixmywindows/discussions)
- 🐛 [Issue Tracker](https://github.com/timlinux/nixmywindows/issues)
- 📧 [Email Support](mailto:timlinux@example.com)

---

**Built with ❤️ by [Tim Sutton](https://github.com/timlinux) and the nixmywindows community.**