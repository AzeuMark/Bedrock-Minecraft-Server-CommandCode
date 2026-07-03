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
    echo "============================================"
    echo "  MINECRAFT BEDROCK SERVER MANAGER"
    echo "============================================"
    echo ""
    echo "  No Minecraft Bedrock server detected."
    echo "  Let's install one first."
    echo ""
    read -r -p "  Press Enter to continue..."
    bash "$SCRIPTS_DIR/versions.sh" install
    if ! is_server_installed; then
      echo ""
      echo "  Installation failed or was cancelled."
      read -r -p "  Press Enter to exit..."
      exit 1
    fi
  fi
}

# ──────────────────────────────────────────────
# Draw the dashboard
# ──────────────────────────────────────────────
draw_dashboard() {
  clear

  local icon status ver ram ip port players max_players
  icon=$(get_status_icon)
  status=$(get_status_text)
  ver=$(get_server_version)
  ram=$(get_ram_usage)
  ip=$(get_server_ip)
  port=$(get_server_port)
  players=$(get_player_count)
  max_players=$(get_max_players)

  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║         MINECRAFT BEDROCK SERVER MANAGER            ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo ""
  echo "    ${icon} Status  : ${status}"
  printf "    Version  : %s\n" "$ver"
  printf "    Players  : %s / %s\n" "$players" "$max_players"
  printf "    RAM      : %s\n" "$ram"
  printf "    Address  : %s:%s\n" "$ip" "$port"
  echo ""
  echo "  ───────────────────────────────────────────────────────"
  echo ""
  echo "    1)  START SERVER"
  echo "    2)  STOP SERVER"
  echo "    3)  RESTART SERVER"
  echo "    4)  VIEW LOGS"
  echo "    5)  BACKUP WORLD"
  echo "    6)  CHECK FOR UPDATES"
  echo "    7)  EXIT"
  echo ""
  echo "  ───────────────────────────────────────────────────────"
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
      ;;
    2)
      bash "$SCRIPTS_DIR/server_actions.sh" stop
      ;;
    3)
      bash "$SCRIPTS_DIR/server_actions.sh" restart
      ;;
    4)
      logs_menu
      ;;
    5)
      backup_menu
      ;;
    6)
      bash "$SCRIPTS_DIR/versions.sh"
      ;;
    7)
      clear
      echo ""
      echo "  Goodbye!"
      echo ""
      exit 0
      ;;
    *)
      echo "  Invalid option. Press Enter to try again."
      read -r
      ;;
  esac
}

# ──────────────────────────────────────────────
# Logs sub-menu
# ──────────────────────────────────────────────
logs_menu() {
  clear
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║                   VIEW LOGS                        ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo ""
  echo "    1)  LIVE TAIL (real-time)"
  echo "    2)  LAST 500 LINES"
  echo "    3)  BACK"
  echo ""
  echo "  ───────────────────────────────────────────────────────"
  echo ""
  read -r -p "  Select an option [1-3]: " choice

  case "$choice" in
    1)
      bash "$SCRIPTS_DIR/logs.sh" tail
      # After tail -f exits (Ctrl+C), just return to dashboard
      return
      ;;
    2)
      bash "$SCRIPTS_DIR/logs.sh" last500
      read -r -p "  Press Enter to return to logs menu..."
      logs_menu
      ;;
    *)
      return
      ;;
  esac
}

# ──────────────────────────────────────────────
# Backup sub-menu
# ──────────────────────────────────────────────
backup_menu() {
  # If gdrive not connected, offer setup
  if ! is_gdrive_connected; then
    clear
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║                 BACKUP WORLD                        ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo ""
    echo "  Google Drive is not connected."
    echo "  Backups require Google Drive."
    echo ""
    read -r -p "  Set up Google Drive now? (y/N): " setup_gd
    if [[ "$setup_gd" == "y" || "$setup_gd" == "Y" ]]; then
      bash "$SCRIPTS_DIR/gdrive_setup.sh"
      if ! is_gdrive_connected; then
        echo ""
        echo "  Google Drive setup was not completed."
        read -r -p "  Press Enter to return..."
        return
      fi
    else
      return
    fi
  fi

  clear
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║                 BACKUP WORLD                        ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo ""
  echo "    1)  BACKUP NOW"
  echo "    2)  RESTORE BACKUP"
  echo "    3)  AUTO BACKUP (schedule)"
  echo "    4)  BACK"
  echo ""
  echo "  ───────────────────────────────────────────────────────"
  echo ""
  read -r -p "  Select an option [1-4]: " choice

  case "$choice" in
    1)
      bash "$SCRIPTS_DIR/backup_now.sh"
      ;;
    2)
      bash "$SCRIPTS_DIR/backup_restore.sh"
      ;;
    3)
      bash "$SCRIPTS_DIR/backup_auto.sh"
      ;;
    *)
      return
      ;;
  esac

  read -r -p "  Press Enter to return to backup menu..."
  backup_menu
}

# ──────────────────────────────────────────────
# Main loop
# ──────────────────────────────────────────────
check_first_run

while true; do
  draw_dashboard
  read -r -p "  Select an option [1-7]: " choice
  handle_choice "$choice"
done
