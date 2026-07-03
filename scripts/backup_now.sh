#!/bin/bash
#
# backup_now.sh — Create a manual backup of the world to Google Drive.
# Stops server if running → compresses worlds → uploads to Drive → restarts if was running.
# Deletes local tarball after successful upload. Keeps + warns if upload fails.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if ! is_gdrive_connected; then
  msgbox "Google Drive is not connected.
Use 'Backups → Connect Google Drive' first."
  exit 1
fi

if [[ ! -d "$SERVER_DIR/worlds" ]]; then
  msgbox "No worlds directory found at $SERVER_DIR/worlds. Nothing to backup."
  exit 1
fi

# Ask for optional note
note=$(inputbox "Add an optional note for this backup
(e.g., \"before-update\", leave blank to skip):")

if [[ -n "$note" ]]; then
  note=$(echo "$note" | sed 's/ /-/g; s/[^a-zA-Z0-9_-]//g')
  note="-$note"
fi

timestamp=$(date '+%m-%d-%Y-%I-%M-%S%p')
backup_name="${timestamp}${note}"
backup_local_path="$BACKUPS_DIR/${backup_name}.tar.gz"

do_backup() {
  local was_running=false

  if server_is_running; then
    was_running=true
    infobox "Stopping server to create backup..."
    systemctl stop "$SERVICE_NAME"
    sleep 2
  fi

  infobox "Compressing world... ($backup_name)"

  mkdir -p "$BACKUPS_DIR"
  cd "$SERVER_DIR"
  tar -czf "$backup_local_path" "worlds" 2>/dev/null

  if [[ $? -ne 0 ]]; then
    msgbox "Failed to compress world."
    log_error "Backup compression failed."
    if $was_running; then
      state_set_on
      systemctl start "$SERVICE_NAME"
    fi
    return 1
  fi

  infobox "Uploading to Google Drive..."
  rclone copy "$backup_local_path" "${GDRIVE_BACKUPS_PATH}/" 2>/dev/null

  if [[ $? -eq 0 ]]; then
    rm -f "$backup_local_path"
    log_info "Backup created and uploaded: $backup_name"
    msgbox "✓ Backup complete!

Name: $backup_name"
  else
    log_error "Backup upload failed, kept local copy at $backup_local_path"
    msgbox "WARNING: Upload to Google Drive FAILED.

Local backup saved at:
$backup_local_path

Check your internet connection and auth, then re-run backup."
  fi

  if $was_running; then
    state_set_on
    systemctl start "$SERVICE_NAME"
    sleep 2
  fi
}

do_backup
