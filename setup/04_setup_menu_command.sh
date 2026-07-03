#!/bin/bash
#
# 04_setup_menu_command.sh
# Installs the `mc` and `minecraft` commands system-wide by symlinking
# to the mc-menu.sh script.
# Run as root or with sudo.

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)."
  exit 1
fi

MENU_SCRIPT="/opt/mcbedrock/scripts/mc-menu.sh"
LINK1="/usr/local/bin/mc"
LINK2="/usr/local/bin/minecraft"

echo "=== Installing 'mc' and 'minecraft' commands ==="

if [[ ! -f "$MENU_SCRIPT" ]]; then
  echo "ERROR: $MENU_SCRIPT not found. Run setup scripts in order."
  exit 1
fi

chmod +x "$MENU_SCRIPT"

ln -sf "$MENU_SCRIPT" "$LINK1"
ln -sf "$MENU_SCRIPT" "$LINK2"

echo "Created symlinks:"
echo "  $LINK1 -> $MENU_SCRIPT"
echo "  $LINK2 -> $MENU_SCRIPT"

echo ""
echo "=== Done ==="
echo "You can now type 'mc' or 'minecraft' anywhere to open the server manager."
