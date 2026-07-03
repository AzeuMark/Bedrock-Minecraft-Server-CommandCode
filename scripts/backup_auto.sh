#!/bin/bash
#
# backup_auto.sh — Configure automatic daily backups.
# Prompts for timezone, hour (1-12), and AM/PM.
# Creates a systemd timer to trigger backups at the configured time daily.
# The actual backup logic is in the companion service unit.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

AUTO_SCRIPT="$SCRIPTS_DIR/backup_auto_runner.sh"
TIMER_UNIT="/etc/systemd/system/mcbedrock-autobackup.timer"
SERVICE_UNIT="/etc/systemd/system/mcbedrock-autobackup.service"

# ──────────────────────────────────────────────
# Check prerequisites
# ──────────────────────────────────────────────
if ! is_gdrive_connected; then
  msgbox "Google Drive is not connected.
Use 'Backups → Connect Google Drive' first."
  exit 1
fi

# ──────────────────────────────────────────────
# Get timezone
# ──────────────────────────────────────────────
get_timezone() {
  local tz
  tz=$(inputbox "Enter your timezone
(e.g., Asia/Manila, America/New_York, UTC):")

  if [[ -z "$tz" ]]; then
    return 1
  fi

  # Validate timezone
  if [[ ! -f "/usr/share/zoneinfo/$tz" ]]; then
    if ! yesno "Timezone '$tz' was not found in zoneinfo.
Would you like to proceed anyway?"; then
      return 1
    fi
  fi

  write_config "AUTO_BACKUP_TIMEZONE" "$tz"
  echo "$tz"
}

# ──────────────────────────────────────────────
# Get hour (1-12)
# ──────────────────────────────────────────────
get_hour() {
  local hour
  hour=$(inputbox "Enter backup hour (1-12):")

  if [[ -z "$hour" ]]; then
    return 1
  fi

  if ! [[ "$hour" =~ ^[1-9]$|^1[0-2]$ ]]; then
    msgbox "Invalid hour. Enter a number between 1 and 12."
    return 1
  fi

  write_config "AUTO_BACKUP_HOUR" "$hour"
  echo "$hour"
}

# ──────────────────────────────────────────────
# Get AM/PM
# ──────────────────────────────────────────────
get_ampm() {
  local ampm
  ampm=$(show_menu "Select AM or PM:" \
    "1" "AM" \
    "2" "PM")

  case "$ampm" in
    1) ampm="AM" ;;
    2) ampm="PM" ;;
    *) return 1 ;;
  esac

  write_config "AUTO_BACKUP_AMPM" "$ampm"
  echo "$ampm"
}

