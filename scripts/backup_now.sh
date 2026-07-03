#!/bin/bash
#
# backup_now.sh — Create a manual backup of the world to Google Drive.
# If the server is running: uses save hold/save resume for a clean snapshot.
# If the server is stopped: copies world directly (server.state OFF check).
# After successful upload to Drive, the local tarball is deleted.
# If upload fails, local copy is kept and user is warned.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ──────────────────────────────────────────────
# Check prerequisites
# ──────────────────────────────────────────────
if ! is_gdrive_connected; then
  msgbox "Google Drive is not connected.
Use 'Backups → Connect Google Drive' first."
  exit 1
fi

if [[ ! -d "$SERVER_DIR/worlds" ]]; then
  msgbox "No worlds directory found at $SERVER_DIR/worlds.
Nothing to backup."
  exit 1
fi

# ──────────────────────────────────────────────
# Ask for optional note
# ──────────────────────────────────────────────
note=$(inputbox "Add an optional note for this backup
(e.g., \"before-update\", leave blank to skip):")

# Sanitize note: replace spaces with hyphens, remove special chars
if [[ -n "$note" ]]; then
  note=$(echo "$note" | sed 's/ /-/g; s/[^a-zA-Z0-9_-]//g')
  note="-$note"
fi

# ──────────────────────────────────────────────
# Build backup name
# ──────────────────────────────────────────────
timestamp=$(date '+%m-%d-%Y-%I-%M-%S%p')
backup_name="${timestamp}${note}"
backup_local_path="$BACKUPS_DIR/${backup_name}.tar.gz"

# ──────────────────────────────────────────────
# Perform backup
# ──────────────────────────────────────────────
backup_world() {
  local was_running=false
  local worlds_dir="$SERVER_DIR/worlds"

  if server_is_running; then
    was_running=true
    infobox "Pausing world saves..."
    server_command "save hold"
    sleep 2
    server_command "save query"
    sleep 1
  fi

  infobox "Compressing world... ($backup_name)"

  cd "$SERVER_DIR"
  tar -czf "$backup_local_path" "worlds" 2>/dev/null

  if [[ $? -ne 0 ]]; then
    msgbox "Failed to compress world."
    log_error "Backup compression failed."
    if $was_running; then
      server_command "save resume"
    fi
    return 1
  fi

  if $was_running; then
    server_command "save resume"
  fi

  local_size=$(stat -c%s "$backup_local_path" 2>/dev/null || stat -f%z "$backup_local_path" 2>/dev/null)
  local_size_hr=""
  if [[ -n "$local_size" ]]; then
    local_size_hr=" ($(numfmt --to=iec $local_size 2>/dev/null || echo "$local_size bytes"))"
  fi

  echo "Backup compressed: $backup_local_path${local_size_hr}"

  infobox "Uploading to Google Drive..."
  rclone copy "$backup_local_path" "${GDRIVE_BACKUPS_PATH}/" 2>/dev/null

  if [[ $? -eq 0 ]]; then
    # Upload succeeded — delete local copy
    rm -f "$backup_local_path"
    log_info "Backup created and uploaded: ${backup_name}${local_size_hr}"
    msgbox "✓ Backup complete!

Name: $backup_name
Size: ${local_size_hr# }"
  else
    # Upload failed — keep local copy, warn user
    log_error "Backup upload failed, kept local copy at $backup_local_path"
    msgbox "WARNING: Upload to Google Drive FAILED.

Local backup saved at:
$backup_local_path

Check your internet connection and auth, then re-run backup."
  fi
}

backup_world
