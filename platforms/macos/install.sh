#!/bin/bash
#
# DRL Simulator Community - macOS Installer
# One-click installer for offline/community play
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       DRL Simulator Community Server - macOS Installer        ║"
echo "║                         v1.0.0                                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_DIR="$REPO_ROOT/common"

# Default paths
DEFAULT_STEAM_PATH="$HOME/Library/Application Support/Steam/steamapps/common/DRL Simulator"
INSTALL_DIR="$HOME/Library/Application Support/DRL-Community"
CONFIG_FILE="$INSTALL_DIR/config.sh"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.drl-community.server.plist"

# Functions
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

check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This installer is for macOS only!"
        exit 1
    fi
    
    # Get macOS version
    MACOS_VERSION=$(sw_vers -productVersion)
    log_info "Detected macOS $MACOS_VERSION"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this installer as root. It will ask for sudo when needed."
        exit 1
    fi
}

check_homebrew() {
    if ! command -v brew &> /dev/null; then
        log_warn "Homebrew not found."
        echo ""
        echo -e "${YELLOW}Homebrew is recommended for installing dependencies.${NC}"
        echo "Install it from: https://brew.sh"
        echo ""
        read -p "Install Homebrew now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            
            # Add Homebrew to PATH for Apple Silicon
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
        fi
    else
        log_success "Homebrew found"
    fi
}

find_game_directory() {
    log_info "Looking for DRL Simulator installation..."
    
    # Check common Steam locations
    POSSIBLE_PATHS=(
        "$DEFAULT_STEAM_PATH"
        "$HOME/Library/Application Support/Steam/steamapps/common/DRL Simulator"
        "/Applications/DRL Simulator"
    )
    
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -d "$path" ]; then
            # Check for either .app bundle or Windows exe (via Proton)
            if [ -d "$path/DRL Simulator.app" ] || [ -f "$path/DRL Simulator.exe" ]; then
                GAME_DIR="$path"
                log_success "Found DRL Simulator at: $GAME_DIR"
                return 0
            fi
        fi
    done
    
    # Ask user for path
    echo ""
    log_warn "Could not auto-detect DRL Simulator installation."
    echo -e "${YELLOW}Please enter the full path to your DRL Simulator folder:${NC}"
    echo "(e.g., /Users/yourname/Library/Application Support/Steam/steamapps/common/DRL Simulator)"
    read -r GAME_DIR
    
    if [ ! -d "$GAME_DIR" ]; then
        log_error "Directory does not exist: $GAME_DIR"
        exit 1
    fi
}

install_dependencies() {
    echo ""
    log_info "Installing dependencies..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_info "Installing Python 3..."
        if command -v brew &> /dev/null; then
            brew install python3
        else
            log_error "Python 3 is required. Please install it manually."
            echo "Download from: https://www.python.org/downloads/macos/"
            exit 1
        fi
    else
        log_success "Python3 found: $(python3 --version)"
    fi
    
    # Check pip
    if ! command -v pip3 &> /dev/null; then
        log_info "Installing pip..."
        python3 -m ensurepip --upgrade 2>/dev/null || true
    fi
    
    # Install Python packages
    log_info "Installing Python packages..."
    pip3 install --user aiohttp requests 2>/dev/null || pip install --user aiohttp requests
    
    # Check/install Mono (for plugin compilation)
    if ! command -v mcs &> /dev/null; then
        log_info "Installing Mono (for plugin compilation)..."
        if command -v brew &> /dev/null; then
            brew install mono
        else
            log_warn "Mono not installed. You won't be able to compile plugins."
            log_warn "Install manually: brew install mono"
        fi
    else
        log_success "Mono compiler found"
    fi
    
    # Check openssl
    if ! command -v openssl &> /dev/null; then
        if command -v brew &> /dev/null; then
            brew install openssl
        fi
    fi
    
    log_success "Dependencies installed"
}

create_install_directory() {
    log_info "Creating installation directory..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/server"
    mkdir -p "$INSTALL_DIR/plugins"
    mkdir -p "$INSTALL_DIR/tools"
    mkdir -p "$INSTALL_DIR/logs"
    mkdir -p "$INSTALL_DIR/certs"
    
    log_success "Created: $INSTALL_DIR"
}

copy_files() {
    log_info "Copying server files..."
    
    # Copy server files
    cp "$COMMON_DIR/server/"*.py "$INSTALL_DIR/server/" 2>/dev/null || true
    
    # Copy plugins
    cp "$COMMON_DIR/plugins/"*.cs "$INSTALL_DIR/plugins/" 2>/dev/null || true
    
    # Copy tools
    cp "$COMMON_DIR/tools/"*.py "$INSTALL_DIR/tools/" 2>/dev/null || true
    
    # Copy macOS scripts
    cp "$SCRIPT_DIR/"*.sh "$INSTALL_DIR/" 2>/dev/null || true
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR/"*.sh 2>/dev/null || true
    
    log_success "Files copied"
}

