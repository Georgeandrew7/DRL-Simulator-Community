# DRL Simulator Community Server - Windows

## Quick Start

### 1. Run the Mock Backend Server

**Option A: Batch Script (Simple)**
```batch
# Run as Administrator
start-offline-mode.bat
```

**Option B: PowerShell (More Options)**
```powershell
# Run PowerShell as Administrator
.\start-offline-mode.ps1

# Custom game path:
.\start-offline-mode.ps1 -GameDir "D:\Games\DRL Simulator"
```

### 2. Launch the Game
Open Steam and launch DRL Simulator normally.

## Scripts Included

| Script | Description |
|--------|-------------|
| `start-offline-mode.bat` | One-click setup - adds hosts entry and starts server |
| `start-offline-mode.ps1` | PowerShell version with more options |
| `install-bepinex.bat` | Downloads and installs BepInEx mod framework |
| `setup-server.bat` | Configure and run the embedded Photon server |

## Default Paths

- **Game**: `C:\Program Files (x86)\Steam\steamapps\common\DRL Simulator`
- **Hosts file**: `C:\Windows\System32\drivers\etc\hosts`

## Requirements

- Python 3.8+ (from [python.org](https://python.org))
- Administrator privileges (for hosts file and port 80)

## Installing BepInEx Plugins

1. Run `install-bepinex.bat` as Administrator
2. Open the plugin source files in Visual Studio
3. Build the DLL
4. Copy to `DRL Simulator\BepInEx\plugins\`

## Troubleshooting

### Port 80 In Use
Common culprits:
- IIS (Internet Information Services)
- Skype
- World Wide Web Publishing Service

Stop via Services (services.msc) or use a different port.

### Python Not Found
1. Install Python from https://python.org
2. Check "Add Python to PATH" during installation
3. Restart your terminal

### Game Still Shows "Connection Lost"
1. Verify hosts file has the entry: `127.0.0.1 api.drlgame.com`
2. Flush DNS: `ipconfig /flushdns`
3. Ensure the mock server is running (check the terminal window)
