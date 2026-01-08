#!/bin/bash
#===============================================================================
# DRL Community Edition - Linux AppImage Builder
# Creates a portable AppImage that runs on any Linux distribution
#===============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION="${1:-1.0.0}"
APP_NAME="DRL-Community"
ARCH="x86_64"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     DRL Community Edition - Linux AppImage Builder           ║"
    echo "║                      Version ${VERSION}                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#===============================================================================
# Check Dependencies
#===============================================================================
check_dependencies() {
    log_info "Checking build dependencies..."
    
    local missing=()
    
    # Required tools (fuse is optional in CI with APPIMAGE_EXTRACT_AND_RUN=1)
    for cmd in wget file; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    # Check for fuse only if not in extract-and-run mode
    if [[ -z "$APPIMAGE_EXTRACT_AND_RUN" ]]; then
        if ! command -v fusermount &>/dev/null && ! command -v fusermount3 &>/dev/null; then
            missing+=("fuse")
        fi
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install with:"
        echo "  Ubuntu/Debian: sudo apt install ${missing[*]}"
        echo "  Fedora:        sudo dnf install ${missing[*]}"
        echo "  Arch:          sudo pacman -S ${missing[*]}"
        exit 1
    fi
    
    log_success "All dependencies found"
}

#===============================================================================
# Download AppImage Tools
#===============================================================================
download_appimage_tools() {
    log_info "Downloading AppImage tools..."
    
    local tools_dir="$SCRIPT_DIR/installer/tools"
    mkdir -p "$tools_dir"
    
    # Download appimagetool if not present
    if [[ ! -f "$tools_dir/appimagetool" ]]; then
        log_info "Downloading appimagetool..."
        wget -q -O "$tools_dir/appimagetool" \
            "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        chmod +x "$tools_dir/appimagetool"
    fi
    
    log_success "AppImage tools ready"
}

#===============================================================================
# Create AppDir Structure
#===============================================================================
create_appdir() {
    local appdir="$SCRIPT_DIR/installer/build/${APP_NAME}.AppDir"
    rm -rf "$appdir"
    mkdir -p "$appdir"
    
    # Standard AppImage directories
    mkdir -p "$appdir/usr/bin"
    mkdir -p "$appdir/usr/lib"
    mkdir -p "$appdir/usr/share/applications"
    mkdir -p "$appdir/usr/share/icons/hicolor/256x256/apps"
    mkdir -p "$appdir/usr/share/drl-community/server"
    mkdir -p "$appdir/usr/share/drl-community/plugins"
    mkdir -p "$appdir/usr/share/drl-community/tools"
    mkdir -p "$appdir/usr/share/drl-community/scripts"
    
    # Return path (only output)
    echo "$appdir"
}

#===============================================================================
# Copy Application Files
#===============================================================================
copy_app_files() {
    local appdir="$1"
    
    log_info "Copying application files..."
    
    # Copy server files
    if [[ -d "$REPO_ROOT/common/server" ]]; then
        cp -r "$REPO_ROOT/common/server/"* "$appdir/usr/share/drl-community/server/"
    fi
    
    # Copy plugins
    if [[ -d "$REPO_ROOT/common/plugins" ]]; then
        cp -r "$REPO_ROOT/common/plugins/"* "$appdir/usr/share/drl-community/plugins/"
    fi
    
    # Copy tools
    if [[ -d "$REPO_ROOT/common/tools" ]]; then
        cp -r "$REPO_ROOT/common/tools/"* "$appdir/usr/share/drl-community/tools/"
    fi
    
    # Copy Linux-specific scripts
    cp "$SCRIPT_DIR/install.sh" "$appdir/usr/share/drl-community/scripts/"
    cp "$SCRIPT_DIR/update.sh" "$appdir/usr/share/drl-community/scripts/"
    cp "$SCRIPT_DIR/diagnose.sh" "$appdir/usr/share/drl-community/scripts/"
    
    if [[ -d "$SCRIPT_DIR/scripts" ]]; then
        cp -r "$SCRIPT_DIR/scripts/"* "$appdir/usr/share/drl-community/scripts/"
    fi
    
    # Copy requirements
    if [[ -f "$REPO_ROOT/requirements.txt" ]]; then
        cp "$REPO_ROOT/requirements.txt" "$appdir/usr/share/drl-community/"
    fi
    
    log_success "Application files copied"
}

