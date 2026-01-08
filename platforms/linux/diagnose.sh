#!/bin/bash
#
# DRL Simulator Community - Linux Diagnostic Tool
# Checks the health of the installation and reports issues
#

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
VERSION_FILE="VERSION.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# Options
VERBOSE=false
EXPORT_REPORT=false
FIX_ISSUES=false

# Results tracking
PASSED=0
WARNINGS=0
FAILED=0
REPORT=""

# Distro detection
DISTRO=""
DISTRO_NAME=""
PKG_MANAGER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -e|--export)
            EXPORT_REPORT=true
            shift
            ;;
        --fix)
            FIX_ISSUES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Show detailed information"
            echo "  -e, --export     Export report to home directory"
            echo "  --fix            Attempt to fix issues automatically"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

START_TIME=$(date +%s)

# Logging functions
print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        DRL Simulator Community - Diagnostic Tool             ║${NC}"
    echo -e "${CYAN}║                       Version 1.0.0                          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " $1"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_pass() {
    local name="$1"
    local message="$2"
    local detail="${3:-}"
    
    echo -e "  ${GREEN}[✓]${NC} ${name}: ${message}"
    if [[ -n "$detail" ]] && [[ "$VERBOSE" == "true" ]]; then
        echo -e "      ${GRAY}└─ ${detail}${NC}"
    fi
    
    ((PASSED++))
    REPORT+="[PASS] $name: $message\n"
}

check_warn() {
    local name="$1"
    local message="$2"
    local detail="${3:-}"
    
    echo -e "  ${YELLOW}[!]${NC} ${name}: ${message}"
    if [[ -n "$detail" ]]; then
        echo -e "      ${GRAY}└─ ${detail}${NC}"
    fi
    
    ((WARNINGS++))
    REPORT+="[WARN] $name: $message - $detail\n"
}

check_fail() {
    local name="$1"
    local message="$2"
    local detail="${3:-}"
    
    echo -e "  ${RED}[✗]${NC} ${name}: ${message}"
    if [[ -n "$detail" ]]; then
        echo -e "      ${GRAY}└─ ${detail}${NC}"
    fi
    
    ((FAILED++))
    REPORT+="[FAIL] $name: $message - $detail\n"
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
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="zypper"
    else
        PKG_MANAGER="unknown"
    fi
}

