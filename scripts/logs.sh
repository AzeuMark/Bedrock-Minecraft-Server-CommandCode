#!/bin/bash
#
# logs.sh — View and tail Minecraft Bedrock server logs

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

LOG_FILE="$LOGS_DIR/server.log"

# ──────────────────────────────────────────────
# Ensure log file exists
# ──────────────────────────────────────────────
ensure_log() {
  if [[ ! -f "$LOG_FILE" ]]; then
    touch "$LOG_FILE"
  fi
}

# ──────────────────────────────────────────────
# Live tail (real-time)
# ──────────────────────────────────────────────
view_tail() {
  if ! server_is_running; then
    msgbox "Server is not running. Nothing to tail."
    return
  fi

  # Use a temporary file to capture tail output, since whiptail can't do live scrollback
  # We'll show a scrolling view in the terminal
  clear
  echo "=== Minecraft Bedrock Server Log — LIVE TAIL ==="
  echo "Press Ctrl+C to stop viewing."
  echo ""
  tail -f "$LOG_FILE"
  # After Ctrl+C, we return to the menu
}

# ──────────────────────────────────────────────
# View last N lines
# ──────────────────────────────────────────────
view_last() {
  ensure_log
  local lines="${1:-100}"

  # Pipe last N lines into whiptail's textbox
  tail -n "$lines" "$LOG_FILE" > /tmp/mcbedrock_log_tail.txt 2>/dev/null

  whiptail --title "$(menu_title) — Last $lines Lines" \
    --textbox /tmp/mcbedrock_log_tail.txt 20 70

  rm -f /tmp/mcbedrock_log_tail.txt
}

# ──────────────────────────────────────────────
# Menu
# ──────────────────────────────────────────────
menu_logs() {
  local choice
  choice=$(show_menu "Server Logs ($(server_status_text))" \
    "1" "Live Tail (real-time)" \
    "2" "View Last 100 Lines" \
    "3" "View Last 500 Lines" \
    "4" "Back")

  case "$choice" in
    1) view_tail ;;
    2) view_last 100 ;;
    3) view_last 500 ;;
    *) return ;;
  esac
}

# ──────────────────────────────────────────────
# Run
# ──────────────────────────────────────────────
menu_logs
