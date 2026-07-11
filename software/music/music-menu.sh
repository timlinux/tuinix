#!/usr/bin/env bash
# shellcheck disable=SC2012  # ls | gum filter is intentional: names are simple

# tuinix Music Menu — a gum-powered launcher for the console-only music
# tools shipped with the tuinix music collection: elevator music
# generators, MIDI composition, rendering (FluidSynth), mastering (sox)
# and terminal live-coding environments.
#
# Adapted from the Kartoza music studio menu; GUI tools are intentionally
# excluded to keep with the TUI theme of tuinix.
#
# Environment (set by the tuinix-music-menu wrapper):
#   MUSIC_PYTHON  - python interpreter with numpy/scipy/psutil/mido
#   MUSIC_SCRIPTS - read-only directory holding the generator .py scripts
#   MUSIC_DIR     - writable output directory (default: ~/Music)
#   SOUNDFONT     - GM soundfont for FluidSynth rendering

set -euo pipefail

# Colors and styling (matches the tuinix installer palette)
HEADER_COLOR="#FF6B9D"
ACCENT_COLOR="#4ECDC4"
SUCCESS_COLOR="#95E1D3"
WARNING_COLOR="#F38BA8"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MUSIC_SCRIPTS="${MUSIC_SCRIPTS:-$SCRIPT_DIR}"
MUSIC_DIR="${MUSIC_DIR:-$HOME/Music}"
PYTHON_CMD="${MUSIC_PYTHON:-$(command -v python || command -v python3 || true)}"

mkdir -p "$MUSIC_DIR"

if [[ -z "$PYTHON_CMD" ]]; then
    echo "Error: no python interpreter found." >&2
    exit 1
fi

if ! command -v gum >/dev/null; then
    echo "Error: gum not found." >&2
    exit 1
fi

style_ok()   { gum style --foreground="$SUCCESS_COLOR" "$@"; }
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
        "🎵 tuinix Music Studio 🎵" \
        "" \
        "Console music tools and generators — output in $MUSIC_DIR" \
        "" \
        "Made with 💗 by Kartoza"
}

pause() {
    echo
    style_info "Press any key to continue..."
    read -n 1 -s -r
}

require_cmd() {
    if ! command -v "$1" >/dev/null; then
        style_warn "⚠️  '$1' is not on PATH."
        return 1
    fi
}

# Run a command with a spinner and surface failures instead of aborting the menu.
run_step() {
    local title="$1"; shift
    if ! gum spin --spinner.foreground="$ACCENT_COLOR" \
        --title="$title" --title.foreground="$ACCENT_COLOR" \
        --show-error -- "$@"; then
        style_warn "❌ Step failed: $title"
        return 1
    fi
}

maybe_play() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    if gum confirm --affirmative="🔊 Play" --negative="⏭️  Skip" \
        --selected.foreground="$ACCENT_COLOR" "Play $file?"; then
        require_cmd ffplay || return 0
        ffplay -nodisp -autoexit "$file" 2>/dev/null || style_warn "⚠️  Playback failed"
    fi
}

# ---------------------------------------------------------------------------
# Python generators
# ---------------------------------------------------------------------------

run_python_script() {
    local script="$1"; shift
    (cd "$MUSIC_DIR" && "$PYTHON_CMD" "$MUSIC_SCRIPTS/$script" "$@")
}

