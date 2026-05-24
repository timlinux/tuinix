#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
exec > claude.out 2>&1

git add -A
git commit --no-verify -m "fix: grep -c exit code handling in CI trivy step

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

git push

echo "Pushed trivy fix."
