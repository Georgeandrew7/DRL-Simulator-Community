#!/bin/bash
#
# DRL Simulator Community - macOS Updater
# Updates the installation to the latest version from GitHub
#

set -e

# Configuration
REPO_URL="https://github.com/Georgeandrew7/DRL-Simulator-Community"
REPO_API="https://api.github.com/repos/Georgeandrew7/DRL-Simulator-Community"
VERSION_FILE="VERSION.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Options
FORCE=false
NO_BACKUP=false
CHECK_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        --no-backup)
            NO_BACKUP=true
            shift
            ;;
        -c|--check-only)
            CHECK_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -f, --force      Force update even if up to date"
            echo "  --no-backup      Skip backup before updating"
            echo "  -c, --check-only Check for updates without installing"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Logging functions
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

log_step() {
    echo ""
    echo -e "${MAGENTA}[$1]${NC} $2"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          DRL Simulator Community - macOS Updater             ║${NC}"
    echo -e "${CYAN}║                       Version 1.0.0                          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This updater is for macOS only!"
        exit 1
    fi
}

check_dependencies() {
    # Check for curl
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    # Check for unzip
    if ! command -v unzip &> /dev/null; then
        log_error "unzip is required but not installed"
        exit 1
    fi
}

get_current_version() {
    local version_path="$INSTALL_DIR/$VERSION_FILE"
    if [[ -f "$version_path" ]]; then
        cat "$version_path" | tr -d '[:space:]'
    else
        echo "unknown"
    fi
}

