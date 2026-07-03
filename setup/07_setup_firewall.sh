#!/bin/bash
#
# 07_setup_firewall.sh — Configures ufw for Bedrock server.
# Opens ports 22 (SSH), 19132/udp (game), 19132/tcp (query).
# Run as root or with sudo.

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)."
  exit 1
fi

echo "=== Configuring firewall (ufw) ==="

ufw allow 22/tcp
ufw allow 19132/udp
ufw allow 19132/tcp

ufw --force enable

echo ""
echo "=== Firewall status ==="
ufw status verbose
