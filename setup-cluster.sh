#!/bin/bash

# Solana Private Cluster Setup Script
# This script sets up a multi-node private Solana cluster
# Run this on the FIRST node (bootstrap validator) to create the cluster

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

echo "=========================================="
echo "Solana Private Cluster Setup"
echo "=========================================="
echo ""

# Configuration
CLUSTER_DIR="$HOME/solana-cluster-config"
LEDGER_DIR="$HOME/solana-local-ledger"
KEYPAIR_DIR="$HOME/.config/solana"

# Step 1: Create cluster configuration directory
echo -e "${YELLOW}[1/6] Creating cluster configuration...${NC}"
mkdir -p "$CLUSTER_DIR"
mkdir -p "$KEYPAIR_DIR"
echo -e "${GREEN}✓ Cluster directory created${NC}"

# Step 2: Generate cluster keypair (bootstrap validator)
echo ""
echo -e "${YELLOW}[2/6] Generating bootstrap validator keypair...${NC}"
BOOTSTRAP_KEYPAIR="$CLUSTER_DIR/bootstrap-validator-keypair.json"

if [ ! -f "$BOOTSTRAP_KEYPAIR" ]; then
    solana-keygen new --outfile "$BOOTSTRAP_KEYPAIR" --no-bip39-passphrase --force
    BOOTSTRAP_PUBKEY=$(solana address -k "$BOOTSTRAP_KEYPAIR")
    echo -e "${GREEN}✓ Bootstrap validator keypair generated${NC}"
    echo "  Bootstrap Validator: $BOOTSTRAP_PUBKEY"
else
    BOOTSTRAP_PUBKEY=$(solana address -k "$BOOTSTRAP_KEYPAIR")
    echo -e "${GREEN}✓ Using existing bootstrap validator${NC}"
    echo "  Bootstrap Validator: $BOOTSTRAP_PUBKEY"
fi

# Step 3: Create cluster configuration file
echo ""
echo -e "${YELLOW}[3/6] Creating cluster configuration...${NC}"

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

cat > "$CLUSTER_DIR/cluster-config.json" << EOF
{
  "clusterName": "private-solana-cluster",
  "bootstrapValidator": "$BOOTSTRAP_PUBKEY",
  "bootstrapValidatorIp": "$SERVER_IP",
  "bootstrapValidatorPort": 8001,
  "rpcPort": 8899,
  "faucetPort": 9900,
  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "validators": [
    {
      "pubkey": "$BOOTSTRAP_PUBKEY",
      "ip": "$SERVER_IP",
      "port": 8001,
      "role": "bootstrap"
    }
  ]
}
EOF

echo -e "${GREEN}✓ Cluster configuration created${NC}"
echo "  Config: $CLUSTER_DIR/cluster-config.json"

# Step 4: Create validator list file
echo ""
echo -e "${YELLOW}[4/6] Creating validator list...${NC}"

cat > "$CLUSTER_DIR/validator-list.txt" << EOF
# Solana Private Cluster Validator List
# Format: <validator-pubkey> <ip-address> <gossip-port>
# Add additional validators below

$BOOTSTRAP_PUBKEY $SERVER_IP 8001
EOF

echo -e "${GREEN}✓ Validator list created${NC}"
echo "  Validator List: $CLUSTER_DIR/validator-list.txt"

# Step 5: Create cluster start script
echo ""
echo -e "${YELLOW}[5/6] Creating cluster start script...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat > "$SCRIPT_DIR/start-cluster-validator.sh" << 'EOFSCRIPT'
#!/bin/bash
# Start Solana Validator as part of a cluster

LEDGER_DIR="$HOME/solana-local-ledger"
CLUSTER_DIR="$HOME/solana-cluster-config"
BOOTSTRAP_KEYPAIR="$CLUSTER_DIR/bootstrap-validator-keypair.json"
RPC_PORT=8899
RPC_BIND_ADDRESS="0.0.0.0"
FAUCET_PORT=9900
GOSSIP_PORT=8001

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Check if bootstrap validator
if [ -f "$BOOTSTRAP_KEYPAIR" ]; then
    echo "Starting as Bootstrap Validator..."
    VALIDATOR_KEYPAIR="$BOOTSTRAP_KEYPAIR"
    RESET_FLAG="--reset"
    ENTRYPOINT=""
