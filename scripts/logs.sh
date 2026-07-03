#!/bin/bash
#
# logs.sh — View server logs (live tail).
# Usage: logs.sh
# Shows live log. Press Ctrl+C to exit.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

do_tail() {
  if ! server_is_running; then
    echo "  Server is not running. Nothing to tail."
    read -r -p "  Press Enter to return..."
    return
  fi

  clear
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║          LIVE LOG — Press Ctrl+C to exit            ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo ""

  tail -f "$LOG_FILE"
}

do_tail
