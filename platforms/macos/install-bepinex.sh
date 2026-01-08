#!/bin/bash
# DRL Community Server - BepInEx Installation Script for macOS
# Installs BepInEx for Unity games on macOS

set -e

GAME_DIR="$HOME/Library/Application Support/Steam/steamapps/common/DRL Simulator"
BEPINEX_VERSION="5.4.23.2"
# macOS uses the unix version
BEPINEX_URL="https://github.com/BepInEx/BepInEx/releases/download/v${BEPINEX_VERSION}/BepInEx_unix_${BEPINEX_VERSION}.zip"

echo "=============================================="
echo "DRL Community Server - BepInEx Installer"
echo "              (macOS Version)"
echo "=============================================="
echo ""

# Check if game exists
if [ ! -f "$GAME_DIR/DRL Simulator.app/Contents/MacOS/DRL Simulator" ]; then
    echo "WARNING: DRL Simulator not found at default location:"
    echo "  $GAME_DIR"
    echo ""
    read -p "Enter custom game path (or press Enter to use default): " CUSTOM_PATH
    if [ -n "$CUSTOM_PATH" ]; then
        GAME_DIR="$CUSTOM_PATH"
    fi
fi

# Check if BepInEx is already installed
if [ -d "$GAME_DIR/BepInEx" ]; then
    echo "BepInEx is already installed!"
    echo "Checking for updates..."
else
    echo "Downloading BepInEx ${BEPINEX_VERSION}..."
    
    # Download BepInEx
    cd /tmp
    curl -L "$BEPINEX_URL" -o bepinex.zip || {
        echo "ERROR: Failed to download BepInEx"
        echo "Please download manually from: $BEPINEX_URL"
        exit 1
    }
    
    echo "Extracting BepInEx..."
    unzip -o bepinex.zip -d "$GAME_DIR"
    rm bepinex.zip
    
    # Make run script executable
    chmod +x "$GAME_DIR/run_bepinex.sh" 2>/dev/null || true
    
    echo "BepInEx installed successfully!"
fi

# Create plugins directory if it doesn't exist
mkdir -p "$GAME_DIR/BepInEx/plugins"

# Copy plugins if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/../common/plugins"
if [ -d "$PLUGIN_DIR" ]; then
    echo ""
    echo "Plugin source files found at: $PLUGIN_DIR"
    echo ""
    echo "To compile plugins on macOS:"
    echo "1. Install Mono: brew install mono"
    echo "2. Run the compile script"
fi

echo ""
echo "=============================================="
echo "         Installation Complete!"
echo "=============================================="
echo ""
echo "BepInEx has been installed to:"
echo "  $GAME_DIR"
echo ""
echo "For macOS, you need to launch the game via the run_bepinex.sh script:"
echo "  cd \"$GAME_DIR\""
echo "  ./run_bepinex.sh"
echo ""
echo "Or set Steam launch options:"
echo "  \"$GAME_DIR/run_bepinex.sh\" %command%"
echo ""
