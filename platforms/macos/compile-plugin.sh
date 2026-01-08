#!/bin/bash
# Compile the SSL Bypass Plugin for DRL Simulator on macOS
# Requires: mono (install via: brew install mono)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$HOME/Library/Application Support/Steam/steamapps/common/DRL Simulator"
MANAGED_DIR="$GAME_DIR/DRL Simulator.app/Contents/Resources/Data/Managed"
BEPINEX_DIR="$GAME_DIR/BepInEx/core"
PLUGIN_DIR="$GAME_DIR/BepInEx/plugins"
SOURCE_DIR="$SCRIPT_DIR/../common/plugins"

echo "=============================================="
echo "DRL SSL Bypass Plugin Compiler (macOS)"
echo "=============================================="
echo ""

# Check for mcs (Mono C# compiler)
if ! command -v mcs &> /dev/null; then
    echo "ERROR: Mono C# compiler (mcs) not found!"
    echo ""
    echo "Install Mono via Homebrew:"
    echo "  brew install mono"
    echo ""
    exit 1
fi

echo "Found Mono C# compiler: $(which mcs)"
echo ""

# Check for required files
echo "Checking dependencies..."

if [ ! -f "$BEPINEX_DIR/BepInEx.dll" ]; then
    echo "ERROR: BepInEx not found. Run install-bepinex.sh first."
    exit 1
fi

if [ ! -f "$MANAGED_DIR/UnityEngine.dll" ]; then
    echo "ERROR: Unity assemblies not found."
    echo "Looking in: $MANAGED_DIR"
    echo ""
    echo "Please check your game installation path."
    exit 1
fi

if [ ! -f "$SOURCE_DIR/SSLBypassPlugin.cs" ]; then
    echo "ERROR: SSLBypassPlugin.cs not found!"
    exit 1
fi

echo "All dependencies found!"
echo ""

# Create plugins directory
mkdir -p "$PLUGIN_DIR"

# Compile
echo "Compiling SSLBypassPlugin.cs..."
mcs -target:library \
    -out:"$PLUGIN_DIR/DRLSSLBypass.dll" \
    -reference:"$BEPINEX_DIR/BepInEx.dll" \
    -reference:"$BEPINEX_DIR/0Harmony.dll" \
    -reference:"$MANAGED_DIR/UnityEngine.dll" \
    -reference:"$MANAGED_DIR/UnityEngine.CoreModule.dll" \
    -reference:"$MANAGED_DIR/UnityEngine.UnityWebRequestModule.dll" \
    "$SOURCE_DIR/SSLBypassPlugin.cs"

if [ $? -eq 0 ]; then
    echo ""
    echo "=============================================="
    echo "SUCCESS!"
    echo "=============================================="
    echo ""
    echo "Plugin compiled to: $PLUGIN_DIR/DRLSSLBypass.dll"
    echo ""
    echo "Next steps:"
    echo "1. Start the mock server: sudo python3 mock_drl_backend.py --dual"
    echo "2. Launch the game via run_bepinex.sh"
    echo ""
    ls -la "$PLUGIN_DIR/DRLSSLBypass.dll"
else
    echo ""
    echo "ERROR: Compilation failed!"
    exit 1
fi
