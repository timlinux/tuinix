#!/usr/bin/env bash
# shellcheck disable=SC2034  # app arrays are consumed via namerefs (local -n)

# tuinix System Menu — a gum-powered launcher that makes the installed
# TUI applications discoverable. Drill down through categories to find
# and launch the app you want; only apps that are actually installed
# are shown, so the menu adapts to the collections you selected at
# install time.

set -euo pipefail

# Colors and styling (matches the tuinix installer palette)
HEADER_COLOR="#FF6B9D"
ACCENT_COLOR="#4ECDC4"
WARNING_COLOR="#F38BA8"

if ! command -v gum >/dev/null; then
    echo "Error: gum not found." >&2
    exit 1
fi

style_info() { gum style --foreground="$ACCENT_COLOR" "$@"; }
style_warn() { gum style --foreground="$WARNING_COLOR" "$@"; }

show_banner() {
    gum style \
        --foreground="$HEADER_COLOR" \
        --border-foreground="$ACCENT_COLOR" \
        --border="rounded" \
        --align="center" \
        --width=64 \
        --margin="1 2" \
        --padding="1 2" \
        "🖥️  tuinix System Menu 🖥️" \
        "" \
        "Discover and launch your terminal apps" \
        "" \
        "Made with 💗 by Kartoza"
}

# ---------------------------------------------------------------------------
# App catalog
#
# Each entry: "command|label — short description"
# Only entries whose command exists on PATH are offered.
# ---------------------------------------------------------------------------

FILES_APPS=(
    "yazi|yazi — blazing fast file manager"
    "lf|lf — minimalist file manager"
    "ncdu|ncdu — disk usage explorer"
    "duf|duf — disk free, prettified"
)

MONITOR_APPS=(
    "btop|btop — resource monitor"
    "bottom|bottom — graphical process monitor (btm)"
    "htop|htop — interactive process viewer"
    "bandwhich|bandwhich — bandwidth by process (needs sudo)"
)

EDITOR_APPS=(
    "nvim|neovim — hyperextensible vim"
    "hx|helix — modal editor with LSP built in"
    "vim|vim — the classic editor"
)

NETWORK_APPS=(
    "impala|impala — WiFi management TUI"
    "bluetui|bluetui — Bluetooth management TUI"
    "nmtui|nmtui — NetworkManager text UI"
    "w3m|w3m — text-mode web browser"
    "lynx|lynx — the original text web browser"
    "mtr|mtr — traceroute + ping combined"
)

COMMS_APPS=(
    "nchat|nchat — Telegram and WhatsApp"
    "iamb|iamb — Matrix client"
    "scli|scli — Signal client"
    "aerc|aerc — email client"
)

ORGANIZER_APPS=(
    "khal|khal — calendar"
    "khard|khard — contacts"
    "todoman|todoman — todo lists (todo)"
    "task|taskwarrior — task management"
)

DEV_APPS=(
    "lazygit|lazygit — git porcelain TUI"
    "zellij|zellij — terminal workspace / multiplexer"
    "tmux|tmux — terminal multiplexer"
    "glow|glow — render markdown in the terminal"
)

GAMES_APPS=(
    "angband|angband — Tolkien-themed dungeon crawler"
    "crawl|crawl — Dungeon Crawl Stone Soup"
    "cataclysm-tiles|cataclysm-dda — survival roguelike"
    "nsnake|nsnake — classic snake"
    "ninvaders|ninvaders — space invaders"
    "vitetris|vitetris — tetris (tetris)"
    "nudoku|nudoku — sudoku"
    "bastet|bastet — evil tetris"
    "greed|greed — number-eating puzzle"
    "moon-buggy|moon-buggy — drive on the moon"
    "ttysolitaire|tty-solitaire — klondike solitaire"
    "frotz|frotz — play Zork & interactive fiction"
    "advent|open-adventure — Colossal Cave Adventure"
)

MUSIC_APPS=(
    "wiremix|wiremix — PipeWire mixer (default sound app)"
    "tuinix-music-menu|Music studio — generators, MIDI, live coding"
    "tuinix-elevator-tui|Elevator music TUI — continuous generator"
    "alsamixer|alsamixer — audio mixer"
)

PENTEST_APPS=(
    "nmap|nmap — network scanner"
    "termshark|termshark — packet capture TUI"
    "msfconsole|metasploit — exploitation framework"
    "sqlmap|sqlmap — SQL injection testing"
    "aircrack-ng|aircrack-ng — WiFi security auditing"
    "hashcat|hashcat — password recovery"
)

