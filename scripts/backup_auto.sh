#!/bin/bash
#
# backup_auto.sh — Configure automatic periodic backups.
# Prompts for timezone and interval in hours.
# Creates a systemd timer to trigger backups at that interval.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

AUTO_SCRIPT="$SCRIPTS_DIR/backup_auto_runner.sh"
TIMER_UNIT="/etc/systemd/system/mcbedrock-autobackup.timer"
SERVICE_UNIT="/etc/systemd/system/mcbedrock-autobackup.service"

if ! is_gdrive_connected; then
  echo "  Google Drive is not connected."
  echo "  Use BACKUP WORLD menu option to set it up first."
  exit 1
fi

menu_auto_backup() {
  clear
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║              AUTO BACKUP SCHEDULE                  ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo ""

  local current_schedule="Not configured"
  if systemctl is-active mcbedrock-autobackup.timer &>/dev/null; then
    local interval
    interval=$(systemctl show mcbedrock-autobackup.timer -p OnCalendar 2>/dev/null | cut -d= -f2)
    current_schedule="Active — $interval"
  fi

  echo "    1)  CONFIGURE AUTO BACKUP"
  echo "    2)  DISABLE AUTO BACKUP"
  echo "    3)  VIEW CURRENT SCHEDULE"
  echo "    4)  BACK"
  echo ""
  echo "  ───────────────────────────────────────────────────────"
  echo "  Current: $current_schedule"
  echo ""

  read -r -p "  Select an option [1-4]: " choice

  case "$choice" in
    1) configure_auto_backup ;;
    2) disable_auto_backup ;;
    3) view_schedule ;;
    *) return ;;
  esac

  echo ""
  read -r -p "  Press Enter to return..."
  menu_auto_backup
}

configure_auto_backup() {
  echo ""
  echo "  Configure automatic backups"
  echo ""

  # Get timezone
  read -r -p "  Timezone (e.g. Asia/Manila, UTC, America/New_York): " tz
  if [[ -z "$tz" ]]; then
    echo "  Cancelled."
    return
  fi

  # Get interval in hours
  echo ""
  echo "  How often should backups run?"
  echo "  Common choices: 1, 2, 3, 4, 6, 8, 12, 24"
  read -r -p "  Interval in hours: " interval

  if [[ -z "$interval" || ! "$interval" =~ ^[0-9]+$ ]] || [[ "$interval" -lt 1 ]]; then
    echo "  Invalid interval. Must be a positive number (hours)."
    return
  fi

  # Write config
  write_config "AUTO_BACKUP_TIMEZONE" "$tz"
  write_config "AUTO_BACKUP_HOUR" "$interval"
  write_config "AUTO_BACKUP_AMPM" ""

  # Create runner
  create_runner

  # Create service unit
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

  # Use OnUnitActiveSec — triggers N hours after last activation
  cat > "$TIMER_UNIT" << TIMER
[Unit]
Description=Minecraft Bedrock Server Auto-Backup (every ${interval}h)

[Timer]
OnBootSec=10min
OnUnitActiveSec=${interval}h
Persistent=true

[Install]
WantedBy=timers.target
TIMER

  systemctl daemon-reload
  systemctl enable mcbedrock-autobackup.timer 2>/dev/null
  systemctl start mcbedrock-autobackup.timer 2>/dev/null
  systemctl enable mcbedrock-autobackup.service 2>/dev/null

  log_info "Auto-backup configured: every ${interval}h in $tz"
  echo ""
  echo "  ✓ Automatic backup configured!"
  echo "    Interval: Every $interval hour(s)"
  echo "    Timezone: $tz"
  echo "    The world will be backed up automatically."
}

disable_auto_backup() {
  echo ""
  read -r -p "  Disable automatic backups? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "  Cancelled."
    return
  fi

  systemctl stop mcbedrock-autobackup.timer 2>/dev/null
  systemctl disable mcbedrock-autobackup.timer 2>/dev/null
  systemctl disable mcbedrock-autobackup.service 2>/dev/null

  write_config "AUTO_BACKUP_TIMEZONE" ""
  write_config "AUTO_BACKUP_HOUR" ""
  write_config "AUTO_BACKUP_AMPM" ""

  log_info "Auto-backup disabled by user."
  echo "  ✓ Automatic backups disabled."
}

view_schedule() {
  echo ""
  if ! systemctl is-active mcbedrock-autobackup.timer &>/dev/null; then
    echo "  Automatic backups are not configured."
    return
  fi

  local interval="${AUTO_BACKUP_HOUR:-not set}"
  local tz="${AUTO_BACKUP_TIMEZONE:-not set}"
  local timer_status
  timer_status=$(systemctl is-active mcbedrock-autobackup.timer 2>/dev/null || echo "inactive")
  local next_run
  next_run=$(systemctl show mcbedrock-autobackup.timer -p NextElapseUSecRealtime 2>/dev/null | cut -d= -f2 || echo "N/A")

  echo "  ───────────────────────────────────────────────────────"
  echo "  Interval: Every $interval hour(s)"
  echo "  Timezone: $tz"
  echo "  Timer:    $timer_status"
  echo "  Next run: ${next_run:-not scheduled}"
  echo "  ───────────────────────────────────────────────────────"
}

create_runner() {
  cat > "$AUTO_SCRIPT" << 'RUNNER'
#!/bin/bash
#
# backup_auto_runner.sh — Called by systemd timer for automatic backups.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if ! is_gdrive_connected; then
  log_error "Auto-backup skipped: Google Drive not connected."
  exit 1
fi

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
  log_info "Auto-backup: stopping server..."
  systemctl stop "$SERVICE_NAME"
  sleep 2
fi

cd "$SERVER_DIR"
tar -czf "$backup_local_path" "worlds" 2>/dev/null

if [[ $? -ne 0 ]]; then
  log_error "Auto-backup: compression failed."
  if $was_running; then
    state_set_on
    systemctl start "$SERVICE_NAME"
  fi
  exit 1
fi

rclone copy "$backup_local_path" "${GDRIVE_BACKUPS_PATH}/" 2>/dev/null

if [[ $? -eq 0 ]]; then
  rm -f "$backup_local_path"
  log_info "Auto-backup completed: $backup_name"
else
  log_error "Auto-backup: upload failed, kept local copy"
fi

if $was_running; then
  state_set_on
  systemctl start "$SERVICE_NAME"
fi
RUNNER

  chmod +x "$AUTO_SCRIPT"
  log_info "Auto-backup runner created"
}

# Run
menu_auto_backup
