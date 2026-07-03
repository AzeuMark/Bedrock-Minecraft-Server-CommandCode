#!/bin/bash
#
# versions.sh — List, install, and switch Bedrock Dedicated Server versions.
# Supports: "Install Latest" (official download), "Install Specific" (community index).
#
# Usage:
#   versions.sh              → interactive menu
#   versions.sh install_latest → non-interactive install of latest version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

VERSIONS_INDEX_URL="https://raw.githubusercontent.com/Bedrock-OSS/BDSVerse/main/versions.json"

# ──────────────────────────────────────────────
# Fetch latest download URL from Mojang
# ──────────────────────────────────────────────
fetch_latest_url() {
  local page
  page=$(curl -sL "https://www.minecraft.net/en-us/download/server/bedrock")
  local url
  url=$(echo "$page" | grep -oP 'https://[^"]+bedrock-server-[^"]+\.zip' | head -1)

  if [[ -z "$url" ]]; then
    # Fallback URL pattern
    url="https://minecraft.azureedge.net/bin-linux/bedrock-server-1.21.70.03.zip"
  fi

  echo "$url"
}

# ──────────────────────────────────────────────
# Extract version string from download URL
# ──────────────────────────────────────────────
version_from_url() {
  local url="$1"
  echo "$url" | grep -oP '\d+\.\d+\.\d+\.\d+'
}

# ──────────────────────────────────────────────
# Install a Bedrock version from a URL
# ──────────────────────────────────────────────
install_version() {
  local url="$1"
  local version="$2"
  local was_running=false

  if server_is_running; then
    was_running=true
    server_command "say Server is updating version..."
    server_command "stop"
    sleep 3
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
  fi

  infobox "Downloading Bedrock $version..."

  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"

  if ! curl -sL -o bedrock-server.zip "$url"; then
    msgbox "Download failed for version $version."
    log_error "Download failed for version $version from $url"
    cd /
    rm -rf "$tmp_dir"
    return 1
  fi

  infobox "Extracting Bedrock $version..."

  # Backup worlds and properties before overwriting
  local world_backup
  world_backup=$(mktemp -d)
  if [[ -d "$SERVER_DIR/worlds" ]]; then
    cp -r "$SERVER_DIR/worlds" "$world_backup/"
  fi
  if [[ -f "$SERVER_DIR/server.properties" ]]; then
    cp "$SERVER_DIR/server.properties" "$world_backup/"
  fi
  if [[ -f "$SERVER_DIR/whitelist.json" ]]; then
    cp "$SERVER_DIR/whitelist.json" "$world_backup/" 2>/dev/null || true
  fi
  if [[ -f "$SERVER_DIR/permissions.json" ]]; then
    cp "$SERVER_DIR/permissions.json" "$world_backup/" 2>/dev/null || true
  fi

  # Extract
  unzip -o bedrock-server.zip -d "$SERVER_DIR/" 2>/dev/null
  chmod +x "$SERVER_DIR/bedrock_server"

  # Restore worlds and properties
  if [[ -d "$world_backup/worlds" ]]; then
    rm -rf "$SERVER_DIR/worlds"
    cp -r "$world_backup/worlds" "$SERVER_DIR/"
  fi
  if [[ -f "$world_backup/server.properties" ]]; then
    cp "$world_backup/server.properties" "$SERVER_DIR/"
  fi
  if [[ -f "$world_backup/whitelist.json" ]]; then
    cp "$world_backup/whitelist.json" "$SERVER_DIR/" 2>/dev/null || true
  fi
  if [[ -f "$world_backup/permissions.json" ]]; then
    cp "$world_backup/permissions.json" "$SERVER_DIR/" 2>/dev/null || true
  fi

  cd /
  rm -rf "$tmp_dir" "$world_backup"

  write_config "CURRENT_VERSION" "$version"
  msgbox "Bedrock $version installed successfully.
Your worlds and settings were preserved."

  log_info "Installed Bedrock version $version"

  # Restart if it was running before
  if $was_running; then
    systemctl start "$SERVICE_NAME"
    sleep 2
    if server_is_running; then
      msgbox "Server restarted with version $version."
    fi
  fi
}

# ──────────────────────────────────────────────
# Install latest version (also called from first-run)
# ──────────────────────────────────────────────
install_latest() {
  local url
  url=$(fetch_latest_url)
  local version
  version=$(version_from_url "$url")

  if [[ -z "$version" ]]; then
    version="latest"
  fi

  install_version "$url" "$version"
}

# ──────────────────────────────────────────────
# Install specific version (from community index)
# ──────────────────────────────────────────────
install_specific() {
  infobox "Fetching available versions..."
  local versions_json
  versions_json=$(curl -sL "$VERSIONS_INDEX_URL" 2>/dev/null)

  if [[ -z "$versions_json" ]]; then
    msgbox "Could not fetch version list from community index.
Check your internet connection or try again later.

Using fallback: installing latest version instead."
    install_latest
    return
  fi

  # Parse version list (supports both array and object formats)
  local versions_list
  versions_list=$(echo "$versions_json" | jq -r 'if type == "array" then .[] else .versions[] end' 2>/dev/null)

  if [[ -z "$versions_list" ]]; then
    msgbox "Could not parse version list. Installing latest instead."
    install_latest
    return
  fi

  # Build whiptail menu
  local menu_items=()
  local i=1
  while IFS= read -r ver; do
    menu_items+=("$i" "$ver")
    i=$((i + 1))
  done <<< "$versions_list"

  if [[ ${#menu_items[@]} -eq 0 ]]; then
    msgbox "No versions found. Installing latest instead."
    install_latest
    return
  fi

  local choice
  choice=$(show_menu "Select a version to install:" "${menu_items[@]}")

  if [[ -z "$choice" ]]; then
    return
  fi

  # Find the selected version text
  local selected_version
  selected_version=$(echo "$versions_list" | sed -n "${choice}p")

  if [[ -z "$selected_version" ]]; then
    return
  fi

  # Get download URL for selected version
  local download_url
  download_url=$(echo "$versions_json" | jq -r --arg v "$selected_version" \
    'if type == "array" then .[] | select(.version == $v) | .downloads.linux.url
     else .versions[] | select(.version == $v) | .downloads.linux.url end' 2>/dev/null)

  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    msgbox "Could not find download URL for version $selected_version.
Try installing the latest version instead."
    return
  fi

  if ! yesno "Install Bedrock $selected_version?

Your current worlds/, server.properties, and settings will be preserved.
The server will be temporarily stopped during installation."; then
    return
  fi

  install_version "$download_url" "$selected_version"
}

# ──────────────────────────────────────────────
# Menu
# ──────────────────────────────────────────────
menu_versions() {
  local choice
  choice=$(show_menu "Versions — Installed: ${CURRENT_VERSION:-none}" \
    "1" "Install Latest" \
    "2" "Install Specific Version" \
    "3" "Back")

  case "$choice" in
    1) install_latest ;;
    2) install_specific ;;
    *) return ;;
  esac
}

# ──────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────
if [[ "$1" == "install_latest" ]]; then
  # Non-interactive mode for first-run
  install_latest
else
  menu_versions
fi
