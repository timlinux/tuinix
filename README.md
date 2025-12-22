<div align="center">
  <img src=".github/assets/LOGO.png" alt="nixmywindows logo" width="120" height="120">
  
  # NIX MY WINDOWS
  
  **A Pure Terminal Based Linux Experience**
</div>

<div align="center">

<!-- CI/CD Status -->
![CI](https://github.com/timlinux/nixmywindows/workflows/CI/badge.svg)
![Release](https://github.com/timlinux/nixmywindows/workflows/Release/badge.svg)

<!-- Quality Assurance -->
[![Pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)
[![Code Quality](https://img.shields.io/badge/code%20quality-A+-brightgreen.svg)]()

<!-- Language-specific Quality -->
[![Nix Format](https://img.shields.io/badge/nix-fmt-blue.svg)](https://nixos.org/)
[![Shell Check](https://img.shields.io/badge/shell-check-green.svg)](https://www.shellcheck.net/)
[![Markdown Lint](https://img.shields.io/badge/markdown-lint-blue.svg)](https://github.com/DavidAnson/markdownlint)
[![Python: Black](https://img.shields.io/badge/python-black-black.svg)](https://github.com/psf/black)
[![Go Format](https://img.shields.io/badge/go-fmt-blue.svg)](https://golang.org/)

<!-- Security -->
[![Security: Trivy](https://img.shields.io/badge/security-trivy-blue.svg)](https://github.com/aquasecurity/trivy)
[![Secrets: Detection](https://img.shields.io/badge/secrets-detection-red.svg)](https://github.com/Yelp/detect-secrets)

<!-- Project Info -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Nix](https://img.shields.io/badge/built%20with-nix-blue.svg)](https://nixos.org/)
[![ZFS](https://img.shields.io/badge/filesystem-ZFS-orange.svg)](https://openzfs.org/)

<!-- Community -->
[![Contributors](https://img.shields.io/github/contributors/timlinux/nixmywindows.svg)](https://github.com/timlinux/nixmywindows/graphs/contributors)
[![Issues](https://img.shields.io/github/issues/timlinux/nixmywindows.svg)](https://github.com/timlinux/nixmywindows/issues)
[![Pull Requests](https://img.shields.io/github/issues-pr/timlinux/nixmywindows.svg)](https://github.com/timlinux/nixmywindows/pulls)
[![Last Commit](https://img.shields.io/github/last-commit/timlinux/nixmywindows.svg)](https://github.com/timlinux/nixmywindows/commits/main)

</div>

This project creates a useable, user-friendly, terminal-centric Linux experience based on NixOS. Experience the power of a purely functional operating system with modern terminal tools, all without the complexity of graphical desktop environments.

**🔥 Ready to install?** Download `nixmywindows.v1.iso` - a single, self-contained bootable ISO that includes both the installer and complete system configuration. No internet required for installation!

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

1. **Get the ISO**
   - Download `nixmywindows.v1.iso` from releases, or
   - Build locally: `./scripts/build-iso.sh`

2. **Create bootable media**
   ```bash
   # Flash to USB drive (replace /dev/sdX with your USB device)
   sudo dd if=nixmywindows.v1.iso of=/dev/sdX bs=4M status=progress
   ```

3. **Install the system**
   - Boot from the USB drive
   - The ISO contains both the installer and complete nixmywindows configuration
   - See [INSTALL.md](INSTALL.md) for detailed installation instructions
   - Quick install: `sudo nixos-install --flake /iso/nixmywindows#laptop`

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

### Project Documentation
- [**Project Requirements**](REQUIREMENTS.md) - Original project vision and requirements
- [**Brand Guidelines**](./.github/BRAND.md) - Visual identity, colors, typography, and design principles
- [**Contributing Guide**](./.github/CONTRIBUTING.md) - How to contribute to the project
- [**Code of Conduct**](./.github/CODE_OF_CONDUCT.md) - Community guidelines and behavior standards
- [**CLA Agreement**](./.github/CLA.md) - Contributor License Agreement
- [**Claude Configuration**](./.github/CLAUDE.md) - AI assistance directives and project context

### Technical Documentation
- [**Installation Guide**](INSTALL.md) - Complete installation instructions
- [Configuration Reference](./.github/docs/configuration.md) - (Coming Soon)
- [Terminal Tools Guide](./.github/docs/terminal-tools.md) - (Coming Soon)
- [ZFS Management](./.github/docs/zfs.md) - (Coming Soon)
- [Troubleshooting](./.github/docs/troubleshooting.md) - (Coming Soon)

### Development Resources
- [**Development Setup**](./.github/CONTRIBUTING.md#development-setup) - Quick start for developers
- [**Quality Assurance**](#quality-assurance) - Our comprehensive QA system
- [**Issue Templates**](./.github/ISSUE_TEMPLATE/) - Bug reports, feature requests, and questions
- [**Assets Directory**](./.github/assets/README.md) - Visual assets and branding resources

## 🔧 Quality Assurance

We maintain high code quality through comprehensive automated checking:

### Pre-commit Hooks
- **Nix**: nixfmt formatter for consistent Nix code style
- **Shell Scripts**: shellcheck linting for bash script quality
- **Markdown**: markdownlint for documentation consistency
- **Python**: black + isort + flake8 + mypy for comprehensive Python QA
- **Go**: gofmt + golangci-lint + go-vet for Go code quality
- **HTML/CSS**: djLint + prettier for web content formatting
- **Security**: detect-secrets for preventing credential leaks

### GitHub Actions CI
- All pre-commit checks run automatically on PRs
- Language-specific quality jobs run conditionally
- Security scanning with Trivy vulnerability detection
- Comprehensive build and test validation

### Developer Setup
```bash
# Quick setup - run from repository root
./scripts/setup-dev.sh
```

This sets up all pre-commit hooks and development tools automatically.

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

## 👥 Contributors

This project is made possible by our amazing contributors:

<!-- CONTRIBUTORS_START -->
| Avatar | GitHub | Contributions |
|--------|--------|---------------|
| <img src="https://avatars.githubusercontent.com/u/178003?v=4" width="64" height="64" alt="timlinux"> | [timlinux](https://github.com/timlinux) | 27 |
| <img src="https://avatars.githubusercontent.com/in/1143301?v=4" width="64" height="64" alt="Copilot"> | [Copilot](https://github.com/apps/copilot-swe-agent) | 4 |
<!-- CONTRIBUTORS_END -->

---

**Built with ❤️ by [Tim Sutton](https://github.com/timlinux) and the nixmywindows community.**
