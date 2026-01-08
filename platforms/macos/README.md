# DRL Simulator Community Server - macOS

## Quick Start

### 1. Run the Mock Backend Server

```bash
# Run with sudo (required for port 80 and hosts file)
sudo ./start-offline-mode.sh
```

### 2. Launch the Game
Open Steam and launch DRL Simulator normally.

## Scripts Included

| Script | Description |
|--------|-------------|
| `start-offline-mode.sh` | One-click setup - adds hosts entry and starts server |
| `install-bepinex.sh` | Downloads and installs BepInEx mod framework |
| `compile-plugin.sh` | Compiles C# plugins using Mono |

## Default Paths

- **Game**: `~/Library/Application Support/Steam/steamapps/common/DRL Simulator`
- **Hosts file**: `/etc/hosts`

## Requirements

- Python 3.8+ (pre-installed on macOS, or via `brew install python`)
- sudo privileges (for hosts file and port 80)
- Mono (for plugin compilation): `brew install mono`

## Installing BepInEx

```bash
# Make executable
chmod +x install-bepinex.sh

# Run
./install-bepinex.sh
```

### Launching with BepInEx

On macOS, you need to launch via the BepInEx script:

```bash
cd ~/Library/Application\ Support/Steam/steamapps/common/DRL\ Simulator
./run_bepinex.sh
```

Or set Steam launch options:
```
~/Library/Application\ Support/Steam/steamapps/common/DRL\ Simulator/run_bepinex.sh %command%
```

## Compiling Plugins

```bash
# Install Mono first
brew install mono

# Make executable
chmod +x compile-plugin.sh

# Compile
./compile-plugin.sh
```

## Troubleshooting

### Permission Denied
Make scripts executable:
```bash
chmod +x *.sh
```

### Port 80 In Use
Check what's using port 80:
```bash
sudo lsof -i :80
```

### DNS Not Updating
Flush DNS cache:
```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Python Issues
Install Python via Homebrew:
```bash
brew install python
```
