# DRL Community Server - SSL Bypass Installation Guide

## Problem

The game uses Unity's TLS implementation (UnityTLS) which validates SSL certificates. When connecting to a self-hosted server with a self-signed certificate, the game rejects the connection with:

```
Curl error 60: Cert verify failed: UNITYTLS_X509VERIFY_FLAG_USER_ERROR1
```

## Solution: BepInEx SSL Bypass Plugin

We use BepInEx (a Unity game modding framework) with a Harmony patch to bypass SSL certificate validation.

### Prerequisites

1. **Mono C# Compiler** - Required to compile the plugin

   On Arch Linux:
   ```bash
   yay -S mono
   # or
   sudo pacman -S mono
   ```

   On Ubuntu/Debian:
   ```bash
   sudo apt install mono-mcs
   ```

### Installation Steps

#### Step 1: BepInEx is Already Installed

BepInEx has been extracted to your DRL Simulator directory. You should see:
- `BepInEx/` folder
- `winhttp.dll`
- `doorstop_config.ini`

#### Step 2: Compile the SSL Bypass Plugin

After installing Mono, run:

```bash
cd "$HOME/.local/share/Steam/steamapps/common/DRL Simulator/community-server"
./compile_plugin.sh
```

Or manually:

```bash
GAME_DIR="$HOME/.local/share/Steam/steamapps/common/DRL Simulator"
mcs -target:library \
    -out:"$GAME_DIR/BepInEx/plugins/DRLSSLBypass.dll" \
    -reference:"$GAME_DIR/BepInEx/core/BepInEx.dll" \
    -reference:"$GAME_DIR/BepInEx/core/0Harmony.dll" \
    -reference:"$GAME_DIR/DRL Simulator_Data/Managed/UnityEngine.dll" \
    -reference:"$GAME_DIR/DRL Simulator_Data/Managed/UnityEngine.CoreModule.dll" \
    -reference:"$GAME_DIR/DRL Simulator_Data/Managed/UnityEngine.UnityWebRequestModule.dll" \
    "$GAME_DIR/community-server/SSLBypassPlugin.cs"
```

#### Step 3: Configure Steam Launch Options

1. Open Steam
2. Right-click **DRL Simulator**
3. Click **Properties**
4. In **General** tab, find **Launch Options**
5. Add: `WINEDLLOVERRIDES="winhttp=n,b" %command%`

This tells Wine/Proton to load the BepInEx winhttp.dll which bootstraps the mod framework.

#### Step 4: Start the Mock Server

```bash
cd "$HOME/.local/share/Steam/steamapps/common/DRL Simulator"
sudo python3 mock_drl_backend.py --dual
```

The `--dual` flag runs both HTTP (port 80) and HTTPS (port 443).

#### Step 5: Configure Hosts File

Make sure your `/etc/hosts` has:
```
127.0.0.1 api.drlgame.com
```

#### Step 6: Launch the Game

Launch DRL Simulator from Steam. With the SSL bypass plugin:
- BepInEx will load and inject Harmony patches
- The patch intercepts all UnityWebRequest calls
- It injects a custom CertificateHandler that accepts all certificates
- The game connects to your local mock server successfully

### Verification

Check the BepInEx log after launching:
```bash
cat "$HOME/.local/share/Steam/steamapps/common/DRL Simulator/BepInEx/LogOutput.log"
```

You should see:
```
[Info   :   BepInEx] BepInEx 5.4.23.2 - DRL Simulator
[Info   :DRL SSL Bypass] DRL SSL Bypass Plugin loaded!
[Info   :DRL SSL Bypass] SSL certificate validation bypass enabled.
```

### Troubleshooting

#### BepInEx Not Loading

- Make sure Steam launch options are set correctly
- Check that `winhttp.dll` exists in the game folder
- Verify `doorstop_config.ini` is present and correct

#### Plugin Not Loading

- Ensure the compiled DLL is in `BepInEx/plugins/`
- Check BepInEx/LogOutput.log for errors

#### Still Getting SSL Errors

- The plugin only affects UnityWebRequest calls
- Some games use different HTTP libraries
- Check if the game uses WWW (deprecated) instead of UnityWebRequest

### Alternative: HTTP-Only Mode (Not Recommended)

If you can't install Mono, you could try patching the game binary to use HTTP instead of HTTPS. This is more complex and may break other functionality.

## Files Installed

- `BepInEx/` - BepInEx framework
- `BepInEx/core/` - Core BepInEx libraries
- `BepInEx/plugins/` - Where plugins are installed
- `winhttp.dll` - BepInEx bootstrapper
- `doorstop_config.ini` - BepInEx configuration
- `community-server/SSLBypassPlugin.cs` - Plugin source code
- `community-server/compile_plugin.sh` - Compilation script
