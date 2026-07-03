#!/bin/bash
#
# 05_setup_gdrive.sh
# Configures rclone with a Google Drive remote for backups.
# You provide the config_token obtained by running:
#   rclone authorize "drive"
# on your Windows/Mac PC (which has a browser).
# Run as root or with sudo.

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)."
  exit 1
fi

REMOTE_NAME="gdrive"

# Check if already configured
if rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:"; then
  echo "Google Drive remote '$REMOTE_NAME' already configured."
  echo ""
  read -r -p "Reconfigure? (y/N): " reconf
  if [[ "$reconf" != "y" && "$reconf" != "Y" ]]; then
    echo "Skipping."
    exit 0
  fi
  rclone config delete "$REMOTE_NAME" 2>/dev/null || true
fi

echo ""
echo "=== Google Drive Setup (rclone) ==="
echo ""
echo "To get your config_token, run this on your Windows/Mac PC (with a browser):"
echo ""
echo "  rclone authorize \"drive\""
echo ""
echo "This will open a browser window asking you to log into Google and grant"
echo "permissions. After you accept, the terminal will show a JSON token."
echo ""
echo "Paste that JSON token below (looks like: {\"access_token\":\"ya29...\"})"
echo ""

read -r -p "config_token: " CONFIG_TOKEN

if [[ -z "$CONFIG_TOKEN" ]]; then
  echo "ERROR: No token provided. Aborting."
  exit 1
fi

# Create rclone config non-interactively
rclone config create "$REMOTE_NAME" drive \
  --quiet \
  --non-interactive \
  --all \
  config_token="$CONFIG_TOKEN"

echo ""
if rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:"; then
  echo "✓ Google Drive remote '$REMOTE_NAME' configured successfully."
  echo "Backups will be stored in: ${REMOTE_NAME}:Minecraft/Backups/"

  # Create the backups folder on Drive to verify connectivity
  echo "Testing connection..."
  rclone mkdir "${REMOTE_NAME}:Minecraft/Backups" 2>/dev/null
  echo "✓ Connection verified."
else
  echo "ERROR: Configuration failed. Check your token and try again."
  exit 1
fi