python_scripts_menu() {
    local choice
    choice=$(gum choose \
        --header="🐍 Python generators (output goes to $MUSIC_DIR):" \
        --header.foreground="$ACCENT_COLOR" \
        --cursor.foreground="$ACCENT_COLOR" \
        "🛗 Elevator music — simple (elevator_music_generator.py)" \
        "🎹 Elevator music — enhanced polyphonic (enhanced_elevator_music.py)" \
        "🎼 MIDI composer (generate_midi.py)" \
        "📜 Run any generator with custom args" \
        "↩️  Back")

    case "$choice" in
        "🛗 Elevator"*)
            local duration output
            duration=$(gum input --prompt="⏱️  Duration (s): " --prompt.foreground="$ACCENT_COLOR" --value="60")
            output=$(gum input --prompt="📁 Output file: " --prompt.foreground="$ACCENT_COLOR" --value="elevator_music.wav")
            run_step "🎼 Generating ${duration}s of elevator music..." \
                "$PYTHON_CMD" "$MUSIC_SCRIPTS/elevator_music_generator.py" \
                --duration "$duration" --output "$MUSIC_DIR/$output" || return 0
            style_ok "✅ Wrote $output"
            maybe_play "$MUSIC_DIR/$output"
            ;;
        "🎹 Elevator"*)
            local duration output
            duration=$(gum input --prompt="⏱️  Duration (s): " --prompt.foreground="$ACCENT_COLOR" --value="60")
            output=$(gum input --prompt="📁 Output file: " --prompt.foreground="$ACCENT_COLOR" --value="elevator_enhanced.wav")
            run_step "🎼 Generating ${duration}s of enhanced elevator music..." \
                "$PYTHON_CMD" "$MUSIC_SCRIPTS/enhanced_elevator_music.py" \
                --duration "$duration" --output "$MUSIC_DIR/$output" || return 0
            style_ok "✅ Wrote $output"
            maybe_play "$MUSIC_DIR/$output"
            ;;
        "🎼 MIDI composer"*)
            midi_compose_workflow "midi-only"
            ;;
        "📜 Run any"*)
            local script args
            script=$(cd "$MUSIC_SCRIPTS" && ls -1 -- *.py 2>/dev/null | gum filter \
                --header="Pick a script:" --header.foreground="$ACCENT_COLOR") || return 0
            [[ -n "$script" ]] || return 0
            args=$(gum input --prompt="⚙️  Arguments (blank for --help): " \
                --prompt.foreground="$ACCENT_COLOR" --placeholder="--duration 30 ...")
            if [[ -z "$args" ]]; then
                run_python_script "$script" --help || true
            else
                # user-supplied args are intentionally word-split
                # shellcheck disable=SC2086
                run_python_script "$script" $args || style_warn "❌ Script exited with an error"
            fi
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Creation workflows
# ---------------------------------------------------------------------------

midi_compose_workflow() {
    local mode="${1:-full}"
    local style key minor bars base

    style=$(gum choose --header="🎨 Style:" --header.foreground="$ACCENT_COLOR" \
        "reggae" "ambient" "classical") || return 0
    key=$(gum choose --header="🎼 Key:" --header.foreground="$ACCENT_COLOR" \
        "C" "C#" "D" "D#" "E" "F" "F#" "G" "G#" "A" "A#" "B") || return 0
    minor=""
    if gum confirm --selected.foreground="$ACCENT_COLOR" "Minor key?"; then
        minor="--minor"
    fi
    bars=$(gum input --prompt="📏 Bars: " --prompt.foreground="$ACCENT_COLOR" --value="16")
    base=$(gum input --prompt="📁 Output basename: " --prompt.foreground="$ACCENT_COLOR" --value="song")

    # $minor is an optional flag
    # shellcheck disable=SC2086
    run_step "🎼 Composing ${base}.mid ($style, $key)..." \
        "$PYTHON_CMD" "$MUSIC_SCRIPTS/generate_midi.py" \
        --style "$style" --key "$key" $minor --bars "$bars" \
        -o "$MUSIC_DIR/${base}.mid" || return 0
    style_ok "✅ Wrote ${base}.mid"

    [[ "$mode" == "midi-only" ]] && return 0

    render_midi_file "$MUSIC_DIR/${base}.mid" "$MUSIC_DIR/${base}.wav" || return 0

    require_cmd sox || return 0
    run_step "✨ Mastering (fade + normalize)..." \
        sox "$MUSIC_DIR/${base}.wav" "$MUSIC_DIR/${base}_final.wav" \
        fade 0.5 -0 2 norm -1 || return 0
    style_ok "✅ Finished track: ${base}_final.wav"
    maybe_play "$MUSIC_DIR/${base}_final.wav"
}

render_midi_file() {
    local mid="$1" wav="$2"
    require_cmd fluidsynth || return 1
    if [[ -z "${SOUNDFONT:-}" || ! -f "${SOUNDFONT:-}" ]]; then
        style_warn "⚠️  \$SOUNDFONT is not set or missing."
        return 1
    fi
    run_step "🎻 Rendering $(basename "$mid") with FluidSynth..." \
        fluidsynth -ni "$SOUNDFONT" "$mid" -F "$wav" -r 44100
}

render_existing_midi() {
    local mid
    mid=$(cd "$MUSIC_DIR" && ls -1 -- *.mid 2>/dev/null | gum filter \
        --header="Pick a MIDI file:" --header.foreground="$ACCENT_COLOR") || {
        style_warn "No .mid files in $MUSIC_DIR"; return 0; }
    [[ -n "$mid" ]] || return 0
    render_midi_file "$MUSIC_DIR/$mid" "$MUSIC_DIR/${mid%.mid}.wav" || return 0
    style_ok "✅ Wrote ${mid%.mid}.wav"
    maybe_play "$MUSIC_DIR/${mid%.mid}.wav"
}

