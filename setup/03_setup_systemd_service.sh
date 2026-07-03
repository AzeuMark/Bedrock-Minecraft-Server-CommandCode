#!/bin/bash
#
# 03_setup_systemd_service.sh
# Creates the mcbedrock systemd service (with FIFO for console commands),
# server.state flag, default config, and send_command.sh.
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
WRAPPER="$INSTALL_ROOT/scripts/bedrock_wrapper.sh"
SEND_CMD="$INSTALL_ROOT/scripts/send_command.sh"

echo ""
echo "=== Creating server.state flag ==="
mkdir -p "$CONFIG_DIR"
echo "OFF" > "$CONFIG_DIR/server.state"
chmod 644 "$CONFIG_DIR/server.state"

echo ""
echo "=== Creating config file ==="
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/mc.conf" ]]; then
  cat > "$CONFIG_DIR/mc.conf" << 'CONF'
INSTALL_DIR=/opt/mcbedrock/server
CURRENT_VERSION=
AUTO_BACKUP_TIMEZONE=
AUTO_BACKUP_HOUR=
AUTO_BACKUP_AMPM=
CONF
fi

echo ""
echo "=== Creating console FIFO ==="
rm -f "$FIFO_PATH"
mkfifo -m 666 "$FIFO_PATH"
echo "FIFO created at $FIFO_PATH"

echo ""
echo "=== Creating bedrock wrapper ==="
cat > "$WRAPPER" << 'WRAP'
#!/bin/bash
# bedrock_wrapper.sh — Runs bedrock_server with a FIFO connected to stdin.
# The FIFO is opened in read-write mode so it never blocks or gets EOF.
# Send commands via: echo "command" > /opt/mcbedrock/server/console.fifo

FIFO="/opt/mcbedrock/server/console.fifo"

# Create FIFO if it doesn't exist
[[ -p "$FIFO" ]] || mkfifo -m 666 "$FIFO" 2>/dev/null || true

# Open FIFO for read-write on fd 3, then redirect stdin from it
# The read-write open prevents EOF from closing the pipe,
# so multiple commands can be sent sequentially
exec 3<>"$FIFO"

cd /opt/mcbedrock/server
export LD_LIBRARY_PATH=.
exec ./bedrock_server <&3
WRAP
chmod +x "$WRAPPER"
echo "Wrapper created at $WRAPPER"

echo ""
echo "=== Creating send_command.sh ==="
cat > "$SEND_CMD" << 'SEND'
#!/bin/bash
# send_command.sh — Send a command to the Minecraft server console.
# Usage: send_command.sh "<command>"
# Examples:
#   send_command.sh "say Hello everyone!"
#   send_command.sh "stop"
#   send_command.sh "list"
#   send_command.sh "kick PlayerName"

FIFO="/opt/mcbedrock/server/console.fifo"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 \"<command>\""
  echo "Example: $0 \"say Hello\""
  exit 1
fi

if [[ ! -p "$FIFO" ]]; then
  echo "Console FIFO not found (server may not be running)."
  exit 1
fi

echo "$1" > "$FIFO"
echo "✓ Command sent: $1"
SEND
chmod +x "$SEND_CMD"
echo "Send-command script created at $SEND_CMD"

echo ""
echo "=== Creating systemd service unit ==="
mkdir -p "$LOGS_DIR"

cat > "$SERVICE_FILE" << 'UNIT'
[Unit]
Description=Minecraft Bedrock Dedicated Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mcbedrock/server
Environment=LD_LIBRARY_PATH=.
ExecStart=/opt/mcbedrock/scripts/bedrock_wrapper.sh
ExecStop=/opt/mcbedrock/scripts/send_command.sh stop
StandardOutput=append:/opt/mcbedrock/logs/server.log
StandardError=append:/opt/mcbedrock/logs/server.log
Restart=on-failure
RestartSec=10
StandardInput=null

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
echo "Send commands to the server console via:"
echo "  send_command.sh \"say Hello\""
echo "  send_command.sh \"stop\""
echo "  send_command.sh \"list\""
echo ""
echo "NOTE: If using DigitalOcean, add UDP 19132 in the cloud firewall."
