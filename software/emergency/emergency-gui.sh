#!/usr/bin/env bash

# tuinix Emergency GUI — start a minimal Wayland session in kiosk mode
# running only the Brave browser. For those emergencies when you
# absolutely must have a GUI (webmail, banking, captive portals, ...).
#
# Privacy by design:
#   - Brave runs in incognito mode with its profile on a tmpfs, so no
#     browsing data is ever written to the ZFS datasets (where snapshots
#     would preserve an audit trail).
#   - Brave runs inside a bubblewrap container: the real /home is
#     replaced with an empty tmpfs, so user folders are never exposed
#     to the browser. Only the Nix store, network config, certificates,
#     fonts and the GPU are visible.
#
# The cage compositor shows a single maximized application and nothing
# else. Quit the browser to return to the console.
#
# Environment (set by the tuinix-emergency-gui wrapper):
#   CAGE_BIN  - path to the cage compositor
#   BRAVE_BIN - path to the brave browser
#   BWRAP_BIN - path to bubblewrap

set -euo pipefail

CAGE_BIN="${CAGE_BIN:-$(command -v cage || true)}"
BRAVE_BIN="${BRAVE_BIN:-$(command -v brave || true)}"
BWRAP_BIN="${BWRAP_BIN:-$(command -v bwrap || true)}"

if [[ -z "$CAGE_BIN" || -z "$BRAVE_BIN" || -z "$BWRAP_BIN" ]]; then
    echo "Error: cage, brave or bwrap not found on PATH." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Inner phase: runs as the cage client, with WAYLAND_DISPLAY set by cage.
# Wraps Brave in a bubblewrap sandbox.
# ---------------------------------------------------------------------------
if [[ "${EMERGENCY_GUI_INNER:-}" == "1" ]]; then
    runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    wayland_socket="$runtime_dir/${WAYLAND_DISPLAY:-wayland-0}"

    # The sandbox sees: nix store, resolver, TLS certs, fonts, GPU and the
    # Wayland socket. /home is an empty tmpfs; everything Brave writes goes
    # to tmpfs and evaporates when the kiosk exits.
    exec "$BWRAP_BIN" \
        --unshare-all \
        --share-net \
        --die-with-parent \
        --new-session \
        --proc /proc \
        --dev /dev \
        --dev-bind-try /dev/dri /dev/dri \
        --ro-bind-try /sys /sys \
        --ro-bind /nix/store /nix/store \
        --ro-bind-try /run/opengl-driver /run/opengl-driver \
        --ro-bind-try /run/current-system /run/current-system \
        --ro-bind-try /etc/resolv.conf /etc/resolv.conf \
        --ro-bind-try /etc/hosts /etc/hosts \
        --ro-bind-try /etc/ssl /etc/ssl \
        --ro-bind-try /etc/static /etc/static \
        --ro-bind-try /etc/fonts /etc/fonts \
        --ro-bind-try /etc/machine-id /etc/machine-id \
        --tmpfs /tmp \
        --tmpfs /home \
        --dir /home/emergency \
        --tmpfs "$runtime_dir" \
        --ro-bind "$wayland_socket" "$wayland_socket" \
        --setenv HOME /home/emergency \
        --setenv XDG_RUNTIME_DIR "$runtime_dir" \
        --setenv WAYLAND_DISPLAY "${WAYLAND_DISPLAY:-wayland-0}" \
        -- \
        "$BRAVE_BIN" \
        --incognito \
        --ozone-platform=wayland \
        --start-maximized \
        --no-first-run \
        --no-default-browser-check \
        --disable-crash-reporter \
        "$@"
fi

# ---------------------------------------------------------------------------
# Outer phase: sanity checks, then start the cage kiosk.
# ---------------------------------------------------------------------------
if [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
    echo "Error: a graphical session is already running." >&2
    exit 1
fi

echo "🚨 Starting emergency GUI (Brave in a private Wayland kiosk)..."
echo "   • Incognito, profile on tmpfs: nothing is written to disk/ZFS"
echo "   • Sandboxed with bubblewrap: your files are not visible to it"
echo "   Close the browser to return to the console."

exec env EMERGENCY_GUI_INNER=1 \
    CAGE_BIN="$CAGE_BIN" BRAVE_BIN="$BRAVE_BIN" BWRAP_BIN="$BWRAP_BIN" \
    "$CAGE_BIN" -- bash "${BASH_SOURCE[0]}" "$@"
