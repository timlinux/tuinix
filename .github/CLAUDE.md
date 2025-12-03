<div align="center">
  <img src="assets/LOGO.png" alt="nixmywindows logo" width="80" height="80">
  
  # Claude Configuration for nixmywindows
  
  **AI Assistant directives for consistent, productive collaboration** 🤖
</div>

This file contains Claude-specific configurations and directives to ensure consistent and productive AI assistance sessions for the nixmywindows project. It serves as a guide for maintaining project context and workflow consistency across multiple AI-assisted development sessions.

## Project Context

**Project Name**: nixmywindows  
**Description**: A pure terminal-based Linux experience built on NixOS with ZFS encryption  
**Primary Technologies**: NixOS, Nix Flakes, ZFS, Terminal-based tools  
**Repository**: https://github.com/timlinux/nixmywindows

## Key Project Information

### Architecture
- **Base**: NixOS with Nix Flakes for reproducible builds
- **Filesystem**: ZFS with LUKS encryption
- **Interface**: Terminal-only (no X11/Wayland)
- **Target**: Power users who prefer command-line interfaces

### Important Files
- `flake.nix` - Main Nix flake configuration
- `configuration.nix` - System configuration
- `REQUIREMENTS.md` - Original project requirements
- `PROMPT.log` - Comprehensive log of all prompts and sessions

### Development Workflow
```bash
# Build system
nix build .#nixosConfigurations.nixmywindows.config.system.build.toplevel

# Check flake
nix flake check

# Build ISO
nix build .#nixosConfigurations.nixmywindows.config.system.build.isoImage

# Format code
nix fmt
```

## Claude Directives

### General Guidelines
1. **Maintain PROMPT.log**: Always update the PROMPT.log file with new prompts and session summaries
2. **Follow Nix Conventions**: Use proper Nix syntax, formatting, and best practices
3. **Terminal-First Mindset**: All suggestions should prioritize terminal/CLI tools over GUI alternatives
4. **Security Focus**: Emphasize security best practices, especially for encryption and system configuration

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
- Update README.md for significant features
- Document new modules in appropriate locations
- Maintain changelog for releases
- Keep installation instructions current

## Common Tasks and Commands

### Building and Testing
```bash
# Validate flake
nix flake check --show-trace

# Build system configuration
nix build .#nixosConfigurations.nixmywindows.config.system.build.toplevel

# Build installer ISO
nix build .#nixosConfigurations.nixmywindows.config.system.build.isoImage

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
nixos-rebuild test --flake .#nixmywindows

# Switch to new configuration
nixos-rebuild switch --flake .#nixmywindows
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

## Session Memory

### Previous Sessions
- Initial repository setup completed
- GitHub repository structure established
- CI/CD workflows configured
- Documentation framework created

### Current Configuration Status
- Repository initialized with Git
- GitHub-ready structure with all standard files
- Professional README with badges
- Comprehensive issue/PR templates
- Security and contribution guidelines
- Claude configuration established

### Next Steps Typically Needed
- Nix flake configuration
- NixOS system configuration
- Hardware-specific modules
- Terminal tool configurations
- ZFS setup scripts
- Installation documentation

## Contact Information

**Primary Maintainer**: Tim Sutton (timlinux)  
**Project Repository**: https://github.com/timlinux/nixmywindows  
**Issues**: Use GitHub issue templates for bug reports and feature requests

---

*This file should be updated whenever significant changes are made to the project structure, development workflow, or important project decisions.*