#===============================================================================
# Create Desktop Entry
#===============================================================================
create_desktop_entry() {
    local appdir="$1"
    
    log_info "Creating desktop entry..."
    
    cat > "$appdir/usr/share/applications/${APP_NAME}.desktop" << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=DRL Community Edition
GenericName=DRL Simulator Offline Mode
Comment=Play DRL Simulator with community servers
Exec=drl-community %F
Icon=drl-community
Terminal=false
Categories=Game;Simulation;
Keywords=drone;racing;simulator;drl;
StartupNotify=true
StartupWMClass=DRL-Community
DESKTOP

    # Copy to AppDir root (required for AppImage)
    cp "$appdir/usr/share/applications/${APP_NAME}.desktop" "$appdir/"
    
    log_success "Desktop entry created"
}

#===============================================================================
# Create Icon
#===============================================================================
create_icon() {
    local appdir="$1"
    
    log_info "Creating application icon..."
    
    # Create a simple SVG icon (can be replaced with actual icon)
    cat > "$appdir/usr/share/icons/hicolor/256x256/apps/drl-community.svg" << 'SVG'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1a1a2e"/>
      <stop offset="100%" style="stop-color:#16213e"/>
    </linearGradient>
    <linearGradient id="drone" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#e94560"/>
      <stop offset="100%" style="stop-color:#ff6b6b"/>
    </linearGradient>
  </defs>
  
  <!-- Background -->
  <rect width="256" height="256" rx="40" fill="url(#bg)"/>
  
  <!-- Drone body -->
  <ellipse cx="128" cy="128" rx="40" ry="20" fill="url(#drone)"/>
  
  <!-- Propeller arms -->
  <line x1="88" y1="128" x2="48" y2="88" stroke="#e94560" stroke-width="8" stroke-linecap="round"/>
  <line x1="168" y1="128" x2="208" y2="88" stroke="#e94560" stroke-width="8" stroke-linecap="round"/>
  <line x1="88" y1="128" x2="48" y2="168" stroke="#e94560" stroke-width="8" stroke-linecap="round"/>
  <line x1="168" y1="128" x2="208" y2="168" stroke="#e94560" stroke-width="8" stroke-linecap="round"/>
  
  <!-- Propellers -->
  <circle cx="48" cy="88" r="24" fill="none" stroke="#0f3460" stroke-width="4"/>
  <circle cx="208" cy="88" r="24" fill="none" stroke="#0f3460" stroke-width="4"/>
  <circle cx="48" cy="168" r="24" fill="none" stroke="#0f3460" stroke-width="4"/>
  <circle cx="208" cy="168" r="24" fill="none" stroke="#0f3460" stroke-width="4"/>
  
  <!-- Propeller centers -->
  <circle cx="48" cy="88" r="6" fill="#e94560"/>
  <circle cx="208" cy="88" r="6" fill="#e94560"/>
  <circle cx="48" cy="168" r="6" fill="#e94560"/>
  <circle cx="208" cy="168" r="6" fill="#e94560"/>
  
  <!-- Camera/LED -->
  <circle cx="128" cy="118" r="8" fill="#00ff88"/>
  
  <!-- Text -->
  <text x="128" y="200" font-family="Arial, sans-serif" font-size="24" font-weight="bold" 
        fill="white" text-anchor="middle">DRL</text>
  <text x="128" y="224" font-family="Arial, sans-serif" font-size="14" 
        fill="#888" text-anchor="middle">COMMUNITY</text>
</svg>
SVG

    # Copy to AppDir root
    cp "$appdir/usr/share/icons/hicolor/256x256/apps/drl-community.svg" "$appdir/drl-community.svg"
    
    # Create PNG version if ImageMagick is available
    if command -v convert &>/dev/null; then
        convert "$appdir/drl-community.svg" -resize 256x256 "$appdir/drl-community.png"
        cp "$appdir/drl-community.png" "$appdir/usr/share/icons/hicolor/256x256/apps/"
    fi
    
    log_success "Icon created"
}

