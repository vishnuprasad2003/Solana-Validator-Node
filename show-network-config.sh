#!/bin/bash

# Show Solana Network Configuration and Version Information
# Displays current Solana version, network settings, and program compatibility

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Solana Network Configuration"
echo "=========================================="
echo ""

# Load configuration
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
else
    echo -e "${RED}Error: config.env not found${NC}"
    exit 1
fi

# Ensure Solana is in PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Check if validator is running
VALIDATOR_RUNNING=false
if pgrep -f solana-test-validator > /dev/null; then
    VALIDATOR_RUNNING=true
    RPC_URL="http://127.0.0.1:$RPC_PORT"
else
    RPC_URL="http://127.0.0.1:$RPC_PORT (validator not running)"
fi

# Display Solana Version
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Solana CLI Version${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if command -v solana &> /dev/null; then
    SOLANA_VERSION_OUTPUT=$(solana --version 2>/dev/null | head -1 || echo "Unknown")
    SOLANA_VERSION_NUM=$(echo "$SOLANA_VERSION_OUTPUT" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo -e "  Version: ${GREEN}$SOLANA_VERSION_OUTPUT${NC}"
    if [ -n "$SOLANA_VERSION_NUM" ]; then
        echo -e "  Version Number: ${GREEN}$SOLANA_VERSION_NUM${NC}"
    fi
else
    echo -e "  Version: ${YELLOW}Not installed${NC}"
fi
echo ""

# Display Rust Version
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Rust Version${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if command -v rustc &> /dev/null; then
    RUST_VERSION=$(rustc --version 2>/dev/null | head -1 || echo "Unknown")
    echo -e "  Version: ${GREEN}$RUST_VERSION${NC}"
else
    echo -e "  Version: ${YELLOW}Not installed${NC}"
fi
echo ""

# Display Anchor Version
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Anchor Framework Version${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if command -v anchor &> /dev/null; then
    ANCHOR_VERSION=$(anchor --version 2>/dev/null | head -1 || echo "Unknown")
    echo -e "  Version: ${GREEN}$ANCHOR_VERSION${NC}"
else
    echo -e "  Version: ${YELLOW}Not installed${NC}"
fi
echo ""

# Display Network Configuration
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Network Configuration${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  RPC Port: ${GREEN}$RPC_PORT${NC}"
echo -e "  Faucet Port: ${GREEN}$FAUCET_PORT${NC}"
echo -e "  Gossip Port: ${GREEN}$GOSSIP_PORT${NC}"
echo -e "  RPC Bind Address: ${GREEN}$RPC_BIND_ADDRESS${NC}"
echo -e "  Ledger Directory: ${GREEN}$LEDGER_DIR${NC}"
echo -e "  Log Level: ${GREEN}$LOG_LEVEL${NC}"
echo ""

# Display RPC Endpoints
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}RPC Endpoints${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Main RPC: ${GREEN}http://127.0.0.1:$RPC_PORT${NC}"
echo -e "  WebSocket: ${GREEN}ws://127.0.0.1:$RPC_PORT${NC}"
echo -e "  Faucet: ${GREEN}http://127.0.0.1:$FAUCET_PORT${NC}"
if [ "$VALIDATOR_RUNNING" = true ]; then
    PUBLIC_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1")
    echo -e "  Remote RPC: ${GREEN}http://$PUBLIC_IP:$RPC_PORT${NC}"
fi
echo ""

# Display Validator Configuration
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Validator Configuration${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Limit Ledger Size: ${GREEN}$LIMIT_LEDGER_SIZE${NC}"
echo -e "  Reset on Start: ${GREEN}$RESET_ON_START${NC}"
echo ""

# Display Program Configuration
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Program Configuration${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Metaplex Program ID: ${GREEN}$METADATA_PROGRAM_ID${NC}"
echo -e "  Programs Directory: ${GREEN}$PROGRAMS_DIR${NC}"
if [ -f "$METADATA_PROGRAM_FILE" ]; then
    echo -e "  Metaplex Program: ${GREEN}Installed${NC}"
    echo -e "    Location: ${GREEN}$METADATA_PROGRAM_FILE${NC}"
else
    echo -e "  Metaplex Program: ${YELLOW}Not found${NC}"
    echo -e "    Run: ${YELLOW}./download-metaplex-program.sh${NC}"
fi
echo ""

# Display Program Compatibility
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Program Compatibility${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

VERSION_COMPATIBILITY_FILE="$SCRIPT_DIR/VERSION_COMPATIBILITY.md"
if [ -f "$VERSION_COMPATIBILITY_FILE" ]; then
    # Extract current version from VERSION_COMPATIBILITY.md
    CURRENT_VERSION=$(grep "^## Current Version:" "$VERSION_COMPATIBILITY_FILE" | sed 's/## Current Version: //')
    
    if [ -n "$CURRENT_VERSION" ]; then
        echo -e "  Solana Version: ${GREEN}$CURRENT_VERSION${NC}"
    fi
    
    # Extract Anchor version
    ANCHOR_COMPAT=$(grep -A 1 "### Anchor Framework Version" "$VERSION_COMPATIBILITY_FILE" | grep "Current Version" | sed 's/.*: //' || echo "")
    if [ -n "$ANCHOR_COMPAT" ]; then
        echo -e "  Anchor Version: ${GREEN}$ANCHOR_COMPAT${NC}"
    fi
    
    # Extract Token Program info
    TOKEN_PROGRAM=$(grep -A 2 "### Program Compatibility" "$VERSION_COMPATIBILITY_FILE" | grep "Token Program" | sed 's/.*: //' || echo "")
    if [ -n "$TOKEN_PROGRAM" ]; then
        echo -e "  Token Programs: ${GREEN}$TOKEN_PROGRAM${NC}"
    fi
else
    echo -e "  ${YELLOW}VERSION_COMPATIBILITY.md not found${NC}"
fi
echo ""

# Display Validator Status
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Validator Status${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$VALIDATOR_RUNNING" = true ]; then
    PID=$(pgrep -f solana-test-validator | head -1)
    echo -e "  Status: ${GREEN}Running${NC}"
    echo -e "  Process ID: ${GREEN}$PID${NC}"
    
    # Try to get validator info
    if command -v solana &> /dev/null; then
        VALIDATOR_INFO=$(solana cluster-version --url http://127.0.0.1:$RPC_PORT 2>/dev/null || echo "")
        if [ -n "$VALIDATOR_INFO" ]; then
            echo -e "  Cluster Version: ${GREEN}$VALIDATOR_INFO${NC}"
        fi
    fi
else
    echo -e "  Status: ${RED}Not Running${NC}"
    echo -e "  ${YELLOW}Start validator with: ./start-validator-tmux.sh${NC}"
fi
echo ""

# Display Quick Reference
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Quick Reference${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Config File: ${GREEN}$SCRIPT_DIR/config.env${NC}"
echo -e "  Compatibility Guide: ${GREEN}$SCRIPT_DIR/VERSION_COMPATIBILITY.md${NC}"
echo -e "  Deployment Guide: ${GREEN}$SCRIPT_DIR/README.md${NC}"
echo ""

echo -e "${GREEN}=========================================="
echo "Configuration Display Complete"
echo "==========================================${NC}"
echo ""

