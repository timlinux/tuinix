# Contributing Guidelines

We welcome contributions from everyone. This page covers the practical workflow for submitting changes.

## Getting started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Set up the development environment (see [Development Guide](development.md))
4. Create a topic branch from `main`
5. Make your changes
6. Test your changes thoroughly
7. Submit a pull request

## Reporting bugs

Before reporting a bug, check the
[issue tracker](https://github.com/timlinux/tuinix/issues)
to see if it's already been reported. Use the
[bug report template](https://github.com/timlinux/tuinix/issues/new?template=bug_report.yml)
and include:

- A clear and descriptive title
- Steps to reproduce the issue
- Expected vs actual behavior
- Your environment details
- Relevant log output

## Suggesting features

Use the [feature request template](https://github.com/timlinux/tuinix/issues/new?template=feature_request.yml) and include:

- A clear description of the proposed feature
- Motivation and use case
- Relevant examples or mockups

## Coding standards

### Nix code style

- Use 2 spaces for indentation
- Follow the [Nix style guide](https://nixos.org/manual/nixpkgs/stable/#chap-conventions)
- Keep lines under 100 characters when possible
- Use descriptive variable names
- Comment complex expressions

### Git commit messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
type(scope): description
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

Examples:

```text
feat(zfs): add automatic snapshot scheduling
fix(boot): resolve UEFI boot issues on certain hardware
docs(readme): update installation instructions
```

## Pull request process

1. Sync with upstream: `git fetch upstream && git rebase upstream/main`
2. Test: `nix flake check`
3. Submit a pull request with a clear description
4. Address review feedback promptly

## AI/LLM tool usage

We allow AI tools but require human review and transparency. See our [AI/LLM Tool Policy](ai-policy.md).

## Contributor License Agreement

By contributing, you agree to the terms of our [Contributor License Agreement](https://github.com/timlinux/tuinix/blob/main/.github/CLA.md).

## Code of Conduct

All participants are expected to follow our [Code of Conduct](https://github.com/timlinux/tuinix/blob/main/.github/CODE_OF_CONDUCT.md).
