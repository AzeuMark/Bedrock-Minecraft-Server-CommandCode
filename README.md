# Minecraft Bedrock Server Manager

A terminal dashboard for managing a Minecraft Bedrock Dedicated Server on Ubuntu. Type `mc` to open it.

The dashboard shows server status, version, player count, RAM usage, and IP/port. All actions are selected by number.

## Quick Start

### 1. Clone

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git /opt/mcbedrock
cd /opt/mcbedrock
chmod +x setup/*.sh scripts/*.sh
```

### 2. Run setup scripts (as root, in order)

```bash
sudo ./setup/01_install_dependencies.sh
sudo ./setup/02_install_bedrock_server.sh
sudo ./setup/03_setup_systemd_service.sh
sudo ./setup/04_setup_menu_command.sh
sudo ./setup/05_setup_gdrive.sh          # optional — for backups
sudo ./setup/06_setup_swap.sh            # recommended — prevents OOM
sudo ./setup/07_setup_firewall.sh        # recommended — opens ports
sudo ./setup/08_tune_kernel.sh           # recommended — TPS/latency
```

### 3. IMPORTANT: Allow ports in VPS dashboard

ufw (the server firewall) is NOT enough if you use **DigitalOcean**, **Linode**, **Vultr**, or any VPS with a cloud firewall panel. You must ALSO add these inbound rules there:

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH |
| 19132 | UDP | Minecraft Bedrock game traffic |
| 19132 | TCP | Server query/ping |

Without the **UDP 19132** rule in your VPS dashboard, no one can connect. The ufw firewall only controls traffic after it passes the VPS's cloud firewall.

### 4. Open the menu

```bash
mc
```

If you cannot connect after starting the server, run:
```bash
sudo ufw status verbose        # check ufw rules
journalctl -u mcbedrock -n 20  # check server logs (look for "IPv4 supported")
```

---

## Setup Files Explained

| File | What it does |
|---|---|
| `01_install_dependencies.sh` | Installs `unzip`, `curl`, `wget`, `jq`, `libssl-dev` — required for downloads and the server binary. |
| `02_install_bedrock_server.sh` | Creates folder structure, downloads latest Bedrock server from Mojang's API, extracts it, writes default `server.properties` with `online-mode=false` and `view-distance=10` for performance. |
| `03_setup_systemd_service.sh` | Creates `mcbedrock` systemd service with `LD_LIBRARY_PATH=.`, `StandardInput=null`, and `server.state` flag. Prints DigitalOcean firewall reminder. |
| `04_setup_menu_command.sh` | Symlinks `/usr/local/bin/mc` and `/usr/local/bin/minecraft` → the menu script. |
| `05_setup_gdrive.sh` | rclone Google Drive setup — paste the `config_token` from `rclone authorize "drive"` on your PC. |
| `06_setup_swap.sh` | 2 GB swap file (`fallocate`, `mkswap`, `swapon`), persistent across reboots via `/etc/fstab`. |
| `07_setup_firewall.sh` | ufw rules: port 22/tcp (SSH), 19132/udp (game), 19132/tcp (query), SSH rate limiting. Warns about cloud firewall. |
| `08_tune_kernel.sh` | Kernel tweaks: BBR congestion control, UDP buffer tuning, `swappiness=10`, higher connection backlog. Improves TPS and reduces latency for Bedrock (which uses UDP). |

## Scripts Called by the Menu

| File | What it does |
|---|---|
| `common.sh` | Shared helpers — path constants, state file management, config loader, status gatherers (RAM, players, IP, port, version). |
| `mc-menu.sh` | Dashboard — draws status panel, handles menu selection, routes to sub-scripts. |
| `server_actions.sh start\|stop\|restart` | Start: sets state ON + systemctl enable + start. Stop: systemctl stop + state OFF + disable. Shows journalctl output on failure. |
| `logs.sh tail\|last500` | `tail`: live follow (Ctrl+C to stop). `last500`: scrollable via `less`. |
| `versions.sh` | Checks Mojang API for latest version, compares against installed, asks to update. |
| `backup_now.sh` | Stops server → compresses worlds → uploads to Drive (3 retries) → deletes local → restarts. Optional note. |
| `backup_restore.sh` | Lists Drive backups → selects → downloads + validates (checks `level.dat` + `db/`) → stops server → safety backup → extracts → restarts. |
| `backup_auto.sh` | Asks for interval hours + timezone → creates systemd timer (`OnUnitActiveSec`). |
| `gdrive_setup.sh` | Same as `05_setup_gdrive.sh`, callable from menu if skipped during setup. |

## File Structure

```
/opt/mcbedrock/
├── setup/           # Run once, in order (01–08)
├── scripts/         # Feature scripts called by the menu
├── config/          # mc.conf (version/schedule), server.state (ON/OFF)
├── server/          # bedrock_server, worlds/, server.properties, .so libs
├── backups/         # Temp staging before Drive upload (deleted on success)
└── logs/            # server.log (server stdout/stderr), mcbedrock-manager.log
```

## How the Safety Flag Works

| Action | server.state | systemd auto-start |
|---|---|---|
| START SERVER | ON | enabled |
| STOP SERVER | OFF | disabled |
| VPS reboot | — | only if state was ON |

Nothing in the system can start the server unless state says ON.

## Why You Couldn't Connect — Checklist

1. **Cloud firewall** — DigitalOcean/etc blocks UDP 19132 by default. Add it in your VPS dashboard.
2. **online-mode=true** — Old default required Xbox Live authentication was causing issues. Changed to `false`.
3. **view-distance=32** — Was too high for small VPS. Lowered to 10 for better TPS.
4. **Kernel tuning** — Added `08_tune_kernel.sh` with BBR and UDP buffers. Bedrock runs on UDP, so TCP defaults were suboptimal.

## Manual Commands

```bash
systemctl start|stop|restart mcbedrock
journalctl -u mcbedrock -f          # live log tail
systemctl status mcbedrock
sudo ufw status verbose             # check firewall rules
sudo rclone authorize "drive"       # get Google Drive token
sysctl net.ipv4.tcp_congestion_control  # check if BBR is active
```
