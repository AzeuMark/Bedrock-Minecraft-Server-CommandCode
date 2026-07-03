#!/bin/bash
#
# server_actions.sh — Start / Stop / Restart / View Status
# Respects server.state flag. Start also enables auto-start on boot.
# Stop also disables auto-start on boot.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ──────────────────────────────────────────────
# Actions
# ──────────────────────────────────────────────
do_start() {
  if server_is_running; then
    msgbox "Server is already running."
    return
  fi

  state_set_on
  systemctl enable "$SERVICE_NAME" 2>/dev/null
  systemctl start "$SERVICE_NAME"

  sleep 3
  if server_is_running; then
    msgbox "Server started successfully.
Auto-start on boot is now ENABLED."
    log_info "Server started, auto-start enabled."
  else
    local err_log
    err_log=$(journalctl -u "$SERVICE_NAME" --no-pager -n 10 2>/dev/null)
    whiptail --title "$(menu_title)" --msgbox "\
Server failed to start.

Recent log entries from journalctl:
${err_log:-(no journal output)}

Check /opt/mcbedrock/logs/server.log for details." 15 65
    log_error "Server start failed. Journalctl output: $err_log"
  fi
}

do_stop() {
  if ! server_is_running; then
    msgbox "Server is not running."
    return
  fi

  if ! yesno "Stop the server?

This will also disable auto-start on boot.
The server will NOT start automatically after a VPS reboot until you
use 'Start' again.

Continue?"; then
    return
  fi

  systemctl stop "$SERVICE_NAME"

  local waited=0
  while server_is_running && [[ $waited -lt 15 ]]; do
    sleep 1
    waited=$((waited + 1))
  done

  state_set_off
  systemctl disable "$SERVICE_NAME" 2>/dev/null

  msgbox "Server stopped.
Auto-start on boot is now DISABLED."
  log_info "Server stopped, auto-start disabled."
}

do_restart() {
  if ! server_is_running; then
    msgbox "Server is not running. Use Start first."
    return
  fi

  systemctl restart "$SERVICE_NAME"

  sleep 3
  if server_is_running; then
    msgbox "Server restarted successfully."
    log_info "Server restarted."
  else
    msgbox "Restart failed. Check logs with 'View Logs' for details."
    log_error "Server restart failed."
  fi
}

do_status() {
  local running_text
  if server_is_running; then
    running_text="● RUNNING"
  else
    running_text="○ STOPPED"
  fi

  if state_is_on; then
    state_text="ON (will auto-start on boot)"
  else
    state_text="OFF (will NOT auto-start on boot)"
  fi

  local pid
  pid=$(systemctl show -p MainPID "$SERVICE_NAME" 2>/dev/null | cut -d= -f2)
  local uptime
  uptime=$(systemctl show -p ActiveEnterTimestamp "$SERVICE_NAME" 2>/dev/null | cut -d= -f2 || echo 'N/A')

  whiptail --title "$(menu_title)" --msgbox "\
Server Status: $running_text
Server State:  $state_text
Version:       ${CURRENT_VERSION:-not set}

PID: ${pid:-N/A}
Uptime: $uptime" 12 55
}

# ──────────────────────────────────────────────
# Menu
# ──────────────────────────────────────────────
menu_server_actions() {
  local choice
  choice=$(show_menu "Server Actions — $(server_status_text)" \
    "1" "Start" \
    "2" "Stop" \
    "3" "Restart" \
    "4" "View Status" \
    "5" "Back")

  case "$choice" in
    1) do_start ;;
    2) do_stop ;;
    3) do_restart ;;
    4) do_status ;;
    *) return ;;
  esac
}

# ──────────────────────────────────────────────
# Run
# ──────────────────────────────────────────────
menu_server_actions