get_latest_version() {
    log_info "Checking GitHub for latest version..."
    
    # Try to get latest release first
    local release_info
    release_info=$(curl -s "$REPO_API/releases/latest" 2>/dev/null)
    
    if echo "$release_info" | grep -q '"tag_name"'; then
        local version=$(echo "$release_info" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
        local date=$(echo "$release_info" | grep '"published_at"' | head -1 | sed 's/.*"published_at": *"\([^"]*\)".*/\1/')
        echo "release:$version:$date"
        return
    fi
    
    # Fall back to latest commit
    local commit_info
    commit_info=$(curl -s "$REPO_API/commits/main" 2>/dev/null)
    
    if echo "$commit_info" | grep -q '"sha"'; then
        local sha=$(echo "$commit_info" | grep '"sha"' | head -1 | sed 's/.*"sha": *"\([^"]*\)".*/\1/' | cut -c1-7)
        local date=$(echo "$commit_info" | grep '"date"' | head -1 | sed 's/.*"date": *"\([^"]*\)".*/\1/')
        echo "commit:$sha:$date"
        return
    fi
    
    echo "error:unknown:unknown"
}

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

create_backup() {
    log_info "Creating backup of current installation..."
    
    local backup_dir="$INSTALL_DIR/backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$backup_dir/backup_$timestamp"
    
    mkdir -p "$backup_dir"
    mkdir -p "$backup_path"
    
    # Items to backup
    local items=("common" "platforms/macos" "$VERSION_FILE")
    
    for item in "${items[@]}"; do
        local source="$INSTALL_DIR/$item"
        if [[ -e "$source" ]]; then
            local dest="$backup_path/$item"
            mkdir -p "$(dirname "$dest")"
            cp -R "$source" "$dest"
        fi
    done
    
    log_success "Backup created at: $backup_path"
    
    # Clean old backups (keep last 5)
    local backup_count=$(ls -1 "$backup_dir" | wc -l | tr -d ' ')
    if [[ $backup_count -gt 5 ]]; then
        log_info "Cleaning old backups..."
        ls -1t "$backup_dir" | tail -n +6 | while read old_backup; do
            rm -rf "$backup_dir/$old_backup"
            log_info "Removed old backup: $old_backup"
        done
    fi
    
    echo "$backup_path"
}

download_and_install() {
    log_info "Downloading latest version from GitHub..."
    
    local temp_dir=$(mktemp -d)
    local zip_path="$temp_dir/DRL-Community-latest.zip"
    
    # Download
    local download_url="$REPO_URL/archive/refs/heads/main.zip"
    log_info "Downloading from: $download_url"
    
    if ! curl -L -o "$zip_path" "$download_url" 2>/dev/null; then
        log_error "Failed to download update"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    log_success "Download complete"
    
    # Extract
    log_info "Extracting files..."
    unzip -q "$zip_path" -d "$temp_dir"
    
    # Find extracted folder
    local extracted_folder=$(find "$temp_dir" -maxdepth 1 -type d -name "DRL-*" | head -1)
    
    if [[ -z "$extracted_folder" ]]; then
        log_error "Failed to find extracted files"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Update files
    log_info "Updating installation..."
    
    # Update common files
    if [[ -d "$extracted_folder/common" ]]; then
        rm -rf "$INSTALL_DIR/common"
        cp -R "$extracted_folder/common" "$INSTALL_DIR/common"
        log_success "Updated common files"
    fi
    
    # Update macOS platform files (preserve config files)
    if [[ -d "$extracted_folder/platforms/macos" ]]; then
        # Save user config files
        local config_files=("config.json" "settings.json")
        for cfg in "${config_files[@]}"; do
            if [[ -f "$INSTALL_DIR/platforms/macos/$cfg" ]]; then
                cp "$INSTALL_DIR/platforms/macos/$cfg" "$temp_dir/$cfg.bak"
            fi
        done
        
        rm -rf "$INSTALL_DIR/platforms/macos"
        mkdir -p "$INSTALL_DIR/platforms"
        cp -R "$extracted_folder/platforms/macos" "$INSTALL_DIR/platforms/macos"
        
        # Restore config files
        for cfg in "${config_files[@]}"; do
            if [[ -f "$temp_dir/$cfg.bak" ]]; then
                cp "$temp_dir/$cfg.bak" "$INSTALL_DIR/platforms/macos/$cfg"
            fi
        done
        
        # Make scripts executable
        chmod +x "$INSTALL_DIR/platforms/macos"/*.sh 2>/dev/null || true
        
        log_success "Updated macOS platform files"
    fi
    
    # Update docs
    if [[ -d "$extracted_folder/docs" ]]; then
        rm -rf "$INSTALL_DIR/docs"
        cp -R "$extracted_folder/docs" "$INSTALL_DIR/docs"
        log_success "Updated documentation"
    fi
    
    # Update version file
    if [[ -f "$extracted_folder/$VERSION_FILE" ]]; then
        cp "$extracted_folder/$VERSION_FILE" "$INSTALL_DIR/$VERSION_FILE"
    else
        date +"%Y.%m.%d" > "$INSTALL_DIR/$VERSION_FILE"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log_success "Update complete!"
}

update_game_plugins() {
    local game_dir=$(find_game_directory)
    
    if [[ -z "$game_dir" ]]; then
        log_warn "Game directory not found, skipping plugin update"
        return
    fi
    
    log_info "Checking BepInEx plugins..."
    
    local plugins_dir="$game_dir/BepInEx/plugins"
    if [[ ! -d "$plugins_dir" ]]; then
        log_warn "BepInEx plugins directory not found"
        return
    fi
    
    log_info "Plugin sources updated. Run compile-plugin.sh to recompile if needed."
}

show_update_available() {
    local current=$1
    local latest_type=$2
    local latest_version=$3
    local latest_date=$4
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                     Update Available                         ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Current Version: ${YELLOW}$current${NC}"
    echo -e "  Latest Version:  ${GREEN}$latest_version${NC} ($latest_type)"
    echo -e "  Released:        ${CYAN}$latest_date${NC}"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

print_banner
check_macos
check_dependencies

log_step 1 "Checking Current Installation"

log_info "Installation directory: $INSTALL_DIR"

CURRENT_VERSION=$(get_current_version)
log_info "Current version: $CURRENT_VERSION"

GAME_DIR=$(find_game_directory)
if [[ -n "$GAME_DIR" ]]; then
    log_info "Game directory: $GAME_DIR"
else
    log_warn "Game directory not found"
fi

log_step 2 "Checking for Updates"

LATEST_INFO=$(get_latest_version)
LATEST_TYPE=$(echo "$LATEST_INFO" | cut -d: -f1)
LATEST_VERSION=$(echo "$LATEST_INFO" | cut -d: -f2)
LATEST_DATE=$(echo "$LATEST_INFO" | cut -d: -f3)

if [[ "$LATEST_TYPE" == "error" ]]; then
    log_error "Failed to check for updates"
    exit 1
fi

log_info "Latest version: $LATEST_VERSION ($LATEST_TYPE)"

# Check if update is needed
NEEDS_UPDATE=false
if [[ "$CURRENT_VERSION" == "unknown" ]]; then
    NEEDS_UPDATE=true
elif [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
    NEEDS_UPDATE=true
fi

if [[ "$NEEDS_UPDATE" == "false" ]] && [[ "$FORCE" == "false" ]]; then
    log_success "You are running the latest version!"
    echo ""
    echo "Use --force to update anyway"
    exit 0
fi

if [[ "$NEEDS_UPDATE" == "true" ]]; then
    show_update_available "$CURRENT_VERSION" "$LATEST_TYPE" "$LATEST_VERSION" "$LATEST_DATE"
fi

if [[ "$CHECK_ONLY" == "true" ]]; then
    log_info "Check-only mode, exiting without updating"
    exit 0
fi

# Confirm update
if [[ "$FORCE" == "false" ]]; then
    echo ""
    read -p "Do you want to update now? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Update cancelled"
        exit 0
    fi
fi

log_step 3 "Creating Backup"

if [[ "$NO_BACKUP" == "false" ]]; then
    BACKUP_PATH=$(create_backup)
else
    log_warn "Skipping backup (--no-backup specified)"
fi

log_step 4 "Downloading and Installing Update"

download_and_install

log_step 5 "Updating Game Files"

update_game_plugins

# Done
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                     Update Complete!                         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

NEW_VERSION=$(get_current_version)
log_success "Updated from $CURRENT_VERSION to $NEW_VERSION"
echo ""
