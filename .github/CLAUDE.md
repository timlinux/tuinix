# Claude Configuration for tuinix

This file contains Claude-specific configurations and directives
for the tuinix project.

## Project Context

**Project Name**: tuinix
**Description**: A pure terminal-based Linux experience built on
NixOS with ZFS encryption
**Primary Technologies**: NixOS, Nix Flakes, ZFS, Terminal-based tools
**Repository**: <https://github.com/timlinux/tuinix>

## Key Project Information

### Architecture

- **Base**: NixOS with Nix Flakes for reproducible builds
- **Filesystem**: ZFS with LUKS encryption
- **Interface**: Terminal-only (no X11/Wayland)
- **Target**: Power users who prefer command-line interfaces

### Important Files

- `flake.nix` - Main Nix flake configuration
- `hosts/` - Per-host configurations
- `modules/` - Shared NixOS modules
- `PROMPT.log` - Log of all prompts and sessions

### Development Workflow

```bash
# Build system
nix build .#nixosConfigurations.laptop.config.system.build.toplevel

# Check flake
nix flake check

# Build ISO
nix build .#nixosConfigurations.laptop.config.system.build.isoImage

# Format code
nix fmt
```

## Claude Directives

### General Guidelines

1. **Maintain PROMPT.log**: Always update with new prompts
2. **Follow Nix Conventions**: Proper Nix syntax and best practices
3. **Terminal-First Mindset**: Prioritize CLI tools over GUI
4. **Security Focus**: Emphasize encryption and system security

### Code Standards

- Use 2-space indentation for Nix files
- Follow the project's existing code style
- Prefer functional programming patterns
- Document complex configurations with comments
- Test changes with `nix flake check` before committing

### Testing Protocol

When making changes:

1. Run `nix flake check` to validate syntax
2. Build the system to ensure no breakage
3. Test ISO generation if installer changes are made
4. Verify ZFS configurations work correctly
5. Check that terminal environment remains functional

### Documentation Requirements

- Update mkdocs site for significant features
- Document new modules in appropriate locations
- Maintain changelog for releases
- Keep installation instructions current

## Common Tasks and Commands

### Building and Testing

```bash
# Validate flake
nix flake check --show-trace

# Build system configuration
nix build .#nixosConfigurations.laptop.config.system.build.toplevel

# Build installer ISO
nix build .#nixosConfigurations.laptop.config.system.build.isoImage

# Format all Nix files
nix fmt

# Update flake inputs
nix flake update
```

### Development Environment

```bash
# Enter development shell
nix develop

# Test configuration changes
nixos-rebuild test --flake .#laptop

# Switch to new configuration
nixos-rebuild switch --flake .#laptop
```

## Project Goals and Constraints

### Goals

- Create a minimal, secure, terminal-centric Linux distribution
- Leverage NixOS for reproducibility and reliability
- Provide a curated set of terminal tools for productivity
- Maintain simplicity while offering power-user features

### Constraints

- No graphical desktop environment (X11/Wayland)
- Must support ZFS with encryption
- All configurations must be declarative
- System must be reproducible across different hardware

## Troubleshooting Common Issues

### Build Failures

1. Check flake syntax with `nix flake check`
2. Verify all inputs are available
3. Ensure hardware-specific configurations are correct
4. Check for circular dependencies in modules

### ZFS Issues

1. Verify ZFS is enabled in kernel
2. Check pool and dataset configurations
3. Ensure encryption settings are correct
4. Validate mount points and options

### Terminal Environment

1. Test shell configurations
2. Verify terminal multiplexer setup
3. Check editor configurations
4. Validate CLI tool availability

---

**Primary Maintainer**: Tim Sutton (timlinux)
**Repository**: <https://github.com/timlinux/tuinix>
