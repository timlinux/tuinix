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

### Build and test the installer (recommended)

```bash
nix run .#test-install         # Build ISO + launch QEMU in one step
```

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

## Versioning

The `VERSION` file in the repository root is the **single point of
truth** for the release version (bare semver, e.g. `0.7.1`). Never
hardcode a version anywhere else. Everything derives from it:

- `scripts/build-version.sh` writes `build-info.txt`, adding build
  provenance: a release build (HEAD exactly on the `v<VERSION>` tag)
  gets a clean `v0.7.1`; anything else becomes
  `v0.7.1-dev-g<commit>[-dirty]`.
- `installer.nix` parses `build-info.txt` for the ISO filename, the
  installer package version, and the version string embedded in the Go
  TUI (`version.txt`, shown on the splash and footer).
- `monitor-builds.sh` and the `scripts/build-*` / `scripts/upload-*`
  helpers read `VERSION` directly.

To cut a release: update `VERSION`, add a `CHANGELOG.md` section, tag
`v<VERSION>`, and build — the ISO and all displayed strings follow.

## Contributing

See the [Contributing Guidelines](guidelines.md) for full details on submitting pull requests.
