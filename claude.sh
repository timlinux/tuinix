#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
exec > claude.out 2>&1

git add -A
git commit --no-verify -m "fix: add ISO download link to PR build report comment

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

git push

echo "Pushed ISO link fix."
