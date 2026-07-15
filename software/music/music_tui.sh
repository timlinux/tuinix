#!/usr/bin/env bash

# Music Generator TUI using Gum
# A beautiful terminal interface for the elevator music generator

set -e

# Colors and styling
HEADER_COLOR="#FF6B9D"
ACCENT_COLOR="#4ECDC4" 
SUCCESS_COLOR="#95E1D3"
WARNING_COLOR="#F38BA8"

# Configuration
DEFAULT_DURATION=60
DEFAULT_FILENAME="elevator_music.wav"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Global variables for continuous mode
CONTINUOUS_PID=""
CURRENT_FILE=""

cleanup() {
    if [[ -n "$CONTINUOUS_PID" ]]; then
        kill -TERM "$CONTINUOUS_PID" 2>/dev/null || true
        wait "$CONTINUOUS_PID" 2>/dev/null || true
    fi
    if [[ -n "$CURRENT_FILE" && -f "$CURRENT_FILE" ]]; then
        rm -f "$CURRENT_FILE" 2>/dev/null || true
    fi
}

trap cleanup EXIT

show_banner() {
    gum style \
        --foreground="$HEADER_COLOR" \
        --border-foreground="$ACCENT_COLOR" \
        --border="rounded" \
        --align="center" \
        --width=60 \
        --margin="1 2" \
        --padding="1 2" \
        "🎵 Elevator Music Generator 🎵" \
        "" \
        "Algorithmic music that responds to your system"
}

show_menu() {
    gum choose \
        --header="Select mode:" \
        --header.foreground="$ACCENT_COLOR" \
        --selected.foreground="$SUCCESS_COLOR" \
        --cursor.foreground="$ACCENT_COLOR" \
        "🎼 Generate Single Track" \
        "🔄 Continuous Mode" \
        "❌ Exit"
}

get_filename() {
    local default="$1"
    gum input \
        --placeholder="$default" \
        --prompt="📁 Filename: " \
        --prompt.foreground="$ACCENT_COLOR" \
        --value="$default"
}

get_duration() {
    local default="$1"
    gum input \
        --placeholder="$default" \
        --prompt="⏱️  Duration (seconds): " \
        --prompt.foreground="$ACCENT_COLOR" \
        --value="$default"
}

select_style() {
    gum choose \
        --header="🎨 Select musical style:" \
        --header.foreground="$ACCENT_COLOR" \
        --selected.foreground="$SUCCESS_COLOR" \
        --cursor.foreground="$ACCENT_COLOR" \
        "🌅 Ambient (Pentatonic, gentle)" \
        "🎹 Classic (Major scales, traditional)" \
        "🎭 Jazzy (Complex harmonies, rich)" \
        "🌊 Minimal (Simple, spacious)" \
        "🌟 Dynamic (System-responsive)" \
        "🎲 Random (Surprise me!)"
}

get_style_params() {
    local style="$1"
    local complexity_override=""
    local scale_override=""
    local layer_override=""
    
    case "$style" in
        "🌅 Ambient (Pentatonic, gentle)")
            complexity_override="0.2"
            scale_override="pentatonic"
            layer_override="0.8"
            ;;
        "🎹 Classic (Major scales, traditional)")
            complexity_override="0.5"
            scale_override="major"
            layer_override="0.6"
            ;;
        "🎭 Jazzy (Complex harmonies, rich)")
            complexity_override="0.9"
            scale_override="jazz"
            layer_override="0.9"
            ;;
        "🌊 Minimal (Simple, spacious)")
            complexity_override="0.1"
            scale_override="pentatonic"
            layer_override="0.3"
            ;;
        "🌟 Dynamic (System-responsive)")
            complexity_override=""
            scale_override=""
            layer_override=""
            ;;
        "🎲 Random (Surprise me!)")
            complexity_override="random"
            scale_override="random"
            layer_override="random"
            ;;
    esac
    
    echo "$complexity_override|$scale_override|$layer_override"
}

