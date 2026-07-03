#!/bin/bash
#
# backup_restore.sh — List backups on Google Drive and restore one.
# Stops the server if running, downloads + extracts the chosen backup
# into the worlds/ folder, then restarts if it was running before.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ──────────────────────────────────────────────
# Check prerequisites
# ──────────────────────────────────────────────
if ! is_gdrive_connected; then
  msgbox "Google Drive is not connected."
  exit 1
fi

# ──────────────────────────────────────────────
# List backups on Drive
# ──────────────────────────────────────────────
list_drive_backups() {
  rclone lsf "${GDRIVE_BACKUPS_PATH}/" 2>/dev/null | sort
}

# ──────────────────────────────────────────────
# Restore
# ──────────────────────────────────────────────
do_restore() {
  local backup_name="$1"
  local was_running=false

  # Confirm
  if ! yesno "Restore backup: $backup_name

This will OVERWRITE your current world with the backup.
Server will be stopped during restore.

Continue?"; then
    return
  fi

  if server_is_running; then
    was_running=true
    infobox "Stopping server..."
    server_command "say Server is being restored from backup..."
    server_command "stop"
    sleep 2
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    sleep 1
  fi

  infobox "Downloading backup from Google Drive..."

  local tmp_dir
  tmp_dir=$(mktemp -d)
  local backup_file="$tmp_dir/$backup_name"

  rclone copy "${GDRIVE_BACKUPS_PATH}/${backup_name}" "$tmp_dir/" 2>/dev/null

  if [[ ! -f "$backup_file" ]]; then
    msgbox "Failed to download backup from Drive."
    log_error "Restore failed: could not download $backup_name"
    rm -rf "$tmp_dir"
    if $was_running; then
      systemctl start "$SERVICE_NAME"
    fi
    return
  fi

  infobox "Extracting world backup..."

  # Backup current world just in case
  local world_bak="${BACKUPS_DIR}/pre-restore-world-$(date '+%m-%d-%Y-%I-%M-%S%p').tar.gz"
  if [[ -d "$SERVER_DIR/worlds" ]]; then
    cd "$SERVER_DIR"
    tar -czf "$world_bak" "worlds" 2>/dev/null
  fi

  # Remove current worlds and extract backup
  rm -rf "$SERVER_DIR/worlds"
  cd "$SERVER_DIR"
  tar -xzf "$backup_file" 2>/dev/null

  if [[ $? -ne 0 ]]; then
    msgbox "Failed to extract backup. Your world was NOT modified."
    log_error "Restore extraction failed for $backup_name"
    rm -rf "$tmp_dir"
    if $was_running; then
      systemctl start "$SERVICE_NAME"
    fi
    return
  fi

  rm -rf "$tmp_dir"
  log_info "Restored backup: $backup_name"

  if $was_running; then
    # Only restart if the user had it running AND state is ON
    if state_is_on; then
      systemctl start "$SERVICE_NAME"
      sleep 2
    fi
  fi

  msgbox "✓ Restore complete!

Backup: $backup_name
was restored successfully.

$([[ -f "$world_bak" ]] && echo "Previous world saved as: $world_bak")"
}

# ──────────────────────────────────────────────
# Menu
# ──────────────────────────────────────────────
menu_restore() {
  infobox "Fetching backup list from Google Drive..."

  local backups
  backups=$(list_drive_backups)

  if [[ -z "$backups" ]]; then
    msgbox "No backups found on Google Drive.
Check: ${GDRIVE_BACKUPS_PATH}/"
    return
  fi

  # Build whiptail menu
  local menu_items=()
  local i=1
  while IFS= read -r file; do
    # Remove .tar.gz extension for display
    local display_name="${file%.tar.gz}"
    menu_items+=("$i" "$display_name")
    i=$((i + 1))
  done <<< "$backups"

  local choice
  choice=$(show_menu "Select a backup to restore:" "${menu_items[@]}")

  if [[ -z "$choice" ]]; then
    return
  fi

  # Map number back to filename
  local selected_file
  selected_file=$(echo "$backups" | sed -n "${choice}p")

  if [[ -z "$selected_file" ]]; then
    return
  fi

  do_restore "$selected_file"
}

# ──────────────────────────────────────────────
# Run
# ──────────────────────────────────────────────
menu_restore
