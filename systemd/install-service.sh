#!/bin/bash

# Install systemd service for Solana validator
# This script installs the service file and enables it

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly SERVICE_FILE="$SCRIPT_DIR/solana-validator.service"
readonly SYSTEMD_DIR="/etc/systemd/system"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Get current user (the user who ran sudo)
CURRENT_USER=${SUDO_USER:-$USER}
CURRENT_HOME=$(eval echo ~$CURRENT_USER)

# Get the actual repository path (handles paths with spaces)
REPO_PATH=$(realpath "$REPO_ROOT")

log_info "Installing systemd service for user: $CURRENT_USER"
log_info "Home directory: $CURRENT_HOME"
log_info "Repository path: $REPO_PATH"

# Check if service file exists
if [ ! -f "$SERVICE_FILE" ]; then
    log_error "Service file not found: $SERVICE_FILE"
    exit 1
fi

# Create a temporary service file with user-specific paths
TEMP_SERVICE=$(mktemp)
# Replace %i with username, %h with home, and %r with repo path
# Read file and replace placeholders (handles paths with spaces correctly)
while IFS= read -r line; do
    line="${line//%i/$CURRENT_USER}"
    line="${line//%h/$CURRENT_HOME}"
    line="${line//%r/$REPO_PATH}"
    echo "$line"
done < "$SERVICE_FILE" > "$TEMP_SERVICE"

# Copy service file to systemd directory
log_info "Copying service file to $SYSTEMD_DIR..."
cp "$TEMP_SERVICE" "$SYSTEMD_DIR/solana-validator.service"
rm "$TEMP_SERVICE"

# Reload systemd
log_info "Reloading systemd daemon..."
systemctl daemon-reload

log_success "Service installed successfully"
echo ""
echo "Service management commands:"
echo "  Start:        sudo systemctl start solana-validator"
echo "  Stop:         sudo systemctl stop solana-validator"
echo "  Force Stop:   %r/scripts/stop-validator.sh --force"
echo "  Status:       sudo systemctl status solana-validator"
echo "  Logs:         sudo journalctl -u solana-validator -f"
echo "  Enable:       sudo systemctl enable solana-validator  (auto-start on boot)"
echo "  Disable:      sudo systemctl disable solana-validator"
echo "  Mask:         sudo systemctl mask solana-validator      (prevent auto-start)"
echo ""
echo "Auto-restart: Service is configured to auto-restart if validator stops"
echo "  Restart delay: 10 seconds"
echo "  Max restarts:  5 attempts per 5 minutes"
echo ""

