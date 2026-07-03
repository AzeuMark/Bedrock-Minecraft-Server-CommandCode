#!/bin/bash
#
# logs.sh — View server logs.
# Usage: logs.sh {tail|last500}

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

do_tail() {
  if ! server_is_running; then
    echo "  Server is not running. Nothing to tail."
    echo "  You can still view the last 500 lines from the logs menu."
    return
  fi

  clear
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║               LIVE LOG — Press Ctrl+C to stop       ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo ""
  tail -f "$LOG_FILE"
}

do_last500() {
  clear
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║                LAST 500 LINES                       ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo ""

  if [[ ! -f "$LOG_FILE" ]]; then
    echo "  No log file found yet."
    return
  fi

  # Use less for scrollable viewing, fallback to cat
  if command -v less &>/dev/null; then
    tail -n 500 "$LOG_FILE" | less
  else
    tail -n 500 "$LOG_FILE"
  fi
}

case "${1}" in
  tail)
    do_tail
    ;;
  last500)
    do_last500
    ;;
  *)
    echo "Usage: $0 {tail|last500}"
    exit 1
    ;;
esac
