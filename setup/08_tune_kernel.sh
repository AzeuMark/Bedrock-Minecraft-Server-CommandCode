#!/bin/bash
#
# 08_tune_kernel.sh — Optimizes kernel network settings for game server TPS.
# Run as root or with sudo.

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)."
  exit 1
fi

SYSCTL_FILE="/etc/sysctl.d/99-mcbedrock.conf"

echo "=== Tuning kernel for game server performance ==="

cat > "$SYSCTL_FILE" << 'SYSCTL'
# ──────────────────────────────────────────────
# Minecraft Bedrock Server — Kernel Optimizations
# ──────────────────────────────────────────────

# Network — reduce latency, increase throughput
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Reduce TIME_WAIT socket backlog
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1

# Increase max backlog for incoming connections
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 1024

# Enable TCP keepalive for faster dead connection detection
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3

# UDP buffer tuning (critical for Bedrock — uses UDP)
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# Reduce swappiness — prefer keeping game data in RAM
vm.swappiness = 10

# Increase max file descriptors for the server
fs.file-max = 65535
SYSCTL

sysctl --system -q

echo ""
echo "=== Kernel tuning applied ==="
echo "Settings saved to $SYSCTL_FILE (persistent across reboots)"
echo ""
echo "Tuning includes:"
echo "  - BBR congestion control (lower latency)"
echo "  - UDP buffer tuning (Bedrock uses UDP)"
echo "  - swappiness=10 (keep data in RAM, not swap)"
echo "  - Higher connection backlog"
echo "  - TCP keepalive — faster dead connection detection"
