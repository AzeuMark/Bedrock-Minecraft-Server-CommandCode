#!/bin/bash
#
# 01_install_dependencies.sh
# Installs all required packages for the Minecraft Bedrock Server Manager.
# Run as root or with sudo.

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)."
  exit 1
fi

echo "=== Installing dependencies ==="

apt update

# whiptail — for the TUI menus
# rclone — for Google Drive backups
# curl, wget — for downloading Bedrock server
# unzip — Bedrock server comes as a zip
# jq — for parsing version JSON (if we cache versions)
# systemd — should already be present on Ubuntu
apt install -y whiptail rclone curl wget unzip jq systemd

echo ""
echo "=== Dependencies installed successfully ==="
echo "whiptail, rclone, curl, wget, unzip, jq, systemd"
