#!/usr/bin/env bash
#
# Solana Validator Node - Airdrop Script
# Airdrops SOL from local validator node to specified pubkey address
#

set -euo pipefail

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load common library
# shellcheck source=common.sh
if ! source "$SCRIPT_DIR/common.sh"; then
    echo "Error: Failed to load common library" >&2
    exit 1
fi

# Initialize common library
init_common

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Load configuration
if ! safe_source "$REPO_ROOT/configs/config.env"; then
    echo -e "${RED}Error: config.env not found${NC}" >&2
    exit 1
fi

# Ensure Solana is in PATH
add_to_path "$HOME/.local/share/solana/install/active_release/bin"
add_to_path "$HOME/.cargo/bin"

# Check if Solana CLI is available
if ! command_exists solana; then
    echo -e "${RED}Error: Solana CLI not found. Please run ./scripts/install.sh first${NC}" >&2
    exit 1
fi

# Detect RPC endpoint
if [ "$RPC_BIND_ADDRESS" = "0.0.0.0" ]; then
    RPC_ENDPOINT="http://127.0.0.1:$RPC_PORT"
else
    RPC_ENDPOINT="http://$RPC_BIND_ADDRESS:$RPC_PORT"
fi

# Function to check if validator is running
check_validator_running() {
    if ! curl -s -X POST "$RPC_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' > /dev/null 2>&1; then
        return 1
    fi
    return 0
}

# Function to validate pubkey address
validate_pubkey() {
    local pubkey="$1"
    # Solana pubkeys are base58 encoded and typically 32-44 characters
    if [ ${#pubkey} -lt 32 ] || [ ${#pubkey} -gt 44 ]; then
        return 1
    fi
    # Check if it contains only base58 characters (alphanumeric except 0, O, I, l)
    if ! echo "$pubkey" | grep -qE '^[1-9A-HJ-NP-Za-km-z]+$'; then
        return 1
    fi
    return 0
}

# Function to validate SOL amount
validate_amount() {
    local amount="$1"
    # Check if amount is a positive number (integer or decimal)
    if ! echo "$amount" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
        return 1
    fi
    # Check if amount is greater than 0 (simple string comparison for common cases)
    # Convert to integer part for comparison
    local int_part="${amount%%.*}"
    if [ -z "$int_part" ] || [ "$int_part" = "0" ]; then
        # Check decimal part
        local dec_part="${amount#*.}"
        if [ -z "$dec_part" ] || [ "$dec_part" = "0" ]; then
            return 1
        fi
    fi
    return 0
}

# Function to airdrop SOL
airdrop_sol() {
    local pubkey_address="$1"
    local amount="$2"
    
    echo ""
    echo "=========================================="
    echo "Solana Airdrop"
    echo "=========================================="
    echo ""
    echo -e "${BLUE}[INFO]${NC} Pubkey Address: ${GREEN}$pubkey_address${NC}"
    echo -e "${BLUE}[INFO]${NC} Amount: ${GREEN}$amount SOL${NC}"
    echo -e "${BLUE}[INFO]${NC} RPC Endpoint: $RPC_ENDPOINT"
    echo ""
    
    # Configure Solana CLI to use local validator
    solana config set --url "$RPC_ENDPOINT" > /dev/null 2>&1
    
    # Perform airdrop
    echo -e "${BLUE}[INFO]${NC} Executing airdrop..."
    if solana airdrop "$amount" "$pubkey_address" --url "$RPC_ENDPOINT" 2>&1; then
        echo ""
        echo -e "${GREEN}[SUCCESS]${NC} Successfully airdropped $amount SOL to $pubkey_address"
        echo ""
        
        # Check balance
        echo -e "${BLUE}[INFO]${NC} Checking balance..."
        BALANCE=$(solana balance "$pubkey_address" --url "$RPC_ENDPOINT" 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "0")
        echo -e "${GREEN}[SUCCESS]${NC} Current balance: ${GREEN}$BALANCE SOL${NC}"
        echo ""
        return 0
    else
        echo ""
        echo -e "${RED}[ERROR]${NC} Airdrop failed"
        echo ""
        return 1
    fi
}

# Main script
if [ $# -lt 2 ]; then
    echo "=========================================="
    echo "Solana Airdrop Script"
    echo "=========================================="
    echo ""
    echo "Usage: $0 <pubkey_address> <amount_in_sol>"
    echo ""
    echo "Arguments:"
    echo "  pubkey_address  - Solana pubkey address (base58 encoded)"
    echo "  amount_in_sol   - Amount of SOL to airdrop (e.g., 1, 10, 100)"
    echo ""
    echo "Examples:"
    echo "  $0 5s37kNok43yPZZk3iUGBZME4UNFPuDTrHyiFDTnVNcR7 1"
    echo "  $0 5s37kNok43yPZZk3iUGBZME4UNFPuDTrHyiFDTnVNcR7 10"
    echo "  $0 5s37kNok43yPZZk3iUGBZME4UNFPuDTrHyiFDTnVNcR7 100.5"
    echo ""
    exit 1
fi

PUBKEY_ADDRESS="$1"
AMOUNT="$2"

# Validate pubkey address format
if ! validate_pubkey "$PUBKEY_ADDRESS"; then
    echo -e "${RED}[ERROR]${NC} Invalid pubkey address format" >&2
    echo -e "${YELLOW}[HINT]${NC} Solana pubkeys are base58 encoded and 32-44 characters long" >&2
    echo -e "${YELLOW}[HINT]${NC} Example: 5s37kNok43yPZZk3iUGBZME4UNFPuDTrHyiFDTnVNcR7" >&2
    exit 1
fi

# Validate amount
if ! validate_amount "$AMOUNT"; then
    echo -e "${RED}[ERROR]${NC} Invalid SOL amount: $AMOUNT" >&2
    echo -e "${YELLOW}[HINT]${NC} Amount must be a positive number (e.g., 1, 10, 100.5)" >&2
    exit 1
fi

# Check if validator is running
echo -e "${BLUE}[INFO]${NC} Checking if validator is running..."
if ! check_validator_running; then
    echo -e "${RED}[ERROR]${NC} Validator is not running or not accessible at $RPC_ENDPOINT" >&2
    echo -e "${YELLOW}[HINT]${NC} Start your validator with: ./scripts/start-validator.sh" >&2
    exit 1
fi

echo -e "${GREEN}[SUCCESS]${NC} Validator is running and accessible"

# Perform airdrop
if airdrop_sol "$PUBKEY_ADDRESS" "$AMOUNT"; then
    echo "=========================================="
    echo -e "${GREEN}Airdrop Complete!${NC}"
    echo "=========================================="
    exit 0
else
    echo "=========================================="
    echo -e "${RED}Airdrop Failed!${NC}"
    echo "=========================================="
    exit 1
fi

