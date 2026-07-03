#!/bin/bash
#
# 02_install_bedrock_server.sh
# Creates the /opt/mcbedrock folder structure and downloads the latest
# Minecraft Bedrock Dedicated Server.
# Run as root or with sudo.

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)."
  exit 1
fi

INSTALL_ROOT="/opt/mcbedrock"
SERVER_DIR="$INSTALL_ROOT/server"

echo "=== Creating /opt/mcbedrock folder structure ==="

mkdir -p "$INSTALL_ROOT"/{setup,scripts,config,server,backups,logs}

# Create a placeholder server.properties so Bedrock doesn't fail on first run
if [[ ! -f "$SERVER_DIR/server.properties" ]]; then
  cat > "$SERVER_DIR/server.properties" << 'PROPS'
server-name=Minecraft Bedrock Server
gamemode=survival
difficulty=easy
allow-cheats=false
max-players=10
online-mode=true
white-list=false
server-port=19132
server-portv6=19133
view-distance=32
tick-distance=4
player-idle-timeout=30
max-threads=8
level-name=Bedrock level
level-seed=
default-player-permission-level=member
texturepack-required=false
content-log-file-enabled=false
compression-threshold=1
server-authoritative-movement=server-short-tick
enable-lan-visibility=false
PROPS
fi

echo ""
echo "=== Folder structure created ==="
echo "$INSTALL_ROOT"
ls -la "$INSTALL_ROOT"

echo ""
echo "=== Downloading latest Bedrock Dedicated Server ==="

API_URL="https://net-secondary.web.minecraft-services.net/api/v1.0/download/links"
DOWNLOAD_URL=$(curl -sL "$API_URL" | jq -r '.result.links[] | select(.downloadType == "serverBedrockLinux") | .downloadUrl')

if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
  echo "ERROR: Could not find download URL from API."
  exit 1
fi

echo "Download URL: $DOWNLOAD_URL"

cd "$SERVER_DIR"
wget -O bedrock-server.zip "$DOWNLOAD_URL"

echo "Extracting..."
unzip -o bedrock-server.zip
rm bedrock-server.zip

chmod +x bedrock_server

# Extract version from the zip filename (e.g. bedrock-server-1.26.32.2.zip)
INSTALLED_VERSION=$(echo "$DOWNLOAD_URL" | grep -oP '\d+\.\d+\.\d+\.\d+')

# Write version to config
if [[ -n "$INSTALLED_VERSION" ]]; then
  CONFIG_FILE="$INSTALL_ROOT/config/mc.conf"
  if grep -q "^CURRENT_VERSION=" "$CONFIG_FILE" 2>/dev/null; then
    sed -i "s|^CURRENT_VERSION=.*|CURRENT_VERSION=${INSTALLED_VERSION}|" "$CONFIG_FILE"
  else
    echo "CURRENT_VERSION=${INSTALLED_VERSION}" >> "$CONFIG_FILE"
  fi
fi

echo ""
echo "=== Bedrock server installed successfully ==="
echo "Version: ${INSTALLED_VERSION:-unknown}"
