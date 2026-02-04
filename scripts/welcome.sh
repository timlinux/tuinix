#!/usr/bin/env bash
# tuinix ISO welcome message - displayed on first login
# This script is deployed to the live ISO and sourced from the root profile.

TUINIX_DIR="/home/tuinix"
LOGO_PATH="${TUINIX_DIR}/assets/LOGO.png"

# Clear screen for clean welcome
clear

# Show mascot logo centered on screen using catimg
show_mascot() {
  if command -v catimg &>/dev/null && [ -f "${LOGO_PATH}" ]; then
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    # Render logo at ~60 catimg width (~30 visible chars)
    local logo_width=60
    local visible_width=$(( logo_width / 2 ))
    local pad=$(( (cols - visible_width) / 2 ))
    if [ "$pad" -lt 0 ]; then
      pad=0
    fi
    # Generate padding string
    local padding
    padding=$(printf '%*s' "$pad" '')
    # Render catimg and prepend padding to each line for centering
    catimg -w "$logo_width" "${LOGO_PATH}" 2>/dev/null | while IFS= read -r line; do
      printf '%s%s\n' "$padding" "$line"
    done
  fi
}

show_mascot

# Show welcome message with gum
if command -v gum &>/dev/null; then
  gum style \
    --border double \
    --border-foreground 208 \
    --padding "1 3" \
    --margin "1 0" \
    --align center \
    --width 60 \
    "Welcome to the tuinix Live Installer" \
    "" \
    "To install tuinix, run:" \
    "" \
    "  sudo installer" \
    "" \
    "You are in: ${TUINIX_DIR}"
else
  echo ""
  echo "=========================================="
  echo "  Welcome to the tuinix Live Installer"
  echo "=========================================="
  echo ""
  echo "  To install tuinix, run:"
  echo ""
  echo "    sudo installer"
  echo ""
  echo "  You are in: ${TUINIX_DIR}"
  echo "=========================================="
  echo ""
fi
