# Minecraft Bedrock Server Manager

A terminal dashboard for managing a Minecraft Bedrock Dedicated Server on Ubuntu. Type `mc` to open it.

---

## Quick Start

### Option 1 — Step by step

<details>
<summary>Click to expand</summary>

**Clone the repo:**

```bash
cd; rm -rf /opt/mcbedrock; git clone https://github.com/AzeuMark/Bedrock-Minecraft-Server-CommandCode.git /opt/mcbedrock; cd /opt/mcbedrock; chmod +x setup/*.sh scripts/*.sh
```

**Install dependencies + Bedrock server + systemd service + menu command:**

```bash
sudo ./setup/01_install_dependencies.sh && sudo ./setup/02_install_bedrock_server.sh && sudo ./setup/03_setup_systemd_service.sh && sudo ./setup/04_setup_menu_command.sh
```

**Google Drive backup setup:**

```bash
sudo ./setup/05_setup_gdrive.sh
```

**2GB swap file (prevents OOM crashes):**

```bash
sudo ./setup/06_setup_swap.sh
```

**Firewall (opens ports 22, 19132):**

```bash
sudo ./setup/07_setup_firewall.sh
```

**Kernel tuning (BBR, UDP buffers — better TPS):**

```bash
sudo ./setup/08_tune_kernel.sh
```

**Open the menu:**

```bash
mc
```

</details>

### Option 2 — One-shot setup (copy-paste the whole thing)

This does everything automatically — clone, install dependencies, download Bedrock, set up systemd, install the `mc` command, swap, firewall, and kernel tuning:

```bash
cd; rm -rf /opt/mcbedrock; git clone https://github.com/AzeuMark/Bedrock-Minecraft-Server-CommandCode.git /opt/mcbedrock; cd /opt/mcbedrock; chmod +x setup/*.sh scripts/*.sh && sudo ./setup/01_install_dependencies.sh && sudo ./setup/02_install_bedrock_server.sh && sudo ./setup/03_setup_systemd_service.sh && sudo ./setup/04_setup_menu_command.sh && sudo ./setup/06_setup_swap.sh && sudo ./setup/07_setup_firewall.sh && sudo ./setup/08_tune_kernel.sh
```

Then optionally set up Google Drive:

```bash
sudo ./setup/05_setup_gdrive.sh
```

Then open the menu:

```bash
mc
```

---

## IMPORTANT — Allow UDP 19132 in your VPS dashboard

ufw is **not enough** if you use DigitalOcean, Linode, Vultr, or any VPS with a cloud firewall.

Add these inbound rules in your VPS dashboard:

| Port | Protocol | Purpose |
|------|----------|---------|
| 19132 | **UDP** | Game traffic — required to join |
| 19132 | TCP | Server query (shows in friends list) |
| 22 | TCP | SSH access |

Without **UDP 19132** no one can connect.

---

## Update to latest

```bash
cd; rm -rf /opt/mcbedrock; git clone https://github.com/AzeuMark/Bedrock-Minecraft-Server-CommandCode.git /opt/mcbedrock; cd /opt/mcbedrock; chmod +x setup/*.sh scripts/*.sh && sudo ./setup/03_setup_systemd_service.sh && sudo ./setup/07_setup_firewall.sh && sudo ./setup/08_tune_kernel.sh
```

---

## Troubleshooting — Why you couldn't connect

1. **Cloud firewall** blocks UDP 19132 — add it in your VPS dashboard
2. **online-mode** — changed to `false` so Xbox Live auth isn't required
3. **view-distance** — lowered from 32 to 10 for better TPS
4. **Kernel tuning** — `08_tune_kernel.sh` enables BBR + UDP buffers

Check server status:

```bash
journalctl -u mcbedrock -n 20 && sudo ufw status verbose
```

---

## File reference

### Setup scripts

| File | Description |
|------|-------------|
| `01_install_dependencies.sh` | Installs `unzip`, `curl`, `wget`, `jq`, `libssl-dev` |
| `02_install_bedrock_server.sh` | Creates folders, downloads latest Bedrock from Mojang API, extracts it, writes `server.properties` |
| `03_setup_systemd_service.sh` | Creates `mcbedrock` systemd service, `server.state` flag |
| `04_setup_menu_command.sh` | Symlinks `/usr/local/bin/mc` → the menu |
| `05_setup_gdrive.sh` | rclone Google Drive config (paste token from PC) |
| `06_setup_swap.sh` | 2GB swap file |
| `07_setup_firewall.sh` | ufw — ports 22, 19132/udp, 19132/tcp |
| `08_tune_kernel.sh` | BBR, UDP buffers, swappiness=10 |

### Menu scripts

| File | Description |
|------|-------------|
| `common.sh` | Shared helpers — paths, state, config, status gatherers |
| `mc-menu.sh` | Dashboard entry point |
| `server_actions.sh` | Start / Stop / Restart |
| `logs.sh` | Live tail or last 500 lines |
| `versions.sh` | Check for Bedrock updates |
| `backup_now.sh` | Manual backup to Google Drive |
| `backup_restore.sh` | Restore from Drive (with validation) |
| `backup_auto.sh` | Schedule automatic backups (interval + timezone) |
| `gdrive_setup.sh` | Re-run Google Drive setup from menu |

