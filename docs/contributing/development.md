# Development Guide

This guide is for contributors and developers working on the
tuinix flake itself -- the "external" environment where the system
configuration, installer, and ISO are built and maintained.

## Prerequisites

You need a working Nix installation with flakes enabled. tuinix is
developed on NixOS but the flake can be built from any system
with Nix.

## Getting started

```bash
git clone https://github.com/timlinux/tuinix.git
cd tuinix

# Set up pre-commit hooks and dev tools
./scripts/setup-dev.sh
```

## Common tasks

### Build the ISO

```bash
./scripts/build-iso.sh
```

### Test in a VM

```bash
./scripts/run-vm.sh iso        # Boot the ISO
./scripts/run-vm.sh harddrive  # Boot installed system
./scripts/run-vm.sh clean      # Remove VM artifacts
```

### Check the flake

```bash
nix flake check
```

### Build the system configuration

```bash
nix build .#nixosConfigurations.tuinix.config.system.build.toplevel
```

### Apply changes on an installed system

```bash
./scripts/rebuild.sh
```

## Repository structure

```text
tuinix/
├── flake.nix           # Main flake -- entry point for everything
├── installer.nix       # ISO/installer configuration
├── hosts/              # Per-host configurations
├── modules/            # Custom NixOS modules
│   ├── networking/     # Ethernet, WiFi
│   ├── security/       # Firewall, SSH, sudo
│   └── system/         # ZFS, boot, etc.
├── profiles/           # Shared configuration profiles
├── software/           # Package sets
├── templates/          # Disko templates, hardware templates
├── scripts/            # Build, install, and dev scripts
├── users/              # User account configurations
└── docs/               # MkDocs documentation site
```

## Quality assurance

All code goes through pre-commit hooks:

- **Nix**: nixfmt formatting
- **Shell**: shellcheck linting
- **Markdown**: markdownlint
- **Python**: black, isort, flake8, mypy
- **Go**: gofmt, golangci-lint, go vet
- **Security**: detect-secrets

CI runs the same checks on every PR.

## Contributing

See the [Contributing Guidelines](guidelines.md) for full details on submitting pull requests.
