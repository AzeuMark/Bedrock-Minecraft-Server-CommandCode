#!/bin/bash
#
# mc-menu.sh — Modern terminal dashboard for Minecraft Bedrock Server Manager.
# Installed to /usr/local/bin/mc and /usr/local/bin/minecraft.
# The status panel refreshes every second while the menu stays static.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ──────────────────────────────────────────────
# First-run detection
# ──────────────────────────────────────────────
check_first_run() {
  if ! is_server_installed; then
    clear
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║       🎮 MINECRAFT BEDROCK SERVER MANAGER          ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo ""
    echo "  ⚠ No Minecraft Bedrock server detected."
    echo "  Let's install one first."
    echo ""
    read -r -p "  Press Enter to continue..."
    bash "$SCRIPTS_DIR/versions.sh" install
    if ! is_server_installed; then
      echo ""; echo "  ✗ Installation failed or was cancelled."
      read -r -p "  Press Enter to exit..."; exit 1
    fi
  fi
}

# ──────────────────────────────────────────────
# ANSI helpers — move cursor and clear lines
# ──────────────────────────────────────────────
move_to() { printf "\033[%s;1H" "$1"; }
clear_line() { printf "\033[2K"; }

# ──────────────────────────────────────────────
# Draw the full dashboard (called once)
# ──────────────────────────────────────────────
draw_static_frame() {
  clear
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║       🎮 MINECRAFT BEDROCK SERVER MANAGER          ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo ""                                                        # line 5
  echo "    status_line_1"                                       # line 6
  echo "    status_line_2"                                       # line 7
  echo "    status_line_3"                                       # line 8
  echo "    status_line_4"                                       # line 9
  echo "    status_line_5"                                       # line 10
  echo "    status_line_6"                                       # line 11
  echo ""                                                        # line 12
  echo "  ═══════════════════════════════════════════════════════"
  echo ""
  echo "    1  ▶  START SERVER"
  echo "    2  ⏹  STOP SERVER"
  echo "    3  🔄  RESTART SERVER"
  echo "    4  📋  VIEW LOGS"
  echo "    5  💾  BACKUP WORLD"
  echo "    6  📡  CHECK FOR UPDATES"
  echo "    7  🚪  EXIT"
  echo ""
  echo "  ═══════════════════════════════════════════════════════"
}

# ──────────────────────────────────────────────
# Refresh only status lines (6-11) in-place
# ──────────────────────────────────────────────
refresh_status_lines() {
  local icon status ver ram ip port players max_players
  icon=$(get_status_icon)
  status=$(get_status_text)
  ver=$(get_server_version)
  ram=$(get_ram_usage)
  ip=$(get_server_ip)
  port=$(get_server_port)
  players=$(get_player_count)
  max_players=$(get_max_players)

  local status_emoji="🔴"
  server_is_running && status_emoji="🟢"

  # Line 6 — Status
  move_to 6; clear_line
  echo "    ${status_emoji} ${icon} Status  : ${status}"

  # Line 7 — Version
  move_to 7; clear_line
  echo "    📦 Version   : ${ver}"

  # Line 8 — Players
  move_to 8; clear_line
  echo "    🧑 Players   : ${players} / ${max_players}"

  # Line 9 — RAM
  move_to 9; clear_line
  echo "    💾 RAM       : ${ram}"

  # Line 10 — IP
  move_to 10; clear_line
  echo "    🌐 IP        : ${ip}"

  # Line 11 — Port
  move_to 11; clear_line
  echo "    🔌 Port      : ${port}"

  # Move cursor back down to the input line (line 22)
  move_to 22
}

# ──────────────────────────────────────────────
# Handle menu choices
# ──────────────────────────────────────────────
handle_choice() {
  local choice="$1"
  case "$choice" in
    1)
      bash "$SCRIPTS_DIR/server_actions.sh" start
      read -r -p "  Press Enter to return..."
      ;;
    2)
      bash "$SCRIPTS_DIR/server_actions.sh" stop
      read -r -p "  Press Enter to return..."
      ;;
    3)
      bash "$SCRIPTS_DIR/server_actions.sh" restart
      read -r -p "  Press Enter to return..."
      ;;
    4)
      trap '' INT
      bash "$SCRIPTS_DIR/logs.sh" tail
      trap - INT
      draw_static_frame
      ;;
    5)
      backup_menu
      ;;
    6)
      bash "$SCRIPTS_DIR/versions.sh"
      echo ""; read -r -p "  Press Enter to return..."
      ;;
    7)
      clear; echo ""; echo "  👋 Goodbye!"; echo ""; exit 0
      ;;
  esac
  # After action completes, redraw and refresh immediately
  draw_static_frame
  refresh_status_lines
}

# ──────────────────────────────────────────────
# Backup sub-menu
# ──────────────────────────────────────────────
backup_menu() {
  if ! is_gdrive_connected; then
    clear
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║          💾 BACKUP WORLD                            ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo ""; echo "  ⚠ Google Drive is not connected."
    echo "  Backups require Google Drive."; echo ""
    read -r -p "  Set up Google Drive now? (y/N): " setup_gd
    if [[ "$setup_gd" == "y" || "$setup_gd" == "Y" ]]; then
      bash "$SCRIPTS_DIR/gdrive_setup.sh"
      if ! is_gdrive_connected; then
        echo ""; echo "  ✗ Google Drive setup was not completed."
        read -r -p "  Press Enter to return..."; return
      fi
    else return; fi
  fi

  while true; do
    clear
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║          💾 BACKUP WORLD                            ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo ""; echo "    1  📤  BACKUP NOW    2  📥  RESTORE    3  ⏰  AUTO    4  🔙  BACK"
    echo ""; read -r -p "  Select an option [1-4]: " c
    case "$c" in
      1) bash "$SCRIPTS_DIR/backup_now.sh"; read -r -p "  Press Enter to return..." ;;
      2) bash "$SCRIPTS_DIR/backup_restore.sh"; read -r -p "  Press Enter to return..." ;;
      3) bash "$SCRIPTS_DIR/backup_auto.sh"; read -r -p "  Press Enter to return..." ;;
      *) return ;;
    esac
  done
}

# ──────────────────────────────────────────────
# Main loop — status refreshes every second
#       the menu stays static and waits for input
# ──────────────────────────────────────────────
check_first_run
draw_static_frame
refresh_status_lines

while true; do
  # Refresh status lines every second
  # Use a 1-second timeout so input is still responsive
  read -rsn1 -t1 choice
  refresh_status_lines

  if [[ -n "$choice" ]]; then
    handle_choice "$choice"
  fi
done