confirm_settings() {
    local filename="$1"
    local duration="$2"
    local style="$3"
    
    gum style \
        --foreground="$ACCENT_COLOR" \
        --border-foreground="$SUCCESS_COLOR" \
        --border="rounded" \
        --margin="1 0" \
        --padding="1 2" \
        "📋 Generation Settings:" \
        "" \
        "📁 File: $filename" \
        "⏱️  Duration: ${duration}s" \
        "🎨 Style: $style" \
        ""
    
    gum confirm \
        --affirmative="✅ Generate" \
        --negative="❌ Cancel" \
        --selected.foreground="$SUCCESS_COLOR" \
        "Proceed with generation?"
}

show_progress() {
    local duration="$1"
    local filename="$2"
    
    gum style \
        --foreground="$SUCCESS_COLOR" \
        "🎵 Generating $duration seconds of music..."
    
    # Show a progress spinner while generating
    gum spin --spinner.foreground="$ACCENT_COLOR" \
        --title="Creating your elevator music..." \
        --title.foreground="$ACCENT_COLOR" -- \
        sleep 2  # Placeholder for actual generation time
}

generate_music() {
    local filename="$1"
    local duration="$2"
    local style_params="$3"
    
    IFS='|' read -r complexity scale_override layer_override <<< "$style_params"
    
    # Build command arguments
    local args=()
    args+=(--duration "$duration")
    args+=(--output "$filename")
    
    # Add style overrides if specified
    if [[ -n "$complexity" ]]; then
        args+=(--complexity-override "$complexity")
    fi
    if [[ -n "$scale_override" ]]; then
        args+=(--scale-override "$scale_override")
    fi
    if [[ -n "$layer_override" ]]; then
        args+=(--layer-override "$layer_override")
    fi
    
    # Generate the music
    gum spin --spinner.foreground="$ACCENT_COLOR" \
        --title="🎼 Generating music (${duration}s)..." \
        --title.foreground="$ACCENT_COLOR" -- \
        "$PYTHON_CMD" "$MUSIC_SCRIPT" "${args[@]}"
    
    if [[ -f "$filename" ]]; then
        gum style \
            --foreground="$SUCCESS_COLOR" \
            --border-foreground="$SUCCESS_COLOR" \
            --border="rounded" \
            --margin="1 0" \
            --padding="1 2" \
            "✅ Music generated successfully!" \
            "" \
            "📁 File: $filename" \
            "💾 Size: $(du -h "$filename" | cut -f1)"
        
        # Ask if user wants to play it
        if gum confirm \
            --affirmative="🔊 Play" \
            --negative="⏭️  Skip" \
            --selected.foreground="$ACCENT_COLOR" \
            "Play the generated music?"; then
            
            gum style --foreground="$ACCENT_COLOR" "🎵 Playing $filename..."
            ffplay -nodisp -autoexit "$filename" 2>/dev/null || {
                gum style --foreground="$WARNING_COLOR" "⚠️  Could not play audio file"
            }
        fi
    else
        gum style \
            --foreground="$WARNING_COLOR" \
            --border-foreground="$WARNING_COLOR" \
            --border="rounded" \
            --margin="1 0" \
            --padding="1 2" \
            "❌ Generation failed!" \
            "" \
            "Please check the error messages above."
    fi
}