else
    echo "Starting as Regular Validator..."
    VALIDATOR_KEYPAIR="$HOME/.config/solana/validator-keypair.json"
    RESET_FLAG=""
    
    # Load cluster config for entrypoint
    if [ -f "$CLUSTER_DIR/cluster-config.json" ]; then
        BOOTSTRAP_IP=$(grep -o '"bootstrapValidatorIp": "[^"]*"' "$CLUSTER_DIR/cluster-config.json" | cut -d'"' -f4)
        BOOTSTRAP_PORT=$(grep -o '"bootstrapValidatorPort": [0-9]*' "$CLUSTER_DIR/cluster-config.json" | awk '{print $2}')
        if [ -n "$BOOTSTRAP_IP" ] && [ -n "$BOOTSTRAP_PORT" ]; then
            ENTRYPOINT="--entrypoint $BOOTSTRAP_IP:$BOOTSTRAP_PORT"
        else
            echo "Warning: Could not parse bootstrap info. Starting as standalone."
            ENTRYPOINT=""
        fi
    else
        echo "Warning: Cluster config not found. Starting as standalone."
        ENTRYPOINT=""
    fi
fi

echo "  RPC: http://$RPC_BIND_ADDRESS:$RPC_PORT"
echo "  Ledger: $LEDGER_DIR"
if [ -n "$ENTRYPOINT" ]; then
    echo "  Entrypoint: $ENTRYPOINT"
fi
echo ""

# Build command
CMD="solana-test-validator --ledger \"$LEDGER_DIR\" --rpc-port $RPC_PORT --rpc-bind-address $RPC_BIND_ADDRESS --faucet-port $FAUCET_PORT --gossip-port $GOSSIP_PORT --identity \"$VALIDATOR_KEYPAIR\" --quiet --limit-ledger-size"

if [ -n "$RESET_FLAG" ]; then
    CMD="$CMD $RESET_FLAG"
fi

if [ -n "$ENTRYPOINT" ]; then
    CMD="$CMD $ENTRYPOINT"
fi

eval $CMD
EOFSCRIPT

chmod +x "$SCRIPT_DIR/start-cluster-validator.sh"
echo -e "${GREEN}✓ Cluster start script created${NC}"

# Step 6: Create cluster info script
echo ""
echo -e "${YELLOW}[6/6] Creating cluster management scripts...${NC}"

cat > "$SCRIPT_DIR/cluster-info.sh" << 'EOFSCRIPT'
#!/bin/bash
# Display cluster information

CLUSTER_DIR="$HOME/solana-cluster-config"

if [ ! -f "$CLUSTER_DIR/cluster-config.json" ]; then
    echo "Cluster not configured. Run setup-cluster.sh first."
    exit 1
fi

echo "=========================================="
echo "Cluster Information"
echo "=========================================="
echo ""
cat "$CLUSTER_DIR/cluster-config.json" | python3 -m json.tool 2>/dev/null || cat "$CLUSTER_DIR/cluster-config.json"
echo ""
echo "Validator List:"
cat "$CLUSTER_DIR/validator-list.txt"
EOFSCRIPT

chmod +x "$SCRIPT_DIR/cluster-info.sh"
echo -e "${GREEN}✓ Cluster info script created${NC}"

echo ""
echo -e "${GREEN}=========================================="
echo "Cluster Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Bootstrap Validator: $BOOTSTRAP_PUBKEY"
echo "Server IP: $SERVER_IP"
echo ""
echo "Next steps:"
echo "1. Start bootstrap validator: ./start-cluster-validator.sh"
echo "2. Add additional validators using: ./add-validator.sh <validator-ip>"
echo "3. View cluster info: ./cluster-info.sh"
echo ""

