#!/bin/bash

# Configure RPC for Local Access Only
# This script configures the validator to accept RPC connections only from localhost (127.0.0.1)
# Use this for local development or to restrict access for security

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Configure RPC for Local Access Only"
echo "=========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if config.env exists
if [ ! -f "$SCRIPT_DIR/config.env" ]; then
    echo -e "${RED}Error: config.env not found${NC}"
    exit 1
fi

# Step 1: Update config.env for local access
echo -e "${YELLOW}[1/3] Configuring RPC_BIND_ADDRESS for local access only...${NC}"

# Check current bind address
CURRENT_BIND=$(grep "^RPC_BIND_ADDRESS=" "$SCRIPT_DIR/config.env" | cut -d'=' -f2 | tr -d '"')

if [ "$CURRENT_BIND" = "127.0.0.1" ]; then
    echo -e "${GREEN}✓ RPC_BIND_ADDRESS already set to 127.0.0.1 (local access only)${NC}"
elif [ "$CURRENT_BIND" = "0.0.0.0" ]; then
    echo "Updating RPC_BIND_ADDRESS from 0.0.0.0 to 127.0.0.1"
    sed -i 's/^RPC_BIND_ADDRESS="0\.0\.0\.0"/RPC_BIND_ADDRESS="127.0.0.1"/' "$SCRIPT_DIR/config.env"
    echo -e "${GREEN}✓ Updated config.env${NC}"
else
    echo -e "${YELLOW}⚠ RPC_BIND_ADDRESS is set to: $CURRENT_BIND${NC}"
    read -p "Change to 127.0.0.1? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        sed -i "s/^RPC_BIND_ADDRESS=.*/RPC_BIND_ADDRESS=\"127.0.0.1\"/" "$SCRIPT_DIR/config.env"
        echo -e "${GREEN}✓ Updated config.env${NC}"
    fi
fi

# Step 2: Update start script if validator is already set up
if [ -f "$SCRIPT_DIR/start-validator.sh" ]; then
    echo ""
    echo -e "${YELLOW}[2/3] Updating start-validator.sh...${NC}"
    
    # Check if start-validator.sh uses hardcoded value
    if grep -q 'RPC_BIND_ADDRESS="0.0.0.0"' "$SCRIPT_DIR/start-validator.sh"; then
        # Backup existing script
        cp "$SCRIPT_DIR/start-validator.sh" "$SCRIPT_DIR/start-validator.sh.backup"
        echo "Backed up start-validator.sh to start-validator.sh.backup"
        
        # Update the hardcoded value
        sed -i 's/RPC_BIND_ADDRESS="0\.0\.0\.0"/RPC_BIND_ADDRESS="127.0.0.1"/' "$SCRIPT_DIR/start-validator.sh"
        echo -e "${GREEN}✓ Updated start-validator.sh${NC}"
    elif grep -q 'RPC_BIND_ADDRESS="127.0.0.1"' "$SCRIPT_DIR/start-validator.sh"; then
        echo -e "${GREEN}✓ start-validator.sh already configured for local access${NC}"
    elif grep -q 'source.*config.env' "$SCRIPT_DIR/start-validator.sh" || grep -q 'config.env' "$SCRIPT_DIR/start-validator.sh"; then
        echo -e "${GREEN}✓ start-validator.sh uses config.env (will use updated value)${NC}"
    else
        echo -e "${YELLOW}⚠ start-validator.sh may need manual update${NC}"
    fi
else
    echo ""
    echo -e "${YELLOW}[2/3] Validator not set up yet. Run ./setup-validator.sh first.${NC}"
fi

# Step 3: Display configuration summary and next steps
echo ""
echo -e "${YELLOW}[3/3] Configuration Summary${NC}"
echo ""
echo -e "${GREEN}✓ RPC configured for local access only (127.0.0.1)${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "1. Restart validator to apply changes:"
echo "   ./stop-validator.sh"
echo "   ./start-validator-tmux.sh"
echo "   # OR for production:"
echo "   sudo systemctl restart solana-validator"
echo ""
echo "2. Test RPC endpoint locally:"
echo "   curl -X POST http://127.0.0.1:8899 \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getHealth\"}'"
echo ""
echo -e "${GREEN}✓ Security: RPC is now only accessible from localhost${NC}"
echo ""
echo -e "${GREEN}=========================================="
echo "Configuration Complete!"
echo "==========================================${NC}"
echo ""
echo "RPC endpoint will be accessible at: http://127.0.0.1:8899 (localhost only)"
echo ""
echo "To enable public access, run: ./configure-rpc-public.sh"
echo ""