#===============================================================================
# Create AppRun Script
#===============================================================================
create_apprun() {
    local appdir="$1"
    
    log_info "Creating AppRun launcher..."
    
    cat > "$appdir/AppRun" << 'APPRUN'
#!/bin/bash
#===============================================================================
# DRL Community Edition - AppImage Launcher
#===============================================================================

SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
export DRL_COMMUNITY_HOME="${HERE}/usr/share/drl-community"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

show_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║          DRL Simulator - Community Edition                   ║"
    echo "║                    Linux AppImage                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "  1) Start Mock Server & Launch Game"
    echo "  2) Start Mock Server Only"
    echo "  3) Install to System"
    echo "  4) Run Diagnostics"
    echo "  5) Update Installation"
    echo "  6) About"
    echo "  7) Exit"
    echo ""
    echo -n "Select option [1-7]: "
}

start_server() {
    echo -e "${GREEN}Starting DRL Mock Server...${NC}"
    
    # Check Python
    if ! command -v python3 &>/dev/null; then
        echo -e "${RED}Python 3 is required but not installed.${NC}"
        echo "Install with: sudo apt install python3 python3-pip"
        read -p "Press Enter to continue..."
        return 1
    fi
    
    # Install requirements if needed
    if [[ -f "${DRL_COMMUNITY_HOME}/requirements.txt" ]]; then
        pip3 install -q -r "${DRL_COMMUNITY_HOME}/requirements.txt" 2>/dev/null || true
    fi
    
    # Start server
    cd "${DRL_COMMUNITY_HOME}/server"
    python3 mock_drl_backend.py &
    SERVER_PID=$!
    echo "Server started (PID: $SERVER_PID)"
    
    return 0
}

start_server_and_game() {
    start_server || return 1
    
    echo ""
    echo -e "${YELLOW}Waiting for server to initialize...${NC}"
    sleep 3
    
    # Find and launch DRL Simulator
    local drl_paths=(
        "$HOME/.local/share/Steam/steamapps/common/DRL Simulator"
        "$HOME/.steam/steam/steamapps/common/DRL Simulator"
        "/opt/DRL Simulator"
    )
    
    local drl_exe=""
    for path in "${drl_paths[@]}"; do
        if [[ -f "$path/DRL Simulator.x86_64" ]]; then
            drl_exe="$path/DRL Simulator.x86_64"
            break
        elif [[ -f "$path/DRL Simulator" ]]; then
            drl_exe="$path/DRL Simulator"
            break
        fi
    done
    
    if [[ -n "$drl_exe" ]]; then
        echo -e "${GREEN}Launching DRL Simulator...${NC}"
        "$drl_exe" &
    else
        echo -e "${YELLOW}DRL Simulator not found in standard locations.${NC}"
        echo "Please launch it manually from Steam."
        echo "Server is running at http://127.0.0.1:8080"
    fi
    
    echo ""
    echo -e "${GREEN}Server running. Press Ctrl+C to stop.${NC}"
    wait $SERVER_PID
}

