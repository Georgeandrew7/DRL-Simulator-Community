#!/bin/bash
# DRL Photon Server Docker Setup Script
# This script prepares and runs the Photon Server in Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(dirname "$SCRIPT_DIR")"
PHOTON_SRC="$GAME_DIR/DRL Simulator_Data/StreamingAssets/PhotonServer"

echo "=== DRL Simulator Photon Server Docker Setup ==="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if docker-compose is available
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo "ERROR: docker-compose is not installed. Please install it first."
    exit 1
fi

# Create PhotonServer directory for Docker context
echo "[1/5] Copying Photon Server files..."
if [ ! -d "$SCRIPT_DIR/PhotonServer" ]; then
    cp -r "$PHOTON_SRC" "$SCRIPT_DIR/PhotonServer"
    echo "      Copied Photon Server to Docker context"
else
    echo "      PhotonServer directory already exists, skipping copy"
fi

# Create logs directory
echo "[2/5] Creating logs directory..."
mkdir -p "$SCRIPT_DIR/logs"

# Update configuration for Docker networking
echo "[3/5] Updating server configuration for Docker..."

# Update Master config to use 0.0.0.0 for binding
MASTER_CONFIG="$SCRIPT_DIR/PhotonServer/Loadbalancing/Master/bin/Photon.LoadBalancing.dll.config"
if [ -f "$MASTER_CONFIG" ]; then
    # Backup original
    cp "$MASTER_CONFIG" "$MASTER_CONFIG.backup" 2>/dev/null || true
    
    # Replace localhost with 0.0.0.0 for public access
    sed -i 's|<value>127\.0\.0\.1</value>|<value>0.0.0.0</value>|g' "$MASTER_CONFIG"
    echo "      Updated Master configuration"
fi

# Update GameServer config
GAME_CONFIG="$SCRIPT_DIR/PhotonServer/Loadbalancing/GameServer/bin/Photon.LoadBalancing.dll.config"
if [ -f "$GAME_CONFIG" ]; then
    cp "$GAME_CONFIG" "$GAME_CONFIG.backup" 2>/dev/null || true
    sed -i 's|<value>127\.0\.0\.1</value>|<value>0.0.0.0</value>|g' "$GAME_CONFIG"
    echo "      Updated GameServer configuration"
fi

echo "[4/5] Building Docker image..."
cd "$SCRIPT_DIR"
$COMPOSE_CMD build

echo "[5/5] Starting Photon Server..."
$COMPOSE_CMD up -d

echo ""
echo "=== Photon Server Started ==="
echo ""
echo "Container status:"
$COMPOSE_CMD ps
echo ""
echo "Ports:"
echo "  UDP 5055 - Master Server"
echo "  UDP 5056 - Game Server"
echo "  TCP 4530 - Master TCP"
echo "  TCP 4531 - Game TCP"
echo "  TCP 9090 - Master WebSocket"
echo "  TCP 9091 - Game WebSocket"
echo ""
echo "To view logs:     $COMPOSE_CMD logs -f"
echo "To stop server:   $COMPOSE_CMD down"
echo "To restart:       $COMPOSE_CMD restart"
echo ""
echo "Server should be accessible at: $(hostname -I | awk '{print $1}'):5055"
