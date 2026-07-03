#!/bin/bash
#
# versions.sh — Check for updates and install latest Bedrock version.
# Compares installed version against the official API.
#
# Usage:
#   versions.sh               → interactive menu (Check Update / Back)
#   versions.sh install_latest → non-interactive install (first-run)

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

API_URL="https://net-secondary.web.minecraft-services.net/api/v1.0/download/links"

# ──────────────────────────────────────────────
# Fetch latest serverBedrockLinux info from API
# ──────────────────────────────────────────────
fetch_latest_info() {
  local json
  json=$(curl -sL "$API_URL")
  local url
  url=$(echo "$json" | jq -r '.result.links[] | select(.downloadType == "serverBedrockLinux") | .downloadUrl')
  local version
  version=$(echo "$url" | grep -oP '\d+\.\d+\.\d+\.\d+')

  if [[ -z "$url" || "$url" == "null" ]]; then
    echo ""
    return
  fi
  echo "$url|$version"
}

# ──────────────────────────────────────────────
# Compare versions (simple string compare)
# ──────────────────────────────────────────────
version_gt() {
  test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# ──────────────────────────────────────────────
# Install a version from a download URL
# ──────────────────────────────────────────────
install_version() {
  local url="$1"
  local version="$2"
  local was_running=false

  if server_is_running; then
    was_running=true
    server_command "say Server is updating to $version..."
    server_command "stop"
    sleep 3
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
  fi

  infobox "Downloading Bedrock $version..."

  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"

  if ! wget -O bedrock-server.zip "$url" 2>/dev/null; then
    msgbox "Download failed."
    log_error "Download failed: $url"
    cd /
    rm -rf "$tmp_dir"
    return 1
  fi

  infobox "Extracting Bedrock $version..."

  # Backup worlds and settings
  local world_backup
  world_backup=$(mktemp -d)
  for item in worlds server.properties whitelist.json permissions.json; do
    [[ -e "$SERVER_DIR/$item" ]] && cp -r "$SERVER_DIR/$item" "$world_backup/"
  done

  # Extract new version
  unzip -o bedrock-server.zip -d "$SERVER_DIR/" 2>/dev/null
  chmod +x "$SERVER_DIR/bedrock_server"

  # Restore worlds and settings
  for item in worlds server.properties whitelist.json permissions.json; do
    [[ -e "$world_backup/$item" ]] && rm -rf "$SERVER_DIR/$item" && cp -r "$world_backup/$item" "$SERVER_DIR/"
  done

  cd /
  rm -rf "$tmp_dir" "$world_backup"

  write_config "CURRENT_VERSION" "$version"
  log_info "Updated to version $version"

  # Restart if it was running before
  if $was_running; then
    systemctl start "$SERVICE_NAME"
    sleep 2
  fi

  msgbox "✓ Updated to Bedrock $version

Your worlds and settings were preserved."
}

# ──────────────────────────────────────────────
# Check for update
# ──────────────────────────────────────────────
check_update() {
  infobox "Checking for updates..."

  local info
  info=$(fetch_latest_info)
  if [[ -z "$info" ]]; then
    msgbox "Could not fetch latest version info.
Check your internet connection."
    return
  fi

  local latest_url="${info%%|*}"
  local latest_ver="${info##*|}"

  if [[ -z "$latest_ver" ]]; then
    msgbox "Could not parse latest version from API response."
    return
  fi

  local current="${CURRENT_VERSION}"

  if [[ -z "$current" ]]; then
    # No version installed yet — offer to install
    if yesno "No Bedrock version installed.

Install latest version $latest_ver?"; then
      install_version "$latest_url" "$latest_ver"
    fi
    return
  fi

  if [[ "$current" == "$latest_ver" ]]; then
    msgbox "You're already on the latest version: $latest_ver"
    return
  fi

  if version_gt "$latest_ver" "$current"; then
    msgbox "Update available!

Current: $current
Latest:  $latest_ver"

    if yesno "Update to Bedrock $latest_ver?

Your worlds and settings will be preserved.
The server will be temporarily stopped."; then
      install_version "$latest_url" "$latest_ver"
    fi
  else
    msgbox "Your version ($current) is ahead of the latest release ($latest_ver).
You may be on a preview version."
  fi
}

# ──────────────────────────────────────────────
# Install latest (non-interactive, for first-run)
# ──────────────────────────────────────────────
install_latest() {
  local info
  info=$(fetch_latest_info)
  if [[ -z "$info" ]]; then
    echo "ERROR: Could not fetch latest version."
    exit 1
  fi

  local latest_url="${info%%|*}"
  local latest_ver="${info##*|}"

  install_version "$latest_url" "$latest_ver"
}

# ──────────────────────────────────────────────
# Menu
# ──────────────────────────────────────────────
menu_versions() {
  local choice
  choice=$(show_menu "Versions — Installed: ${CURRENT_VERSION:-none}" \
    "1" "Check for Update" \
    "2" "Back")

  case "$choice" in
    1) check_update ;;
    *) return ;;
  esac
}

# ──────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────
if [[ "$1" == "install_latest" ]]; then
  install_latest
else
  menu_versions
fi
