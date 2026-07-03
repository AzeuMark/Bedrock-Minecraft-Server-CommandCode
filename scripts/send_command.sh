#!/bin/bash
#
# send_command.sh — Send a command to the Minecraft server console.
# Usage: send_command.sh "<command>"
# Examples:
#   send_command.sh "say Hello everyone!"
#   send_command.sh "stop"
#   send_command.sh "list"
#   send_command.sh "kick PlayerName"
#   send_command.sh "time set day"

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
