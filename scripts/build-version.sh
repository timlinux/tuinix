#!/usr/bin/env bash
# Generate build version and timestamp for tuinix ISO
set -euo pipefail

# Get version from environment or git
VERSION="${TUINIX_VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo "dev-$(date +%Y%m%d)")}"

# Generate timestamp
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

# Git commit info if available
if git rev-parse --git-dir >/dev/null 2>&1; then
  COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
else
  COMMIT_HASH="unknown"
  BRANCH="unknown"
fi

# Create simple text version for easy reading
cat >build-info.txt <<EOF
tuinix Build Information
==============================
Version: $VERSION
Build Date: $TIMESTAMP
Commit: $COMMIT_HASH ($BRANCH)
Builder: $(whoami)@$(hostname)
EOF

echo "Build information generated:"
cat build-info.txt
