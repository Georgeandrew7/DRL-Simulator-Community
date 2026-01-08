#!/bin/bash
#
# DRL Simulator Community - macOS Installer Package Builder
# Creates a .pkg installer with wizard UI
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
BUILD_DIR="$SCRIPT_DIR/installer/build"
OUTPUT_DIR="$SCRIPT_DIR/installer/output"
RESOURCES_DIR="$SCRIPT_DIR/installer/resources"

# Package info
PKG_ID="com.drl-community.installer"
PKG_VERSION="1.0.0"
PKG_NAME="DRL-Community-Installer"
INSTALL_LOCATION="/Applications/DRL-Community"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       DRL Community - macOS Installer Package Builder        ║${NC}"
    echo -e "${CYAN}║                       Version 1.0.0                          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script must be run on macOS!"
        exit 1
    fi
    
    log_info "Running on macOS $(sw_vers -productVersion)"
}

check_tools() {
    log_info "Checking build tools..."
    
    local tools=("pkgbuild" "productbuild" "hdiutil")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is required but not found"
            exit 1
        fi
    done
    
    log_success "All build tools available"
}

clean_build() {
    log_info "Cleaning previous build..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$RESOURCES_DIR"
    log_success "Clean complete"
}

prepare_payload() {
    log_info "Preparing package payload..."
    
    local payload_dir="$BUILD_DIR/payload"
    mkdir -p "$payload_dir/DRL-Community"
    
    # Copy common files
    cp -R "$PROJECT_ROOT/common" "$payload_dir/DRL-Community/"
    
    # Copy macOS platform files
    cp -R "$SCRIPT_DIR"/*.sh "$payload_dir/DRL-Community/"
    
    # Copy documentation
    if [[ -d "$PROJECT_ROOT/docs" ]]; then
        cp -R "$PROJECT_ROOT/docs" "$payload_dir/DRL-Community/"
    fi
    
    # Copy license and readme
    cp "$PROJECT_ROOT/LICENSE" "$payload_dir/DRL-Community/" 2>/dev/null || true
    cp "$PROJECT_ROOT/README.md" "$payload_dir/DRL-Community/" 2>/dev/null || true
    
    # Copy requirements
    cp "$PROJECT_ROOT/requirements.txt" "$payload_dir/DRL-Community/" 2>/dev/null || true
    
    # Create version file
    echo "$PKG_VERSION" > "$payload_dir/DRL-Community/VERSION.txt"
    
    # Make scripts executable
    chmod +x "$payload_dir/DRL-Community"/*.sh 2>/dev/null || true
    
    # Create directories
    mkdir -p "$payload_dir/DRL-Community/logs"
    mkdir -p "$payload_dir/DRL-Community/certs"
    mkdir -p "$payload_dir/DRL-Community/backups"
    
    log_success "Payload prepared"
}

create_scripts() {
    log_info "Creating installer scripts..."
    
    local scripts_dir="$BUILD_DIR/scripts"
    mkdir -p "$scripts_dir"
    
    # Preinstall script
    cat > "$scripts_dir/preinstall" << 'EOF'
#!/bin/bash
# DRL Community - Preinstall Script

echo "Preparing to install DRL Simulator Community..."

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "WARNING: Python 3 is not installed."
    echo "You will need to install Python 3.8+ for the mock server to work."
fi

exit 0
EOF
    
    # Postinstall script
    cat > "$scripts_dir/postinstall" << 'EOF'
#!/bin/bash
# DRL Community - Postinstall Script

INSTALL_DIR="/Applications/DRL-Community"

echo "Configuring DRL Simulator Community..."

# Make scripts executable
chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true

# Install Python packages if pip is available
if command -v pip3 &> /dev/null; then
    echo "Installing Python dependencies..."
    pip3 install aiohttp requests cryptography --quiet 2>/dev/null || true
fi

# Add hosts entry (requires admin, which installer has)
HOSTS_FILE="/etc/hosts"
if ! grep -q "api.drlgame.com" "$HOSTS_FILE" 2>/dev/null; then
    echo "Adding hosts file entry..."
    echo "127.0.0.1 api.drlgame.com" >> "$HOSTS_FILE"
fi

# Create symlink in /usr/local/bin for easy access
mkdir -p /usr/local/bin
ln -sf "$INSTALL_DIR/start-offline-mode.sh" /usr/local/bin/drl-offline 2>/dev/null || true
ln -sf "$INSTALL_DIR/diagnose.sh" /usr/local/bin/drl-diagnose 2>/dev/null || true

# Create Application alias
if [[ -d "/Applications" ]]; then
    # Create a simple launcher app
    APP_DIR="/Applications/DRL Offline Mode.app"
    mkdir -p "$APP_DIR/Contents/MacOS"
    mkdir -p "$APP_DIR/Contents/Resources"
    
    # Create launcher script
    cat > "$APP_DIR/Contents/MacOS/DRL Offline Mode" << 'LAUNCHER'
#!/bin/bash
osascript -e 'tell application "Terminal" to do script "cd /Applications/DRL-Community && ./start-offline-mode.sh"'
LAUNCHER
    chmod +x "$APP_DIR/Contents/MacOS/DRL Offline Mode"
    
    # Create Info.plist
    cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DRL Offline Mode</string>
    <key>CFBundleIdentifier</key>
    <string>com.drl-community.launcher</string>
    <key>CFBundleName</key>
    <string>DRL Offline Mode</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST
fi

echo "Installation complete!"
echo ""
echo "To start playing:"
echo "1. Open Terminal and run: drl-offline"
echo "   OR double-click 'DRL Offline Mode' in Applications"
echo "2. Launch DRL Simulator from Steam"
echo ""

exit 0
EOF
    
    chmod +x "$scripts_dir/preinstall"
    chmod +x "$scripts_dir/postinstall"
    
    log_success "Scripts created"
}

create_resources() {
    log_info "Creating installer resources..."
    
    # Welcome text
    cat > "$RESOURCES_DIR/welcome.txt" << 'EOF'
Welcome to DRL Simulator Community!

This installer will set up everything you need to play DRL Simulator offline after the official servers were shut down.

What will be installed:
• Mock Backend Server - Replaces the defunct api.drlgame.com
• BepInEx Support Files - For mod loading
• SSL Bypass Plugin - For self-signed certificates
• Utility Tools - Diagnostics, updates, and more

Requirements:
• macOS 10.14 or later
• Python 3.8+ (for the mock server)
• DRL Simulator installed via Steam

Click Continue to proceed with the installation.
EOF
    
    # License (copy from project or create)
    if [[ -f "$PROJECT_ROOT/LICENSE" ]]; then
        cp "$PROJECT_ROOT/LICENSE" "$RESOURCES_DIR/license.txt"
    else
        cat > "$RESOURCES_DIR/license.txt" << 'EOF'
MIT License

Copyright (c) 2025 DRL Community

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
    fi
    
    # Readme / conclusion
    cat > "$RESOURCES_DIR/readme.txt" << 'EOF'
Installation Complete!

Getting Started:
1. Open Terminal and run: drl-offline
   OR double-click "DRL Offline Mode" in Applications
2. Wait for the mock server to start
3. Launch DRL Simulator from Steam
4. Enjoy offline play!

First Time Setup:
• If Python packages weren't installed automatically, run:
  pip3 install aiohttp requests cryptography

• For BepInEx, you may need to install it manually:
  Run: /Applications/DRL-Community/install-bepinex.sh

Troubleshooting:
• Run: drl-diagnose (or /Applications/DRL-Community/diagnose.sh)
• Check documentation in /Applications/DRL-Community/docs/

For updates, run:
  /Applications/DRL-Community/update.sh

Thank you for using DRL Simulator Community!

Project: https://github.com/Georgeandrew7/DRL-Simulator-Community
EOF
    
    log_success "Resources created"
}

create_distribution() {
    log_info "Creating distribution.xml..."
    
    cat > "$BUILD_DIR/distribution.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>DRL Simulator Community</title>
    <organization>com.drl-community</organization>
    <domains enable_localSystem="true"/>
    <options customize="never" require-scripts="true" rootVolumeOnly="true"/>
    
    <!-- Installer background -->
    <background file="background.png" alignment="bottomleft" scaling="none"/>
    
    <!-- Welcome, License, Readme -->
    <welcome file="welcome.txt"/>
    <license file="license.txt"/>
    <readme file="readme.txt"/>
    
    <!-- Installation choices -->
    <choices-outline>
        <line choice="default">
            <line choice="com.drl-community.pkg"/>
        </line>
    </choices-outline>
    
    <choice id="default"/>
    
    <choice id="com.drl-community.pkg" visible="false">
        <pkg-ref id="$PKG_ID"/>
    </choice>
    
    <pkg-ref id="$PKG_ID" version="$PKG_VERSION" onConclusion="none">DRL-Community.pkg</pkg-ref>
    
    <!-- System requirements -->
    <volume-check>
        <allowed-os-versions>
            <os-version min="10.14"/>
        </allowed-os-versions>
    </volume-check>
    
</installer-gui-script>
EOF
    
    log_success "Distribution XML created"
}

build_component_pkg() {
    log_info "Building component package..."
    
    pkgbuild \
        --root "$BUILD_DIR/payload" \
        --scripts "$BUILD_DIR/scripts" \
        --identifier "$PKG_ID" \
        --version "$PKG_VERSION" \
        --install-location "/Applications" \
        "$BUILD_DIR/DRL-Community.pkg"
    
    log_success "Component package built"
}

build_product_pkg() {
    log_info "Building product package..."
    
    # Copy resources
    cp "$RESOURCES_DIR"/* "$BUILD_DIR/" 2>/dev/null || true
    
    # Create a simple background if not exists
    if [[ ! -f "$BUILD_DIR/background.png" ]]; then
        # Create placeholder - in production use a real image
        log_warn "No background.png found, using default"
    fi
    
    productbuild \
        --distribution "$BUILD_DIR/distribution.xml" \
        --resources "$BUILD_DIR" \
        --package-path "$BUILD_DIR" \
        "$OUTPUT_DIR/$PKG_NAME-$PKG_VERSION.pkg"
    
    log_success "Product package built: $OUTPUT_DIR/$PKG_NAME-$PKG_VERSION.pkg"
}

create_dmg() {
    log_info "Creating DMG disk image..."
    
    local dmg_dir="$BUILD_DIR/dmg"
    local dmg_name="$PKG_NAME-$PKG_VERSION"
    
    mkdir -p "$dmg_dir"
    
    # Copy the pkg to dmg folder
    cp "$OUTPUT_DIR/$PKG_NAME-$PKG_VERSION.pkg" "$dmg_dir/"
    
    # Create a readme
    cat > "$dmg_dir/README.txt" << 'EOF'
DRL Simulator Community Installer

To install:
1. Double-click "DRL-Community-Installer-1.0.0.pkg"
2. Follow the installation wizard
3. Enter your password when prompted

After installation:
- Open Terminal and run: drl-offline
- Or use the "DRL Offline Mode" app in Applications
- Launch DRL Simulator from Steam

For help: https://github.com/Georgeandrew7/DRL-Simulator-Community
EOF
    
    # Create the DMG
    hdiutil create \
        -volname "$dmg_name" \
        -srcfolder "$dmg_dir" \
        -ov \
        -format UDZO \
        "$OUTPUT_DIR/$dmg_name.dmg"
    
    log_success "DMG created: $OUTPUT_DIR/$dmg_name.dmg"
}

show_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Build Complete!                           ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Output files:"
    echo ""
    ls -lh "$OUTPUT_DIR"/*.pkg "$OUTPUT_DIR"/*.dmg 2>/dev/null | while read line; do
        echo "    $line"
    done
    echo ""
    echo "  To install, double-click the .pkg file or mount the .dmg"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

print_banner
check_macos
check_tools
clean_build
prepare_payload
create_scripts
create_resources
create_distribution
build_component_pkg
build_product_pkg
create_dmg
show_summary
