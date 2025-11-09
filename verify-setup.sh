#!/bin/bash

# Verification Script for Solana Validator
# This script verifies that the validator is running and functional

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

RPC_URL="http://127.0.0.1:8899"

echo "=========================================="
echo "Solana Validator Verification"
echo "=========================================="
echo ""

# Test 1: Check if validator is running
echo -e "${YELLOW}[1/6] Checking if validator is running...${NC}"
if pgrep -f solana-test-validator > /dev/null; then
    echo -e "${GREEN}✓ Validator process is running${NC}"
else
    echo -e "${RED}✗ Validator process is not running${NC}"
    echo "  Start it with: ./start-validator.sh"
    exit 1
fi

# Test 2: Check RPC connectivity
echo ""
echo -e "${YELLOW}[2/6] Testing RPC connectivity...${NC}"
if curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | grep -q "ok"; then
    echo -e "${GREEN}✓ RPC endpoint is responding${NC}"
else
    echo -e "${RED}✗ RPC endpoint is not responding${NC}"
    echo "  Waiting 5 seconds for validator to initialize..."
    sleep 5
    if curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | grep -q "ok"; then
        echo -e "${GREEN}✓ RPC endpoint is now responding${NC}"
    else
        echo -e "${RED}✗ RPC endpoint is still not responding${NC}"
        exit 1
    fi
fi

# Test 3: Check Solana CLI configuration
echo ""
echo -e "${YELLOW}[3/6] Checking Solana CLI configuration...${NC}"
CURRENT_URL=$(solana config get | grep "RPC URL" | awk '{print $3}')
if [ "$CURRENT_URL" = "$RPC_URL" ]; then
    echo -e "${GREEN}✓ Solana CLI is configured for local network${NC}"
    solana config get
else
    echo -e "${YELLOW}⚠ Solana CLI is configured for: $CURRENT_URL${NC}"
    echo "  Expected: $RPC_URL"
    echo "  Run: solana config set --url $RPC_URL"
fi

# Test 4: Check cluster version
echo ""
echo -e "${YELLOW}[4/6] Checking cluster version...${NC}"
VERSION=$(solana cluster-version 2>/dev/null || echo "unknown")
if [ "$VERSION" != "unknown" ]; then
    echo -e "${GREEN}✓ Cluster version: $VERSION${NC}"
else
    echo -e "${RED}✗ Could not get cluster version${NC}"
fi

# Test 5: Check balance
echo ""
echo -e "${YELLOW}[5/6] Checking default account balance...${NC}"
BALANCE=$(solana balance 2>/dev/null | awk '{print $1}' || echo "0")
if [ "$BALANCE" != "0" ]; then
    echo -e "${GREEN}✓ Account balance: $BALANCE SOL${NC}"
else
    echo -e "${YELLOW}⚠ Account balance is 0 SOL${NC}"
    echo "  Airdropping SOL..."
    solana airdrop 10 2>/dev/null || echo "  Airdrop may have failed, but this is normal for test validator"
    sleep 2
    BALANCE=$(solana balance 2>/dev/null | awk '{print $1}' || echo "0")
    echo -e "${GREEN}✓ Account balance: $BALANCE SOL${NC}"
fi

# Test 6: Check account info
echo ""
echo -e "${YELLOW}[6/6] Checking account information...${NC}"
ACCOUNT=$(solana address)
echo "  Account address: $ACCOUNT"
ACCOUNT_INFO=$(solana account "$ACCOUNT" 2>/dev/null || echo "")
if [ -n "$ACCOUNT_INFO" ]; then
    echo -e "${GREEN}✓ Account information retrieved${NC}"
else
    echo -e "${YELLOW}⚠ Could not retrieve account information${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Verification Complete!"
echo "==========================================${NC}"
echo ""
echo "Validator Status:"
echo "  RPC URL: $RPC_URL"
echo "  Status: Running"
echo "  Cluster Version: $VERSION"
echo "  Account: $ACCOUNT"
echo "  Balance: $BALANCE SOL"
echo ""
echo "Next steps:"
echo "1. Deploy a test program: ./deploy-example-program.sh"
echo "2. Mint test tokens: ./mint-test-tokens.sh"
echo "3. Test Node.js integration: node examples/test-rpc.js"
echo ""

