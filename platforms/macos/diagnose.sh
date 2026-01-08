#!/bin/bash
#
# DRL Simulator Community - macOS Diagnostic Tool
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
            echo "  -e, --export     Export report to Desktop"
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

# Find game directory
find_game_directory() {
    local possible_paths=(
        "$HOME/Library/Application Support/Steam/steamapps/common/DRL Simulator"
        "/Applications/DRL Simulator.app"
        "$HOME/Games/DRL Simulator"
    )
    
    for path in "${possible_paths[@]}"; do
        if [[ -d "$path" ]]; then
            echo "$path"
            return
        fi
    done
    
    echo ""
}

# ============================================================================
# DIAGNOSTIC CHECKS
# ============================================================================

check_system_requirements() {
    print_section "System Requirements"
    
    # macOS version
    local macos_version=$(sw_vers -productVersion)
    local major_version=$(echo "$macos_version" | cut -d. -f1)
    
    if [[ $major_version -ge 11 ]] || [[ "$macos_version" == 10.15* ]]; then
        check_pass "macOS Version" "$macos_version"
    elif [[ "$macos_version" == 10.14* ]]; then
        check_warn "macOS Version" "$macos_version" "macOS 10.15+ recommended"
    else
        check_fail "macOS Version" "$macos_version" "macOS 10.14+ required"
    fi
    
    # Architecture
    local arch=$(uname -m)
    if [[ "$arch" == "arm64" ]]; then
        check_pass "Architecture" "Apple Silicon (M1/M2/M3)"
    else
        check_pass "Architecture" "Intel x86_64"
    fi
    
    # RAM
    local ram_bytes=$(sysctl -n hw.memsize)
    local ram_gb=$((ram_bytes / 1024 / 1024 / 1024))
    
    if [[ $ram_gb -ge 8 ]]; then
        check_pass "System Memory" "${ram_gb} GB RAM"
    elif [[ $ram_gb -ge 4 ]]; then
        check_warn "System Memory" "${ram_gb} GB RAM" "8GB+ recommended"
    else
        check_fail "System Memory" "${ram_gb} GB RAM" "Minimum 4GB required"
    fi
    
    # Disk space
    local free_space=$(df -g "$INSTALL_DIR" | tail -1 | awk '{print $4}')
    
    if [[ $free_space -ge 5 ]]; then
        check_pass "Disk Space" "${free_space} GB free"
    elif [[ $free_space -ge 1 ]]; then
        check_warn "Disk Space" "${free_space} GB free" "5GB+ recommended"
    else
        check_fail "Disk Space" "${free_space} GB free" "Low disk space"
    fi
    
    # Xcode Command Line Tools
    if xcode-select -p &> /dev/null; then
        check_pass "Xcode CLI Tools" "Installed"
    else
        check_warn "Xcode CLI Tools" "Not installed" "Run: xcode-select --install"
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
            check_fail "Pip" "Not installed" "Run: $python_cmd -m ensurepip"
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
        check_fail "Python" "Not found" "Install Python 3.8+ from python.org or via Homebrew"
    fi
}

check_homebrew() {
    print_section "Homebrew"
    
    if command -v brew &> /dev/null; then
        local brew_version=$(brew --version | head -1)
        check_pass "Homebrew" "$brew_version"
        
        # Check for Mono
        if brew list mono &> /dev/null; then
            local mono_version=$(mono --version 2>&1 | head -1)
            check_pass "Mono" "$mono_version"
        else
            check_warn "Mono" "Not installed" "Run: brew install mono (required for plugin compilation)"
        fi
    else
        check_warn "Homebrew" "Not installed" "Visit https://brew.sh to install"
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
    
    # Check for executable or app bundle
    if [[ -d "$game_dir" ]] && [[ "$game_dir" == *".app" ]]; then
        check_pass "Game Bundle" "macOS App Bundle"
    elif [[ -f "$game_dir/DRL Simulator.x86_64" ]] || [[ -f "$game_dir/DRL Simulator" ]]; then
        check_pass "Game Executable" "Found"
    else
        check_warn "Game Executable" "Not found in expected location"
    fi
    
    # Check Data folder
    local data_paths=(
        "$game_dir/Contents/Resources/Data"
        "$game_dir/DRL Simulator_Data"
    )
    
    local data_found=false
    for data_path in "${data_paths[@]}"; do
        if [[ -d "$data_path" ]]; then
            check_pass "Game Data" "Found" "$data_path"
            data_found=true
            
            # Check Managed folder
            local managed_path="$data_path/Managed"
            if [[ -d "$managed_path" ]]; then
                if [[ -f "$managed_path/Assembly-CSharp.dll" ]]; then
                    check_pass "Assembly-CSharp.dll" "Found"
                else
                    check_warn "Assembly-CSharp.dll" "Not found"
                fi
            fi
            break
        fi
    done
    
    if [[ "$data_found" == "false" ]]; then
        check_fail "Game Data" "Not found"
    fi
    
    GAME_DIR="$game_dir"
}

