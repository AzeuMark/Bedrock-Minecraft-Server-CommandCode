#!/bin/bash
#
# common.sh — Shared paths, state management, config loader, and UI helpers
# Source this from any other script:  source "$(dirname "$(readlink -f "$0")")/common.sh"

# ──────────────────────────────────────────────
# Paths
# ──────────────────────────────────────────────
INSTALL_ROOT="/opt/mcbedrock"
SCRIPTS_DIR="$INSTALL_ROOT/scripts"
SERVER_DIR="$INSTALL_ROOT/server"
CONFIG_DIR="$INSTALL_ROOT/config"
BACKUPS_DIR="$INSTALL_ROOT/backups"
LOGS_DIR="$INSTALL_ROOT/logs"
SETUP_DIR="$INSTALL_ROOT/setup"

CONFIG_FILE="$CONFIG_DIR/mc.conf"
STATE_FILE="$CONFIG_DIR/server.state"
VERSIONS_CACHE="$CONFIG_DIR/versions.json"
FIFO_PATH="$SERVER_DIR/console.fifo"
SERVICE_NAME="mcbedrock"

GDRIVE_REMOTE="gdrive"
GDRIVE_BACKUPS_PATH="${GDRIVE_REMOTE}:Minecraft/Backups"

# ──────────────────────────────────────────────
# Default configuration values
# ──────────────────────────────────────────────
MC_CONF_DEFAULTS=(
  "INSTALL_DIR=$SERVER_DIR"
  "CURRENT_VERSION="
  "AUTO_BACKUP_TIMEZONE="
  "AUTO_BACKUP_HOUR="
  "AUTO_BACKUP_AMPM="
)

# ──────────────────────────────────────────────
# Load / init config file
# ──────────────────────────────────────────────
load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    for pair in "${MC_CONF_DEFAULTS[@]}"; do
      echo "$pair"
    done > "$CONFIG_FILE"
  fi
  source "$CONFIG_FILE"
}

# ──────────────────────────────────────────────
# Write a single key=value to config file
# ──────────────────────────────────────────────
write_config() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
  else
    echo "${key}=${value}" >> "$CONFIG_FILE"
  fi
}

# ──────────────────────────────────────────────
# State file management
# ──────────────────────────────────────────────
state_is_on() {
  [[ -f "$STATE_FILE" && "$(cat "$STATE_FILE")" == "ON" ]]
}

state_is_off() {
  ! state_is_on
}

state_set_on() {
  echo "ON" > "$STATE_FILE"
}

state_set_off() {
  echo "OFF" > "$STATE_FILE"
}

# ──────────────────────────────────────────────
# Server binary detection
# ──────────────────────────────────────────────
is_server_installed() {
  [[ -x "$SERVER_DIR/bedrock_server" ]]
}

# ──────────────────────────────────────────────
# rclone remote check
# ──────────────────────────────────────────────
is_gdrive_connected() {
  rclone listremotes 2>/dev/null | grep -q "^${GDRIVE_REMOTE}:"
}

# ──────────────────────────────────────────────
# whiptail helpers
# ──────────────────────────────────────────────
menu_title() {
  echo "Minecraft Bedrock Server Manager"
}

yesno() {
  local prompt="$1"
  whiptail --title "$(menu_title)" --yesno "$prompt" 10 60
}

msgbox() {
  local msg="$1"
  whiptail --title "$(menu_title)" --msgbox "$msg" 12 60
}

infobox() {
  local msg="$1"
  whiptail --title "$(menu_title)" --infobox "$msg" 8 50
}

inputbox() {
  local prompt="$1"
  whiptail --title "$(menu_title)" --inputbox "$prompt" 10 60 3>&1 1>&2 2>&3
}

passwordbox() {
  local prompt="$1"
  whiptail --title "$(menu_title)" --passwordbox "$prompt" 10 60 3>&1 1>&2 2>&3
}

# Display a menu and return the selected item
show_menu() {
  local prompt="$1"
  shift
  whiptail --title "$(menu_title)" --menu "$prompt" 18 60 10 "$@" 3>&1 1>&2 2>&3
}

# Show a spinner while a command runs
with_spinner() {
  local msg="$1"
  shift
  (
    eval "$@" &>/dev/null &
    pid=$!
    while kill -0 $pid 2>/dev/null; do
      echo -n "."
      sleep 0.5
    done
    wait $pid
  ) &
  spinner_pid=$!
  whiptail --title "$(menu_title)" --infobox "$msg" 8 50
  wait $spinner_pid
}

# ──────────────────────────────────────────────
# Log helpers
# ──────────────────────────────────────────────
log_info() {
  echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOGS_DIR/mcbedrock-manager.log"
}

log_error() {
  echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOGS_DIR/mcbedrock-manager.log"
}

# ──────────────────────────────────────────────
# Systemd wrapper
# ──────────────────────────────────────────────
server_is_running() {
  systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null
}

server_status_text() {
  if server_is_running; then
    echo "● RUNNING"
  else
    echo "○ STOPPED"
  fi
}

# ──────────────────────────────────────────────
# Send command to running server (via FIFO)
# ──────────────────────────────────────────────
server_command() {
  local cmd="$1"
  if server_is_running && [[ -p "$FIFO_PATH" ]]; then
    echo "$cmd" > "$FIFO_PATH"
    log_info "Sent command to server: $cmd"
  fi
}

# ──────────────────────────────────────────────
# Init on source
# ──────────────────────────────────────────────
load_config
