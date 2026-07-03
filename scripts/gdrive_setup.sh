#!/bin/bash
#
# gdrive_setup.sh — Configure rclone Google Drive remote.
# Can be run standalone or called from the backup menu.
# You provide the config_token from running:
#   rclone authorize "drive"
# on a machine with a browser.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REMOTE_NAME="gdrive"

setup_gdrive() {
  # Check if already configured
  if is_gdrive_connected; then
    if ! yesno "Google Drive remote '$REMOTE_NAME' is already configured.

Would you like to reconfigure?"; then
      return
    fi
    rclone config delete "$REMOTE_NAME" 2>/dev/null || true
  fi

  whiptail --title "$(menu_title)" --msgbox "\
Google Drive Setup

To connect Google Drive for backups, you need a config_token.

Step 1: On your Windows/Mac PC, open a terminal and run:

   rclone authorize \"drive\"

Step 2: A browser will open asking you to log into Google and
grant permissions.

Step 3: After you accept, the terminal will show a long JSON
token. Copy the entire thing (starts with {\"access_token\"...).

Step 4: Paste it on the next screen.

Do NOT close the terminal on your PC until you finish here." 18 65

  local token
  token=$(passwordbox "Paste your config_token here:")

  if [[ -z "$token" ]]; then
    msgbox "No token provided. Setup cancelled."
    return
  fi

  infobox "Configuring rclone..."

  rclone config create "$REMOTE_NAME" drive \
    --quiet \
    --non-interactive \
    --all \
    config_token="$token" 2>/dev/null

  if is_gdrive_connected; then
    # Verify by creating the backups folder
    rclone mkdir "${GDRIVE_BACKUPS_PATH}" 2>/dev/null
    msgbox "✓ Google Drive connected successfully!

Backups will be stored in:
${GDRIVE_BACKUPS_PATH}/"
    log_info "Google Drive configured successfully."
  else
    msgbox "ERROR: Configuration failed.

Check your token and try again.
Make sure you copied the entire JSON token."
    log_error "Google Drive configuration failed."
  fi
}

setup_gdrive