### Folder structure

```
/opt/mcbedrock/
├── setup/           # 01–08, run once
├── scripts/         # Called by the menu
├── config/          # mc.conf, server.state
├── server/          # bedrock_server, worlds/, server.properties
├── backups/         # Temp (deleted after Drive upload)
└── logs/            # server.log, mcbedrock-manager.log
```

## How the safety flag works

| Action | server.state | Auto-start on boot |
|--------|-------------|-------------------|
| START SERVER | ON | enabled |
| STOP SERVER | OFF | disabled |
| VPS reboot | — | only if state was ON |

## Manual commands

```bash
systemctl start|stop|restart mcbedrock
journalctl -u mcbedrock -f
systemctl status mcbedrock
sudo ufw status verbose
sudo rclone authorize "drive"
```

---

## Source Code

<details>
<summary>setup/01_install_dependencies.sh</summary>

```bash
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

apt install -y whiptail rclone curl wget unzip jq libssl-dev

echo ""
echo "=== Dependencies installed successfully ==="
echo "whiptail, rclone, curl, wget, unzip, jq, libssl-dev"
```
</details>

<details>
<summary>setup/02_install_bedrock_server.sh</summary>

```bash
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
online-mode=false
white-list=false
server-port=19132
server-portv6=19133
view-distance=10
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
```
</details>

<details>
<summary>setup/03_setup_systemd_service.sh</summary>

```bash
#!/bin/bash
#
# 03_setup_systemd_service.sh
# Creates the mcbedrock systemd service unit, the server.state flag,
# and default config. Run as root or with sudo.

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)."
  exit 1
fi

INSTALL_ROOT="/opt/mcbedrock"
SERVER_DIR="$INSTALL_ROOT/server"
CONFIG_DIR="$INSTALL_ROOT/config"
LOGS_DIR="$INSTALL_ROOT/logs"
SERVICE_FILE="/etc/systemd/system/mcbedrock.service"

echo ""
echo "=== Creating server.state flag ==="
mkdir -p "$CONFIG_DIR"
echo "OFF" > "$CONFIG_DIR/server.state"
chmod 644 "$CONFIG_DIR/server.state"
echo "State file created at $CONFIG_DIR/server.state (initial: OFF)"

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
  echo "Default config created at $CONFIG_DIR/mc.conf"
fi

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
ExecStart=/opt/mcbedrock/server/bedrock_server
StandardOutput=append:/opt/mcbedrock/logs/server.log
StandardError=append:/opt/mcbedrock/logs/server.log
Restart=on-failure
RestartSec=5
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
echo "You can now start the server using the 'mc' menu or:"
echo "  systemctl start mcbedrock"
echo ""
echo "NOTE: If using DigitalOcean, you MUST also allow port 19132/udp"
echo "in the DigitalOcean Cloud Firewall section of your dashboard."
echo ""
echo "  → Go to: Networking → Firewalls → Edit → Inbound Rules"
echo "  → Add: Custom UDP port 19132"
```
</details>

<details>
<summary>setup/04_setup_menu_command.sh</summary>

```bash
#!/bin/bash
#
# 04_setup_menu_command.sh
# Installs the `mc` and `minecraft` commands system-wide by symlinking
# to the mc-menu.sh script.
# Run as root or with sudo.

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)."
  exit 1
fi

MENU_SCRIPT="/opt/mcbedrock/scripts/mc-menu.sh"
LINK1="/usr/local/bin/mc"
LINK2="/usr/local/bin/minecraft"

echo "=== Installing 'mc' and 'minecraft' commands ==="

if [[ ! -f "$MENU_SCRIPT" ]]; then
  echo "ERROR: $MENU_SCRIPT not found. Run setup scripts in order."
  exit 1
fi

chmod +x "$MENU_SCRIPT"

ln -sf "$MENU_SCRIPT" "$LINK1"
ln -sf "$MENU_SCRIPT" "$LINK2"

echo "Created symlinks:"
echo "  $LINK1 -> $MENU_SCRIPT"
echo "  $LINK2 -> $MENU_SCRIPT"

echo ""
echo "=== Done ==="
echo "You can now type 'mc' or 'minecraft' anywhere to open the server manager."
```
</details>

<details>
<summary>setup/05_setup_gdrive.sh</summary>