find_game_directory() {
    local possible_paths=(
        "$HOME/.local/share/Steam/steamapps/common/DRL Simulator"
        "$HOME/.steam/steam/steamapps/common/DRL Simulator"
        "$HOME/Games/DRL Simulator"
        "/opt/DRL Simulator"
    )
    
    for path in "${possible_paths[@]}"; do
        if [[ -d "$path" ]]; then
            echo "$path"
            return
        fi
    done
    
    # Check Steam library folders
    local steam_libs="$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"
    if [[ -f "$steam_libs" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ \"path\"[[:space:]]*\"([^\"]+)\" ]]; then
                local lib_path="${BASH_REMATCH[1]}/steamapps/common/DRL Simulator"
                if [[ -d "$lib_path" ]]; then
                    echo "$lib_path"
                    return
                fi
            fi
        done < "$steam_libs"
    fi
    
    echo ""
}

# ============================================================================
# DIAGNOSTIC CHECKS
# ============================================================================

check_system_requirements() {
    print_section "System Requirements"
    
    # Linux distribution
    check_pass "Distribution" "$DISTRO_NAME"
    
    # Kernel version
    local kernel=$(uname -r)
    check_pass "Kernel" "$kernel"
    
    # Architecture
    local arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then
        check_pass "Architecture" "64-bit ($arch)"
    elif [[ "$arch" == "aarch64" ]]; then
        check_pass "Architecture" "ARM64 ($arch)"
    else
        check_warn "Architecture" "$arch" "x86_64 recommended"
    fi
    
    # RAM
    local ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local ram_gb=$((ram_kb / 1024 / 1024))
    
    if [[ $ram_gb -ge 8 ]]; then
        check_pass "System Memory" "${ram_gb} GB RAM"
    elif [[ $ram_gb -ge 4 ]]; then
        check_warn "System Memory" "${ram_gb} GB RAM" "8GB+ recommended"
    else
        check_fail "System Memory" "${ram_gb} GB RAM" "Minimum 4GB required"
    fi
    
    # Disk space
    local free_space=$(df -BG "$INSTALL_DIR" 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G')
    
    if [[ $free_space -ge 5 ]]; then
        check_pass "Disk Space" "${free_space} GB free"
    elif [[ $free_space -ge 1 ]]; then
        check_warn "Disk Space" "${free_space} GB free" "5GB+ recommended"
    else
        check_fail "Disk Space" "${free_space} GB free" "Low disk space"
    fi
    
    # Package manager
    check_pass "Package Manager" "$PKG_MANAGER"
    
    # Graphics (check for Vulkan/OpenGL)
    if command -v glxinfo &> /dev/null; then
        local gl_version=$(glxinfo 2>/dev/null | grep "OpenGL version" | head -1 | awk '{print $4}')
        if [[ -n "$gl_version" ]]; then
            check_pass "OpenGL" "Version $gl_version"
        fi
    elif [[ -d /usr/share/vulkan ]]; then
        check_pass "Vulkan" "Installed"
    else
        check_warn "Graphics" "Could not detect OpenGL/Vulkan" "Install mesa-utils to check"
    fi
}

check_python_installation() {
    print_section "Python Environment"
    
    # Check for Python 3
    local python_cmd=""
    if command -v python3 &> /dev/null; then
        python_cmd="python3"
    elif command -v python &> /dev/null; then
        local version=$(python --version 2>&1)
        if [[ "$version" == *"Python 3"* ]]; then
            python_cmd="python"
        fi
    fi
    
    if [[ -n "$python_cmd" ]]; then
        local version=$($python_cmd --version 2>&1)
        local major=$(echo "$version" | sed 's/Python //' | cut -d. -f1)
        local minor=$(echo "$version" | sed 's/Python //' | cut -d. -f2)
        
        if [[ $major -ge 3 ]] && [[ $minor -ge 8 ]]; then
            check_pass "Python Version" "$version" "$($python_cmd -c 'import sys; print(sys.executable)')"
        elif [[ $major -ge 3 ]]; then
            check_warn "Python Version" "$version" "Python 3.8+ recommended"
        else
            check_fail "Python Version" "$version" "Python 3.8+ required"
        fi
        
        # Check pip
        if $python_cmd -m pip --version &> /dev/null; then
            local pip_version=$($python_cmd -m pip --version | awk '{print $2}')
            check_pass "Pip" "Version $pip_version"
        else
            check_fail "Pip" "Not installed" "Install: $python_cmd -m ensurepip"
        fi
        
        # Check required packages
        local packages=("aiohttp" "requests")
        for pkg in "${packages[@]}"; do
            if $python_cmd -c "import $pkg" &> /dev/null; then
                local pkg_version=$($python_cmd -c "import $pkg; print($pkg.__version__)" 2>/dev/null || echo "installed")
                check_pass "Package: $pkg" "Version $pkg_version"
            else
                check_fail "Package: $pkg" "Not installed" "Run: pip3 install $pkg"
            fi
        done
    else
        check_fail "Python" "Not found" "Install Python 3.8+"
        case $PKG_MANAGER in
            apt) echo -e "      ${GRAY}└─ sudo apt install python3 python3-pip${NC}" ;;
            dnf) echo -e "      ${GRAY}└─ sudo dnf install python3 python3-pip${NC}" ;;
            pacman) echo -e "      ${GRAY}└─ sudo pacman -S python python-pip${NC}" ;;
            zypper) echo -e "      ${GRAY}└─ sudo zypper install python3 python3-pip${NC}" ;;
        esac
    fi
}

