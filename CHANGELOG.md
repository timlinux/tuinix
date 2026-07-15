# Changelog

All notable changes to tuinix are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.8.0] - 2026-07-11

### Added

- `tuinix-menu`: gum-powered system menu with drill-down categories so
  installed TUI apps are discoverable; only installed apps are shown.
  Includes a Utilities category with a screen-brightness picker.
- Sound and Music collection (`tuinix.packages.music`): console-only
  music studio — `tuinix-music-menu`, elevator music generators, MIDI
  composer, FluidSynth rendering, sox mastering, csound, chuck, orca,
  abcmidi.
- Emergency GUI collection (`tuinix.packages.emergency`):
  `tuinix-emergency-gui` runs Brave in a cage Wayland kiosk — incognito,
  profile on tmpfs (no writes to snapshotted ZFS datasets) and inside a
  bubblewrap sandbox that hides the user's home folders.
- Base system additions: `wiremix` (default sound app), `bluetui`,
  `yazi` as default file manager with `f` alias, `brightnessctl`, `gum`,
  PipeWire sound stack and Bluetooth enabled by default.
- Installer wizard: Previous/Cancel and context-aware Next/Install!
  buttons pinned bottom-left/bottom-right, reachable with Tab/Shift+Tab;
  back-navigation preserves earlier answers.
- CI: ISO-contents check (`scripts/check-iso-contents.sh`) that
  re-evaluates the flake from only the files shipped on the ISO;
  all-collections evaluation check; gofmt check; Go tests; blocking
  ShellCheck.

### Changed

- Build artifacts renamed to a single intuitive scheme for both local
  and CI builds: `tuinix-<architecture>-<version>.iso` with a matching
  `tuinix-<architecture>-<version>.md5` checksum. CI artifacts and
  GitHub release uploads include both files.
- Versioning consolidated to a single point of truth: the `VERSION`
  file in the repo root. `build-info.txt` is generated from it with git
  provenance; the ISO filename, installer package version, TUI splash
  and footer, build monitor, and build/upload scripts all derive from
  it (previously six divergent hardcoded versions existed).
- Live installer ISO now uses `iwd` + `impala` (WiFi TUI) instead of
  wpa_supplicant for wireless setup.
- Matrix TUI client switched from gomuks to iamb: gomuks depends on
  libolm, which is deprecated upstream with known side-channel issues
  and is refused by nixpkgs (users selecting the TUI suite would have
  hit an install failure).
- CI format check now uses the flake's pinned formatter instead of the
  removed `nixpkgs#nixfmt-classic` registry package.

### Fixed

- Installation failed with `path '...-source/software' does not exist`:
  the ISO did not ship the `software/` and `profiles/` directories that
  the flake references. They are now included in `isoImage.contents`.
- `noto-fonts-emoji` renamed to `noto-fonts-color-emoji`.

### Removed

- All R36S handheld support (hosts/r36s, firmware blobs, SD-image
  modules, build scripts, docs and CI references) — 94 MB lighter repo
  and simpler flake evaluation.

## [0.7.1] - 2026-07-09

See GitHub releases for details of 0.7.1 and earlier.