```bash
#!/bin/bash
#
# 05_setup_gdrive.sh
# Configures rclone with a Google Drive remote for backups.
# You provide the config_token obtained by running:
#   rclone authorize "drive"
# on your Windows/Mac PC (which has a browser).
# Run as root or with sudo.

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)."
  exit 1
fi

REMOTE_NAME="gdrive"

# Check if already configured
if rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:"; then
  echo "Google Drive remote '$REMOTE_NAME' already configured."
  echo ""
  read -r -p "Reconfigure? (y/N): " reconf
  if [[ "$reconf" != "y" && "$reconf" != "Y" ]]; then
    echo "Skipping."
    exit 0
  fi
  rclone config delete "$REMOTE_NAME" 2>/dev/null || true
fi

echo ""
echo "=== Google Drive Setup (rclone) ==="
echo ""
echo "To get your config_token, run this on your Windows/Mac PC (with a browser):"
echo ""
echo "  rclone authorize \"drive\""
echo ""
echo "This will open a browser window asking you to log into Google and grant"
echo "permissions. After you accept, the terminal will show a JSON token."
echo ""
echo "Paste that JSON token below (looks like: {\"access_token\":\"ya29...\"})"
echo ""

read -r -p "config_token: " CONFIG_TOKEN

if [[ -z "$CONFIG_TOKEN" ]]; then
  echo "ERROR: No token provided. Aborting."
  exit 1
fi

# Create rclone config non-interactively
rclone config create "$REMOTE_NAME" drive \
  --quiet \
  --non-interactive \
  --all \
  config_token="$CONFIG_TOKEN"

echo ""
if rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:"; then
  echo "✓ Google Drive remote '$REMOTE_NAME' configured successfully."
  echo "Backups will be stored in: ${REMOTE_NAME}:Minecraft/Backups/"

  # Create the backups folder on Drive to verify connectivity
  echo "Testing connection..."
  rclone mkdir "${REMOTE_NAME}:Minecraft/Backups" 2>/dev/null
  echo "✓ Connection verified."
else
  echo "ERROR: Configuration failed. Check your token and try again."
  exit 1
fi
```
</details>

<details>
<summary>setup/06_setup_swap.sh</summary>

```bash
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
```
</details>

<details>
<summary>setup/07_setup_firewall.sh</summary>

```bash
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
```
</details>

<details>
<summary>setup/08_tune_kernel.sh</summary>

```bash
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
```
</details>

<details>
<summary>scripts/common.sh</summary>

```bash
#!/bin/bash
#
# common.sh — Shared paths, state management, config loader, and helpers.
# Source this from any other script:  source "$(dirname "$(readlink -f "$0")")/common.sh"

# ──────────────────────────────────────────────
# Paths
# ──────────────────────────────────────────────
INSTALL_ROOT="/opt/mcbedrock"
SCRIPTS_DIR="$INSTALL_ROOT/scripts"
SERVER_DIR="$INSTALL_ROOT/server"
CONFIG_DIR="$INSTALL_ROOT/config"
BACKUPS_DIR="$INSTALL_ROOT/backups"
LOGS_DIR="$INSTALL_ROOT/logs"
SETUP_DIR="$INSTALL_ROOT/setup"

CONFIG_FILE="$CONFIG_DIR/mc.conf"
STATE_FILE="$CONFIG_DIR/server.state"
SERVICE_NAME="mcbedrock"
LOG_FILE="$LOGS_DIR/server.log"

GDRIVE_REMOTE="gdrive"
GDRIVE_BACKUPS_PATH="${GDRIVE_REMOTE}:Minecraft/Backups"

# ──────────────────────────────────────────────
# Default configuration values
# ──────────────────────────────────────────────
MC_CONF_DEFAULTS=(
  "INSTALL_DIR=$SERVER_DIR"
  "CURRENT_VERSION="
  "AUTO_BACKUP_TIMEZONE="
  "AUTO_BACKUP_HOUR="
  "AUTO_BACKUP_AMPM="
)

# ──────────────────────────────────────────────
# Load / init config file
# ──────────────────────────────────────────────
load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    for pair in "${MC_CONF_DEFAULTS[@]}"; do
      echo "$pair"
    done > "$CONFIG_FILE"
  fi
  source "$CONFIG_FILE"
}

# ──────────────────────────────────────────────
# Write a single key=value to config file
# ──────────────────────────────────────────────
write_config() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
  else
    echo "${key}=${value}" >> "$CONFIG_FILE"
  fi
}

# ──────────────────────────────────────────────
# State file management
# ──────────────────────────────────────────────
state_is_on() {
  [[ -f "$STATE_FILE" && "$(cat "$STATE_FILE")" == "ON" ]]
}

state_is_off() {
  ! state_is_on
}

state_set_on() {
  echo "ON" > "$STATE_FILE"
}

state_set_off() {
  echo "OFF" > "$STATE_FILE"
}

# ──────────────────────────────────────────────
# Server binary detection
# ──────────────────────────────────────────────
is_server_installed() {
  [[ -x "$SERVER_DIR/bedrock_server" ]]
}

# ──────────────────────────────────────────────
# rclone remote check
# ──────────────────────────────────────────────
is_gdrive_connected() {
  rclone listremotes 2>/dev/null | grep -q "^${GDRIVE_REMOTE}:"
}

# ──────────────────────────────────────────────
# Systemd wrapper
# ──────────────────────────────────────────────
server_is_running() {
  systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null
}

# ──────────────────────────────────────────────
# Dashboard info gatherers
# ──────────────────────────────────────────────
get_status_icon() {
  if server_is_running; then
    echo "●"
  else
    echo "○"
  fi
}

get_status_text() {
  if server_is_running; then
    echo "RUNNING"
  else
    echo "STOPPED"
  fi
}

get_server_version() {
  echo "${CURRENT_VERSION:-not set}"
}

get_ram_usage() {
  local pid
  pid=$(systemctl show -p MainPID "$SERVICE_NAME" 2>/dev/null | cut -d= -f2)
  if [[ -n "$pid" && "$pid" -gt 1 ]]; then
    local rss
    rss=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')
    if [[ -n "$rss" ]]; then
      if (( rss > 1048576 )); then
        echo "$(echo "scale=1; $rss/1048576" | bc)G"
      elif (( rss > 1024 )); then
        echo "$(echo "scale=1; $rss/1024" | bc)M"
      else
        echo "${rss}K"
      fi
    else
      echo "N/A"
    fi
  else
    echo "N/A"
  fi
}

get_server_ip() {
  ip -4 addr show | grep -oP 'inet \K[\d.]+' | grep -v '^127\.' | head -1
}

get_server_port() {
  local port
  port=$(grep '^server-port=' "$SERVER_DIR/server.properties" 2>/dev/null | cut -d= -f2)
  echo "${port:-19132}"
}

get_player_count() {
  if ! server_is_running; then
    echo "0"
    return
  fi
  local log_content
  log_content=$(cat "$LOG_FILE" 2>/dev/null)
  if [[ -z "$log_content" ]]; then
    echo "0"
    return
  fi
  local connected
  connected=$(echo "$log_content" | grep -c "Player connected:" 2>/dev/null)
  local disconnected
  disconnected=$(echo "$log_content" | grep -c "Player disconnected:" 2>/dev/null)
  local count=$((connected - disconnected))
  if (( count < 0 )); then
    count=0
  fi
  echo "$count"
}

get_max_players() {
  local max
  max=$(grep '^max-players=' "$SERVER_DIR/server.properties" 2>/dev/null | cut -d= -f2)
  echo "${max:-10}"
}

# ──────────────────────────────────────────────
# Log helpers
# ──────────────────────────────────────────────
log_info() {
  echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOGS_DIR/mcbedrock-manager.log"
}

log_error() {
  echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOGS_DIR/mcbedrock-manager.log"
}

# ──────────────────────────────────────────────
# Init on source
# ──────────────────────────────────────────────
load_config
```
</details>

