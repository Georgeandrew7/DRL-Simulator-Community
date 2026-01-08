# DRL Simulator Community Server

A collection of tools, scripts, and mods to keep **The Drone Racing League (DRL) Simulator** playable after the official servers were shut down.

> **Note:** This project is for educational purposes and community game preservation.

## 🎮 Overview

After DRL shut down their backend servers (`api.drlgame.com`), the game became unplayable due to required authentication. This project provides:

- **Mock Backend Server** - Mimics the DRL API to bypass login requirements
- **Self-Hosted Multiplayer** - Tools to enable LAN and P2P multiplayer
- **Track/Map Management** - Utilities for managing and sharing custom tracks
- **BepInEx Plugins** - SSL bypass and license bypass for self-hosted servers
- **Steam Integration** - Sync Steam profile data with the game

## 📁 Project Structure

```
DRL-Simulator-Community/
├── server/                    # Backend server components
│   ├── mock_drl_backend.py   # Main mock API server
│   ├── master_server.py      # P2P session coordinator
│   ├── track_sharing.py      # Track sharing server
│   └── ssl_proxy.py          # SSL termination proxy
│
├── plugins/                   # BepInEx mod plugins
│   ├── SSLBypassPlugin.cs    # SSL certificate bypass
│   ├── LicenseBypassPlugin.cs # License check bypass
│   └── DRLCommunityMod.cs    # Full community multiplayer mod
│
├── tools/                     # Utility scripts
│   ├── binary_patcher.py     # Patch game for self-hosted mode
│   ├── patch_client.py       # Client patching utilities
│   ├── steam_player_sync.py  # Steam profile synchronization
│   ├── extract_photon_settings.py
│   └── extract_photon_deep.py
│
├── analysis/                  # Game analysis scripts
│   ├── analyze_state.py      # Analyze player-state.json
│   ├── check_circuits.py     # Check circuit/track data
│   ├── check_favs.py         # Check favorites
│   ├── check_downloads.py    # Check downloaded maps
│   ├── compare_maps.py       # Compare map data
│   ├── test_tracks.py        # Test track loading
│   └── test_guid_check.py    # Test GUID validation
│
├── scripts/                   # Shell scripts
│   ├── start-offline-mode.sh # One-click offline mode setup
│   ├── setup-server.sh       # Photon server setup
│   ├── install_bepinex.sh    # BepInEx installation
│   └── compile_plugin.sh     # Plugin compilation
│
├── docker/                    # Docker configurations
│   └── setup.sh              # Docker Photon server setup
│
└── docs/                      # Documentation
    ├── SELF_HOSTING_GUIDE.md
    ├── ARCHITECTURE.md
    └── SSL_BYPASS_GUIDE.md
```

## 🚀 Quick Start

### Option 1: Simple Offline Mode (Recommended)

```bash
# 1. Clone this repository
git clone https://github.com/yourusername/DRL-Simulator-Community.git
cd DRL-Simulator-Community

# 2. Start the mock backend server
sudo python3 server/mock_drl_backend.py --dual

# 3. In another terminal, add the hosts entry
echo "127.0.0.1 api.drlgame.com" | sudo tee -a /etc/hosts

# 4. Launch DRL Simulator from Steam
```

### Option 2: Full Self-Hosted Setup

See [SELF_HOSTING_GUIDE.md](docs/SELF_HOSTING_GUIDE.md) for complete instructions.

## 🔧 Components

### Mock Backend Server

The mock server (`server/mock_drl_backend.py`) emulates the DRL API:

- **Login service** - Returns mock authentication tokens
- **Time service** - Server time synchronization  
- **Storage service** - Player data persistence
- **Content service** - Map and track metadata
- **Progression service** - XP and level data

```bash
# Run on HTTP (port 80) and HTTPS (port 443)
sudo python3 server/mock_drl_backend.py --dual

# Run on specific port
sudo python3 server/mock_drl_backend.py --port 80
```

### Master Server (P2P Coordinator)

Coordinates P2P multiplayer sessions:

```bash
python3 server/master_server.py --port 8080
```

API Endpoints:
- `GET /api/sessions` - List active sessions
- `POST /api/sessions` - Create new session
- `POST /api/sessions/{id}/join` - Join a session
- `WebSocket /ws` - Real-time session updates

### BepInEx Plugins

Install BepInEx and compile the plugins:

```bash
# Install BepInEx
./scripts/install_bepinex.sh

# Compile SSL bypass plugin (requires Mono)
./scripts/compile_plugin.sh
```

Steam Launch Options:
```
WINEDLLOVERRIDES="winhttp=n,b" %command%
```

### Binary Patcher

Patch the game for self-hosted Photon servers:

```bash
# Dry run (show what would change)
python3 tools/binary_patcher.py

# Apply patch
python3 tools/binary_patcher.py --patch

# Restore original
python3 tools/binary_patcher.py --restore
```

## 📋 Requirements

- Python 3.8+
- aiohttp (`pip install aiohttp`)
- requests (`pip install requests`)
- Mono (for plugin compilation): `sudo apt install mono-mcs`
- BepInEx 5.4.x (for plugin loading)

## 🎯 Game Information

- **Engine:** Unity 2020.3.48f1
- **Networking:** Photon PUN (Photon Unity Networking)
- **Backend API:** `api.drlgame.com` (offline, now mocked)
- **Photon License:** 100 CCU included with game

### Key Ports

| Service | UDP | TCP | WebSocket |
|---------|-----|-----|-----------|
| Master | 5055 | 4530 | 9090 |
| Game | 5056 | 4531 | 9091 |

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## ⚠️ Disclaimer

This project is for educational purposes and community game preservation after official server shutdown. Please respect intellectual property rights.

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.
