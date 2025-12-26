#!/bin/bash
# Start Solana Test Validator with Metaplex Token Metadata Program

set -euo pipefail

# Load configuration from config.env if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
fi

# Set defaults if not in config.env
LEDGER_DIR="${LEDGER_DIR:-$HOME/solana-local-ledger}"
RPC_PORT="${RPC_PORT:-8899}"
RPC_BIND_ADDRESS="${RPC_BIND_ADDRESS:-127.0.0.1}"
FAUCET_PORT="${FAUCET_PORT:-9900}"
PROGRAMS_DIR="${PROGRAMS_DIR:-$HOME/.local/share/solana-programs}"
METADATA_PROGRAM_ID="${METADATA_PROGRAM_ID:-metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s}"
METADATA_PROGRAM_FILE="${METADATA_PROGRAM_FILE:-$PROGRAMS_DIR/mpl-token-metadata.so}"

# Ensure Solana is in PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Check if Solana CLI is available
if ! command -v solana-test-validator &> /dev/null; then
    echo "Error: solana-test-validator not found in PATH"
    echo "Run ./install.sh to install Solana CLI"
    exit 1
fi

# Check port availability
if command -v lsof &> /dev/null; then
    if lsof -i :$RPC_PORT >/dev/null 2>&1; then
        echo "Warning: Port $RPC_PORT is already in use"
        echo "Run ./stop-validator.sh to stop existing validator"
        exit 1
    fi
fi

# Detect public IP for display
PUBLIC_IP=$(curl -s --max-time 2 https://api.ipify.org 2>/dev/null || echo "")

echo "=========================================="
echo "Starting Solana Test Validator"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  RPC Endpoint (binding): http://$RPC_BIND_ADDRESS:$RPC_PORT"
if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "$RPC_BIND_ADDRESS" ]; then
    echo "  Public Access (USE THIS): http://$PUBLIC_IP:$RPC_PORT"
    echo ""
    echo "  For reqbin.com / Postman Web:"
    echo "    http://$PUBLIC_IP:$RPC_PORT"
fi
echo "  Faucet Port:      $FAUCET_PORT"
echo "  Ledger Directory: $LEDGER_DIR"
echo ""

# Ensure ledger directory exists
mkdir -p "$LEDGER_DIR"

# Build validator command
VALIDATOR_CMD="solana-test-validator \
    --ledger \"$LEDGER_DIR\" \
    --reset \
    --rpc-port $RPC_PORT \
    --bind-address $RPC_BIND_ADDRESS \
    --faucet-port $FAUCET_PORT \
    --quiet \
    --limit-ledger-size"

# Add Metaplex Token Metadata program if it exists
if [ -f "$METADATA_PROGRAM_FILE" ]; then
    echo "✓ Including Metaplex Token Metadata Program"
    VALIDATOR_CMD="$VALIDATOR_CMD --bpf-program $METADATA_PROGRAM_ID $METADATA_PROGRAM_FILE"
else
    echo "⚠ Metaplex Token Metadata program not found"
    echo "  Run: scripts/download-metaplex-program.sh"
fi

echo ""
echo "Starting validator..."

# Execute validator command
eval "$VALIDATOR_CMD"