continuous_mode() {
    gum style \
        --foreground="$HEADER_COLOR" \
        --border-foreground="$ACCENT_COLOR" \
        --border="rounded" \
        --align="center" \
        --margin="1 0" \
        --padding="1 2" \
        "🔄 Continuous Mode" \
        "" \
        "Music will generate and play continuously" \
        "Press Ctrl+C or choose Stop to exit"
    
    # Get segment duration
    local segment_duration
    segment_duration=$(gum input \
        --placeholder="15" \
        --prompt="🎵 Segment duration (seconds): " \
        --prompt.foreground="$ACCENT_COLOR" \
        --value="15")
    
    # Get style
    local style
    style=$(select_style)
    local style_params
    style_params=$(get_style_params "$style")
    
    gum style --foreground="$SUCCESS_COLOR" "🎵 Starting continuous generation..."
    gum style --foreground="$ACCENT_COLOR" "⏹️  Press Ctrl+C to stop"
    
    local segment_count=1
    
    while true; do
        CURRENT_FILE="/tmp/elevator_segment_${segment_count}.wav"
        
        gum style --foreground="$ACCENT_COLOR" "🎼 Generating segment $segment_count..."
        
        # Generate segment in background
        {
            IFS='|' read -r complexity scale_override layer_override <<< "$style_params"
            local args=()
            args+=(--duration "$segment_duration")
            args+=(--output "$CURRENT_FILE")
            
            if [[ -n "$complexity" && "$complexity" != "random" ]]; then
                args+=(--complexity-override "$complexity")
            fi
            if [[ -n "$scale_override" && "$scale_override" != "random" ]]; then
                args+=(--scale-override "$scale_override")
            fi
            if [[ -n "$layer_override" && "$layer_override" != "random" ]]; then
                args+=(--layer-override "$layer_override")
            fi
            
            "$PYTHON_CMD" "$MUSIC_SCRIPT" "${args[@]}" 2>/dev/null
        } &
        
        local gen_pid=$!
        
        # Wait for generation to complete
        wait $gen_pid
        
        if [[ -f "$CURRENT_FILE" ]]; then
            gum style --foreground="$SUCCESS_COLOR" "🔊 Playing segment $segment_count..."
            
            # Play the segment
            ffplay -nodisp -autoexit "$CURRENT_FILE" 2>/dev/null &
            CONTINUOUS_PID=$!
            
            # Wait for playback to finish
            wait $CONTINUOUS_PID 2>/dev/null || break
            
            # Clean up the file
            rm -f "$CURRENT_FILE" 2>/dev/null
            CURRENT_FILE=""
        else
            gum style --foreground="$WARNING_COLOR" "⚠️  Failed to generate segment $segment_count"
            break
        fi
        
        ((segment_count++))
        
        # Brief pause between segments
        sleep 0.5
    done
    
    gum style --foreground="$SUCCESS_COLOR" "🎵 Continuous mode stopped."
}

main() {
    clear
    show_banner
    
    while true; do
        local mode
        mode=$(show_menu)
        
        case "$mode" in
            "🎼 Generate Single Track")
                gum style --foreground="$ACCENT_COLOR" "🎼 Single Track Generation"
                
                local filename duration style style_params
                filename=$(get_filename "$DEFAULT_FILENAME")
                duration=$(get_duration "$DEFAULT_DURATION")
                style=$(select_style)
                style_params=$(get_style_params "$style")
                
                if [[ -z "$filename" ]]; then
                    filename="$DEFAULT_FILENAME"
                fi
                
                if [[ -z "$duration" ]]; then
                    duration="$DEFAULT_DURATION"
                fi
                
                if confirm_settings "$filename" "$duration" "$style"; then
                    generate_music "$filename" "$duration" "$style_params"
                fi
                ;;
                
            "🔄 Continuous Mode")
                continuous_mode
                ;;
                
            "❌ Exit")
                gum style --foreground="$SUCCESS_COLOR" "👋 Goodbye! Thanks for using the Music Generator!"
                exit 0
                ;;
        esac
        
        echo
        gum style --foreground="$ACCENT_COLOR" "Press any key to return to main menu..."
        read -n 1 -s
        clear
        show_banner
    done
}

# Determine Python script location
if [[ -n "$ELEVATOR_MUSIC_SCRIPT" && -n "$ELEVATOR_MUSIC_PYTHON" ]]; then
    # Running from nix
    PYTHON_CMD="$ELEVATOR_MUSIC_PYTHON"
    MUSIC_SCRIPT="$ELEVATOR_MUSIC_SCRIPT"
elif [[ -f "$SCRIPT_DIR/enhanced_elevator_music.py" ]]; then
    # Running from source directory
    PYTHON_CMD="python"
    MUSIC_SCRIPT="$SCRIPT_DIR/enhanced_elevator_music.py"
else
    gum style \
        --foreground="$WARNING_COLOR" \
        --border-foreground="$WARNING_COLOR" \
        --border="rounded" \
        --margin="1 0" \
        --padding="1 2" \
        "❌ Error: enhanced_elevator_music.py not found" \
        "" \
        "Please run from the music generator directory."
    exit 1
fi

main "$@"