<details>
<summary>scripts/mc-menu.sh</summary>

```bash
#!/bin/bash
#
# mc-menu.sh — Modern terminal dashboard for Minecraft Bedrock Server Manager.
# Installed to /usr/local/bin/mc and /usr/local/bin/minecraft.
# The status panel refreshes every second while the menu stays static.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_first_run() {
  if ! is_server_installed; then
    clear
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║       🎮 MINECRAFT BEDROCK SERVER MANAGER          ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo ""; echo "  ⚠ No Minecraft Bedrock server detected."
    echo "  Let's install one first."; echo ""
    read -r -p "  Press Enter to continue..."
    bash "$SCRIPTS_DIR/versions.sh" install
    if ! is_server_installed; then
      echo ""; echo "  ✗ Installation failed."; read -r -p "  Press Enter to exit..."; exit 1
    fi
  fi
}

move_to() { printf "\033[%s;1H" "$1"; }
clear_line() { printf "\033[2K"; }

draw_static_frame() {
  clear
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║       🎮 MINECRAFT BEDROCK SERVER MANAGER          ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo ""
  echo "    status_line_1"; echo "    status_line_2"
  echo "    status_line_3"; echo "    status_line_4"
  echo "    status_line_5"; echo "    status_line_6"
  echo ""
  echo "  ═══════════════════════════════════════════════════════"
  echo ""
  echo "    1  ▶  START SERVER"
  echo "    2  ⏹  STOP SERVER"
  echo "    3  🔄  RESTART SERVER"
  echo "    4  📋  VIEW LOGS"
  echo "    5  💾  BACKUP WORLD"
  echo "    6  📡  CHECK FOR UPDATES"
  echo "    7  🚪  EXIT"
  echo ""; echo "  ═══════════════════════════════════════════════════════"
}

refresh_status_lines() {
  local icon status ver ram ip port players max_players
  icon=$(get_status_icon); status=$(get_status_text)
  ver=$(get_server_version); ram=$(get_ram_usage)
  ip=$(get_server_ip); port=$(get_server_port)
  players=$(get_player_count); max_players=$(get_max_players)
  local e="🔴"; server_is_running && e="🟢"

  move_to 6; clear_line; echo "    ${e} ${icon} Status  : ${status}"
  move_to 7; clear_line; echo "    📦 Version   : ${ver}"
  move_to 8; clear_line; echo "    🧑 Players   : ${players} / ${max_players}"
  move_to 9; clear_line; echo "    💾 RAM       : ${ram}"
  move_to 10; clear_line; echo "    🌐 IP        : ${ip}"
  move_to 11; clear_line; echo "    🔌 Port      : ${port}"
  move_to 22
}

handle_choice() {
  local choice="$1"
  case "$choice" in
    1) bash "$SCRIPTS_DIR/server_actions.sh" start; read -r -p "  Press Enter to return..." ;;
    2) bash "$SCRIPTS_DIR/server_actions.sh" stop; read -r -p "  Press Enter to return..." ;;
    3) bash "$SCRIPTS_DIR/server_actions.sh" restart; read -r -p "  Press Enter to return..." ;;
    4) trap '' INT; bash "$SCRIPTS_DIR/logs.sh" tail; trap - INT; draw_static_frame ;;
    5) backup_menu ;;
    6) bash "$SCRIPTS_DIR/versions.sh"; echo ""; read -r -p "  Press Enter to return..." ;;
    7) clear; echo ""; echo "  👋 Goodbye!"; echo ""; exit 0 ;;
  esac
  draw_static_frame; refresh_status_lines
}

backup_menu() {
  if ! is_gdrive_connected; then
    clear
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║          💾 BACKUP WORLD                            ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo ""; echo "  ⚠ Google Drive is not connected."; echo ""; read -r -p "  Set up now? (y/N): " g
    if [[ "$g" == "y" || "$g" == "Y" ]]; then bash "$SCRIPTS_DIR/gdrive_setup.sh"
      if ! is_gdrive_connected; then echo ""; echo "  ✗ Not completed."; read -r -p "  Enter..."; return; fi
    else return; fi
  fi
  while true; do
    clear
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║          💾 BACKUP WORLD                            ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo ""; echo "    1  📤  BACKUP    2  📥  RESTORE    3  ⏰  AUTO    4  🔙  BACK"; echo ""
    read -r -p "  Option [1-4]: " c
    case "$c" in
      1) bash "$SCRIPTS_DIR/backup_now.sh"; read -r -p "  Enter..." ;;
      2) bash "$SCRIPTS_DIR/backup_restore.sh"; read -r -p "  Enter..." ;;
      3) bash "$SCRIPTS_DIR/backup_auto.sh"; read -r -p "  Enter..." ;;
      *) return ;;
    esac
  done
}

check_first_run; draw_static_frame; refresh_status_lines
while true; do
  read -rsn1 -t1 choice; refresh_status_lines
  [[ -n "$choice" ]] && handle_choice "$choice"
done
```
</details>

