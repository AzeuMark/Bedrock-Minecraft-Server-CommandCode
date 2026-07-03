#!/bin/bash
#
# mc-menu.sh — Main entry point for the Minecraft Bedrock Server Manager.
# Installed to /usr/local/bin/mc and /usr/local/bin/minecraft.
# Sources common.sh, routes to sub-menus.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ──────────────────────────────────────────────
# First-run detection
# ──────────────────────────────────────────────
check_first_run() {
  if ! is_server_installed; then
    whiptail --title "$(menu_title)" --msgbox "\
No Minecraft Bedrock server detected.

The server binary was not found.
Let's install one first." 10 50

    # Run versions install and re-check
    bash "$SCRIPTS_DIR/versions.sh" install_latest

    if ! is_server_installed; then
      msgbox "Installation failed or was cancelled. Exiting."
      exit 1
    fi
  fi
}

# ──────────────────────────────────────────────
# Main menu
# ──────────────────────────────────────────────
main_menu() {
  local status_msg
  status_msg="Status: $(server_status_text)  |  Version: ${CURRENT_VERSION:-not set}"

  # Add auto-backup info if configured
  if [[ -n "$AUTO_BACKUP_HOUR" && -n "$AUTO_BACKUP_AMPM" ]]; then
    status_msg="$status_msg  |  Auto: ${AUTO_BACKUP_HOUR}:00 ${AUTO_BACKUP_AMPM}"
  fi

  local choice
  choice=$(show_menu "\
$status_msg

Select an action:" \
    "1" "Server Actions  (Start/Stop/Restart)" \
    "2" "Backups" \
    "3" "Versions" \
    "4" "View Logs" \
    "5" "Exit")

  case "$choice" in
    1) bash "$SCRIPTS_DIR/server_actions.sh" ;;
    2) backups_menu ;;
    3) bash "$SCRIPTS_DIR/versions.sh" ;;
    4) bash "$SCRIPTS_DIR/logs.sh" ;;
    5) exit 0 ;;
    *) exit 0 ;;
  esac
}

# ──────────────────────────────────────────────
# Backups sub-menu
# ──────────────────────────────────────────────
backups_menu() {
  # If gdrive not connected, offer to set it up
  if ! is_gdrive_connected; then
    if yesno "Google Drive is not connected.

Backups require a Google Drive connection.

Would you like to set it up now?"; then
      bash "$SCRIPTS_DIR/gdrive_setup.sh"
      # If still not connected after setup, go back
      if ! is_gdrive_connected; then
        msgbox "Google Drive setup was not completed. Returning to main menu."
        return
      fi
    else
      return
    fi
  fi

  local choice
  choice=$(show_menu "Backups — Google Drive: ✓ Connected" \
    "1" "Backup Now" \
    "2" "Restore" \
    "3" "Automatic Backup" \
    "4" "Back")

  case "$choice" in
    1) bash "$SCRIPTS_DIR/backup_now.sh" ;;
    2) bash "$SCRIPTS_DIR/backup_restore.sh" ;;
    3) bash "$SCRIPTS_DIR/backup_auto.sh" ;;
    *) return ;;
  esac
}

# ──────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────
check_first_run

while true; do
  main_menu
done
