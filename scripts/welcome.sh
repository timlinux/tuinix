#!/usr/bin/env bash
# tuinix ISO welcome message - displayed on first login
# This script is deployed to the live ISO and sourced from the root profile.

TUINIX_DIR="/home/tuinix"
LOGO="${TUINIX_DIR}/.github/assets/LOGO.png"

# Show the mascot logo
if command -v chafa &>/dev/null && [ -f "$LOGO" ]; then
  chafa --size=40x20 "$LOGO"
fi

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
    "  sudo scripts/install.sh" \
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
  echo "    sudo scripts/install.sh"
  echo ""
  echo "  You are in: ${TUINIX_DIR}"
  echo "=========================================="
  echo ""
fi