play_audio_file() {
    local file
    file=$(cd "$MUSIC_DIR" && ls -1 -- *.wav *.mp3 *.flac *.ogg 2>/dev/null | gum filter \
        --header="🎧 Pick a file to play:" --header.foreground="$ACCENT_COLOR") || {
        style_warn "No audio files in $MUSIC_DIR"; return 0; }
    [[ -n "$file" ]] || return 0
    require_cmd ffplay || return 0
    style_info "🎵 Playing $file (q to stop)..."
    ffplay -nodisp -autoexit "$MUSIC_DIR/$file" 2>/dev/null || style_warn "⚠️  Playback failed"
}

workflows_menu() {
    local choice
    choice=$(gum choose \
        --header="🔄 Creation workflows:" \
        --header.foreground="$ACCENT_COLOR" \
        --cursor.foreground="$ACCENT_COLOR" \
        "🎼 Compose → render → master (MIDI → FluidSynth → sox)" \
        "🎻 Render an existing .mid to WAV" \
        "🛗 Elevator music TUI (interactive, continuous mode)" \
        "🎧 Play an audio file" \
        "↩️  Back")

    case "$choice" in
        "🎼 Compose"*) midi_compose_workflow "full" ;;
        "🎻 Render"*) render_existing_midi ;;
        "🛗 Elevator"*) "${MUSIC_TUI:-$MUSIC_SCRIPTS/music_tui.sh}" || true ;;
        "🎧 Play"*) play_audio_file ;;
    esac
}

# ---------------------------------------------------------------------------
# Console tool launcher
# ---------------------------------------------------------------------------

tools_menu() {
    local choice
    choice=$(gum choose \
        --header="🛠  Launch a console music tool:" \
        --header.foreground="$ACCENT_COLOR" \
        --cursor.foreground="$ACCENT_COLOR" \
        "🔲 Orca — esoteric livecoding sequencer" \
        "🥁 ChucK — strongly-timed audio language (REPL)" \
        "📯 Csound — sound & score language" \
        "🎼 abc2midi — ABC notation to MIDI" \
        "↩️  Back")

    case "$choice" in
        "🔲 Orca"*)
            require_cmd orca || return 0
            style_info "🔲 Starting Orca (Ctrl+Q to quit). Route its MIDI to fluidsynth."
            orca || true ;;
        "🥁 ChucK"*)
            require_cmd chuck || return 0
            style_info "🥁 chuck is on PATH. Example: chuck myprogram.ck"
            local ck
            ck=$(gum input --prompt="⚙️  .ck file to run (blank to skip): " --prompt.foreground="$ACCENT_COLOR")
            [[ -n "$ck" ]] && { chuck "$ck" || style_warn "❌ chuck exited with an error"; } ;;
        "📯 Csound"*)
            require_cmd csound || return 0
            style_info "📯 csound is on PATH. Example: csound mypiece.csd"
            local csd
            csd=$(gum input --prompt="⚙️  .csd file to run (blank to skip): " --prompt.foreground="$ACCENT_COLOR")
            [[ -n "$csd" ]] && { csound -odac "$csd" || style_warn "❌ csound exited with an error"; } ;;
        "🎼 abc2midi"*)
            require_cmd abc2midi || return 0
            local abc
            abc=$(cd "$MUSIC_DIR" && ls -1 -- *.abc 2>/dev/null | gum filter \
                --header="Pick an .abc file:" --header.foreground="$ACCENT_COLOR") || {
                style_warn "No .abc files in $MUSIC_DIR"; return 0; }
            [[ -n "$abc" ]] || return 0
            (cd "$MUSIC_DIR" && abc2midi "$abc") || style_warn "❌ abc2midi exited with an error" ;;
    esac
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

main() {
    clear
    show_banner

    while true; do
        local choice
        choice=$(gum choose \
            --header="What would you like to do?" \
            --header.foreground="$ACCENT_COLOR" \
            --cursor.foreground="$ACCENT_COLOR" \
            "🐍 Python generators" \
            "🔄 Creation workflows" \
            "🛠  Launch a console music tool" \
            "🎧 Play an audio file" \
            "❌ Exit") || exit 0

        case "$choice" in
            "🐍 Python"*) python_scripts_menu ;;
            "🔄 Creation"*) workflows_menu ;;
            "🛠  Launch"*) tools_menu ;;
            "🎧 Play"*) play_audio_file ;;
            "❌ Exit")
                style_ok "👋 Goodbye!"
                exit 0
                ;;
        esac

        pause
        clear
        show_banner
    done
}

main "$@"
