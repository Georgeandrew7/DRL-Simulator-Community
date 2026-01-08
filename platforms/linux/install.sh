#!/bin/bash
#
# DRL Simulator Community - Linux Installer
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
echo "║       DRL Simulator Community Server - Linux Installer        ║"
echo "║                         v1.0.0                                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_DIR="$REPO_ROOT/common"

# Default paths
DEFAULT_STEAM_PATH="$HOME/.local/share/Steam/steamapps/common/DRL Simulator"
DEFAULT_PROTON_STEAM_PATH="$HOME/.steam/steam/steamapps/common/DRL Simulator"
INSTALL_DIR="$HOME/.drl-community"
CONFIG_FILE="$INSTALL_DIR/config.sh"

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

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this installer as root. It will ask for sudo when needed."
        exit 1
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_NAME=$NAME
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO=$DISTRIB_ID
        DISTRO_NAME=$DISTRIB_DESCRIPTION
    else
        DISTRO="unknown"
        DISTRO_NAME="Unknown Linux"
    fi
    log_info "Detected: $DISTRO_NAME"
}

detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
        PKG_INSTALL="sudo apt-get install -y"
        PKG_UPDATE="sudo apt-get update"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="sudo dnf install -y"
        PKG_UPDATE="sudo dnf check-update || true"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="sudo pacman -S --noconfirm"
        PKG_UPDATE="sudo pacman -Sy"
    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="zypper"
        PKG_INSTALL="sudo zypper install -y"
        PKG_UPDATE="sudo zypper refresh"
    else
        PKG_MANAGER="unknown"
        log_warn "Unknown package manager. You may need to install dependencies manually."
    fi
}

find_game_directory() {
    log_info "Looking for DRL Simulator installation..."
    
    # Check common Steam locations
    POSSIBLE_PATHS=(
        "$DEFAULT_STEAM_PATH"
        "$DEFAULT_PROTON_STEAM_PATH"
        "$HOME/.steam/steam/steamapps/common/DRL Simulator"
        "$HOME/.local/share/Steam/steamapps/common/DRL Simulator"
        "/opt/steam/steamapps/common/DRL Simulator"
    )
    
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -d "$path" ] && [ -f "$path/DRL Simulator.exe" ]; then
            GAME_DIR="$path"
            log_success "Found DRL Simulator at: $GAME_DIR"
            return 0
        fi
    done
    
    # Ask user for path
    echo ""
    log_warn "Could not auto-detect DRL Simulator installation."
    echo -e "${YELLOW}Please enter the full path to your DRL Simulator folder:${NC}"
    echo "(e.g., /home/user/.local/share/Steam/steamapps/common/DRL Simulator)"
    read -r GAME_DIR
    
    if [ ! -d "$GAME_DIR" ]; then
        log_error "Directory does not exist: $GAME_DIR"
        exit 1
    fi
    
    if [ ! -f "$GAME_DIR/DRL Simulator.exe" ]; then
        log_warn "DRL Simulator.exe not found in directory. Continuing anyway..."
    fi
}