# ──────────────────────────────────────────────
# Convert 12-hour to 24-hour for systemd OnCalendar
# ──────────────────────────────────────────────
to_24h() {
  local hour="$1"
  local ampm="$2"

  if [[ "$ampm" == "AM" ]]; then
    if [[ "$hour" -eq 12 ]]; then
      echo "00"
    else
      printf "%02d" "$hour"
    fi
  else
    if [[ "$hour" -eq 12 ]]; then
      echo "12"
    else
      printf "%02d" $((10#$hour + 12))
    fi
  fi
}

# ──────────────────────────────────────────────
# Create the auto-backup runner script
# ──────────────────────────────────────────────
create_runner() {
  cat > "$AUTO_SCRIPT" << 'RUNNER'
#!/bin/bash
#
# backup_auto_runner.sh — Called by systemd timer for automatic daily backups.
# Checks server.state: if OFF, backs up safely without starting server.
# If ON, uses save hold/save resume for clean snapshot.
# Deletes local tarball after successful upload to Drive.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Abort if no gdrive connection
if ! is_gdrive_connected; then
  log_error "Auto-backup skipped: Google Drive not connected."
  exit 1
fi

# Abort if no worlds directory
if [[ ! -d "$SERVER_DIR/worlds" ]]; then
  log_error "Auto-backup skipped: no worlds directory."
  exit 1
fi

timestamp=$(date '+%m-%d-%Y-%I-%M-%S%p')
backup_name="${timestamp}"
backup_local_path="$BACKUPS_DIR/${backup_name}.tar.gz"

was_running=false

if server_is_running; then
  was_running=true
  log_info "Auto-backup: pausing world saves..."
  server_command "save hold"
  sleep 2
  server_command "save query"
  sleep 1
fi

cd "$SERVER_DIR"
tar -czf "$backup_local_path" "worlds" 2>/dev/null

if [[ $? -ne 0 ]]; then
  log_error "Auto-backup: compression failed."
  if $was_running; then
    server_command "save resume"
  fi
  exit 1
fi

if $was_running; then
  server_command "save resume"
fi

rclone copy "$backup_local_path" "${GDRIVE_BACKUPS_PATH}/" 2>/dev/null

if [[ $? -eq 0 ]]; then
  rm -f "$backup_local_path"
  log_info "Auto-backup completed and uploaded: $backup_name"
else
  log_error "Auto-backup: upload failed, kept local copy at $backup_local_path"
  exit 1
fi
RUNNER

  chmod +x "$AUTO_SCRIPT"
  log_info "Auto-backup runner created at $AUTO_SCRIPT"
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
setup_auto_backup() {
  local tz hour ampm hour_24

  # Read existing config if available
  tz="$AUTO_BACKUP_TIMEZONE"
  hour="$AUTO_BACKUP_HOUR"
  ampm="$AUTO_BACKUP_AMPM"

  if [[ -z "$tz" || -z "$hour" || -z "$ampm" ]]; then
    # Run through the setup prompts
    tz=$(get_timezone) || return
    hour=$(get_hour) || return
    ampm=$(get_ampm) || return
  else
    if ! yesno "Auto-backup is already configured for $hour:00 $ampm $tz.

Would you like to reconfigure?"; then
      return
    fi
    tz=$(get_timezone) || return
    hour=$(get_hour) || return
    ampm=$(get_ampm) || return
  fi

  hour_24=$(to_24h "$hour" "$ampm")

  create_runner

  # Create the timer unit with proper OnCalendar
  cat > "$TIMER_UNIT" << TIMER
[Unit]
Description=Daily Minecraft Bedrock Server Auto-Backup

[Timer]
OnCalendar=*-*-* ${hour_24}:00:00
Persistent=true

[Install]
WantedBy=timers.target
TIMER

  # Create the service unit
  cat > "$SERVICE_UNIT" << 'UNIT'
[Unit]
Description=Minecraft Bedrock Server Auto-Backup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=/opt/mcbedrock/scripts/backup_auto_runner.sh

[Install]
WantedBy=multi-user.target
UNIT

  systemctl daemon-reload
  systemctl enable mcbedrock-autobackup.timer 2>/dev/null
  systemctl start mcbedrock-autobackup.timer 2>/dev/null

  systemctl enable mcbedrock-autobackup.service 2>/dev/null

  write_config "AUTO_BACKUP_TIMEZONE" "$tz"
  write_config "AUTO_BACKUP_HOUR" "$hour"
  write_config "AUTO_BACKUP_AMPM" "$ampm"

  log_info "Auto-backup configured: $hour:00 $ampm $tz daily"
  msgbox "✓ Automatic backup configured!

Time: $hour:00 $ampm ($tz)
Schedule: Daily

The world will be backed up automatically at this time."
}

# ──────────────────────────────────────────────
# Menu entry from backup menu
# ──────────────────────────────────────────────
menu_auto_backup() {
  local choice
  choice=$(show_menu "Automatic Backup — \
$([[ -n "$AUTO_BACKUP_HOUR" ]] && echo "Current: ${AUTO_BACKUP_HOUR}:00 ${AUTO_BACKUP_AMPM} ${AUTO_BACKUP_TIMEZONE}" || echo "Not configured")" \
    "1" "Configure / Reconfigure" \
    "2" "Disable Automatic Backup" \
    "3" "View Current Schedule" \
    "4" "Back")

  case "$choice" in
    1) setup_auto_backup ;;
    2) disable_auto_backup ;;
    3) view_schedule ;;
    *) return ;;
  esac
}

disable_auto_backup() {
  if ! yesno "Disable automatic backups?"; then
    return
  fi

  systemctl stop mcbedrock-autobackup.timer 2>/dev/null
  systemctl disable mcbedrock-autobackup.timer 2>/dev/null
  systemctl disable mcbedrock-autobackup.service 2>/dev/null

  write_config "AUTO_BACKUP_TIMEZONE" ""
  write_config "AUTO_BACKUP_HOUR" ""
  write_config "AUTO_BACKUP_AMPM" ""

  log_info "Auto-backup disabled by user."
  msgbox "Automatic backups disabled."
}

view_schedule() {
  if [[ -z "$AUTO_BACKUP_HOUR" || -z "$AUTO_BACKUP_TIMEZONE" ]]; then
    msgbox "Automatic backups are not configured."
    return
  fi

  local timer_status
  timer_status=$(systemctl is-active mcbedrock-autobackup.timer 2>/dev/null || echo "inactive")

  local next_run
  next_run=$(systemctl show mcbedrock-autobackup.timer -p NextElapseUSecRealtime 2>/dev/null | cut -d= -f2 || echo "N/A")

  msgbox "Automatic Backup Schedule:

Time:  $AUTO_BACKUP_HOUR:00 $AUTO_BACKUP_AMPM
TZ:    $AUTO_BACKUP_TIMEZONE
Timer: $timer_status
Next:  ${next_run:-not scheduled}"
}

# ──────────────────────────────────────────────
# Run
# ──────────────────────────────────────────────
menu_auto_backup
