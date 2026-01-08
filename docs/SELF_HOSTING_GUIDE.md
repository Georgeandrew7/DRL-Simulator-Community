# DRL Simulator Self-Hosted Server Guide

## Overview

This guide documents how to set up a self-hosted multiplayer server for The Drone Racing League (DRL) Simulator after the official servers were shut down.

**Issue Discovered:** The game requires DRL's backend API (`api.drlgame.com`) for login/authentication. This server is now offline, causing "Connection Lost" errors.

**Solution:** Run a mock backend server to bypass the login requirement.

## Quick Start (RECOMMENDED)

### Step 1: Start the Mock Backend Server

```bash
cd "/home/george/.local/share/Steam/steamapps/common/DRL Simulator"
sudo ./start-offline-mode.sh
```

This will:
1. Add `api.drlgame.com` to your `/etc/hosts` pointing to localhost
2. Start a mock API server that responds to game requests

### Step 2: Launch the Game

In a separate terminal, launch DRL Simulator through Steam. The game should now get past the login screen.

### Step 3: Access LAN/Multiplayer

Once in-game, look for LAN or Local multiplayer options.

---

## Manual Setup (Alternative)

### Step 1: Add hosts entry
```bash
sudo sh -c 'echo "127.0.0.1 api.drlgame.com" >> /etc/hosts'
```

### Step 2: Run mock server
```bash
cd "/home/george/.local/share/Steam/steamapps/common/DRL Simulator"
sudo python3 mock_drl_backend.py --port 80
```

### Step 3: Patch the Client (Already Done)
```bash
python binary_patcher.py --patch
```

---

## Key Findings

### Backend Services Required
The game contacts `api.drlgame.com` for:
- `drl.service.time` - Server time synchronization
- `drl.service.login.v2` - User authentication
- `drl.service.storage.*` - User data storage

### Game Architecture
- **Engine:** Unity 2020.3.48f1
- **Networking:** Photon PUN (Photon Unity Networking) with LoadBalancing architecture
- **Backend API:** `api.drlgame.com` (now offline, mocked by our server)
- **Server Type:** Photon Server (self-hostable, not cloud-only)
- **License:** 100 CCU (Concurrent Users) license included (`ben_t@drl.io.Photon-vX.free.100-ccu.license`)

### Photon App IDs Found in Game
These GUIDs are embedded in PhotonServerSettings:
- `28c108ec-052d-4900-863c-3c5aad81d945` (Primary App ID - likely Realtime/PUN)
- `f590668c-6490-4259-a9df-8dbba78093c9` (Secondary App ID - likely Voice or Chat)

### Binary Patching Details
The HostingOption field is located at:
- **File:** `DRL Simulator_Data/resources.assets`
- **Offset:** `0x42B640`
- **Original Value:** `01 00 00 00` (PhotonCloud)
- **Patched Value:** `02 00 00 00` (SelfHosted)

### Port Configuration
| Service | UDP Port | TCP Port | WebSocket Port |
|---------|----------|----------|----------------|
| Master Server | 5055 | 4530 | 9090 |
| Game Server | 5056 | 4531 | 9091 |
| Policy (Unity) | - | 843 | - |
| Policy (Silverlight) | - | 943 | - |
| GameServer Internal | - | 4520 | - |

## Server Location

The embedded Photon Server is located at:
```
DRL Simulator_Data/StreamingAssets/PhotonServer/
```

Structure:
```
PhotonServer/
├── bin_Win64/
│   ├── PhotonSocketServer.exe      # Main server executable
│   ├── PhotonControl.exe           # GUI control panel
│   ├── PhotonServer.config         # Server configuration
│   ├── ben_t@drl.io.Photon-vX.free.100-ccu.license
│   ├── _run-Photon-as-application.start.cmd
│   └── _run-Photon-as-application.stop.cmd
├── LoadBalancing/
│   ├── Master/
│   │   └── bin/
│   │       └── Photon.LoadBalancing.dll.config
│   └── GameServer/
│       └── bin/
│           └── Photon.LoadBalancing.dll.config
└── CounterPublisher/
```

## Self-Hosting Options

### Option 1: Built-in LAN Mode (Try First!)

The game has **built-in LAN server functionality** that should be accessible after patching:

**LAN Features Found in Game Code:**
- `LobbyLANStartServerClick` - Start LAN server button
- `EnableLanCreateServerButton`, `ShowLanCreateServerButton` - LAN UI controls  
- `lanServerIpField` - Enter server IP
- `LANServerOnline`, `LANServerStarting` - Server states

**To test:**
1. Launch the game through Steam
2. Look for a "LAN" or "Local" option in the multiplayer menu
3. Try creating a LAN server or connecting to one

### Option 2: Run Photon Server on Windows

The embedded Photon Server requires native Windows. Wine has a limitation with `CCLRRuntimeInfo::IsLoadable()`.

On Windows:
1. Navigate to `DRL Simulator_Data/StreamingAssets/PhotonServer/bin_Win64/`
2. Run `_run-Photon-as-application.start.cmd` as Administrator
3. The server will start with LoadBalancing configuration

### Option 3: Docker Container (Recommended for Production)

See the Docker setup section below.

## Client Configuration

To connect clients to the self-hosted server, you need to modify the game to point to your server instead of the Photon Cloud.

### Method 1: DNS Redirection (Easiest)

