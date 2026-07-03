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
