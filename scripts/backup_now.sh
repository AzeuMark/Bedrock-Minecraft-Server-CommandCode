#!/bin/bash
#
# backup_now.sh — Create a manual backup of the world to Google Drive.
# Stops server if running, compresses worlds, uploads to Drive, restarts.
# Deletes local tarball after successful upload.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if ! is_gdrive_connected; then
  echo "  Google Drive is not connected."
  echo "  Use BACKUP WORLD menu option to set it up."
  exit 1
fi

if [[ ! -d "$SERVER_DIR/worlds" ]]; then
  echo "  No worlds directory found at $SERVER_DIR/worlds."
  echo "  Nothing to backup."
  exit 1
fi

echo ""
read -r -p "  Add an optional note (leave blank to skip): " note
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
    echo "  Stopping server for backup..."
    systemctl stop "$SERVICE_NAME"
    sleep 2
  fi

  echo "  Compressing world..."
  mkdir -p "$BACKUPS_DIR"
  cd "$SERVER_DIR"
  tar -czf "$backup_local_path" "worlds" 2>/dev/null

  if [[ $? -ne 0 ]]; then
    echo "  ✗ Failed to compress world."
    log_error "Backup compression failed."
    if $was_running; then
      state_set_on
      systemctl start "$SERVICE_NAME"
    fi
    return 1
  fi

  echo "  Uploading to Google Drive..."

  local upload_ok=false
  local retries=0
  while [[ $retries -lt 3 ]]; do
    if rclone copy "$backup_local_path" "${GDRIVE_BACKUPS_PATH}/" 2>/dev/null; then
      upload_ok=true
      break
    fi
    retries=$((retries + 1))
    if [[ $retries -lt 3 ]]; then
      echo "  Upload failed, retrying ($retries/3)..."
      sleep 2
    fi
  done

  # Also delete the temp file in backups/ dir after upload attempt
  rm -f "$backup_local_path"

  if $upload_ok; then
    rm -f "$backup_local_path"
    echo ""
    echo "  ✓ Backup complete!"
    echo "    $backup_name"
    log_info "Backup created and uploaded: $backup_name"
  else
    echo ""
    echo "  ✗ Upload to Google Drive FAILED after 3 attempts."
    echo "  Local backup saved at: $backup_local_path"
    echo "  Check your internet and auth, then re-run backup."
    log_error "Backup upload failed, kept local copy"
  fi

  if $was_running; then
    echo "  Restarting server..."
    state_set_on
    systemctl start "$SERVICE_NAME"
    sleep 2
  fi
}

do_backup