<details>
<summary>scripts/server_actions.sh</summary>

```bash
#!/bin/bash
#
# server_actions.sh — Start / Stop / Restart / View Status
# Usage: server_actions.sh {start|stop|restart|status}
# Respects server.state flag.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

do_start() {
  if server_is_running; then
    echo "  Server is already running."
    return
  fi

  echo "  Starting server..."
  state_set_on
  systemctl enable "$SERVICE_NAME" 2>/dev/null
  systemctl start "$SERVICE_NAME"
  sleep 3

  if server_is_running; then
    echo "  ✓ Server started successfully."
    echo "  Auto-start on boot is now ENABLED."
    log_info "Server started, auto-start enabled."
  else
    echo "  ✗ Server failed to start."
    echo ""
    journalctl -u "$SERVICE_NAME" --no-pager -n 15 2>/dev/null
    log_error "Server start failed."
  fi
}

do_stop() {
  if ! server_is_running; then
    echo "  Server is not running."
    return
  fi
  echo "  The server has been fully stopped and will not auto-start upon VPS reboot."
  read -r -p "  Press Enter to dismiss..."
  echo "  Stopping server..."
  systemctl disable "$SERVICE_NAME" 2>/dev/null
  systemctl stop "$SERVICE_NAME" 2>/dev/null
  local waited=0
  while server_is_running && [[ $waited -lt 15 ]]; do sleep 1; waited=$((waited + 1)); done
  if server_is_running; then systemctl kill "$SERVICE_NAME" --signal=SIGKILL 2>/dev/null; sleep 1; fi
  state_set_off
  echo "  ✓ Server stopped. Auto-start on boot is now DISABLED."
  log_info "Server stopped, auto-start disabled."
}

do_restart() {
  if ! server_is_running; then
    echo "  Server is not running. Use START SERVER first."
    return
  fi
  echo "  Restarting server..."
  systemctl restart "$SERVICE_NAME"
  sleep 3
  if server_is_running; then
    echo "  ✓ Server restarted successfully."
    log_info "Server restarted."
  else
    echo "  ✗ Restart failed. Check logs."
    log_error "Server restart failed."
  fi
}

do_status() {
  if server_is_running; then echo "Running"; else echo "Stopped"; fi
}

case "${1:-menu}" in
  start) do_start ;;
  stop) do_stop ;;
  restart) do_restart ;;
  status) do_status ;;
  *) echo "Usage: $0 {start|stop|restart|status}"; exit 1 ;;
esac
```
</details>

<details>
<summary>scripts/logs.sh</summary>

```bash
#!/bin/bash
#
# logs.sh — View server logs.
# Usage: logs.sh {tail|last500}

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

do_tail() {
  if ! server_is_running; then
    echo "  Server is not running. Nothing to tail."
    read -r -p "  Press Enter to return..."
    return
  fi
  clear
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║          LIVE LOG — Press Ctrl+C to exit            ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo ""
  tail -f "$LOG_FILE"
}

do_tail
```
</details>

<details>
<summary>scripts/versions.sh</summary>

