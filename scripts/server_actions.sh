#!/bin/bash
#
# server_actions.sh — Start / Stop / Restart / View Status
# Respects server.state flag. Start also enables auto-start on boot.
# Stop also disables auto-start on boot.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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

  # Wait a moment then check
  sleep 2
  if server_is_running; then
    msgbox "Server started successfully.
Auto-start on boot is now ENABLED."
    log_info "Server started, auto-start enabled."
  else
    msgbox "Server failed to start. Check logs for details."
    log_error "Server start failed."
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

  # Send clean stop command via console
  server_command "stop"

  # Wait for graceful shutdown
  local waited=0
  while server_is_running && [[ $waited -lt 30 ]]; do
    sleep 1
    waited=$((waited + 1))
  done

  # Force stop if still running
  if server_is_running; then
    systemctl stop "$SERVICE_NAME"
  fi

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

  server_command "say Server is restarting..."
  server_command "stop"

  local waited=0
  while server_is_running && [[ $waited -lt 30 ]]; do
    sleep 1
    waited=$((waited + 1))
  done

  systemctl restart "$SERVICE_NAME"

  sleep 2
  if server_is_running; then
    msgbox "Server restarted successfully."
    log_info "Server restarted."
  else
    msgbox "Restart failed. Check logs."
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

  local version_text="${CURRENT_VERSION:-not set}"

  whiptail --title "$(menu_title)" --msgbox "\
Server Status: $running_text
Server State:  $state_text
Version:       $version_text

PID: $(systemctl show -p MainPID "$SERVICE_NAME" 2>/dev/null | cut -d= -f2)
Memory: $(systemctl show -p MemoryCurrent "$SERVICE_NAME" 2>/dev/null | cut -d= -f2 || echo 'N/A')
Uptime: $(systemctl show -p ActiveEnterTimestamp "$SERVICE_NAME" 2>/dev/null | cut -d= -f2 || echo 'N/A')" 14 55
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
