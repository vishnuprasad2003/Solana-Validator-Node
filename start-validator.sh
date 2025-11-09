#!/bin/bash
# Start Solana Test Validator with Metaplex Token Metadata Program

LEDGER_DIR="$HOME/solana-local-ledger"
RPC_PORT=8899
RPC_BIND_ADDRESS="0.0.0.0"
FAUCET_PORT=9900
PROGRAMS_DIR="$HOME/.local/share/solana-programs"
METADATA_PROGRAM_ID="metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
METADATA_PROGRAM_FILE="$PROGRAMS_DIR/mpl-token-metadata.so"

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

echo "Starting Solana test validator..."
echo "  RPC: http://$RPC_BIND_ADDRESS:$RPC_PORT"
echo "  Ledger: $LEDGER_DIR"
echo ""

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
    echo "  Including: Metaplex Token Metadata Program"
    VALIDATOR_CMD="$VALIDATOR_CMD --bpf-program $METADATA_PROGRAM_ID $METADATA_PROGRAM_FILE"
else
    echo "  ⚠ Metaplex Token Metadata program not found at: $METADATA_PROGRAM_FILE"
    echo "     Run ./download-metaplex-program.sh to download it"
fi

echo ""

# Execute validator command
eval $VALIDATOR_CMD