UTILITY_APPS=(
    "brightnessctl|brightness — adjust screen backlight"
    "wiremix|wiremix — PipeWire mixer"
    "bluetui|bluetui — Bluetooth management"
)

EMERGENCY_APPS=(
    "tuinix-emergency-gui|Emergency GUI — Brave browser in a Wayland kiosk"
)

# Category catalog: "emoji label|array name"
CATEGORIES=(
    "📁 File management|FILES_APPS"
    "📊 System monitoring|MONITOR_APPS"
    "✏️  Editors|EDITOR_APPS"
    "🌐 Network & web|NETWORK_APPS"
    "💬 Communication|COMMS_APPS"
    "📅 Calendar & tasks|ORGANIZER_APPS"
    "🛠  Development|DEV_APPS"
    "🎮 Games|GAMES_APPS"
    "🎵 Sound and Music|MUSIC_APPS"
    "🔧 Utilities|UTILITY_APPS"
    "🔐 Pentest|PENTEST_APPS"
    "🚨 Emergency|EMERGENCY_APPS"
)

# List installed entries of an app array (by name), one label per line.
installed_entries() {
    local -n apps=$1
    local entry cmd
    for entry in "${apps[@]}"; do
        cmd="${entry%%|*}"
        if command -v "$cmd" >/dev/null; then
            printf '%s\n' "${entry#*|}"
        fi
    done
}

# Find the command for a selected label in an app array.
command_for_label() {
    local -n apps=$1
    local label=$2 entry
    for entry in "${apps[@]}"; do
        if [[ "${entry#*|}" == "$label" ]]; then
            printf '%s\n' "${entry%%|*}"
            return 0
        fi
    done
    return 1
}

category_menu() {
    local array_name=$1 title=$2
    local entries label cmd

    entries=$(installed_entries "$array_name")
    if [[ -z "$entries" ]]; then
        style_warn "No apps from this category are installed."
        return 0
    fi

    label=$(printf '%s\n↩️  Back\n' "$entries" | gum choose \
        --header="$title" \
        --header.foreground="$ACCENT_COLOR" \
        --cursor.foreground="$ACCENT_COLOR" \
        --height=18) || return 0
    [[ "$label" == "↩️  Back" || -z "$label" ]] && return 0

    cmd=$(command_for_label "$array_name" "$label") || return 0
    clear
    case "$cmd" in
        brightnessctl) brightness_menu ;;
        *)
            style_info "🚀 Launching $cmd... (exit the app to return to the menu)"
            "$cmd" || style_warn "⚠️  $cmd exited with an error"
            ;;
    esac
}

# brightnessctl is not interactive, so offer a gum-driven percentage picker.
brightness_menu() {
    local current pct
    current=$(brightnessctl --machine-readable 2>/dev/null | cut -d, -f4 || true)
    pct=$(gum choose \
        --header="🔆 Screen brightness${current:+ (currently $current)}:" \
        --header.foreground="$ACCENT_COLOR" \
        --cursor.foreground="$ACCENT_COLOR" \
        "100%" "80%" "60%" "40%" "20%" "10%" "5%" "↩️  Back") || return 0
    [[ "$pct" == "↩️  Back" || -z "$pct" ]] && return 0
    brightnessctl set "$pct" >/dev/null \
        || style_warn "⚠️  Could not set brightness (no backlight device?)"
}

main() {
    while true; do
        clear
        show_banner

        # Only offer categories that have at least one installed app
        local available=() cat label array_name
        for cat in "${CATEGORIES[@]}"; do
            array_name="${cat#*|}"
            if [[ -n "$(installed_entries "$array_name")" ]]; then
                available+=("${cat%%|*}")
            fi
        done

        label=$(printf '%s\n' "${available[@]}" "❌ Exit" | gum choose \
            --header="Pick a category:" \
            --header.foreground="$ACCENT_COLOR" \
            --cursor.foreground="$ACCENT_COLOR" \
            --height=16) || exit 0
        [[ "$label" == "❌ Exit" || -z "$label" ]] && exit 0

        for cat in "${CATEGORIES[@]}"; do
            if [[ "${cat%%|*}" == "$label" ]]; then
                category_menu "${cat#*|}" "$label"
                break
            fi
        done
    done
}

main "$@"
