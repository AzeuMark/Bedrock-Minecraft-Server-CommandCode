#!/bin/bash
#
# gdrive_setup.sh — Configure rclone Google Drive remote.
# You provide the config_token from running:
#   rclone authorize "drive"
# on a machine with a browser.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REMOTE_NAME="gdrive"

setup_gdrive() {
  if is_gdrive_connected; then
    echo ""
    echo "  Google Drive remote '$REMOTE_NAME' is already configured."
    read -r -p "  Reconfigure? (y/N): " reconf
    if [[ "$reconf" != "y" && "$reconf" != "Y" ]]; then
      echo "  Skipping."
      return
    fi
    rclone config delete "$REMOTE_NAME" 2>/dev/null || true
  fi

  echo ""
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║              GOOGLE DRIVE SETUP                    ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo ""
  echo "  Step 1: On your Windows/Mac PC, open a terminal and run:"
  echo ""
  echo "      rclone authorize \"drive\""
  echo ""
  echo "  Step 2: A browser will open asking you to log into Google"
  echo "  and grant permissions."
  echo ""
  echo "  Step 3: After you accept, the terminal will show a long"
  echo "  JSON token. Copy the entire thing."
  echo ""
  echo "  Step 4: Paste it below."
  echo ""
  echo "  Do NOT close the terminal on your PC until you finish."
  echo ""
  echo "  ───────────────────────────────────────────────────────"
  echo ""

  read -r -p "  config_token: " token

  if [[ -z "$token" ]]; then
    echo ""
    echo "  No token provided. Setup cancelled."
    return
  fi

  echo "  Configuring rclone..."

  rclone config create "$REMOTE_NAME" drive \
    --quiet \
    --non-interactive \
    --all \
    config_token="$token" 2>/dev/null

  if is_gdrive_connected; then
    rclone mkdir "${GDRIVE_BACKUPS_PATH}" 2>/dev/null
    echo ""
    echo "  ✓ Google Drive connected successfully!"
    echo "  Backups will be stored in: ${GDRIVE_BACKUPS_PATH}/"
    log_info "Google Drive configured successfully."
  else
    echo ""
    echo "  ✗ Configuration failed."
    echo "  Check your token and try again."
    echo "  Make sure you copied the entire JSON token."
    log_error "Google Drive configuration failed."
  fi
}

setup_gdrive
