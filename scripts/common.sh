#!/bin/bash
#
# common.sh — Shared paths, state management, config loader, and helpers.
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
SERVICE_NAME="mcbedrock"
LOG_FILE="$LOGS_DIR/server.log"

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
# Systemd wrapper
# ──────────────────────────────────────────────
server_is_running() {
  systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null
}

# ──────────────────────────────────────────────
# Dashboard info gatherers
# ──────────────────────────────────────────────
get_status_icon() {
  if server_is_running; then
    echo "●"
  else
    echo "○"
  fi
}

get_status_text() {
  if server_is_running; then
    echo "RUNNING"
  else
    echo "STOPPED"
  fi
}

get_server_version() {
  echo "${CURRENT_VERSION:-not set}"
}

get_ram_usage() {
  local pid
  pid=$(systemctl show -p MainPID "$SERVICE_NAME" 2>/dev/null | cut -d= -f2)
  if [[ -n "$pid" && "$pid" -gt 1 ]]; then
    local rss
    rss=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')
    if [[ -n "$rss" ]]; then
      # rss is in KB, convert to human
      if (( rss > 1048576 )); then
        echo "$(echo "scale=1; $rss/1048576" | bc)G"
      elif (( rss > 1024 )); then
        echo "$(echo "scale=1; $rss/1024" | bc)M"
      else
        echo "${rss}K"
      fi
    else
      echo "N/A"
    fi
  else
    echo "N/A"
  fi
}

get_server_ip() {
  # Get the primary public IP
  ip -4 addr show | grep -oP 'inet \K[\d.]+' | grep -v '^127\.' | head -1
}

get_server_port() {
  local port
  port=$(grep '^server-port=' "$SERVER_DIR/server.properties" 2>/dev/null | cut -d= -f2)
  echo "${port:-19132}"
}

get_player_count() {
  if ! server_is_running; then
    echo "0"
    return
  fi
  local log_content
  log_content=$(cat "$LOG_FILE" 2>/dev/null)
  if [[ -z "$log_content" ]]; then
    echo "0"
    return
  fi
  # Count connected vs disconnected players from log
  # Bedrock formats: "Player connected:" and "Player disconnected:"
  local connected
  connected=$(echo "$log_content" | grep -c "Player connected:" 2>/dev/null)
  local disconnected
  disconnected=$(echo "$log_content" | grep -c "Player disconnected:" 2>/dev/null)
  local count=$((connected - disconnected))
  if (( count < 0 )); then
    count=0
  fi
  echo "$count"
}

get_max_players() {
  local max
  max=$(grep '^max-players=' "$SERVER_DIR/server.properties" 2>/dev/null | cut -d= -f2)
  echo "${max:-10}"
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
# Init on source
# ──────────────────────────────────────────────
load_config
