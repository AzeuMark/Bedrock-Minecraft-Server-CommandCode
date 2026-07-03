#!/bin/bash
#
# server_actions.sh — Start / Stop / Restart / View Status
# Usage: server_actions.sh {start|stop|restart|status}
# Respects server.state flag.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

do_start() {
  if server_is_running; then
    echo "  Server is already running."
    return
  fi

  echo "  Starting server..."
  state_set_on
  systemctl enable "$SERVICE_NAME" 2>/dev/null
  systemctl start "$SERVICE_NAME"
  sleep 3

  if server_is_running; then
    echo "  ✓ Server started successfully."
    echo "  Auto-start on boot is now ENABLED."
    log_info "Server started, auto-start enabled."
  else
    echo "  ✗ Server failed to start."
    echo ""
    journalctl -u "$SERVICE_NAME" --no-pager -n 15 2>/dev/null
    log_error "Server start failed."
  fi
}

do_stop() {
  if ! server_is_running; then
    echo "  Server is not running."
    return
  fi

  echo "  The server has been fully stopped and will not auto-start upon VPS reboot."
  read -r -p "  Press Enter to dismiss..."

  echo "  Stopping server..."

  # Disable first so Restart= won't re-fire the service
  systemctl disable "$SERVICE_NAME" 2>/dev/null

  # Now stop — try graceful, then force
  systemctl stop "$SERVICE_NAME" 2>/dev/null

  # Wait up to 15s for it to actually stop
  local waited=0
  while server_is_running && [[ $waited -lt 15 ]]; do
    sleep 1
    waited=$((waited + 1))
  done

  # Force kill if still running
  if server_is_running; then
    systemctl kill "$SERVICE_NAME" --signal=SIGKILL 2>/dev/null
    sleep 1
  fi

  state_set_off
  echo "  ✓ Server stopped."
  echo "  Auto-start on boot is now DISABLED."
  log_info "Server stopped, auto-start disabled."
}

do_restart() {
  if ! server_is_running; then
    echo "  Server is not running. Use START SERVER first."
    return
  fi

  echo "  Restarting server..."
  systemctl restart "$SERVICE_NAME"
  sleep 3

  if server_is_running; then
    echo "  ✓ Server restarted successfully."
    log_info "Server restarted."
  else
    echo "  ✗ Restart failed. Check logs."
    log_error "Server restart failed."
  fi
}

do_status() {
  if server_is_running; then
    echo "Running"
  else
    echo "Stopped"
  fi
}

# ──────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────
case "${1:-menu}" in
  start)
    do_start
    ;;
  stop)
    do_stop
    ;;
  restart)
    do_restart
    ;;
  status)
    do_status
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
