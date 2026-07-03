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
echo ""

# ──────────────────────────────────────────────
# Always allow SSH first (critical before enabling)
# ──────────────────────────────────────────────
echo "Allowing SSH (port 22/tcp)..."
ufw allow 22/tcp

# ──────────────────────────────────────────────
# Minecraft Bedrock ports
# ──────────────────────────────────────────────
echo "Allowing Minecraft Bedrock game traffic (19132/udp)..."
ufw allow 19132/udp

echo "Allowing Minecraft Bedrock query (19132/tcp)..."
ufw allow 19132/tcp

# ──────────────────────────────────────────────
# Rate limiting for SSH brute force protection
# ──────────────────────────────────────────────
echo "Enabling SSH rate limiting..."
ufw limit 22/tcp

# ──────────────────────────────────────────────
# Enable firewall
# ──────────────────────────────────────────────
echo "Enabling firewall..."
ufw --force enable

echo ""
echo "=== Firewall status ==="
ufw status verbose

echo ""
echo "============================================="
echo "IMPORTANT: If using DigitalOcean (or any VPS"
echo "with a cloud firewall), ufw is NOT enough!"
echo ""
echo "You MUST also add these rules in the"
echo "DigitalOcean Cloud Firewall / VPS dashboard:"
echo ""
echo "  → Inbound Rules:"
echo "      UDP  19132  (Minecraft Bedrock game)"
echo "      TCP  19132  (Minecraft query)"
echo "      TCP  22     (SSH)"
echo ""
echo "  → Outbound Rules: allow all"
echo "============================================="
