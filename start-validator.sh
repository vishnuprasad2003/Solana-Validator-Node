#!/bin/bash
# Start Solana Test Validator

LEDGER_DIR="$HOME/solana-local-ledger"
RPC_PORT=8899
RPC_BIND_ADDRESS="0.0.0.0"
FAUCET_PORT=9900

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

echo "Starting Solana test validator..."
echo "  RPC: http://$RPC_BIND_ADDRESS:$RPC_PORT"
echo "  Ledger: $LEDGER_DIR"
echo ""

solana-test-validator \
    --ledger "$LEDGER_DIR" \
    --reset \
    --rpc-port "$RPC_PORT" \
    --bind-address "$RPC_BIND_ADDRESS" \
    --faucet-port "$FAUCET_PORT" \
    --quiet \
    --limit-ledger-size