generate_ssl_certs() {
    log_info "Generating SSL certificates..."
    
    CERT_DIR="$INSTALL_DIR/certs"
    
    if [ -f "$CERT_DIR/server.crt" ] && [ -f "$CERT_DIR/server.key" ]; then
        log_warn "SSL certificates already exist. Skipping generation."
        return
    fi
    
    # Generate self-signed certificate
    openssl req -x509 -newkey rsa:4096 -keyout "$CERT_DIR/server.key" \
        -out "$CERT_DIR/server.crt" -days 365 -nodes \
        -subj "/CN=api.drlgame.com/O=DRL Community/C=US" 2>/dev/null
    
    log_success "SSL certificates generated"
}

install_bepinex() {
    log_info "Installing BepInEx..."
    
    # macOS uses the Unix version of BepInEx
    BEPINEX_URL="https://github.com/BepInEx/BepInEx/releases/download/v5.4.23.2/BepInEx_unix_5.4.23.2.0.zip"
    BEPINEX_DIR="$GAME_DIR/BepInEx"
    
    if [ -d "$BEPINEX_DIR" ]; then
        log_warn "BepInEx already installed. Skipping."
    else
        log_info "Downloading BepInEx..."
        
        TEMP_ZIP="/tmp/bepinex.zip"
        curl -sL -o "$TEMP_ZIP" "$BEPINEX_URL"
        
        log_info "Extracting BepInEx..."
        unzip -q -o "$TEMP_ZIP" -d "$GAME_DIR"
        rm "$TEMP_ZIP"
        
        # Make run script executable
        chmod +x "$GAME_DIR/run_bepinex.sh" 2>/dev/null || true
        
        log_success "BepInEx installed"
    fi
    
    # Create plugins directory
    mkdir -p "$BEPINEX_DIR/plugins"
}

compile_plugins() {
    log_info "Compiling BepInEx plugins..."
    
    if ! command -v mcs &> /dev/null; then
        log_warn "Mono compiler not found. Skipping plugin compilation."
        return
    fi
    
    BEPINEX_DIR="$GAME_DIR/BepInEx"
    
    # Try to find Managed DLLs
    MANAGED_DIR=""
    if [ -d "$GAME_DIR/DRL Simulator.app/Contents/Resources/Data/Managed" ]; then
        MANAGED_DIR="$GAME_DIR/DRL Simulator.app/Contents/Resources/Data/Managed"
    elif [ -d "$GAME_DIR/DRL Simulator_Data/Managed" ]; then
        MANAGED_DIR="$GAME_DIR/DRL Simulator_Data/Managed"
    fi
    
    if [ -z "$MANAGED_DIR" ] || [ ! -f "$MANAGED_DIR/UnityEngine.dll" ]; then
        log_warn "Game DLLs not found. Skipping plugin compilation."
        return
    fi
    
    # Reference assemblies
    REFS="-r:$BEPINEX_DIR/core/BepInEx.dll"
    REFS="$REFS -r:$BEPINEX_DIR/core/0Harmony.dll"
    REFS="$REFS -r:$MANAGED_DIR/UnityEngine.dll"
    REFS="$REFS -r:$MANAGED_DIR/UnityEngine.CoreModule.dll"
    REFS="$REFS -r:$MANAGED_DIR/Assembly-CSharp.dll"
    
    # Compile SSL Bypass Plugin
    if [ -f "$INSTALL_DIR/plugins/SSLBypassPlugin.cs" ]; then
        log_info "Compiling SSLBypassPlugin..."
        mcs -target:library -out:"$BEPINEX_DIR/plugins/SSLBypassPlugin.dll" \
            $REFS "$INSTALL_DIR/plugins/SSLBypassPlugin.cs" 2>/dev/null && \
            log_success "SSLBypassPlugin compiled" || \
            log_warn "SSLBypassPlugin compilation failed"
    fi
    
    # Compile License Bypass Plugin
    if [ -f "$INSTALL_DIR/plugins/LicenseBypassPlugin.cs" ]; then
        log_info "Compiling LicenseBypassPlugin..."
        mcs -target:library -out:"$BEPINEX_DIR/plugins/LicenseBypassPlugin.dll" \
            $REFS "$INSTALL_DIR/plugins/LicenseBypassPlugin.cs" 2>/dev/null && \
            log_success "LicenseBypassPlugin compiled" || \
            log_warn "LicenseBypassPlugin compilation failed"
    fi
}

