#!/bin/bash
#
# 06_setup_swap.sh — Creates a 2 GB swap file to prevent OOM crashes.
# Run as root or with sudo.

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)."
  exit 1
fi

SWAPFILE="/swapfile"

if [[ -f "$SWAPFILE" ]]; then
  echo "Swap file already exists at $SWAPFILE."
  read -r -p "Recreate it? (y/N): " recreate
  if [[ "$recreate" != "y" && "$recreate" != "Y" ]]; then
    echo "Skipping."
    exit 0
  fi
  swapoff "$SWAPFILE" 2>/dev/null || true
fi

echo "Allocating 2 GB swap file..."
fallocate -l 2G "$SWAPFILE"

echo "Setting permissions (root only)..."
chmod 600 "$SWAPFILE"

echo "Formatting as swap..."
mkswap "$SWAPFILE"

echo "Activating swap..."
swapon "$SWAPFILE"

if grep -q "$SWAPFILE" /etc/fstab 2>/dev/null; then
  echo "Swap entry already in /etc/fstab."
else
  echo "Adding to /etc/fstab for persistence across reboots..."
  echo "$SWAPFILE none swap sw 0 0" | tee -a /etc/fstab
fi

echo ""
echo "=== Swap setup complete ==="
free -h | grep -i swap
