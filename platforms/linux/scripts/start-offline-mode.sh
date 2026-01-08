#!/bin/bash
# DRL Simulator Self-Hosted Multiplayer Setup
# This script sets up everything needed for offline/LAN play

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_ENTRY="127.0.0.1 api.drlgame.com"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       DRL Simulator Self-Hosted Setup                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root (needed for hosts file and port 80)
if [ "$EUID" -ne 0 ]; then
    echo "This script needs root privileges to:"
    echo "  1. Modify /etc/hosts to redirect api.drlgame.com"
    echo "  2. Bind to port 80 for the mock API server"
    echo ""
    echo "Please run with sudo:"
    echo "  sudo $0"
    exit 1
fi

# Check if hosts entry exists
if grep -q "api.drlgame.com" /etc/hosts; then
    echo "[✓] /etc/hosts already contains api.drlgame.com entry"
else
    echo "[*] Adding api.drlgame.com to /etc/hosts..."
    echo "$HOSTS_ENTRY" >> /etc/hosts
    echo "[✓] Added: $HOSTS_ENTRY"
fi

# Kill any existing server on port 80
if lsof -i :80 > /dev/null 2>&1; then
    echo "[*] Port 80 is in use, stopping existing service..."
    fuser -k 80/tcp 2>/dev/null || true
    sleep 1
fi

# Start the mock backend server
echo ""
echo "[*] Starting mock DRL backend server..."
echo ""

cd "$SCRIPT_DIR"
python3 mock_drl_backend.py --port 80 &
SERVER_PID=$!

echo "[✓] Mock server started (PID: $SERVER_PID)"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "The mock backend server is now running!"
echo ""
echo "Next steps:"
echo "  1. Open a new terminal"
echo "  2. Launch DRL Simulator through Steam"
echo "  3. The game should now get past the login screen"
echo ""
echo "Press Ctrl+C to stop the server and clean up."
echo ""

# Wait for interrupt
trap "echo ''; echo 'Cleaning up...'; kill $SERVER_PID 2>/dev/null; echo 'Server stopped.'" EXIT

wait $SERVER_PID