install_to_system() {
    echo -e "${CYAN}Installing DRL Community Edition to system...${NC}"
    
    # Run installation script with sudo
    if [[ -f "${DRL_COMMUNITY_HOME}/scripts/install.sh" ]]; then
        sudo bash "${DRL_COMMUNITY_HOME}/scripts/install.sh"
    else
        echo -e "${RED}Installation script not found.${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

run_diagnostics() {
    echo -e "${CYAN}Running diagnostics...${NC}"
    echo ""
    
    if [[ -f "${DRL_COMMUNITY_HOME}/scripts/diagnose.sh" ]]; then
        bash "${DRL_COMMUNITY_HOME}/scripts/diagnose.sh"
    else
        echo "Diagnostics script not found."
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

run_update() {
    echo -e "${CYAN}Checking for updates...${NC}"
    
    if [[ -f "${DRL_COMMUNITY_HOME}/scripts/update.sh" ]]; then
        bash "${DRL_COMMUNITY_HOME}/scripts/update.sh"
    else
        echo "Update script not found."
    fi
    
    read -p "Press Enter to continue..."
}

show_about() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                         ABOUT                                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "  DRL Simulator - Community Edition"
    echo "  Version: 1.0.0"
    echo ""
    echo "  A community project to keep DRL Simulator playable"
    echo "  after the official servers were discontinued."
    echo ""
    echo "  Components:"
    echo "    • Mock DRL Backend Server"
    echo "    • BepInEx Mod Framework"
    echo "    • Community Plugins"
    echo ""
    echo "  GitHub: github.com/Georgeandrew7/DRL-Simulator-Community"
    echo ""
    echo "  This project is not affiliated with Drone Racing League, Inc."
    echo ""
    read -p "Press Enter to continue..."
}

# Handle command-line arguments
case "$1" in
    --server)
        start_server
        wait
        ;;
    --install)
        install_to_system
        ;;
    --diagnose)
        run_diagnostics
        ;;
    --update)
        run_update
        ;;
    --help)
        echo "DRL Community Edition AppImage"
        echo ""
        echo "Usage: $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  --server    Start mock server only"
        echo "  --install   Install to system"
        echo "  --diagnose  Run diagnostics"
        echo "  --update    Check for updates"
        echo "  --help      Show this help"
        echo ""
        echo "Without options, shows interactive menu."
        ;;
    *)
        # Interactive menu
        while true; do
            show_menu
            read -r choice
            case $choice in
                1) start_server_and_game ;;
                2) start_server; echo "Press Ctrl+C to stop."; wait ;;
                3) install_to_system ;;
                4) run_diagnostics ;;
                5) run_update ;;
                6) show_about ;;
                7) echo "Goodbye!"; exit 0 ;;
                *) echo "Invalid option" ;;
            esac
        done
        ;;
esac
APPRUN

    chmod +x "$appdir/AppRun"
    
    log_success "AppRun launcher created"
}

#===============================================================================
# Create Wrapper Binary
#===============================================================================
create_wrapper() {
    local appdir="$1"
    
    log_info "Creating wrapper binary..."
    
    # Create a simple shell wrapper
    cat > "$appdir/usr/bin/drl-community" << 'WRAPPER'
#!/bin/bash
exec "$(dirname "$(readlink -f "$0")")/../../AppRun" "$@"
WRAPPER

    chmod +x "$appdir/usr/bin/drl-community"
    
    log_success "Wrapper binary created"
}

#===============================================================================
# Build AppImage
#===============================================================================
build_appimage() {
    local appdir="$1"
    local output_dir="$SCRIPT_DIR/installer/output"
    
    log_info "Building AppImage..."
    
    mkdir -p "$output_dir"
    
    local appimage_name="${APP_NAME}-${VERSION}-${ARCH}.AppImage"
    local tools_dir="$SCRIPT_DIR/installer/tools"
    
    # Set ARCH for appimagetool
    export ARCH="$ARCH"
    
    # Build the AppImage
    "$tools_dir/appimagetool" "$appdir" "$output_dir/$appimage_name"
    
    if [[ -f "$output_dir/$appimage_name" ]]; then
        chmod +x "$output_dir/$appimage_name"
        log_success "AppImage created: $output_dir/$appimage_name"
        
        # Get file size
        local size=$(du -h "$output_dir/$appimage_name" | cut -f1)
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                    BUILD SUCCESSFUL                          ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "  Output: $output_dir/$appimage_name"
        echo "  Size:   $size"
        echo ""
        echo "  To run: ./$appimage_name"
        echo "  Or:     ./$appimage_name --help"
    else
        log_error "Failed to create AppImage"
        exit 1
    fi
}

