#!/bin/bash
#
# DRL Simulator Self-Hosted Server Setup Script
# This script helps configure and run the embedded Photon Server
#

set -e

GAME_DIR="$(cd "$(dirname "$0")" && pwd)"
PHOTON_DIR="$GAME_DIR/DRL Simulator_Data/StreamingAssets/PhotonServer"
BIN_DIR="$PHOTON_DIR/bin_Win64"

echo "=============================================="
echo "DRL Simulator Self-Hosted Server Setup"
echo "=============================================="
echo ""
echo "Game Directory: $GAME_DIR"
echo "Photon Server: $PHOTON_DIR"
echo ""

# Check if the Photon Server exists
if [ ! -d "$PHOTON_DIR" ]; then
    echo "ERROR: Photon Server directory not found!"
    echo "Expected at: $PHOTON_DIR"
    exit 1
fi

echo "✓ Photon Server files found"

# Check for Wine on Linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v wine &> /dev/null; then
        echo "✓ Wine is available for running Windows server"
        USE_WINE=true
    else
        echo "⚠ Wine not found. Install wine to run the Photon Server:"
        echo "  Ubuntu/Debian: sudo apt install wine"
        echo "  Arch: sudo pacman -S wine"
        echo "  Fedora: sudo dnf install wine"
        USE_WINE=false
    fi
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    echo "✓ Running on Windows"
    USE_WINE=false
fi

# Function to update server configuration
configure_server() {
    local PUBLIC_IP="$1"
    local MASTER_CONFIG="$PHOTON_DIR/LoadBalancing/Master/bin/Photon.LoadBalancing.dll.config"
    local GAME_CONFIG="$PHOTON_DIR/LoadBalancing/GameServer/bin/Photon.LoadBalancing.dll.config"
    
    if [ -z "$PUBLIC_IP" ]; then
        echo ""
        echo "Enter your server's public IP address (or leave blank for localhost):"
        read -r PUBLIC_IP
        if [ -z "$PUBLIC_IP" ]; then
            PUBLIC_IP="127.0.0.1"
        fi
    fi
    
    echo ""
    echo "Configuring server for IP: $PUBLIC_IP"
    
    # Backup original configs
    if [ ! -f "$MASTER_CONFIG.backup" ]; then
        cp "$MASTER_CONFIG" "$MASTER_CONFIG.backup"
        echo "✓ Backed up Master config"
    fi
    if [ ! -f "$GAME_CONFIG.backup" ]; then
        cp "$GAME_CONFIG" "$GAME_CONFIG.backup"
        echo "✓ Backed up GameServer config"
    fi
    
    # Update Master config
    if command -v sed &> /dev/null; then
        sed -i "s|<add key=\"PublicIPAddress\" value=\"[^\"]*\"|<add key=\"PublicIPAddress\" value=\"$PUBLIC_IP\"|g" "$MASTER_CONFIG"
        sed -i "s|<add key=\"PublicIPAddress\" value=\"[^\"]*\"|<add key=\"PublicIPAddress\" value=\"$PUBLIC_IP\"|g" "$GAME_CONFIG"
        echo "✓ Updated server configurations"
    else
        echo "⚠ sed not available, please manually update PublicIPAddress in:"
        echo "  - $MASTER_CONFIG"
        echo "  - $GAME_CONFIG"
    fi
}

# Function to start the server
start_server() {
    echo ""
    echo "Starting Photon Server..."
    
    cd "$BIN_DIR"
    
    if [[ "$USE_WINE" == "true" ]]; then
        echo "Running via Wine..."
        wine PhotonSocketServer.exe /debug LoadBalancing &
        SERVER_PID=$!
        echo "Server started with PID: $SERVER_PID"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
        echo "Running natively on Windows..."
        ./PhotonSocketServer.exe /debug LoadBalancing &
        SERVER_PID=$!
        echo "Server started with PID: $SERVER_PID"
    else
        echo "Cannot start server: No suitable runtime available"
        echo "Please run manually on Windows or install Wine"
        return 1
    fi
    
    echo ""
    echo "Server should be listening on:"
    echo "  Master: UDP 5055, TCP 4530, WS 9090"
    echo "  Game:   UDP 5056, TCP 4531, WS 9091"
    echo ""
    echo "To stop the server, run: kill $SERVER_PID"
}

# Function to show server status
show_ports() {
    echo ""
    echo "Checking if server ports are in use..."
    
    for port in 5055 5056 4530 4531 9090 9091; do
        if command -v ss &> /dev/null; then
            result=$(ss -tuln | grep ":$port " || echo "")
        elif command -v netstat &> /dev/null; then
            result=$(netstat -tuln | grep ":$port " || echo "")
        else
            result=""
        fi
        
        if [ -n "$result" ]; then
            echo "  Port $port: IN USE"
        else
            echo "  Port $port: available"
        fi
    done
}

# Function to create Docker setup
create_docker() {
    local DOCKER_DIR="$GAME_DIR/docker-server"
    
    echo ""
    echo "Creating Docker setup in: $DOCKER_DIR"
    
    mkdir -p "$DOCKER_DIR"
    
    # Copy Photon Server files
    cp -r "$PHOTON_DIR" "$DOCKER_DIR/"
    
    # Create Dockerfile
    cat > "$DOCKER_DIR/Dockerfile" << 'EOF'
FROM scottyhardy/docker-wine:latest

WORKDIR /opt/photon
COPY PhotonServer/ ./

# Expose all necessary ports
EXPOSE 5055/udp 5056/udp
EXPOSE 4530/tcp 4531/tcp 4520/tcp
EXPOSE 843/tcp 943/tcp
EXPOSE 9090/tcp 9091/tcp

# Run the Photon Server
CMD ["wine", "bin_Win64/PhotonSocketServer.exe", "/run", "LoadBalancing"]
EOF

    # Create docker-compose.yml
    cat > "$DOCKER_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  photon-server:
    build: .
    container_name: drl-photon-server
    ports:
      - "5055:5055/udp"
      - "5056:5056/udp"
      - "4530:4530"
      - "4531:4531"
      - "4520:4520"
      - "843:843"
      - "943:943"
      - "9090:9090"
      - "9091:9091"
    restart: unless-stopped
    volumes:
      - ./logs:/opt/photon/bin_Win64/log
EOF

    echo "✓ Created Dockerfile"
    echo "✓ Created docker-compose.yml"
    echo ""
    echo "To build and run:"
    echo "  cd $DOCKER_DIR"
    echo "  docker-compose up -d"
}

# Menu
echo ""
echo "Select an option:"
echo "  1) Configure server IP"
echo "  2) Start server (Wine/Native)"
echo "  3) Check port availability"
echo "  4) Create Docker setup"
echo "  5) Show configuration locations"
echo "  6) Exit"
echo ""
read -r -p "Choice [1-6]: " choice

case $choice in
    1)
        configure_server
        ;;
    2)
        start_server
        ;;
    3)
        show_ports
        ;;
    4)
        create_docker
        ;;
    5)
        echo ""
        echo "Configuration files:"
        echo "  Master: $PHOTON_DIR/LoadBalancing/Master/bin/Photon.LoadBalancing.dll.config"
        echo "  Game:   $PHOTON_DIR/LoadBalancing/GameServer/bin/Photon.LoadBalancing.dll.config"
        echo "  Server: $BIN_DIR/PhotonServer.config"
        echo "  License: $BIN_DIR/ben_t@drl.io.Photon-vX.free.100-ccu.license"
        ;;
    6)
        echo "Exiting."
        exit 0
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "Done!"
