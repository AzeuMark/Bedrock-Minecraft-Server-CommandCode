#!/bin/bash
#
# backup_restore.sh — List backups on Google Drive and restore one.
# Validates the downloaded backup is a valid world before restoring.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if ! is_gdrive_connected; then
  echo "  Google Drive is not connected."
  exit 1
fi

list_drive_backups() {
  rclone lsf "${GDRIVE_BACKUPS_PATH}/" 2>/dev/null | sort
}

validate_world() {
  local dir="$1"
  # A valid Bedrock world has a level.dat and a db/ directory (LevelDB format)
  if [[ ! -f "$dir/level.dat" ]]; then
    return 1
  fi
  if [[ ! -d "$dir/db" ]]; then
    return 1
  fi
  local count
  count=$(find "$dir/db" -type f 2>/dev/null | wc -l)
  if [[ "$count" -eq 0 ]]; then
    return 1
  fi
  return 0
}

download_and_validate() {
  local backup_name="$1"
  local tmp_dir
  tmp_dir=$(mktemp -d)

  echo "  Downloading backup from Google Drive..."
  rclone copy "${GDRIVE_BACKUPS_PATH}/${backup_name}" "$tmp_dir/" 2>/dev/null

  local backup_file="$tmp_dir/$backup_name"
  if [[ ! -f "$backup_file" ]]; then
    echo "  ✗ Failed to download backup."
    rm -rf "$tmp_dir"
    return 1
  fi

  echo "  Validating backup..."
  local check_dir
  check_dir=$(mktemp -d)
  tar -xzf "$backup_file" -C "$check_dir" 2>/dev/null

  if [[ -d "$check_dir/worlds" ]]; then
    # Multiple worlds bundled
    local valid=false
    for w in "$check_dir/worlds"/*/; do
      if [[ -d "$w" ]] && validate_world "$w"; then
        valid=true
        break
      fi
    done
    if ! $valid; then
      echo "  ✗ Backup appears invalid or corrupted (no valid worlds found)."
      rm -rf "$tmp_dir" "$check_dir"
      return 1
    fi
  elif [[ -d "$check_dir" ]]; then
    # Single world or worlds dir directly
    local found_valid=false
    if [[ -f "$check_dir/level.dat" ]]; then
      if validate_world "$check_dir"; then
        found_valid=true
      fi
    else
      for w in "$check_dir"/*/; do
        if [[ -d "$w" ]] && validate_world "$w"; then
          found_valid=true
          break
        fi
      done
    fi
    if ! $found_valid; then
      echo "  ✗ Backup appears invalid or corrupted."
      rm -rf "$tmp_dir" "$check_dir"
      return 1
    fi
  else
    echo "  ✗ Backup appears invalid or corrupted (unexpected structure)."
    rm -rf "$tmp_dir" "$check_dir"
    return 1
  fi

  rm -rf "$check_dir"
  echo "$tmp_dir"
  return 0
}

do_restore() {
  local backup_name="$1"
  local was_running=false

  echo ""
  echo "  Selected backup: $backup_name"
  echo ""
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

  # Download and validate
  local result
  result=$(download_and_validate "$backup_name")
  if [[ $? -ne 0 ]]; then
    echo ""
    if $was_running; then
      state_set_on
      systemctl start "$SERVICE_NAME"
    fi
    return
  fi

  local tmp_dir="$result"
  local backup_file="$tmp_dir/$backup_name"

  echo "  Backup validated successfully."

  # Backup current world just in case
  local world_bak="${BACKUPS_DIR}/pre-restore-$(date '+%m-%d-%Y-%I-%M-%S%p').tar.gz"
  if [[ -d "$SERVER_DIR/worlds" ]]; then
    echo "  Saving current world as safety backup..."
    cd "$SERVER_DIR"
    tar -czf "$world_bak" "worlds" 2>/dev/null
  fi

  # Remove current worlds and extract backup
  rm -rf "$SERVER_DIR/worlds"
  cd "$SERVER_DIR"
  tar -xzf "$backup_file" 2>/dev/null

  if [[ $? -ne 0 ]]; then
    echo "  ✗ Failed to extract backup."
    log_error "Restore extraction failed"
    rm -rf "$tmp_dir"
    if $was_running; then
      state_set_on
      systemctl start "$SERVICE_NAME"
    fi
    return
  fi

  echo "  ✓ Backup restored successfully."
  log_info "Restored backup: $backup_name"

  # Show the restored world
  echo "  Worlds found:"
  for w in "$SERVER_DIR/worlds"/*/; do
    if [[ -d "$w" ]]; then
      echo "    - $(basename "$w")"
    fi
  done

  rm -rf "$tmp_dir"

  if $was_running; then
    echo "  Restarting server..."
    state_set_on
    systemctl start "$SERVICE_NAME"
    sleep 2
  fi

  echo ""
  echo "  ✓ Restore complete!"
  [[ -f "$world_bak" ]] && echo "  Previous world saved as: $(basename "$world_bak")"
}

menu_restore() {
  echo "  Fetching backup list from Google Drive..."

  local backups
  backups=$(list_drive_backups)

  if [[ -z "$backups" ]]; then
    echo "  No backups found on Google Drive."
    echo "  Check: ${GDRIVE_BACKUPS_PATH}/"
    return
  fi

  echo ""
  echo "  Available backups:"
  echo ""

  local names=()
  local i=1
  while IFS= read -r file; do
    local display="${file%.tar.gz}"
    names+=("$file")
    printf "  %2d) %s\n" "$i" "$display"
    i=$((i + 1))
  done <<< "$backups"

  echo ""
  read -r -p "  Select a backup to restore [1-$((i-1))]: " choice

  if [[ -z "$choice" || "$choice" -lt 1 || "$choice" -ge "$i" ]]; then
    echo "  Invalid selection."
    return
  fi

  local selected
  selected="${names[$((choice-1))]}"
  do_restore "$selected"
}

menu_restore