```bash
#!/bin/bash
#
# versions.sh — Check for Bedrock updates and install latest if available.
# Usage: versions.sh          → interactive check-for-update
#        versions.sh install  → non-interactive install (first-run)

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

API_URL="https://net-secondary.web.minecraft-services.net/api/v1.0/download/links"

fetch_latest_url() {
  local json; json=$(curl -sL "$API_URL")
  echo "$json" | jq -r '.result.links[] | select(.downloadType == "serverBedrockLinux") | .downloadUrl'
}

version_from_url() {
  echo "$1" | grep -oP '\d+\.\d+\.\d+\.\d+'
}

install_version() {
  local url="$1" version="$2" was_running=false

  if server_is_running; then
    was_running=true; echo "  Stopping server..."; systemctl stop "$SERVICE_NAME"; sleep 2
  fi

  echo "  Downloading Bedrock $version..."
  local tmp_dir; tmp_dir=$(mktemp -d); cd "$tmp_dir"
  if ! wget -O bedrock-server.zip "$url" 2>/dev/null; then
    echo "  ✗ Download failed."; log_error "Download failed: $url"; cd /; rm -rf "$tmp_dir"; return 1
  fi

  echo "  Extracting..."
  local world_backup; world_backup=$(mktemp -d)
  for item in worlds server.properties whitelist.json permissions.json; do
    [[ -e "$SERVER_DIR/$item" ]] && cp -r "$SERVER_DIR/$item" "$world_backup/"
  done

  unzip -o bedrock-server.zip -d "$SERVER_DIR/" 2>/dev/null
  chmod +x "$SERVER_DIR/bedrock_server"

  for item in worlds server.properties whitelist.json permissions.json; do
    [[ -e "$world_backup/$item" ]] && rm -rf "$SERVER_DIR/$item" && cp -r "$world_backup/$item" "$SERVER_DIR/"
  done

  cd /; rm -rf "$tmp_dir" "$world_backup"
  write_config "CURRENT_VERSION" "$version"; log_info "Updated to version $version"

  if $was_running; then systemctl start "$SERVICE_NAME"; sleep 2; fi
  echo ""; echo "  ✓ Updated to Bedrock $version"; echo "  Your worlds and settings were preserved."
}

check_update() {
  echo "  Checking for updates..."
  local url; url=$(fetch_latest_url)
  if [[ -z "$url" ]]; then echo "  ✗ Could not fetch latest version info."; return; fi

  local latest_ver; latest_ver=$(version_from_url "$url")
  local current="${CURRENT_VERSION}"

  if [[ -z "$current" ]]; then
    echo "  No version currently installed."
    read -r -p "  Install Bedrock $latest_ver? (Y/n): " yn
    [[ "$yn" != "n" && "$yn" != "N" ]] && install_version "$url" "$latest_ver"
    return
  fi

  echo "  Current:  $current"; echo "  Latest:   $latest_ver"
  if [[ "$current" == "$latest_ver" ]]; then echo "  ✓ You're on the latest version."; return; fi

  local greater; greater=$(printf '%s\n' "$current" "$latest_ver" | sort -V | tail -1)
  if [[ "$greater" != "$current" ]]; then
    echo "  A new version is available!"
    read -r -p "  Update to $latest_ver? (y/N): " yn
    [[ "$yn" == "y" || "$yn" == "Y" ]] && install_version "$url" "$latest_ver" || echo "  Skipped."
  else
    echo "  Your version is ahead of the latest release. (Preview build?)"
  fi
}

if [[ "$1" == "install" ]]; then
  local url; url=$(fetch_latest_url)
  if [[ -z "$url" ]]; then echo "ERROR: Could not fetch latest version."; exit 1; fi
  install_version "$url" "$(version_from_url "$url")"
else
  check_update
fi
```
</details>

<details>
<summary>scripts/backup_now.sh</summary>

```bash
#!/bin/bash
#
# backup_now.sh — Manual world backup to Google Drive.
# Uses rclone copy (no compression). Stops server, copies worlds/ directly
# to a dated folder on Drive, then restarts.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if ! is_gdrive_connected; then
  echo "  Google Drive is not connected."
  read -r -p "  Press Enter to return..."; exit 1
fi
if [[ ! -d "$SERVER_DIR/worlds" ]]; then
  echo "  No worlds directory found."; read -r -p "  Press Enter to return..."; exit 1
fi

echo ""
read -r -p "  Enter a note for this backup (optional): " note
if [[ -n "$note" ]]; then
  note_clean=$(echo "$note" | tr ' ' '-' | sed 's/[^a-zA-Z0-9_-]//g')
  folder_name="Manual_$(date '+%B-%d-%Y_%H-%M-%S')_${note_clean}"
else
  folder_name="Backup_$(date '+%B-%d-%Y_%H-%M-%S')"
fi
remote_path="${GDRIVE_BACKUPS_PATH}/${folder_name}"
echo "  Backing up to: ${remote_path}"

was_running=false
if server_is_running; then
  was_running=true; echo "  Stopping server..."; systemctl stop "$SERVICE_NAME"; sleep 2
fi

echo "  Uploading worlds to Google Drive..."
rclone copy "$SERVER_DIR/worlds" "$remote_path" --progress 2>/dev/null

if [[ $? -eq 0 ]]; then
  echo ""; echo "  ✓ Backup complete! → ${remote_path}"
  log_info "Backup created: $folder_name"
else
  echo ""; echo "  ✗ Upload failed. Check connectivity."
  log_error "Backup upload failed"
fi

if $was_running; then
  echo "  Restarting server..."; state_set_on; systemctl start "$SERVICE_NAME"; sleep 2
fi
```
</details>

