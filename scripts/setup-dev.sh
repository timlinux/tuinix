#!/usr/bin/env bash

# Development Environment Setup Script for tuinix
# This script sets up pre-commit hooks and development tools

set -euo pipefail

echo "🚀 Setting up tuinix development environment..."

# Check if we're in the right directory
if [[ ! -f "flake.nix" && ! -f ".pre-commit-config.yaml" ]]; then
  echo "❌ This doesn't appear to be the tuinix repository root"
  echo "   Please run this script from the repository root directory"
  exit 1
fi

# Install pre-commit if not already installed
if ! command -v pre-commit &> /dev/null; then
  echo "📦 Installing pre-commit..."
  if command -v pip &> /dev/null; then
    pip install pre-commit
  elif command -v nix &> /dev/null; then
    nix profile install nixpkgs#python3Packages.pre-commit
  else
    echo "❌ Neither pip nor nix found. Please install pre-commit manually:"
    echo "   https://pre-commit.com/#installation"
    exit 1
  fi
fi

# Install pre-commit hooks
echo "🔧 Installing pre-commit hooks..."
pre-commit install
pre-commit install --hook-type commit-msg

# Install additional tools with nix if available
if command -v nix &> /dev/null; then
  echo "📦 Installing nixfmt and other tools..."
  nix profile install nixpkgs#nixfmt-classic

  echo "📦 Installing shellcheck..."
  nix profile install nixpkgs#shellcheck

  echo "📦 Installing other development tools..."
  nix profile install nixpkgs#pre-commit
fi

# Run initial check
echo "✅ Running initial pre-commit check..."
pre-commit run --all-files || {
  echo "⚠️  Some files need formatting. This is normal for first setup."
  echo "   The hooks are now installed and will run automatically on commit."
}

echo ""
echo "🎉 Development environment setup complete!"
echo ""
echo "Next steps:"
echo "  • Pre-commit hooks are now active"
echo "  • Run 'pre-commit run --all-files' to check all files"
echo "  • Hooks will automatically run before each commit"
echo "  • To skip hooks for a commit, use: git commit --no-verify"
echo ""
echo "Quality tools installed:"
echo "  ✓ Pre-commit hooks for all file types"
echo "  ✓ Nix formatting (nixfmt)"
echo "  ✓ Shell script linting (shellcheck)"
echo "  ✓ Markdown linting"
echo "  ✓ Python formatting (black, isort, flake8)"
echo "  ✓ Go formatting and linting"
echo "  ✓ Security scanning"
echo ""
echo "Happy coding! 🎯"
