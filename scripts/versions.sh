#!/bin/bash
#
# versions.sh — Check for Bedrock updates and install latest if available.
# Usage: versions.sh          → interactive check-for-update
#        versions.sh install  → non-interactive install (first-run)

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

API_URL="https://net-secondary.web.minecraft-services.net/api/v1.0/download/links"

fetch_latest_url() {
  local json
  json=$(curl -sL "$API_URL")
  local url
  url=$(echo "$json" | jq -r '.result.links[] | select(.downloadType == "serverBedrockLinux") | .downloadUrl')
  echo "$url"
}

version_from_url() {
  echo "$1" | grep -oP '\d+\.\d+\.\d+\.\d+'
}

install_version() {
  local url="$1"
  local version="$2"
  local was_running=false

  if server_is_running; then
    was_running=true
    echo "  Stopping server..."
    systemctl stop "$SERVICE_NAME"
    sleep 2
  fi

  echo "  Downloading Bedrock $version..."
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"

  if ! wget -O bedrock-server.zip "$url" 2>/dev/null; then
    echo "  ✗ Download failed."
    log_error "Download failed: $url"
    cd /; rm -rf "$tmp_dir"
    return 1
  fi

  echo "  Extracting..."
  local world_backup
  world_backup=$(mktemp -d)
  for item in worlds server.properties whitelist.json permissions.json; do
    [[ -e "$SERVER_DIR/$item" ]] && cp -r "$SERVER_DIR/$item" "$world_backup/"
  done

  unzip -o bedrock-server.zip -d "$SERVER_DIR/" 2>/dev/null
  chmod +x "$SERVER_DIR/bedrock_server"

  for item in worlds server.properties whitelist.json permissions.json; do
    [[ -e "$world_backup/$item" ]] && rm -rf "$SERVER_DIR/$item" && cp -r "$world_backup/$item" "$SERVER_DIR/"
  done

  cd /; rm -rf "$tmp_dir" "$world_backup"
  write_config "CURRENT_VERSION" "$version"
  log_info "Updated to version $version"

  if $was_running; then
    systemctl start "$SERVICE_NAME"
    sleep 2
  fi

  echo ""
  echo "  ✓ Updated to Bedrock $version"
  echo "  Your worlds and settings were preserved."
}

check_update() {
  echo "  Checking for updates..."

  local url
  url=$(fetch_latest_url)
  if [[ -z "$url" ]]; then
    echo "  ✗ Could not fetch latest version info."
    echo "  Check your internet connection."
    return
  fi

  local latest_ver
  latest_ver=$(version_from_url "$url")
  local current="${CURRENT_VERSION}"

  if [[ -z "$current" ]]; then
    echo "  No version currently installed."
    read -r -p "  Install Bedrock $latest_ver? (Y/n): " yn
    if [[ "$yn" != "n" && "$yn" != "N" ]]; then
      install_version "$url" "$latest_ver"
    fi
    return
  fi

  echo "  Current:  $current"
  echo "  Latest:   $latest_ver"
  echo ""

  if [[ "$current" == "$latest_ver" ]]; then
    echo "  ✓ You're on the latest version."
    return
  fi

  local greater
  greater=$(printf '%s\n' "$current" "$latest_ver" | sort -V | tail -1)
  if [[ "$greater" != "$current" ]]; then
    echo "  A new version is available!"
    read -r -p "  Update to $latest_ver? (y/N): " yn
    if [[ "$yn" == "y" || "$yn" == "Y" ]]; then
      install_version "$url" "$latest_ver"
    else
      echo "  Skipped."
    fi
  else
    echo "  Your version is ahead of the latest release."
    echo "  (You may be on a preview build.)"
  fi
}

# ──────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────
if [[ "$1" == "install" ]]; then
  local url
  url=$(fetch_latest_url)
  if [[ -z "$url" ]]; then
    echo "ERROR: Could not fetch latest version."
    exit 1
  fi
  local version
  version=$(version_from_url "$url")
  install_version "$url" "$version"
else
  check_update
fi
