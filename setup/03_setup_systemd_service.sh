#!/bin/bash
#
# 03_setup_systemd_service.sh
# Creates the mcbedrock systemd service unit, the console FIFO,
# the server.state flag, and default config.
# Run as root or with sudo.

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)."
  exit 1
fi

INSTALL_ROOT="/opt/mcbedrock"
SERVER_DIR="$INSTALL_ROOT/server"
CONFIG_DIR="$INSTALL_ROOT/config"
LOGS_DIR="$INSTALL_ROOT/logs"
FIFO_PATH="$SERVER_DIR/console.fifo"
SERVICE_FILE="/etc/systemd/system/mcbedrock.service"

echo "=== Creating console FIFO ==="

# Remove existing FIFO if stale
if [[ -e "$FIFO_PATH" ]]; then
  rm -f "$FIFO_PATH"
fi
mkfifo "$FIFO_PATH"
chmod 666 "$FIFO_PATH"

echo "FIFO created at $FIFO_PATH"

echo ""
echo "=== Creating server.state flag ==="

echo "OFF" > "$CONFIG_DIR/server.state"
chmod 644 "$CONFIG_DIR/server.state"
echo "State file created at $CONFIG_DIR/server.state (initial: OFF)"

echo ""
echo "=== Creating config file ==="

if [[ ! -f "$CONFIG_DIR/mc.conf" ]]; then
  cat > "$CONFIG_DIR/mc.conf" << 'CONF'
INSTALL_DIR=/opt/mcbedrock/server
CURRENT_VERSION=
AUTO_BACKUP_TIMEZONE=
AUTO_BACKUP_HOUR=
AUTO_BACKUP_AMPM=
CONF
  echo "Default config created at $CONFIG_DIR/mc.conf"
fi

echo ""
echo "=== Creating systemd service unit ==="

cat > "$SERVICE_FILE" << 'UNIT'
[Unit]
Description=Minecraft Bedrock Dedicated Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mcbedrock/server
ExecStart=/opt/mcbedrock/server/bedrock_server
StandardInput=file:/opt/mcbedrock/server/console.fifo
StandardOutput=append:/opt/mcbedrock/logs/server.log
StandardError=append:/opt/mcbedrock/logs/server.log
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT

chmod 644 "$SERVICE_FILE"

echo "Service unit created at $SERVICE_FILE"

echo ""
echo "=== Reloading systemd daemon ==="

systemctl daemon-reload

echo ""
echo "=== Setup complete ==="
echo "Service: mcbedrock"
echo "Status: $(systemctl is-active mcbedrock 2>/dev/null || echo 'inactive')"
echo "Auto-start on boot: $(systemctl is-enabled mcbedrock 2>/dev/null || echo 'disabled')"
echo ""
echo "You can now start the server using the 'mc' menu or:"
echo "  systemctl start mcbedrock"
