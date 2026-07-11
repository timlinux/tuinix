#!/usr/bin/env bash
# Generate build-info.txt for the tuinix ISO build.
#
# The single point of truth for the release version is the VERSION file
# in the repo root; this script only adds build provenance (commit,
# dirty suffix, timestamp). Do not edit versions anywhere else.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ ! -f VERSION ]]; then
  echo "ERROR: VERSION file not found in repo root" >&2
  exit 1
fi

BASE_VERSION="v$(tr -d '[:space:]' <VERSION)"

# Git commit info if available
if git rev-parse --git-dir >/dev/null 2>&1; then
  COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  DIRTY=""
  git diff --quiet HEAD 2>/dev/null || DIRTY="-dirty"
  # Release builds (HEAD is exactly the version tag) get a clean version;
  # anything else is marked as a dev build of that version.
  if git describe --tags --exact-match 2>/dev/null | grep -qx "$BASE_VERSION"; then
    VERSION="$BASE_VERSION$DIRTY"
  else
    VERSION="$BASE_VERSION-dev-g$COMMIT_HASH$DIRTY"
  fi
else
  COMMIT_HASH="unknown"
  BRANCH="unknown"
  VERSION="$BASE_VERSION"
fi

# Allow explicit override (used by release automation)
VERSION="${TUINIX_VERSION:-$VERSION}"

TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

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
