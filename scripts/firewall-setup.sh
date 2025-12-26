#!/bin/bash

# Firewall Setup Script
# This script configures UFW firewall to allow RPC access

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RPC_PORT=8899
FAUCET_PORT=9900

echo -e "${BLUE}=========================================="
echo "Firewall Configuration for Solana RPC"
echo "==========================================${NC}"
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

# Allow RPC port (only if not already added)
if ! ufw status | grep -q "$RPC_PORT/tcp"; then
    ufw allow $RPC_PORT/tcp comment "Solana RPC"
    echo -e "${GREEN}✓ Allowed RPC port $RPC_PORT${NC}"
else
    echo -e "${GREEN}✓ RPC port $RPC_PORT already allowed${NC}"
fi

# Allow faucet port (only if not already added)
if ! ufw status | grep -q "$FAUCET_PORT/tcp"; then
    ufw allow $FAUCET_PORT/tcp comment "Solana Faucet"
    echo -e "${GREEN}✓ Allowed faucet port $FAUCET_PORT${NC}"
else
    echo -e "${GREEN}✓ Faucet port $FAUCET_PORT already allowed${NC}"
fi

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
echo -e "${BLUE}Firewall status:${NC}"
ufw status | head -10
echo ""
PRIVATE_IP=$(hostname -I | awk '{print $1}' || echo "N/A")
echo -e "${BLUE}RPC endpoint:${NC}"
echo "  http://$PRIVATE_IP:$RPC_PORT"
echo ""
echo -e "${YELLOW}Note:${NC} Ensure validator is configured for network access:"
echo "  Run: ./configure-rpc-public.sh"
echo ""

