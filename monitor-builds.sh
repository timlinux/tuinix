#!/usr/bin/env bash
# Build Monitor Script for tuinix
# Monitors x86_64 and aarch64 builds and displays progress in a table

set -e

# Version comes from the VERSION file (single point of truth)
TUINIX_VERSION="v$(tr -d '[:space:]' <"$(dirname "${BASH_SOURCE[0]}")/VERSION" 2>/dev/null || echo dev)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Build result symlinks to check
BUILDS=(
    "x86_64:result-x86_64"
    "aarch64:result-aarch64"
)

print_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}              ${GREEN}tuinix $TUINIX_VERSION Build Monitor${NC}                            ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Last updated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

check_build_status() {
    local name=$1
    local link=$2
    local status=""
    local size=""
    local path=""

    if [[ -L "$link" ]]; then
        # Symlink exists - build completed
        path=$(readlink -f "$link")
        if [[ -f "$path" ]]; then
            size=$(du -h "$path" 2>/dev/null | cut -f1)
            status="${GREEN}✅ Complete${NC}"
        elif [[ -d "$path" ]]; then
            # For directories (like ISO result), find the actual file
            iso_file=$(find "$path" -name "*.iso" 2>/dev/null | head -1)
            if [[ -n "$iso_file" ]]; then
                size=$(du -h "$iso_file" 2>/dev/null | cut -f1)
                status="${GREEN}✅ Complete${NC}"
            else
                status="${GREEN}✅ Complete${NC}"
                size="(dir)"
            fi
        else
            status="${GREEN}✅ Complete${NC}"
            size="N/A"
        fi
    else
        # Check if build process is running
        if pgrep -f "nix build.*${link}" > /dev/null 2>&1; then
            status="${YELLOW}🔄 Building${NC}"
            size="-"
        else
            status="${RED}⏳ Not started${NC}"
            size="-"
        fi
    fi

    echo -e "| $name | $status | $size |"
}

print_table() {
    echo "┌──────────────┬────────────────┬──────────┐"
    echo "│ Build        │ Status         │ Size     │"
    echo "├──────────────┼────────────────┼──────────┤"

    for build in "${BUILDS[@]}"; do
        name="${build%%:*}"
        link="${build##*:}"

        # Get status
        if [[ -L "$link" ]]; then
            path=$(readlink -f "$link")
            if [[ -d "$path" ]]; then
                iso_file=$(find "$path" -name "*.iso" 2>/dev/null | head -1)
                if [[ -n "$iso_file" ]]; then
                    size=$(du -h "$iso_file" 2>/dev/null | cut -f1)
                else
                    size="(dir)"
                fi
            elif [[ -f "$path" ]]; then
                size=$(du -h "$path" 2>/dev/null | cut -f1)
            else
                size="N/A"
            fi
            printf "│ %-12s │ ${GREEN}✅ Complete${NC}    │ %-8s │\n" "$name" "$size"
        elif pgrep -f "nix build.*out-link.*${link}" > /dev/null 2>&1; then
            printf "│ %-12s │ ${YELLOW}🔄 Building${NC}    │ %-8s │\n" "$name" "-"
        else
            printf "│ %-12s │ ${RED}⏳ Pending${NC}     │ %-8s │\n" "$name" "-"
        fi
    done

    echo "└──────────────┴────────────────┴──────────┘"
}

check_nix_processes() {
    echo ""
    echo -e "${BLUE}Active Nix Build Processes:${NC}"
    echo "─────────────────────────────────────────────────────────────────"

    # Check for nix-build or nix build processes
    local procs
    procs=$(ps aux | grep -E "nix.*(build|daemon)" | grep -v grep | head -5)
    if [[ -n "$procs" ]]; then
        echo "$procs" | while read line; do
            echo "  $(echo "$line" | awk '{print $2, $11, $12, $13}' | head -c 70)"
        done
    else
        echo "  No active nix build processes found"
    fi
}

show_disk_usage() {
    echo ""
    echo -e "${BLUE}Disk Usage:${NC}"
    echo "─────────────────────────────────────────────────────────────────"
    df -h /nix/store 2>/dev/null | tail -1 | awk '{printf "  /nix/store: %s used of %s (%s)\n", $3, $2, $5}'
}

main() {
    local interval=${1:-300}  # Default 5 minutes (300 seconds)

    while true; do
        print_header
        print_table
        check_nix_processes
        show_disk_usage

        echo ""
        echo -e "Refreshing every ${interval} seconds. Press Ctrl+C to exit."
        echo -e "Next refresh at: $(date -d "+${interval} seconds" '+%H:%M:%S')"

        sleep "$interval"
    done
}

# Run with optional interval argument (default 300 seconds = 5 minutes)
main "$@"
