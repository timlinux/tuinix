<div align="center">
  <img src="assets/LOGO.png" alt="nixmywindows logo" width="80" height="80">
  
  # Contributing to nixmywindows
  
  **Welcome to the nixmywindows contributor community!** 🎉
</div>

Thank you for your interest in contributing to nixmywindows! We welcome contributions from everyone and appreciate your help in making this project better.

Whether you're fixing a bug, adding a feature, improving documentation, or sharing ideas, your contribution helps build a better terminal-based Linux experience for everyone. The Ubuntu philosophy of "I am because we are" is at the heart of our project - we're stronger together!

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Community](#community)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
3. **Set up the development environment** (see [Development Setup](#development-setup))
4. **Create a topic branch** from `main`
5. **Make your changes**
6. **Test your changes** thoroughly
7. **Submit a pull request**

## How to Contribute

### Reporting Bugs

Before reporting a bug, please check the [issue tracker](https://github.com/timlinux/nixmywindows/issues) to see if the bug has already been reported.

When reporting bugs, please use the [bug report template](https://github.com/timlinux/nixmywindows/issues/new?template=bug_report.yml) and include:

- A clear and descriptive title
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Your environment details
- Any relevant log output

### Suggesting Features

Feature requests are welcome! Please use the [feature request template](https://github.com/timlinux/nixmywindows/issues/new?template=feature_request.yml) and include:

- A clear and descriptive title
- A detailed description of the proposed feature
- The motivation and use case for the feature
- Any relevant examples or mockups

### Asking Questions

If you have questions about using nixmywindows, please use the [question template](https://github.com/timlinux/nixmywindows/issues/new?template=question.yml) or start a [discussion](https://github.com/timlinux/nixmywindows/discussions).

## Development Setup

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- [Git](https://git-scm.com/)
- A GitHub account for submitting pull requests

### Setting up the Environment

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/nixmywindows.git
cd nixmywindows

# Add the upstream repository as a remote
git remote add upstream https://github.com/timlinux/nixmywindows.git

# Run the development setup script (sets up pre-commit hooks and tools)
../scripts/setup-dev.sh

# Enter the development shell (if using Nix)
nix develop

# Build the system to test your changes
nix build .#nixosConfigurations.nixmywindows.config.system.build.toplevel
```

### Building and Testing

```bash
# Check that everything builds correctly
nix flake check

# Build the ISO image
nix build .#nixosConfigurations.nixmywindows.config.system.build.isoImage

# Test in a virtual machine (if supported)
nix run .#vm
```

## Coding Standards

### Nix Code Style

- Use 2 spaces for indentation
- Follow the [Nix style guide](https://nixos.org/manual/nixpkgs/stable/#chap-conventions)
- Keep lines under 100 characters when possible
- Use descriptive variable names
- Comment complex expressions

### Git Commit Messages

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
type(scope): description

[optional body]

[optional footer(s)]
```

Types:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that don't affect the meaning of the code
- `refactor`: Code changes that neither fix a bug nor add a feature
- `perf`: Performance improvements
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to the build process or auxiliary tools

Examples:
```
feat(zfs): add automatic snapshot scheduling
fix(boot): resolve UEFI boot issues on certain hardware
docs(readme): update installation instructions
```

## Testing

### Manual Testing

- Test your changes on actual hardware when possible
- Verify that the system boots correctly
- Test ZFS functionality if your changes affect storage
- Ensure terminal environment works as expected

### Automated Testing

- Run `nix flake check` to verify all builds work
- Ensure CI passes for your pull request
- Add tests for new functionality when applicable

## Submitting Changes

### Before Submitting

1. **Sync with upstream**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Test your changes**:
   ```bash
   nix flake check
   nix build .#nixosConfigurations.nixmywindows.config.system.build.toplevel
   ```

3. **Review your commits**:
   - Ensure commit messages follow our standards
   - Squash related commits if necessary
   - Remove any debugging or temporary code

### Pull Request Process

1. **Create a pull request** using the provided template
2. **Fill out the template completely** with:
   - Clear description of changes
   - Type of change
   - Testing performed
   - Any breaking changes
3. **Link to related issues** if applicable
4. **Request review** from maintainers
5. **Address feedback** promptly and professionally

### Pull Request Guidelines

- One feature/fix per pull request
- Include tests for new functionality
- Update documentation as needed
- Ensure CI passes
- Keep the PR scope focused and manageable

## Code Review Process

All pull requests require review before merging. The review process includes:

1. **Automated checks**: CI must pass
2. **Code review**: At least one maintainer review
3. **Testing**: Manual testing may be required for significant changes
4. **Documentation**: Ensure docs are updated if needed

## Contributor License Agreement

By contributing to this project, you agree to the terms of our [Contributor License Agreement](CLA.md).

## Recognition

Contributors are recognized in several ways:
- Listed in the README contributors section
- Mentioned in release notes for significant contributions
- Invited to join the maintainers team for sustained contributions

## Community

### Communication Channels

- [GitHub Discussions](https://github.com/timlinux/nixmywindows/discussions) - General discussions
- [GitHub Issues](https://github.com/timlinux/nixmywindows/issues) - Bug reports and feature requests
- [Pull Requests](https://github.com/timlinux/nixmywindows/pulls) - Code contributions

### Getting Help

If you need help contributing:
- Check existing documentation
- Ask in GitHub Discussions
- Reach out to maintainers
- Join our community chat (if available)

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/)
- [Nix Language Reference](https://nixos.org/manual/nix/stable/language/)
- [ZFS Documentation](https://openzfs.github.io/openzfs-docs/)

---

Thank you for contributing to nixmywindows! Your efforts help make this project better for everyone.