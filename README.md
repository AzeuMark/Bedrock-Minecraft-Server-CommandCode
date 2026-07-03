# Minecraft Bedrock Server Manager

A terminal interface (TUI) for managing a Minecraft Bedrock Dedicated Server on Ubuntu. Type `mc` or `minecraft` to open the menu.

**Features:** Start/Stop/Restart, Google Drive backups (manual & automatic), version switching, log viewer.

## Quick Start (Ubuntu VPS)

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git /opt/mcbedrock
cd /opt/mcbedrock
chmod +x setup/*.sh scripts/*.sh
```

### 2. Run setup scripts (in order, as root)

```bash
sudo ./setup/01_install_dependencies.sh
sudo ./setup/02_install_bedrock_server.sh
sudo ./setup/03_setup_systemd_service.sh
sudo ./setup/04_setup_menu_command.sh
```

### 3. Connect Google Drive

On your **Windows/Mac PC**, open a terminal and run:

```bash
rclone authorize "drive"
```

A browser will open. Log into your Google account and grant permissions. Copy the JSON token that appears in the terminal (it looks like `{"access_token":"ya29..."}`).

Back on the VPS, run:

```bash
sudo ./setup/05_setup_gdrive.sh
```

Paste the token when prompted.

### 4. Open the menu

```bash
mc
```

## Usage

| Command | Action |
|---|---|
| `mc` | Open the server manager menu |
| `minecraft` | Same as `mc` |

### Menu Structure

- **Server Actions** — Start (enables auto-start on boot), Stop (disables auto-start on boot), Restart, View Status
- **Backups** — Backup Now (with optional note), Restore (from Drive), Automatic Backup (daily schedule with timezone)
- **Versions** — Install latest version or choose a specific version
- **View Logs** — Live tail or last 100/500 lines

### How the safety flag works

- `server.state` in `/opt/mcbedrock/config/` contains `ON` or `OFF`
- **Start** → sets state `ON` + enables systemd auto-start on boot
- **Stop** → sends clean `stop` command + sets state `OFF` + disables auto-start
- Nothing in the system will start the server unless the state says `ON`

### Backup behavior

- Worlds are compressed with `save hold`/`save resume` for clean snapshots
- Uploaded to `Google Drive:Minecraft/Backups/{timestamp}-{optional-note}.tar.gz`
- Local tarball is **deleted** after successful upload
- If upload fails, local copy is kept and you're warned

## File Structure

```
/opt/mcbedrock/
├── setup/           # Run once in order (scripts 01–05)
├── scripts/         # Feature scripts called by the menu
├── config/          # mc.conf and server.state
├── server/          # Bedrock server binary, worlds, server.properties
├── backups/         # Temporary staging before upload
└── logs/            # Server log output
```
