#!/bin/bash

# Add Validator to Cluster Script
# Run this on additional nodes to join the cluster

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

CLUSTER_DIR="$HOME/solana-cluster-config"

echo "=========================================="
echo "Add Validator to Cluster"
echo "=========================================="
echo ""

# Check if bootstrap validator info exists
if [ ! -f "$CLUSTER_DIR/cluster-config.json" ]; then
    echo -e "${RED}Error: Cluster not configured on this node.${NC}"
    echo "Please provide bootstrap validator information:"
    echo ""
    read -p "Bootstrap Validator IP: " BOOTSTRAP_IP
    read -p "Bootstrap Validator Port (default 8001): " BOOTSTRAP_PORT
    BOOTSTRAP_PORT=${BOOTSTRAP_PORT:-8001}
    
    mkdir -p "$CLUSTER_DIR"
    cat > "$CLUSTER_DIR/cluster-config.json" << EOF
{
  "bootstrapValidatorIp": "$BOOTSTRAP_IP",
  "bootstrapValidatorPort": $BOOTSTRAP_PORT,
  "rpcPort": 8899,
  "faucetPort": 9900
}
EOF
    echo -e "${GREEN}✓ Cluster config created${NC}"
else
    echo -e "${GREEN}✓ Using existing cluster config${NC}"
fi

# Generate validator keypair
echo ""
echo -e "${YELLOW}Generating validator keypair...${NC}"
VALIDATOR_KEYPAIR="$HOME/.config/solana/validator-keypair.json"

if [ ! -f "$VALIDATOR_KEYPAIR" ]; then
    solana-keygen new --outfile "$VALIDATOR_KEYPAIR" --no-bip39-passphrase --force
    VALIDATOR_PUBKEY=$(solana address -k "$VALIDATOR_KEYPAIR")
    echo -e "${GREEN}✓ Validator keypair generated${NC}"
    echo "  Validator: $VALIDATOR_PUBKEY"
else
    VALIDATOR_PUBKEY=$(solana address -k "$VALIDATOR_KEYPAIR")
    echo -e "${GREEN}✓ Using existing validator keypair${NC}"
    echo "  Validator: $VALIDATOR_PUBKEY"
fi

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}=========================================="
echo "Validator Ready to Join Cluster"
echo "==========================================${NC}"
echo ""
echo "Validator Pubkey: $VALIDATOR_PUBKEY"
echo "Validator IP: $SERVER_IP"
echo ""
echo "Next steps:"
echo "1. Add this validator to bootstrap node's validator-list.txt:"
echo "   $VALIDATOR_PUBKEY $SERVER_IP 8001"
echo ""
echo "2. Start this validator:"
echo "   ./start-cluster-validator.sh"
echo ""

