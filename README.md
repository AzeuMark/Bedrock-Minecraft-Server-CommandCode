# Minecraft Bedrock Server Manager

A terminal dashboard for managing a Minecraft Bedrock Dedicated Server on Ubuntu. Type `mc` or `minecraft` to open it.

The dashboard shows server status, version, player count, RAM usage, and IP/port. All actions are selected by number.

## Quick Start (Ubuntu VPS)

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
sudo ./setup/05_setup_gdrive.sh       # optional — for backups only
sudo ./setup/06_setup_swap.sh         # recommended — prevents OOM crashes
sudo ./setup/07_setup_firewall.sh     # recommended — opens ports
```

### 3. Open the menu

```bash
mc
```

---

## Setup Files Explained

| File | What it does |
|---|---|
| `01_install_dependencies.sh` | Installs `unzip`, `curl`, `wget`, `jq`, `libssl-dev`. Required before anything else. |
| `02_install_bedrock_server.sh` | Creates `/opt/mcbedrock` folder structure. Downloads the latest official Bedrock server binary from Mojang's API and extracts it. Preserves worlds and settings if re-run. |
| `03_setup_systemd_service.sh` | Creates the `mcbedrock` systemd service and `server.state` flag (ON/OFF). The service sets `LD_LIBRARY_PATH=.` so the server can find its bundled `.so` libraries. |
| `04_setup_menu_command.sh` | Symlinks `/usr/local/bin/mc` and `/usr/local/bin/minecraft` to the menu script so you can type `mc` from anywhere. |
| `05_setup_gdrive.sh` | Sets up rclone with a Google Drive remote for backups. You paste the `config_token` from `rclone authorize "drive"` run on your PC. |
| `06_setup_swap.sh` | Creates a 2 GB swap file to prevent out-of-memory crashes. Persistent across reboots. |
| `07_setup_firewall.sh` | Opens ports 22 (SSH), 19132/udp (game), 19132/tcp (query) via ufw. |

## Scripts Called by the Menu

| File | What it does |
|---|---|
| `common.sh` | Shared helper — sets paths (`/opt/mcbedrock/...`), handles config/state files, provides functions for checking server status, RAM, player count, IP, port. Sourced by every other script. |
| `mc-menu.sh` | The dashboard entry point. Draws the status panel and menu, routes to other scripts. |
| `server_actions.sh` | Takes `start`, `stop`, or `restart` as argument. Start enables systemd + sets state ON. Stop disables systemd + sets state OFF. |
| `logs.sh` | Takes `tail` (live follow with Ctrl+C to stop) or `last500` (scrollable via `less`). |
| `versions.sh` | Checks Mojang's API for the latest version. Compares against installed version. If newer, asks you to confirm update. |
| `backup_now.sh` | Stops server → compresses world → uploads to Google Drive (retries 3x) → deletes local tarball → restarts server. Prompts for optional note. |
| `backup_restore.sh` | Lists backups from Drive in a numbered menu. Downloads + validates the backup (checks for `level.dat` and world data files). Stops server, saves safety copy of current world, extracts backup, restarts if was running. |
| `backup_auto.sh` | Prompts for timezone and interval in hours. Creates a systemd timer that triggers backups every N hours. |
| `gdrive_setup.sh` | Same as `05_setup_gdrive.sh` but callable from the menu if you skipped initial setup. |

## File Structure

```
/opt/mcbedrock/
├── setup/           # Run once, in order (01–07)
├── scripts/         # Feature scripts called by the menu
├── config/          # mc.conf (version, auto-backup settings), server.state (ON/OFF)
├── server/          # Bedrock server binary, worlds/, server.properties
├── backups/         # Temporary staging before upload to Drive (deleted on success)
└── logs/            # server.log (server stdout/stderr), mcbedrock-manager.log (menu actions)
```

## How the Safety Flag Works

- **START SERVER** → writes `ON` to `server.state`, enables systemd auto-start
- **STOP SERVER** → writes `OFF`, disables systemd auto-start
- On VPS reboot, the server only starts if it was ON before shutdown
- Nothing in the system can start the server unless state is ON

## Bedrock Version Updates

The script fetches the latest Linux download URL from:

```
https://net-secondary.web.minecraft-services.net/api/v1.0/download/links
```

It filters for `serverBedrockLinux`, extracts the version number from the URL, and compares it against the stored `CURRENT_VERSION` in `mc.conf`.

## Google Drive Backups

Backups are stored at: `gdrive:Minecraft/Backups/{Month-Day-Year-Hr-Min-SecAMPM}{-note}.tar.gz`

**Backup flow:**
1. Server stops (cleanly via systemd)
2. Worlds compressed to a `.tar.gz` in `/opt/mcbedrock/backups/`
3. Uploaded to Google Drive via `rclone copy` (3 retries)
4. Local tarball deleted on success
5. Server restarted if it was running before

**Restore flow:**
1. Downloads backup from Drive
2. Validates it has `level.dat` and world data files
3. Saves current world as safety backup
4. Extracts backup into `server/worlds/`
5. Restarts server if it was running before

## Manual Commands

```bash
systemctl start|stop|restart mcbedrock
journalctl -u mcbedrock -f          # live server logs
systemctl status mcbedrock
sudo rclone authorize "drive"       # get Google token
```