install_dependencies() {
    echo ""
    log_info "Installing dependencies..."
    
    DEPS_NEEDED=()
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        DEPS_NEEDED+=("python3")
    else
        log_success "Python3 found: $(python3 --version)"
    fi
    
    # Check pip
    if ! command -v pip3 &> /dev/null; then
        DEPS_NEEDED+=("python3-pip")
    fi
    
    # Check mono (for plugin compilation)
    if ! command -v mcs &> /dev/null; then
        case $PKG_MANAGER in
            apt) DEPS_NEEDED+=("mono-mcs") ;;
            dnf) DEPS_NEEDED+=("mono-core") ;;
            pacman) DEPS_NEEDED+=("mono") ;;
            zypper) DEPS_NEEDED+=("mono-core") ;;
        esac
    else
        log_success "Mono compiler found"
    fi
    
    # Check wget/curl
    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        DEPS_NEEDED+=("wget")
    fi
    
    # Install system dependencies
    if [ ${#DEPS_NEEDED[@]} -gt 0 ]; then
        log_info "Installing: ${DEPS_NEEDED[*]}"
        $PKG_UPDATE
        $PKG_INSTALL "${DEPS_NEEDED[@]}"
    fi
    
    # Install Python packages
    log_info "Installing Python packages..."
    pip3 install --user aiohttp requests cryptography 2>/dev/null || pip install --user aiohttp requests cryptography
    
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
    
    # Copy scripts
    cp "$SCRIPT_DIR/scripts/"*.sh "$INSTALL_DIR/" 2>/dev/null || true
    
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
    
    BEPINEX_URL="https://github.com/BepInEx/BepInEx/releases/download/v5.4.23.2/BepInEx_unix_5.4.23.2.0.zip"
    BEPINEX_DIR="$GAME_DIR/BepInEx"
    
    if [ -d "$BEPINEX_DIR" ]; then
        log_warn "BepInEx already installed. Skipping."
    else
        log_info "Downloading BepInEx..."
        
        TEMP_ZIP="/tmp/bepinex.zip"
        if command -v wget &> /dev/null; then
            wget -q -O "$TEMP_ZIP" "$BEPINEX_URL"
        else
            curl -sL -o "$TEMP_ZIP" "$BEPINEX_URL"
        fi
        
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
        log_warn "You can compile plugins manually later with: mcs -target:library ..."
        return
    fi
    
    BEPINEX_DIR="$GAME_DIR/BepInEx"
    MANAGED_DIR="$GAME_DIR/DRL Simulator_Data/Managed"
    
    # Reference assemblies
    REFS="-r:$BEPINEX_DIR/core/BepInEx.dll"
    REFS="$REFS -r:$BEPINEX_DIR/core/0Harmony.dll"
    REFS="$REFS -r:$MANAGED_DIR/UnityEngine.dll"
    REFS="$REFS -r:$MANAGED_DIR/UnityEngine.CoreModule.dll"
    REFS="$REFS -r:$MANAGED_DIR/Assembly-CSharp.dll"
    
    # Check if references exist
    if [ ! -f "$MANAGED_DIR/UnityEngine.dll" ]; then
        log_warn "Game DLLs not found. Skipping plugin compilation."
        return
    fi
    
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
    cat > "$INSTALL_DIR/start-server.sh" << 'EOF'
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
EOF
    chmod +x "$INSTALL_DIR/start-server.sh"
    
    # Desktop entry
    DESKTOP_FILE="$HOME/.local/share/applications/drl-community-server.desktop"
    mkdir -p "$(dirname "$DESKTOP_FILE")"
    
    cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=DRL Community Server
Comment=Start the DRL Simulator Community Server
Exec=gnome-terminal -- bash -c '$INSTALL_DIR/start-server.sh; read -p "Press Enter to close..."'
Icon=applications-games
Terminal=false
Type=Application
Categories=Game;
EOF
    
    log_success "Launcher scripts created"
}

configure_steam() {
    log_info "Configuring Steam launch options..."
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  Steam Configuration Required                 ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Please set the following launch options in Steam:"
    echo ""
    echo "1. Right-click 'DRL Simulator' in Steam Library"
    echo "2. Click 'Properties'"
    echo "3. In 'Launch Options', paste:"
    echo ""
    echo -e "${GREEN}WINEDLLOVERRIDES=\"winhttp=n,b\" %command%${NC}"
    echo ""
    echo "This enables BepInEx to load properly with Proton/Wine."
    echo ""
    read -p "Press Enter when done..."
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
    echo "  1. Start the community server:"
    echo -e "     ${GREEN}$INSTALL_DIR/start-server.sh${NC}"
    echo ""
    echo "  2. Launch DRL Simulator from Steam"
    echo ""
    echo -e "${CYAN}Quick Commands:${NC}"
    echo "  • Start server:  $INSTALL_DIR/start-server.sh"
    echo "  • View logs:     tail -f $INSTALL_DIR/logs/*.log"
    echo "  • Uninstall:     rm -rf $INSTALL_DIR"
    echo ""
    echo -e "${YELLOW}Note: The server requires sudo for ports 80/443${NC}"
    echo ""
}

# Main installation flow
main() {
    check_root
    detect_distro
    detect_package_manager
    
    echo ""
    echo -e "${CYAN}This installer will:${NC}"
    echo "  1. Install required dependencies (Python, Mono)"
    echo "  2. Set up the mock backend server"
    echo "  3. Install BepInEx mod framework"
    echo "  4. Compile and install bypass plugins"
    echo "  5. Configure hosts file"
    echo "  6. Create launcher scripts"
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
    configure_steam
    print_summary
}

# Run installer
main "$@"
