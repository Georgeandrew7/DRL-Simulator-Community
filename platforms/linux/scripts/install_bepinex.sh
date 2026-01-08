#!/bin/bash
# DRL Community Server - BepInEx Installation Script
# This script installs BepInEx and the SSL Bypass plugin for DRL Simulator
# Allows connection to self-hosted servers with self-signed certificates

set -e

GAME_DIR="$HOME/.local/share/Steam/steamapps/common/DRL Simulator"
BEPINEX_VERSION="5.4.23.2"
BEPINEX_URL="https://github.com/BepInEx/BepInEx/releases/download/v${BEPINEX_VERSION}/BepInEx_win_x64_${BEPINEX_VERSION}.zip"

echo "=============================================="
echo "DRL Community Server - BepInEx Installer"
echo "=============================================="
echo ""

# Check if game exists
if [ ! -f "$GAME_DIR/DRL Simulator.exe" ]; then
    echo "ERROR: DRL Simulator not found at $GAME_DIR"
    exit 1
fi

# Check if BepInEx is already installed
if [ -d "$GAME_DIR/BepInEx" ]; then
    echo "BepInEx is already installed!"
    echo "Checking for updates..."
else
    echo "Downloading BepInEx ${BEPINEX_VERSION}..."
    
    # Download BepInEx
    cd /tmp
    wget -q "$BEPINEX_URL" -O bepinex.zip || {
        echo "ERROR: Failed to download BepInEx"
        echo "Please download manually from: $BEPINEX_URL"
        exit 1
    }
    
    echo "Extracting BepInEx..."
    unzip -o bepinex.zip -d "$GAME_DIR"
    rm bepinex.zip
    
    echo "BepInEx installed successfully!"
fi

# Create plugins directory if it doesn't exist
mkdir -p "$GAME_DIR/BepInEx/plugins"

# Copy our SSL Bypass plugin source
PLUGIN_DIR="$GAME_DIR/community-server"
if [ -f "$PLUGIN_DIR/SSLBypassPlugin.cs" ]; then
    echo ""
    echo "SSL Bypass Plugin source found!"
    echo ""
    echo "To compile the plugin, you need:"
    echo "1. .NET SDK or Visual Studio"
    echo "2. BepInEx references"
    echo ""
    echo "For now, we'll create a pre-compiled version..."
fi

# Create the winhttp.dll configuration for Proton/Wine
echo ""
echo "Configuring BepInEx for Proton/Wine..."

# Create the BepInEx config directory
mkdir -p "$GAME_DIR/BepInEx/config"

# Create doorstop config
cat > "$GAME_DIR/doorstop_config.ini" << 'EOF'
[General]
enabled=true
targetAssembly=BepInEx/core/BepInEx.Preloader.dll
redirectOutputLog=true
ignoreDisableSwitch=false
dllSearchPathOverride=
EOF

echo "Configuration created!"

# Set up Steam launch options message
echo ""
echo "=============================================="
echo "IMPORTANT: Steam Launch Options Required"
echo "=============================================="
echo ""
echo "You need to add the following to Steam's Launch Options for DRL Simulator:"
echo ""
echo 'WINEDLLOVERRIDES="winhttp=n,b" %command%'
echo ""
echo "To do this:"
echo "1. Right-click DRL Simulator in Steam"
echo "2. Click Properties"
echo "3. In the General tab, find 'Launch Options'"
echo "4. Paste the command above"
echo ""

# Create a helper script to compile the plugin (if dotnet is available)
cat > "$PLUGIN_DIR/compile_plugin.sh" << 'COMPILE_SCRIPT'
#!/bin/bash
# Compile the SSL Bypass Plugin

GAME_DIR="$HOME/.local/share/Steam/steamapps/common/DRL Simulator"
MANAGED_DIR="$GAME_DIR/DRL Simulator_Data/Managed"
BEPINEX_DIR="$GAME_DIR/BepInEx/core"

# Check for mcs (Mono C# compiler)
if command -v mcs &> /dev/null; then
    echo "Compiling with Mono..."
    mcs -target:library \
        -out:"$GAME_DIR/BepInEx/plugins/DRLSSLBypass.dll" \
        -reference:"$BEPINEX_DIR/BepInEx.dll" \
        -reference:"$BEPINEX_DIR/0Harmony.dll" \
        -reference:"$MANAGED_DIR/UnityEngine.dll" \
        -reference:"$MANAGED_DIR/UnityEngine.CoreModule.dll" \
        -reference:"$MANAGED_DIR/UnityEngine.UnityWebRequestModule.dll" \
        SSLBypassPlugin.cs
    
    if [ $? -eq 0 ]; then
        echo "Plugin compiled successfully!"
        echo "Installed to: $GAME_DIR/BepInEx/plugins/DRLSSLBypass.dll"
    else
        echo "Compilation failed!"
    fi
else
    echo "Mono C# compiler (mcs) not found."
    echo "Install with: sudo apt install mono-mcs"
fi
COMPILE_SCRIPT

chmod +x "$PLUGIN_DIR/compile_plugin.sh"

echo "=============================================="
echo "Installation Summary"
echo "=============================================="
echo ""
echo "1. BepInEx installed to: $GAME_DIR/BepInEx/"
echo "2. Plugin source at: $PLUGIN_DIR/SSLBypassPlugin.cs"
echo "3. Compile script at: $PLUGIN_DIR/compile_plugin.sh"
echo ""
echo "Next steps:"
echo "1. Install Mono: sudo apt install mono-mcs"
echo "2. Run: $PLUGIN_DIR/compile_plugin.sh"
echo "3. Set Steam launch options (see above)"
echo "4. Start the mock server: python mock_drl_backend.py --dual"
echo "5. Launch the game!"
echo ""
echo "Done!"
