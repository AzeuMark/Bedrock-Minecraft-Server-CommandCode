#!/bin/bash
#
# backup_now.sh — Manual world backup to Google Drive.
# Uses rclone copy (no compression). Stops server, copies worlds/ directly
# to a dated folder on Drive, then restarts.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if ! is_gdrive_connected; then
  echo "  Google Drive is not connected."
  read -r -p "  Press Enter to return..."
  exit 1
fi

if [[ ! -d "$SERVER_DIR/worlds" ]]; then
  echo "  No worlds directory found at $SERVER_DIR/worlds."
  read -r -p "  Press Enter to return..."
  exit 1
fi

echo ""
read -r -p "  Enter a note for this backup (optional): " note
if [[ -n "$note" ]]; then
  note_clean=$(echo "$note" | tr ' ' '-' | sed 's/[^a-zA-Z0-9_-]//g')
  folder_name="Manual_$(date '+%B-%d-%Y_%H-%M-%S')_${note_clean}"
else
  folder_name="Backup_$(date '+%B-%d-%Y_%H-%M-%S')"
fi

remote_path="${GDRIVE_BACKUPS_PATH}/${folder_name}"

echo ""
echo "  Backing up to: ${remote_path}"
echo ""

local was_running=false
if server_is_running; then
  was_running=true
  echo "  Stopping server..."
  systemctl stop "$SERVICE_NAME"
  sleep 2
fi

echo "  Uploading worlds to Google Drive..."
rclone copy "$SERVER_DIR/worlds" "$remote_path" --progress 2>/dev/null

if [[ $? -eq 0 ]]; then
  echo ""
  echo "  ✓ Backup complete!"
  echo "    → ${remote_path}"
  log_info "Backup created: $folder_name"
else
  echo ""
  echo "  ✗ Upload failed. Check your internet connection and auth."
  echo "  Run: rclone lsd gdrive:  to test connectivity."
  log_error "Backup upload failed"
fi

if $was_running; then
  echo "  Restarting server..."
  state_set_on
  systemctl start "$SERVICE_NAME"
  sleep 2
fi