<details>
<summary>scripts/backup_restore.sh</summary>

```bash
#!/bin/bash
#
# backup_restore.sh — Restore a world backup from Google Drive.
# Lists backup folders on Drive, lets you pick one, restores it.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if ! is_gdrive_connected; then
  echo "  Google Drive is not connected."
  read -r -p "  Press Enter to return..."; exit 1
fi

list_backup_folders() {
  rclone lsd "${GDRIVE_BACKUPS_PATH}/" 2>/dev/null | awk '{for(i=5;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//'
}

validate_world() {
  local dir="$1"
  [[ ! -f "$dir/level.dat" ]] && return 1
  [[ ! -d "$dir/db" ]] && return 1
  [[ $(find "$dir/db" -type f 2>/dev/null | wc -l) -eq 0 ]] && return 1
  return 0
}

do_restore() {
  local selected_display="$1" was_running=false
  echo ""; echo "  Selected: $selected_display"
  read -r -p "  Overwrite current world? (y/N): " confirm
  [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "  Cancelled."; return; }

  if server_is_running; then
    was_running=true; echo "  Stopping server..."; systemctl stop "$SERVICE_NAME"; sleep 2
  fi

  echo "  Removing old world..."; rm -rf "$SERVER_DIR/worlds"
  echo "  Downloading backup..."
  rclone copy "${GDRIVE_BACKUPS_PATH}/${selected_display}" "$SERVER_DIR/worlds" --progress 2>/dev/null

  if [[ $? -ne 0 ]]; then
    echo "  ✗ Download failed."; log_error "Restore download failed"
    if $was_running; then state_set_on; systemctl start "$SERVICE_NAME"; fi; return
  fi

  echo "  Fixing permissions..."; chmod -R 755 "$SERVER_DIR/worlds" 2>/dev/null

  echo "  Validating..."
  local found_valid=false
  for w in "$SERVER_DIR/worlds"/*/; do
    if [[ -d "$w" ]]; then
      if validate_world "$w"; then
        echo "    ✓ $(basename "$w") — valid"; found_valid=true
      else
        echo "    ⚠ $(basename "$w") — may be incomplete"
      fi
    fi
  done
  ! $found_valid && echo "  ⚠ No valid worlds found."

  log_info "Restored: $selected_display"
  echo ""; echo "  ✓ Restore complete!"
  if $was_running; then echo "  Restarting server..."; state_set_on; systemctl start "$SERVICE_NAME"; sleep 2; fi
}

menu_restore() {
  echo "  Fetching backups..."; echo ""
  mapfile -t folders < <(list_backup_folders)
  [[ ${#folders[@]} -eq 0 ]] && { echo "  No backups found."; read -r -p "  Press Enter to return..."; return; }

  echo "  Available backups:"; echo ""
  local i=1
  for f in "${folders[@]}"; do printf "  %2d) %s\n" "$i" "$f"; i=$((i+1)); done
  echo ""; read -r -p "  Select backup [1-$((i-1))]: " choice
  [[ -z "$choice" || "$choice" -lt 1 || "$choice" -ge "$i" ]] && { echo "  Invalid."; read -r -p "  Press Enter to return..."; return; }
  do_restore "${folders[$((choice-1))]}"
  read -r -p "  Press Enter to return..."
}

menu_restore
```
</details>

<details>
<summary>scripts/backup_auto.sh</summary>

