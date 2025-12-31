#!/bin/bash

LEDGER_DIR="$HOME/solana-local-ledger"
RPC_PORT=8899
RPC_BIND_ADDRESS="127.0.0.1"
FAUCET_PORT=9900
GOSSIP_PORT=8001
PROGRAMS_DIR="$HOME/.local/share/solana-programs"
METADATA_PROGRAM_ID="metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
METADATA_PROGRAM_FILE="$PROGRAMS_DIR/mpl-token-metadata.so"

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load config first (may override LEDGER_DIR)
[ -f "$REPO_ROOT/configs/config.env" ] && source "$REPO_ROOT/configs/config.env"

# Ensure LEDGER_DIR is set and create it
LEDGER_DIR="${LEDGER_DIR:-$HOME/solana-local-ledger}"
mkdir -p "$LEDGER_DIR" || { echo "Error: Failed to create ledger directory: $LEDGER_DIR"; exit 1; }

CLUSTER_MODE="${CLUSTER_MODE:-false}"
NODE_ROLE="${NODE_ROLE:-bootstrap}"
BOOTSTRAP_NODE="${BOOTSTRAP_NODE:-}"

echo "Starting Solana test validator..."
[ "$CLUSTER_MODE" = "true" ] && echo "  Mode: Cluster ($NODE_ROLE)" || echo "  Mode: Single node"
echo "  RPC: http://$RPC_BIND_ADDRESS:$RPC_PORT"
echo "  Ledger: $LEDGER_DIR"
echo ""

# Build command array (safer than string concatenation)
CMD_ARGS=(
    "solana-test-validator"
    "--ledger" "$LEDGER_DIR"
    "--reset"
    "--rpc-port" "$RPC_PORT"
    "--bind-address" "$RPC_BIND_ADDRESS"
    "--faucet-port" "$FAUCET_PORT"
    "--quiet"
    "--limit-ledger-size"
)

if [ "$CLUSTER_MODE" = "true" ]; then
    CMD_ARGS+=("--gossip-port" "$GOSSIP_PORT")
    [ "$NODE_ROLE" = "validator" ] && [ -n "$BOOTSTRAP_NODE" ] && CMD_ARGS+=("--known-validator" "$BOOTSTRAP_NODE")
fi

[ -f "$METADATA_PROGRAM_FILE" ] && CMD_ARGS+=("--bpf-program" "$METADATA_PROGRAM_ID" "$METADATA_PROGRAM_FILE") && echo "  ✓ Metaplex Token Metadata Program" || echo "  ⚠ Metaplex program not found"

echo ""
# Check if running under systemd
if [ -n "${INVOCATION_ID:-}" ] || systemd-detect-virt -q 2>/dev/null; then
    # Systemd will handle process management - exec replaces shell process
    exec "${CMD_ARGS[@]}"
else
    # Manual execution - run in background
    "${CMD_ARGS[@]}" > /dev/null 2>&1 &
    VALIDATOR_PID=$!
    echo "Validator started in background (PID: $VALIDATOR_PID)"
    echo "To stop: ./scripts/stop-validator.sh"
    echo "To force stop: ./scripts/stop-validator.sh --force"
fi