#===============================================================================
# Create DEB Package (Alternative)
#===============================================================================
create_deb_package() {
    log_info "Creating DEB package..."
    
    local deb_dir="$SCRIPT_DIR/installer/build/deb"
    local pkg_name="drl-community"
    local pkg_version="$VERSION"
    
    rm -rf "$deb_dir"
    mkdir -p "$deb_dir/DEBIAN"
    mkdir -p "$deb_dir/usr/bin"
    mkdir -p "$deb_dir/usr/share/drl-community"
    mkdir -p "$deb_dir/usr/share/applications"
    mkdir -p "$deb_dir/usr/share/icons/hicolor/256x256/apps"
    
    # Control file
    cat > "$deb_dir/DEBIAN/control" << CONTROL
Package: ${pkg_name}
Version: ${pkg_version}
Section: games
Priority: optional
Architecture: amd64
Depends: python3 (>= 3.8), python3-pip
Maintainer: DRL Community <community@example.com>
Description: DRL Simulator Community Edition
 Play DRL Simulator with community servers after
 official servers were discontinued.
Homepage: https://github.com/Georgeandrew7/DRL-Simulator-Community
CONTROL

    # Post-install script
    cat > "$deb_dir/DEBIAN/postinst" << 'POSTINST'
#!/bin/bash
set -e

# Add hosts entry
if ! grep -q "api.drlgame.com" /etc/hosts; then
    echo "127.0.0.1 api.drlgame.com" >> /etc/hosts
fi

# Install Python dependencies
if [[ -f /usr/share/drl-community/requirements.txt ]]; then
    pip3 install -r /usr/share/drl-community/requirements.txt 2>/dev/null || true
fi

echo "DRL Community Edition installed successfully!"
echo "Run 'drl-community' to start."
POSTINST
    chmod 755 "$deb_dir/DEBIAN/postinst"
    
    # Post-remove script
    cat > "$deb_dir/DEBIAN/postrm" << 'POSTRM'
#!/bin/bash
set -e

if [[ "$1" = "purge" ]]; then
    # Remove hosts entry
    sed -i '/api.drlgame.com/d' /etc/hosts 2>/dev/null || true
fi
POSTRM
    chmod 755 "$deb_dir/DEBIAN/postrm"
    
    # Copy files
    cp -r "$REPO_ROOT/common/"* "$deb_dir/usr/share/drl-community/" 2>/dev/null || true
    cp -r "$SCRIPT_DIR/scripts/"* "$deb_dir/usr/share/drl-community/" 2>/dev/null || true
    cp "$REPO_ROOT/requirements.txt" "$deb_dir/usr/share/drl-community/" 2>/dev/null || true
    
    # Create launcher script
    cat > "$deb_dir/usr/bin/drl-community" << 'LAUNCHER'
#!/bin/bash
cd /usr/share/drl-community/server
python3 mock_drl_backend.py "$@"
LAUNCHER
    chmod 755 "$deb_dir/usr/bin/drl-community"
    
    # Build DEB
    local output_dir="$SCRIPT_DIR/installer/output"
    mkdir -p "$output_dir"
    
    if command -v dpkg-deb &>/dev/null; then
        dpkg-deb --build "$deb_dir" "$output_dir/${pkg_name}_${pkg_version}_amd64.deb"
        log_success "DEB package created: $output_dir/${pkg_name}_${pkg_version}_amd64.deb"
    else
        log_warn "dpkg-deb not found, skipping DEB package"
    fi
}

#===============================================================================
# Main
#===============================================================================
main() {
    # Parse arguments FIRST (before print_header uses VERSION)
    local build_deb=false
    for arg in "$@"; do
        case "$arg" in
            --version=*) VERSION="${arg#*=}" ;;
            --deb) build_deb=true ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --version=X.X.X  Set version number (default: 1.0.0)"
                echo "  --deb            Also create DEB package"
                echo "  --help           Show this help"
                exit 0
                ;;
        esac
    done
    
    print_header
    
    check_dependencies
    download_appimage_tools
    
    log_info "Creating AppDir structure..."
    local appdir=$(create_appdir)
    copy_app_files "$appdir"
    create_desktop_entry "$appdir"
    create_icon "$appdir"
    create_apprun "$appdir"
    create_wrapper "$appdir"
    build_appimage "$appdir"
    
    if $build_deb; then
        create_deb_package
    fi
    
    echo ""
    log_success "Build complete!"
}

main "$@"
