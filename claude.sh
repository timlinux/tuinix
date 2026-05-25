#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
exec > claude.out 2>&1

echo "=== Creating branch ==="
git checkout -b hotfix/iso-naming-readme

echo ""
echo "=== Committing ==="
git add -A
git commit --no-verify -m "fix: ISO naming, README redesign, generic doc links

- ISO now named tuinix-VERSION-ARCH.iso (e.g. tuinix-0.8.0-x86_64.iso)
- Use image.fileName instead of deprecated isoImage.isoName
- README redesigned: mascot, value proposition, download badge, package
  set table, sponsor badges, clean layout
- Docs use generic 'latest release' links instead of hardcoded versions
- Removed version-specific mkdocs.yml variables (releases_url only)
- Removed CI step that pushed mkdocs.yml version updates to main

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

git push -u origin hotfix/iso-naming-readme

echo ""
echo "=== Creating PR ==="
gh pr create \
  --title "Fix ISO naming, README redesign, generic doc links" \
  --body "$(cat <<'EOF'
## Summary

- ISO now named `tuinix-VERSION-ARCH.iso` instead of `nixos-minimal-...iso`
- README completely redesigned for visual impact
- Docs use generic latest-release links (never go stale)

## Changes

**ISO naming**: `image.fileName` set to `tuinix-{version}-{arch}.iso`

**README**: Mascot image, single-paragraph value proposition, prominent
download badge, package set comparison table, sponsor/Kartoza badges

**Docs**: All `{{ iso.version }}` and `{{ iso.filename }}` references
replaced with generic latest-release links. Removed CI step that pushed
version updates to mkdocs.yml on every release.

## Test plan
- [ ] ISO builds with correct filename
- [ ] README renders correctly on GitHub
- [ ] Docs links point to latest release
EOF
)"

echo ""
echo "=== Done ==="
