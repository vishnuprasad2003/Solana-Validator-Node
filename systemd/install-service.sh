#!/bin/bash

# Install systemd service for Solana Validator
# This script sets up the validator to run as a systemd service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Install Solana Validator Systemd Service"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Get the user who will run the service
if [ -z "$SUDO_USER" ]; then
    echo -e "${RED}Must be run with sudo${NC}"
    exit 1
fi

SERVICE_USER="$SUDO_USER"
SERVICE_USER_HOME=$(eval echo ~$SERVICE_USER)
SERVICE_FILE="/etc/systemd/system/solana-validator.service"

echo -e "${YELLOW}Installing systemd service...${NC}"

# Create service file
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Solana Test Validator
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$SERVICE_USER_HOME
Environment="PATH=$SERVICE_USER_HOME/.local/share/solana/install/active_release/bin:$SERVICE_USER_HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=$SERVICE_USER_HOME/start-validator.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

echo -e "${GREEN}✓ Service file created: $SERVICE_FILE${NC}"

echo ""
echo -e "${GREEN}=========================================="
echo "Service Installation Complete!"
echo "==========================================${NC}"
echo ""
echo "Service management commands:"
echo "  Start:   sudo systemctl start solana-validator"
echo "  Stop:    sudo systemctl stop solana-validator"
echo "  Status:  sudo systemctl status solana-validator"
echo "  Enable:  sudo systemctl enable solana-validator  (start on boot)"
echo "  Logs:    sudo journalctl -u solana-validator -f"
echo ""
echo "Note: Make sure start-validator.sh is executable:"
echo "  chmod +x $SERVICE_USER_HOME/start-validator.sh"
echo ""

