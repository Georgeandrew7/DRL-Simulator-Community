# DRL Simulator Community Server - Linux

## Quick Start

### 1. Run the Mock Backend Server

```bash
# Make executable (first time only)
chmod +x scripts/*.sh

# Run with sudo (required for port 80 and hosts file)
sudo ./scripts/start-offline-mode.sh
```

### 2. Launch the Game
Open Steam and launch DRL Simulator normally.

## Scripts Included

| Script | Description |
|--------|-------------|
| `scripts/start-offline-mode.sh` | One-click setup - adds hosts entry and starts server |
| `scripts/install_bepinex.sh` | Downloads and installs BepInEx mod framework |
| `scripts/compile_plugin.sh` | Compiles C# plugins using Mono |
| `scripts/setup-server.sh` | Configure and run the embedded Photon server |

## Default Paths

- **Game**: `~/.local/share/Steam/steamapps/common/DRL Simulator`
- **Hosts file**: `/etc/hosts`

## Requirements

- Python 3.8+
- sudo privileges (for hosts file and port 80)
- aiohttp: `pip install aiohttp`
- Mono (for plugin compilation): 
  - Ubuntu/Debian: `sudo apt install mono-mcs`
  - Arch: `sudo pacman -S mono` or `yay -S mono`

## Installing BepInEx

```bash
./scripts/install_bepinex.sh
```

### Steam Launch Options
After installing BepInEx, set Steam launch options:
```
WINEDLLOVERRIDES="winhttp=n,b" %command%
```

## Compiling Plugins

```bash
# Install Mono first
sudo apt install mono-mcs  # Ubuntu/Debian
# OR
sudo pacman -S mono        # Arch

# Compile
./scripts/compile_plugin.sh
```

## Docker Setup

Run the Photon server in Docker:

```bash
cd docker
./setup.sh
```

## Troubleshooting

### Permission Denied
```bash
chmod +x scripts/*.sh
```

### Port 80 In Use
Check what's using port 80:
```bash
sudo lsof -i :80
sudo fuser 80/tcp
```

Kill process on port 80:
```bash
sudo fuser -k 80/tcp
```

### SELinux Issues (Fedora/RHEL)
```bash
sudo setenforce 0  # Temporarily disable
```

### Python Module Not Found
```bash
pip install aiohttp requests
```
