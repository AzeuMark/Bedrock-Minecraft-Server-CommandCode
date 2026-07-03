#!/bin/bash
#
# backup_restore.sh — Restore a world backup from Google Drive.
# Lists backup folders on Drive, lets you pick one, restores it.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if ! is_gdrive_connected; then
  echo "  Google Drive is not connected."
  read -r -p "  Press Enter to return..."
  exit 1
fi

list_backup_folders() {
  rclone lsd "${GDRIVE_BACKUPS_PATH}/" 2>/dev/null | awk '{for(i=5;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//'
}

validate_world() {
  local dir="$1"
  if [[ ! -f "$dir/level.dat" ]]; then return 1; fi
  if [[ ! -d "$dir/db" ]]; then return 1; fi
  local count; count=$(find "$dir/db" -type f 2>/dev/null | wc -l)
  [[ "$count" -eq 0 ]] && return 1
  return 0
}

do_restore() {
  local selected_display="$1"
  local was_running=false

  echo ""
  echo "  Selected backup: $selected_display"
  echo "  This will OVERWRITE your current world."
  read -r -p "  Continue? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "  Cancelled."
    return
  fi

  if server_is_running; then
    was_running=true
    echo "  Stopping server..."
    systemctl stop "$SERVICE_NAME"
    sleep 2
  fi

  echo "  Removing old world..."
  rm -rf "$SERVER_DIR/worlds"

  echo "  Downloading backup from Google Drive..."
  rclone copy "${GDRIVE_BACKUPS_PATH}/${selected_display}" "$SERVER_DIR/worlds" --progress 2>/dev/null

  if [[ $? -ne 0 ]]; then
    echo "  ✗ Download failed."
    log_error "Restore download failed"
    if $was_running; then state_set_on; systemctl start "$SERVICE_NAME"; fi
    return
  fi

  echo "  Fixing permissions..."
  chmod -R 755 "$SERVER_DIR/worlds" 2>/dev/null

  # Find the actual world folder(s) downloaded
  echo "  Validating..."
  local found_valid=false
  for w in "$SERVER_DIR/worlds"/*/; do
    if [[ -d "$w" ]]; then
      if validate_world "$w"; then
        echo "    ✓ $(basename "$w") — valid"
        found_valid=true
      else
        echo "    ⚠ $(basename "$w") — may be incomplete"
      fi
    fi
  done

  if ! $found_valid; then
    echo "  ⚠ No valid worlds found in backup."
  fi

  log_info "Restored backup: $selected_display"
  echo ""
  echo "  ✓ Restore complete!"

  if $was_running; then
    echo "  Restarting server..."
    state_set_on
    systemctl start "$SERVICE_NAME"
    sleep 2
  fi
}

menu_restore() {
  echo "  Fetching backup list from Google Drive..."
  echo ""

  local folders
  mapfile -t folders < <(list_backup_folders)

  if [[ ${#folders[@]} -eq 0 ]]; then
    echo "  No backups found."
    echo "  Check: ${GDRIVE_BACKUPS_PATH}/"
    read -r -p "  Press Enter to return..."
    return
  fi

  echo "  Available backups:"
  echo ""
  local i=1
  for f in "${folders[@]}"; do
    printf "  %2d) %s\n" "$i" "$f"
    i=$((i + 1))
  done

  echo ""
  read -r -p "  Select backup [1-$((i-1))] (or press 0 / Enter to cancel): " choice

  if [[ "$choice" == "0" || -z "$choice" ]]; then
    echo "  Cancelled."
    read -r -p "  Press Enter to return..."
    return
  fi

  if [[ "$choice" -lt 1 || "$choice" -ge "$i" ]]; then
    echo "  Invalid selection."
    read -r -p "  Press Enter to return..."
    return
  fi

  do_restore "${folders[$((choice-1))]}"
  read -r -p "  Press Enter to return..."
}

menu_restore
