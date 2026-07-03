#!/bin/bash
#
# mc-menu.sh — Modern terminal dashboard for Minecraft Bedrock Server Manager.
# Installed to /usr/local/bin/mc and /usr/local/bin/minecraft.

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
      echo ""; echo "  ✗ Installation failed."; read -r -p "  Press Enter to exit..."; exit 1
    fi
  fi
}

# ──────────────────────────────────────────────
# Draw the dashboard
# ──────────────────────────────────────────────
draw_dashboard() {
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

  echo ""
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║       🎮 MINECRAFT BEDROCK SERVER MANAGER          ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo ""
  echo "    ${status_emoji} ${icon} Status    : ${status}"
  echo "    📦 Version   : ${ver}"
  echo "    🧑 Players   : ${players} / ${max_players}"
  echo "    💾 RAM       : ${ram}"
  echo "    🌐 IP        : ${ip}"
  echo "    🔌 Port      : ${port}"
  echo ""
  echo "  ═══════════════════════════════════════════════════════"
  echo ""
  echo "    1  ▶  START SERVER"
  echo "    2  ⏹  STOP SERVER"
  echo "    3  🔄  RESTART SERVER"
  echo "    4  📋  VIEW LOGS"
  echo "    5  💾  BACKUP WORLD"
  echo "    6  📡  CHECK FOR UPDATES"
  echo "    7  ⌨  SEND COMMAND"
  echo "    8  🚪  EXIT"
  echo ""
  echo "  ═══════════════════════════════════════════════════════"
  echo ""
}

# ──────────────────────────────────────────────
# Handle menu choice
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
      # Parent ignores Ctrl+C, child runs with default signal handling
      # so tail -f can be killed by Ctrl+C without killing the menu
      trap '' INT
      (trap - INT; exec bash "$SCRIPTS_DIR/logs.sh" tail)
      trap - INT
      ;;
    5)
      backup_menu
      ;;
    6)
      bash "$SCRIPTS_DIR/versions.sh"
      echo ""; read -r -p "  Press Enter to return..."
      ;;
    7)
      clear
      echo "  Type a command to send to the server console."
      echo "  Common commands: stop, list, say Hello, kick PlayerName"
      echo "  Leave empty and press Enter to cancel."
      echo ""
      read -r -p "  Command: " cmd
      if [[ -n "$cmd" ]]; then
        bash "$SCRIPTS_DIR/send_command.sh" "$cmd"
      fi
      read -r -p "  Press Enter to return..."
      ;;
    8)
      clear; echo ""; echo "  👋 Goodbye!"; echo ""; exit 0
      ;;
  esac
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
    echo ""; read -r -p "  Select an option [1-4]: " choice
    case "$choice" in
      1) bash "$SCRIPTS_DIR/backup_now.sh"; read -r -p "  Press Enter to return..." ;;
      2) bash "$SCRIPTS_DIR/backup_restore.sh"; read -r -p "  Press Enter to return..." ;;
      3) bash "$SCRIPTS_DIR/backup_auto.sh"; read -r -p "  Press Enter to return..." ;;
      *) return ;;
    esac
  done
}

# ──────────────────────────────────────────────
# Main loop
# ──────────────────────────────────────────────
check_first_run

while true; do
  clear
  draw_dashboard
  read -r -p "  Select an option [1-8]: " choice
  handle_choice "$choice"
done
