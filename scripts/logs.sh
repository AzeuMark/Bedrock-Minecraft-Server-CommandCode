#!/bin/bash
#
# logs.sh — View server logs (live tail).
# Usage: logs.sh
# Shows live log. Press q to exit (less +F).

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
  echo "  ║               LIVE LOG — Press q to exit            ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo ""

  if command -v less &>/dev/null; then
    less +F "$LOG_FILE"
  else
    tail -f "$LOG_FILE"
  fi
}

case "${1}" in
  tail|*) do_tail ;;
esac