Since Photon typically uses nameservers like `ns.photonengine.io` or `ns.exitgames.com`, you can:

1. Find the exact nameserver the game uses (see Investigation section)
2. Add a hosts file entry to redirect to your server:
   ```
   YOUR_SERVER_IP    ns.photonengine.io
   YOUR_SERVER_IP    ns.exitgames.com
   ```

### Method 2: Binary Patching

Modify `Assembly-CSharp.dll` to change the server address. This requires:
1. Decompiling with dnSpy or ILSpy
2. Finding `PhotonServerSettings` or `PhotonNetwork.ConnectToMaster()` calls
3. Changing the server address to your self-hosted server IP
4. Recompiling

### Method 3: Unity Asset Modification

PhotonServerSettings is stored in `resources.assets`. Use UABE (Unity Asset Bundle Extractor) or similar to:
1. Export the PhotonServerSettings MonoBehaviour
2. Modify the server address and hosting type
3. Replace the asset

## Server Configuration Files

### LoadBalancing/Master/bin/Photon.LoadBalancing.dll.config

Key settings to modify:
```xml
<appSettings>
    <!-- Change to your public IP for internet play -->
    <add key="MasterIPAddress" value="127.0.0.1" />
    <add key="PublicIPAddress" value="YOUR_PUBLIC_IP" />
    
    <!-- Authentication - disabled by default -->
    <add key="AuthSettings.Enabled" value="false" />
</appSettings>
```

### LoadBalancing/GameServer/bin/Photon.LoadBalancing.dll.config

Key settings:
```xml
<appSettings>
    <!-- Must match the Master server address -->
    <add key="MasterIPAddress" value="127.0.0.1" />
    <add key="PublicIPAddress" value="YOUR_PUBLIC_IP" />
    <add key="GamingUdpPort" value="5056" />
    <add key="GamingTcpPort" value="4531" />
    <add key="GamingWebSocketPort" value="9091" />
</appSettings>
```

## Firewall Configuration

Open these ports on your server:

```bash
# UDP
sudo ufw allow 5055/udp  # Master
sudo ufw allow 5056/udp  # Game

# TCP
sudo ufw allow 4530/tcp  # Master
sudo ufw allow 4531/tcp  # Game
sudo ufw allow 4520/tcp  # Internal
sudo ufw allow 843/tcp   # Policy
sudo ufw allow 943/tcp   # Policy

# WebSocket (if needed)
sudo ufw allow 9090/tcp  # Master WS
sudo ufw allow 9091/tcp  # Game WS
```

## Docker Setup (Linux Host)

Create a Docker container using Wine to run the Windows Photon Server:

```dockerfile
FROM scottyhardy/docker-wine:latest

WORKDIR /opt/photon
COPY PhotonServer/ ./

EXPOSE 5055/udp 5056/udp
EXPOSE 4530/tcp 4531/tcp 4520/tcp
EXPOSE 843/tcp 943/tcp
EXPOSE 9090/tcp 9091/tcp

CMD ["wine", "bin_Win64/PhotonSocketServer.exe", "/run", "LoadBalancing"]
```

## Existing LAN Support

The game already has built-in LAN connection methods found in the code:
- `ConnectToLAN`
- `ConnectToLANAsync`  
- `TryConnectLANAsync`

This suggests there may be hidden LAN play functionality that can be activated through:
1. Command-line arguments
2. Configuration files
3. Debug menus

### Investigating LAN Mode

Search for launch options or config files:
```bash
find "DRL Simulator_Data" -name "*.json" -o -name "*.xml" -o -name "*.cfg" | xargs grep -l -i "lan\|local\|offline"
```

## Additional Features Found

### Offline Functionality
The game has offline map editing and leaderboard sync code:
- `SyncOfflineMapEditorMaps`
- `SyncOfflineLeaderboard`
- `GetMapEditorLocalMaps`
- `LoadCommunityMapOffline`

This suggests substantial offline capability that may work without server modifications.

### Epic Online Services Integration
The game also integrates with Epic Online Services (EOS), which may provide:
- Authentication
- Anti-cheat
- Matchmaking

For full self-hosting, you may need to either:
- Disable EOS integration
- Set up your own EOS application
- Mock the EOS endpoints

## Next Steps

1. **Test the embedded Photon Server** on Windows or via Wine
2. **Capture network traffic** to identify exact server addresses used
3. **Decompile Assembly-CSharp.dll** with dnSpy to find connection code
4. **Modify PhotonServerSettings** to point to self-hosted server
5. **Test LAN mode** functionality if available
6. **Document any additional authentication requirements**

## Tools Needed

- **dnSpy** or **ILSpy** - .NET decompiler for code analysis
- **UABE** - Unity Asset Bundle Extractor for asset modification
- **Wireshark** - Network traffic analysis
- **Wine** - For running Photon Server on Linux
- **Docker** - For containerized server deployment

## Community Resources

- Photon Documentation: https://doc.photonengine.com/
- Unity Asset Bundle Extractor: https://github.com/SeriousCache/UABE
- dnSpy: https://github.com/dnSpy/dnSpy

## Files Created

- `extract_photon_settings.py` - Python script to extract Photon configuration from Unity assets
- `extract_photon_deep.py` - Deep extraction script for PhotonServerSettings
- `photon_settings_raw.bin` - Raw binary dump of PhotonServerSettings MonoBehaviour

---

*This guide is for educational purposes and community game preservation after official server shutdown.*