check_mono_installation() {
    print_section "Mono Runtime (for plugin compilation)"
    
    if command -v mono &> /dev/null; then
        local mono_version=$(mono --version 2>&1 | head -1)
        check_pass "Mono Runtime" "$mono_version"
    else
        check_warn "Mono Runtime" "Not installed" "Required for plugin compilation"
        case $PKG_MANAGER in
            apt) echo -e "      ${GRAY}└─ sudo apt install mono-mcs${NC}" ;;
            dnf) echo -e "      ${GRAY}└─ sudo dnf install mono-devel${NC}" ;;
            pacman) echo -e "      ${GRAY}└─ sudo pacman -S mono${NC}" ;;
            zypper) echo -e "      ${GRAY}└─ sudo zypper install mono-devel${NC}" ;;
        esac
    fi
    
    if command -v mcs &> /dev/null; then
        check_pass "Mono C# Compiler" "mcs available"
    elif command -v mono &> /dev/null; then
        check_warn "Mono C# Compiler" "mcs not found" "May need mono-devel package"
    fi
}

check_game_installation() {
    print_section "Game Installation"
    
    local game_dir=$(find_game_directory)
    
    if [[ -z "$game_dir" ]]; then
        check_fail "Game Directory" "DRL Simulator not found" "Install from Steam"
        return
    fi
    
    check_pass "Game Directory" "Found" "$game_dir"
    GAME_DIR="$game_dir"
    
    # Check for executable
    local exe_files=(
        "$game_dir/DRL Simulator.x86_64"
        "$game_dir/DRL Simulator"
        "$game_dir/DRLSimulator.x86_64"
    )
    
    local exe_found=false
    for exe in "${exe_files[@]}"; do
        if [[ -f "$exe" ]]; then
            local size=$(ls -lh "$exe" | awk '{print $5}')
            check_pass "Game Executable" "$size" "$exe"
            exe_found=true
            break
        fi
    done
    
    if [[ "$exe_found" == "false" ]]; then
        check_warn "Game Executable" "Not found in expected location"
    fi
    
    # Check Data folder
    local data_path="$game_dir/DRL Simulator_Data"
    if [[ ! -d "$data_path" ]]; then
        data_path="$game_dir/DRLSimulator_Data"
    fi
    
    if [[ -d "$data_path" ]]; then
        check_pass "Game Data" "Found" "$data_path"
        
        # Check Managed folder
        local managed_path="$data_path/Managed"
        if [[ -d "$managed_path" ]]; then
            if [[ -f "$managed_path/Assembly-CSharp.dll" ]]; then
                check_pass "Assembly-CSharp.dll" "Found"
            else
                check_warn "Assembly-CSharp.dll" "Not found"
            fi
            
            if [[ -f "$managed_path/UnityEngine.dll" ]]; then
                check_pass "UnityEngine.dll" "Found"
            fi
        fi
    else
        check_fail "Game Data" "Not found"
    fi
}