```bash
#!/bin/bash
#
# backup_auto.sh — Configure automatic periodic backups.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

AUTO_SCRIPT="$SCRIPTS_DIR/backup_auto_runner.sh"
TIMER_UNIT="/etc/systemd/system/mcbedrock-autobackup.timer"
SERVICE_UNIT="/etc/systemd/system/mcbedrock-autobackup.service"

if ! is_gdrive_connected; then echo "  Google Drive not connected."; exit 1; fi

menu_auto_backup() {
  while true; do
    clear
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║              AUTO BACKUP SCHEDULE                  ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    local sched="Not configured"
    systemctl is-active mcbedrock-autobackup.timer &>/dev/null && sched="Active"
    echo "    1)  CONFIGURE    2)  DISABLE    3)  VIEW    4)  BACK"
    echo "  Current: $sched"; echo ""; read -r -p "  Option [1-4]: " c
    case "$c" in
      1) configure_auto_backup ;;
      2) disable_auto_backup ;;
      3) view_schedule ;;
      *) return ;;
    esac
    read -r -p "  Press Enter..."; done
}

configure_auto_backup() {
  read -r -p "  Timezone (e.g. Asia/Manila): " tz; [[ -z "$tz" ]] && return
  read -r -p "  Interval in hours (e.g. 6): " interval
  [[ -z "$interval" || ! "$interval" =~ ^[0-9]+$ || "$interval" -lt 1 ]] && { echo "  Invalid."; return; }

  write_config "AUTO_BACKUP_TIMEZONE" "$tz"
  write_config "AUTO_BACKUP_HOUR" "$interval"
  write_config "AUTO_BACKUP_AMPM" ""

  create_runner

  cat > "$SERVICE_UNIT" << 'UNIT'
[Unit]
Description=Minecraft Bedrock Server Auto-Backup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=/opt/mcbedrock/scripts/backup_auto_runner.sh

[Install]
WantedBy=multi-user.target
UNIT

  cat > "$TIMER_UNIT" << TIMER
[Unit]
Description=Minecraft Bedrock Server Auto-Backup (every ${interval}h)
[Timer]
OnBootSec=10min
OnUnitActiveSec=${interval}h
Persistent=true

[Install]
WantedBy=timers.target
TIMER

  systemctl daemon-reload; systemctl enable mcbedrock-autobackup.timer 2>/dev/null
  systemctl start mcbedrock-autobackup.timer 2>/dev/null; systemctl enable mcbedrock-autobackup.service 2>/dev/null
  log_info "Auto-backup configured: every ${interval}h in $tz"
  echo "  ✓ Automatic backup set: every $interval hour(s) in $tz"
}

disable_auto_backup() {
  read -r -p "  Disable? (y/N): " confirm; [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return
  systemctl stop mcbedrock-autobackup.timer 2>/dev/null; systemctl disable mcbedrock-autobackup.timer 2>/dev/null
  systemctl disable mcbedrock-autobackup.service 2>/dev/null
  write_config "AUTO_BACKUP_TIMEZONE" ""; write_config "AUTO_BACKUP_HOUR" ""; write_config "AUTO_BACKUP_AMPM" ""
  log_info "Auto-backup disabled."; echo "  ✓ Disabled."
}

view_schedule() {
  ! systemctl is-active mcbedrock-autobackup.timer &>/dev/null && { echo "  Not configured."; return; }
  echo "  Interval: ${AUTO_BACKUP_HOUR:-N/A}h  TZ: ${AUTO_BACKUP_TIMEZONE:-N/A}"
  echo "  Status: $(systemctl is-active mcbedrock-autobackup.timer 2>/dev/null)"
  echo "  Next: $(systemctl show mcbedrock-autobackup.timer -p NextElapseUSecRealtime 2>/dev/null | cut -d= -f2 || echo 'N/A')"
}

create_runner() {
  cat > "$AUTO_SCRIPT" << 'RUNNER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"
if ! is_gdrive_connected; then log_error "Auto-backup skipped: no Drive."; exit 1; fi
if [[ ! -d "$SERVER_DIR/worlds" ]]; then log_error "Auto-backup skipped: no worlds."; exit 1; fi
folder_name="Auto_$(date '+%B-%d-%Y_%H-%M-%S')"
remote_path="${GDRIVE_BACKUPS_PATH}/${folder_name}"
was_running=false
if server_is_running; then was_running=true; systemctl stop "$SERVICE_NAME"; sleep 2; fi
rclone copy "$SERVER_DIR/worlds" "$remote_path" 2>/dev/null
if [[ $? -eq 0 ]]; then log_info "Auto-backup: $folder_name"
else log_error "Auto-backup upload failed"; fi
if $was_running; then state_set_on; systemctl start "$SERVICE_NAME"; fi
RUNNER
  chmod +x "$AUTO_SCRIPT"
}

menu_auto_backup
```
</details>

<details>
<summary>scripts/gdrive_setup.sh</summary>

```bash
#!/bin/bash
#
# gdrive_setup.sh — Configure rclone Google Drive remote.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REMOTE_NAME="gdrive"

setup_gdrive() {
  if is_gdrive_connected; then
    read -r -p "  Already configured. Reconfigure? (y/N): " r
    [[ "$r" != "y" && "$r" != "Y" ]] && return
    rclone config delete "$REMOTE_NAME" 2>/dev/null || true
  fi

  echo ""
  echo "  Step 1: On your PC, run: rclone authorize \"drive\""
  echo "  Step 2: Log into Google in the browser that opens"
  echo "  Step 3: Copy the JSON token from the terminal"
  echo "  Step 4: Paste it below"
  echo ""
  read -r -p "  config_token: " token
  [[ -z "$token" ]] && { echo "  Cancelled."; return; }

  echo "  Configuring rclone..."
  rclone config create "$REMOTE_NAME" drive --quiet --non-interactive --all config_token="$token" 2>/dev/null

  if is_gdrive_connected; then
    rclone mkdir "${GDRIVE_BACKUPS_PATH}" 2>/dev/null
    echo "  ✓ Google Drive connected! Backups → ${GDRIVE_BACKUPS_PATH}/"
    log_info "Google Drive configured."
  else
    echo "  ✗ Failed. Check your token."
    log_error "Google Drive config failed."
  fi
}

setup_gdrive
```
</details>