check_bepinex_installation() {
    print_section "BepInEx Installation"
    
    if [[ -z "$GAME_DIR" ]]; then
        check_fail "BepInEx" "Game not found" "Cannot check BepInEx installation"
        return
    fi
    
    local bepinex_path="$GAME_DIR/BepInEx"
    
    if [[ ! -d "$bepinex_path" ]]; then
        check_fail "BepInEx Directory" "Not installed" "Run install.sh to install BepInEx"
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
    
    # Check plugins directory
    local plugins_path="$bepinex_path/plugins"
    if [[ -d "$plugins_path" ]]; then
        local plugin_count=$(find "$plugins_path" -name "*.dll" 2>/dev/null | wc -l | tr -d ' ')
        if [[ $plugin_count -gt 0 ]]; then
            check_pass "Plugins Directory" "$plugin_count plugin(s) installed"
            
            # List plugins if verbose
            if [[ "$VERBOSE" == "true" ]]; then
                for plugin in "$plugins_path"/*.dll; do
                    if [[ -f "$plugin" ]]; then
                        echo -e "      ${GRAY}└─ $(basename "$plugin")${NC}"
                    fi
                done
            fi
        else
            check_warn "Plugins Directory" "No plugins installed" "Run install.sh to compile plugins"
        fi
    else
        check_warn "Plugins Directory" "Not found"
    fi
    
    # Check logs
    local log_file="$bepinex_path/LogOutput.log"
    if [[ -f "$log_file" ]]; then
        local log_age=$(( ($(date +%s) - $(stat -f %m "$log_file")) / 86400 ))
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
        
        if lsof -i :$port &> /dev/null; then
            # Port in use - might be our server
            local process=$(lsof -i :$port | tail -1 | awk '{print $1}')
            if [[ "$process" == "python"* ]] || [[ "$process" == "Python"* ]]; then
                check_pass "Port $port ($name)" "In use by Python (server running?)"
            else
                check_warn "Port $port ($name)" "In use by $process"
            fi
        else
            check_pass "Port $port ($name)" "Available"
        fi
    done
    
    # Test mock server
    if curl -s --connect-timeout 2 "http://127.0.0.1:80" &> /dev/null; then
        check_pass "Mock Server (HTTP)" "Responding on port 80"
    else
        check_warn "Mock Server (HTTP)" "Not running" "Start with: ./start-offline-mode.sh"
    fi
    
    # Test internet connectivity
    if curl -s --connect-timeout 5 "https://github.com" &> /dev/null; then
        check_pass "Internet Connection" "Connected"
    else
        check_warn "Internet Connection" "Limited or no connection" "Updates may not work"
    fi
}

check_ssl_certificates() {
    print_section "SSL Certificates"
    
    local cert_paths=(
        "$INSTALL_DIR/certs"
        "$SCRIPT_DIR/certs"
        "$INSTALL_DIR/platforms/macos/certs"
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
                local created=$(stat -f %SB -t %Y-%m-%d "$file_path")
                check_pass "$file" "Found" "Created $created"
            else
                check_warn "$file" "Not found" "HTTPS may not work"
            fi
        done
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
            local cs_count=$(find "$plugins_path" -name "*.cs" | wc -l | tr -d ' ')
            check_pass "Plugin Sources" "$cs_count source file(s)"
        fi
    else
        check_fail "Common Files" "Not found" "Installation may be corrupted"
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
    if pgrep -x "steam_osx" &> /dev/null || pgrep -x "Steam" &> /dev/null; then
        check_pass "Steam Process" "Running"
    else
        check_warn "Steam Process" "Not running" "Start Steam before playing"
    fi
    
    # Check Steam installation
    local steam_paths=(
        "/Applications/Steam.app"
        "$HOME/Library/Application Support/Steam"
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
    echo ""
}

export_report() {
    local report_path="$HOME/Desktop/DRL-Diagnostic-Report.txt"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local total=$((PASSED + WARNINGS + FAILED))
    local health_score=$((PASSED * 100 / total))
    
    cat > "$report_path" << EOF
DRL Simulator Community - Diagnostic Report
Generated: $timestamp
============================================

$REPORT

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

# Check we're on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}This diagnostic tool is for macOS only!${NC}"
    exit 1
fi

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
check_homebrew
check_game_installation
check_bepinex_installation
check_network_configuration
check_ssl_certificates
check_community_files
check_steam_integration

# Show summary
print_summary

# Export report if requested
if [[ "$EXPORT_REPORT" == "true" ]]; then
    export_report
fi

echo ""