check_bepinex_installation() {
    print_section "BepInEx Installation"
    
    if [[ -z "$GAME_DIR" ]]; then
        check_fail "BepInEx" "Game not found" "Cannot check BepInEx installation"
        return
    fi
    
    local bepinex_path="$GAME_DIR/BepInEx"
    
    if [[ ! -d "$bepinex_path" ]]; then
        check_fail "BepInEx Directory" "Not installed" "Run: ./scripts/install_bepinex.sh"
        return
    fi
    
    check_pass "BepInEx Directory" "Found" "$bepinex_path"
    
    # Check core files
    local core_files=(
        "core/BepInEx.dll"
        "core/0Harmony.dll"
        "core/MonoMod.RuntimeDetour.dll"
    )
    
    for file in "${core_files[@]}"; do
        local file_path="$bepinex_path/$file"
        if [[ -f "$file_path" ]]; then
            local size=$(ls -lh "$file_path" | awk '{print $5}')
            check_pass "$(basename "$file")" "Found" "$size"
        else
            check_fail "$(basename "$file")" "Missing" "BepInEx may be corrupted"
        fi
    done
    
    # Check run script for Steam
    local run_bepinex="$GAME_DIR/run_bepinex.sh"
    if [[ -f "$run_bepinex" ]]; then
        if [[ -x "$run_bepinex" ]]; then
            check_pass "run_bepinex.sh" "Found and executable"
        else
            check_warn "run_bepinex.sh" "Found but not executable" "chmod +x run_bepinex.sh"
        fi
    else
        check_warn "run_bepinex.sh" "Not found" "BepInEx may not load on Linux"
    fi
    
    # Check plugins directory
    local plugins_path="$bepinex_path/plugins"
    if [[ -d "$plugins_path" ]]; then
        local plugin_count=$(find "$plugins_path" -name "*.dll" 2>/dev/null | wc -l)
        if [[ $plugin_count -gt 0 ]]; then
            check_pass "Plugins Directory" "$plugin_count plugin(s) installed"
            
            if [[ "$VERBOSE" == "true" ]]; then
                for plugin in "$plugins_path"/*.dll; do
                    if [[ -f "$plugin" ]]; then
                        echo -e "      ${GRAY}└─ $(basename "$plugin")${NC}"
                    fi
                done
            fi
        else
            check_warn "Plugins Directory" "No plugins installed" "Run: ./scripts/compile_plugin.sh"
        fi
    else
        check_warn "Plugins Directory" "Not found"
    fi
    
    # Check logs
    local log_file="$bepinex_path/LogOutput.log"
    if [[ -f "$log_file" ]]; then
        local log_age=$(( ($(date +%s) - $(stat -c %Y "$log_file")) / 86400 ))
        if [[ $log_age -lt 7 ]]; then
            check_pass "BepInEx Log" "Recent activity" "Modified $log_age days ago"
        else
            check_warn "BepInEx Log" "Old log file" "Game may not have been run recently"
        fi
        
        # Check for errors
        local error_count=$(grep -ci "error\|exception\|fail" "$log_file" 2>/dev/null || echo "0")
        if [[ $error_count -gt 0 ]]; then
            check_warn "Log Errors" "$error_count potential error(s) in log"
        fi
    fi
}

check_network_configuration() {
    print_section "Network Configuration"
    
    # Check hosts file
    local hosts_file="/etc/hosts"
    if [[ -f "$hosts_file" ]]; then
        if grep -q "api\.drlgame\.com" "$hosts_file"; then
            if grep -q "127\.0\.0\.1.*api\.drlgame\.com" "$hosts_file"; then
                check_pass "Hosts Entry" "api.drlgame.com → 127.0.0.1"
            else
                check_warn "Hosts Entry" "api.drlgame.com exists but may be misconfigured"
            fi
        else
            check_fail "Hosts Entry" "api.drlgame.com not in hosts file" "Run: sudo ./install.sh"
        fi
    else
        check_fail "Hosts File" "Cannot read /etc/hosts"
    fi
    
    # Check if ports are available
    local ports=(80 443 8080)
    local port_names=("HTTP" "HTTPS" "Master Server")
    
    for i in "${!ports[@]}"; do
        local port=${ports[$i]}
        local name=${port_names[$i]}
        
        if command -v ss &> /dev/null; then
            if ss -tuln | grep -q ":$port "; then
                local process=$(ss -tulnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'"' -f2 | head -1)
                if [[ "$process" == "python"* ]]; then
                    check_pass "Port $port ($name)" "In use by Python (server running)"
                else
                    check_warn "Port $port ($name)" "In use by $process"
                fi
            else
                check_pass "Port $port ($name)" "Available"
            fi
        elif command -v netstat &> /dev/null; then
            if netstat -tuln | grep -q ":$port "; then
                check_warn "Port $port ($name)" "In use"
            else
                check_pass "Port $port ($name)" "Available"
            fi
        else
            check_warn "Port $port ($name)" "Cannot check" "Install ss or netstat"
        fi
    done
    
    # Test mock server
    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout 2 "http://127.0.0.1:80" &> /dev/null; then
            check_pass "Mock Server (HTTP)" "Responding on port 80"
        else
            check_warn "Mock Server (HTTP)" "Not running" "Start with: ./scripts/start-offline-mode.sh"
        fi
    fi
    
    # Test internet connectivity
    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout 5 "https://github.com" &> /dev/null; then
            check_pass "Internet Connection" "Connected"
        else
            check_warn "Internet Connection" "Limited or no connection"
        fi
    elif command -v ping &> /dev/null; then
        if ping -c 1 -W 5 github.com &> /dev/null; then
            check_pass "Internet Connection" "Connected"
        else
            check_warn "Internet Connection" "Limited or no connection"
        fi
    fi
}

check_ssl_certificates() {
    print_section "SSL Certificates"
    
    local cert_paths=(
        "$INSTALL_DIR/certs"
        "$SCRIPT_DIR/../certs"
        "$INSTALL_DIR/platforms/linux/certs"
    )
    
    local cert_dir=""
    for path in "${cert_paths[@]}"; do
        if [[ -d "$path" ]]; then
            cert_dir="$path"
            break
        fi
    done
    
    if [[ -n "$cert_dir" ]]; then
        check_pass "Certificates Directory" "Found" "$cert_dir"
        
        local cert_files=("server.crt" "server.key")
        for file in "${cert_files[@]}"; do
            local file_path="$cert_dir/$file"
            if [[ -f "$file_path" ]]; then
                local created=$(stat -c %y "$file_path" | cut -d' ' -f1)
                check_pass "$file" "Found" "Created $created"
            else
                check_warn "$file" "Not found" "HTTPS may not work"
            fi
        done
        
        # Check certificate expiry if openssl available
        if command -v openssl &> /dev/null && [[ -f "$cert_dir/server.crt" ]]; then
            local expiry=$(openssl x509 -enddate -noout -in "$cert_dir/server.crt" 2>/dev/null | cut -d= -f2)
            if [[ -n "$expiry" ]]; then
                check_pass "Certificate Expiry" "$expiry"
            fi
        fi
    else
        check_warn "Certificates" "No certificates directory found" "HTTPS mock server may not work"
    fi
}

check_community_files() {
    print_section "Community Files"
    
    check_pass "Install Directory" "$INSTALL_DIR"
    
    # Check common files
    local common_path="$INSTALL_DIR/common"
    if [[ -d "$common_path" ]]; then
        check_pass "Common Files" "Found"
        
        # Check server files
        local server_files=(
            "server/mock_drl_backend.py"
            "server/master_server.py"
            "server/track_sharing.py"
        )
        
        for file in "${server_files[@]}"; do
            local file_path="$common_path/$file"
            if [[ -f "$file_path" ]]; then
                check_pass "$(basename "$file")" "Found"
            else
                check_fail "$(basename "$file")" "Missing"
            fi
        done
        
        # Check plugins source
        local plugins_path="$common_path/plugins"
        if [[ -d "$plugins_path" ]]; then
            local cs_count=$(find "$plugins_path" -name "*.cs" | wc -l)
            check_pass "Plugin Sources" "$cs_count source file(s)"
        fi
    else
        check_fail "Common Files" "Not found" "Installation may be corrupted"
    fi
    
    # Check Linux scripts
    local scripts_path="$INSTALL_DIR/platforms/linux/scripts"
    if [[ -d "$scripts_path" ]]; then
        local script_count=$(find "$scripts_path" -name "*.sh" | wc -l)
        check_pass "Linux Scripts" "$script_count script(s)"
        
        # Check if executable
        local non_exec=$(find "$scripts_path" -name "*.sh" ! -executable | wc -l)
        if [[ $non_exec -gt 0 ]]; then
            check_warn "Script Permissions" "$non_exec script(s) not executable" "chmod +x scripts/*.sh"
        fi
    fi
    
    # Check version
    local version_file="$INSTALL_DIR/$VERSION_FILE"
    if [[ -f "$version_file" ]]; then
        local version=$(cat "$version_file" | tr -d '[:space:]')
        check_pass "Version" "$version"
    else
        check_warn "Version" "No version file"
    fi
}

check_steam_integration() {
    print_section "Steam Integration"
    
    # Check if Steam is running
    if pgrep -x "steam" &> /dev/null; then
        check_pass "Steam Process" "Running"
    else
        check_warn "Steam Process" "Not running" "Start Steam before playing"
    fi
    
    # Check Steam installation
    local steam_paths=(
        "$HOME/.local/share/Steam"
        "$HOME/.steam/steam"
        "/usr/share/steam"
    )
    
    local steam_found=false
    for path in "${steam_paths[@]}"; do
        if [[ -d "$path" ]]; then
            check_pass "Steam Installation" "Found" "$path"
            steam_found=true
            break
        fi
    done
    
    if [[ "$steam_found" == "false" ]]; then
        check_warn "Steam Installation" "Not found in default locations"
    fi
    
    # Check Proton/Wine if needed (DRL is native Linux, but just in case)
    if command -v wine &> /dev/null; then
        local wine_version=$(wine --version 2>/dev/null)
        check_pass "Wine" "$wine_version" "(not required for DRL)"
    fi
}

check_wine_proton() {
    print_section "Wine/Proton (optional)"
    
    # Check Steam Play / Proton
    local proton_path="$HOME/.local/share/Steam/steamapps/common/Proton"
    if ls -d "$proton_path"* &> /dev/null 2>&1; then
        local proton_versions=$(ls -d "$proton_path"* 2>/dev/null | wc -l)
        check_pass "Proton" "$proton_versions version(s) installed"
    else
        check_warn "Proton" "Not installed" "May be needed for some games"
    fi
    
    # Check for Wine
    if command -v wine &> /dev/null; then
        local wine_version=$(wine --version 2>/dev/null)
        check_pass "Wine" "$wine_version"
    else
        check_warn "Wine" "Not installed" "Not required for DRL (native Linux)"
    fi
}

print_summary() {
    local end_time=$(date +%s)
    local elapsed=$((end_time - START_TIME))
    local total=$((PASSED + WARNINGS + FAILED))
    
    echo ""
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " DIAGNOSTIC SUMMARY"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Checks completed in ${elapsed} seconds"
    echo ""
    echo -e "  ${GREEN}[✓] Passed:${NC}   $PASSED / $total"
    echo -e "  ${YELLOW}[!] Warnings:${NC} $WARNINGS / $total"
    echo -e "  ${RED}[✗] Failed:${NC}   $FAILED / $total"
    echo ""
    
    # Health score
    local health_score=0
    if [[ $total -gt 0 ]]; then
        health_score=$((PASSED * 100 / total))
    fi
    
    local health_color=$GREEN
    if [[ $health_score -lt 80 ]]; then
        health_color=$YELLOW
    fi
    if [[ $health_score -lt 60 ]]; then
        health_color=$RED
    fi
    
    echo -e "  Health Score: ${health_color}${health_score}%${NC}"
    
    # Recommendations
    if [[ $FAILED -gt 0 ]]; then
        echo ""
        echo -e "  ${RED}Issues requiring attention:${NC}"
        echo -e "${REPORT}" | grep "^\[FAIL\]" | while read line; do
            echo -e "    ${RED}•${NC} ${line#\[FAIL\] }"
        done
    fi
    
    echo ""
}

export_report() {
    local report_path="$HOME/DRL-Diagnostic-Report.txt"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local total=$((PASSED + WARNINGS + FAILED))
    local health_score=0
    if [[ $total -gt 0 ]]; then
        health_score=$((PASSED * 100 / total))
    fi
    
    cat > "$report_path" << EOF
DRL Simulator Community - Diagnostic Report
Generated: $timestamp
System: $DISTRO_NAME
============================================

$(echo -e "$REPORT")

============================================
Summary:
  Passed:   $PASSED / $total
  Warnings: $WARNINGS / $total
  Failed:   $FAILED / $total
  
Health Score: ${health_score}%
EOF
    
    echo -e "  ${CYAN}Report exported to: $report_path${NC}"
}

# ============================================================================
# MAIN
# ============================================================================

print_banner

# Check we're on Linux
if [[ "$(uname)" != "Linux" ]]; then
    echo -e "${RED}This diagnostic tool is for Linux only!${NC}"
    exit 1
fi

detect_distro
echo -e "  Distribution: ${GREEN}$DISTRO_NAME${NC}"

# Find game directory first
GAME_DIR=$(find_game_directory)
if [[ -n "$GAME_DIR" ]]; then
    echo -e "  Game found: ${GREEN}$GAME_DIR${NC}"
else
    echo -e "  ${YELLOW}Game not found - some checks will be skipped${NC}"
fi
echo ""

# Run all diagnostics
check_system_requirements
check_python_installation
check_mono_installation
check_game_installation
check_bepinex_installation
check_network_configuration
check_ssl_certificates
check_community_files
check_steam_integration
check_wine_proton

# Show summary
print_summary

# Export report if requested
if [[ "$EXPORT_REPORT" == "true" ]]; then
    export_report
fi

echo ""