configure_hosts() {
    log_info "Configuring hosts file..."
    
    HOSTS_ENTRY="127.0.0.1 api.drlgame.com"
    
    if grep -q "api.drlgame.com" /etc/hosts; then
        log_warn "hosts entry already exists"
    else
        echo ""
        echo -e "${YELLOW}We need to add an entry to /etc/hosts to redirect api.drlgame.com${NC}"
        echo -e "${YELLOW}This requires sudo access.${NC}"
        echo ""
        read -p "Add hosts entry now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$HOSTS_ENTRY" | sudo tee -a /etc/hosts > /dev/null
            log_success "hosts entry added"
        else
            log_warn "Skipped. You'll need to add manually: $HOSTS_ENTRY"
        fi
    fi
}

save_config() {
    log_info "Saving configuration..."
    
    cat > "$CONFIG_FILE" << EOF
#!/bin/bash
# DRL Community Server Configuration
# Generated: $(date)

export DRL_GAME_DIR="$GAME_DIR"
export DRL_INSTALL_DIR="$INSTALL_DIR"
export DRL_CERT_DIR="$INSTALL_DIR/certs"
export DRL_LOG_DIR="$INSTALL_DIR/logs"
EOF
    
    chmod +x "$CONFIG_FILE"
    log_success "Configuration saved"
}

create_launcher_scripts() {
    log_info "Creating launcher scripts..."
    
    # Main launcher script
    cat > "$INSTALL_DIR/start-server.sh" << 'LAUNCHER'
#!/bin/bash
# DRL Community Server Launcher

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "Starting DRL Community Server..."
echo "Game Directory: $DRL_GAME_DIR"
echo ""

# Start the mock backend
cd "$SCRIPT_DIR/server"
sudo python3 mock_drl_backend.py --dual --game-dir "$DRL_GAME_DIR" --cert "$DRL_CERT_DIR/server.crt" --key "$DRL_CERT_DIR/server.key"
LAUNCHER
    chmod +x "$INSTALL_DIR/start-server.sh"
    
    # Create macOS .command file (double-clickable)
    cat > "$HOME/Desktop/DRL Community Server.command" << COMMAND
#!/bin/bash
cd "$INSTALL_DIR"
./start-server.sh
COMMAND
    chmod +x "$HOME/Desktop/DRL Community Server.command"
    
    log_success "Created desktop launcher: DRL Community Server.command"
}

create_app_bundle() {
    log_info "Creating macOS application bundle..."
    
    APP_DIR="$HOME/Applications/DRL Community Server.app"
    mkdir -p "$APP_DIR/Contents/MacOS"
    mkdir -p "$APP_DIR/Contents/Resources"
    
    # Create Info.plist
    cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIdentifier</key>
    <string>com.drl-community.server</string>
    <key>CFBundleName</key>
    <string>DRL Community Server</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST
    
    # Create launcher script
    cat > "$APP_DIR/Contents/MacOS/launcher" << LAUNCHER
#!/bin/bash
osascript -e 'tell app "Terminal" to do script "cd \"$INSTALL_DIR\" && ./start-server.sh"'
LAUNCHER
    chmod +x "$APP_DIR/Contents/MacOS/launcher"
    
    log_success "Created app bundle: DRL Community Server.app"
}

print_summary() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Installation Complete! 🎮                        ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Installation Summary:${NC}"
    echo "  • Install Directory: $INSTALL_DIR"
    echo "  • Game Directory: $GAME_DIR"
    echo "  • BepInEx: Installed"
    echo "  • SSL Certificates: Generated"
    echo ""
    echo -e "${CYAN}To start playing:${NC}"
    echo ""
    echo "  Option 1: Double-click 'DRL Community Server' on your Desktop"
    echo ""
    echo "  Option 2: Run from Terminal:"
    echo -e "     ${GREEN}$INSTALL_DIR/start-server.sh${NC}"
    echo ""
    echo "  Then launch DRL Simulator from Steam"
    echo ""
    echo -e "${YELLOW}Note: The server requires sudo for ports 80/443${NC}"
    echo ""
    echo -e "${CYAN}If using Steam with Proton/CrossOver, set launch options:${NC}"
    echo -e "${GREEN}WINEDLLOVERRIDES=\"winhttp=n,b\" %command%${NC}"
    echo ""
}

# Main installation flow
main() {
    check_macos
    check_root
    check_homebrew
    
    echo ""
    echo -e "${CYAN}This installer will:${NC}"
    echo "  1. Install required dependencies (Python, Mono)"
    echo "  2. Set up the mock backend server"
    echo "  3. Install BepInEx mod framework"
    echo "  4. Compile and install bypass plugins"
    echo "  5. Configure hosts file"
    echo "  6. Create launcher application"
    echo ""
    read -p "Continue with installation? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled."
        exit 0
    fi
    
    find_game_directory
    install_dependencies
    create_install_directory
    copy_files
    generate_ssl_certs
    install_bepinex
    compile_plugins
    configure_hosts
    save_config
    create_launcher_scripts
    create_app_bundle
    print_summary
}

# Run installer
main "$@"
