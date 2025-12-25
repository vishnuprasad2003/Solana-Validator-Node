#!/bin/bash

# Firewall Setup Script
# This script configures UFW firewall to allow RPC access

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

RPC_PORT=8899
FAUCET_PORT=9900

echo "=========================================="
echo "Firewall Configuration for Solana RPC"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Check if UFW is installed
if ! command -v ufw &> /dev/null; then
    echo -e "${YELLOW}UFW is not installed. Installing...${NC}"
    apt-get update
    apt-get install -y ufw
fi

echo -e "${YELLOW}Configuring firewall rules...${NC}"

# Allow RPC port
ufw allow $RPC_PORT/tcp comment "Solana RPC"
echo -e "${GREEN}✓ Allowed RPC port $RPC_PORT${NC}"

# Allow faucet port
ufw allow $FAUCET_PORT/tcp comment "Solana Faucet"
echo -e "${GREEN}✓ Allowed faucet port $FAUCET_PORT${NC}"

# Enable UFW if not already enabled
if ! ufw status | grep -q "Status: active"; then
    echo ""
    echo -e "${YELLOW}Enabling UFW firewall...${NC}"
    ufw --force enable
    echo -e "${GREEN}✓ UFW enabled${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Firewall Configuration Complete!"
echo "==========================================${NC}"
echo ""
echo "Firewall status:"
ufw status
echo ""
echo "RPC endpoint will be accessible at:"
echo "  http://$(hostname -I | awk '{print $1}'):$RPC_PORT"
echo ""
echo "Note: For remote access, use SSH port forwarding or a reverse proxy."
echo "  The test validator uses --bind-address 127.0.0.1 for local access."
echo ""

