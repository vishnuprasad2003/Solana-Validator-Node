#!/bin/bash
# Create vote account for validator
# Usage: ./scripts/create-vote-account.sh <node-name> [rpc-url]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

NODE_NAME="${1:-}"
RPC_URL="${2:-http://localhost:8899}"

if [[ -z "$NODE_NAME" ]]; then
    log_error "Usage: $0 <node-name> [rpc-url]"
    exit 1
fi

CONFIG_PATH="${WORKSPACE_ROOT}/configs/${NODE_NAME}.conf"
if [[ ! -f "$CONFIG_PATH" ]]; then
    log_error "Config file not found: $CONFIG_PATH"
    exit 1
fi

source "$CONFIG_PATH"

if [[ "$NODE_TYPE" == "bootstrap" ]]; then
    log_info "Bootstrap validators have vote accounts created during genesis"
    exit 0
fi

# Resolve paths (supports absolute paths like /solana/...)
IDENTITY_PATH=$(resolve_path "$IDENTITY_KEY")
VOTE_PATH=$(resolve_path "$VOTE_KEY")
# Faucet key location - try absolute first, then relative
if [[ -f "/solana/keys/faucet.json" ]]; then
    FAUCET_KEY="/solana/keys/faucet.json"
else
    FAUCET_KEY=$(resolve_path "keys/faucet.json")
fi

# Check if vote account already exists
VOTE_PUBKEY=$(get_pubkey "$VOTE_PATH" 2>/dev/null || echo "")
if [[ -n "$VOTE_PUBKEY" ]]; then
    if solana vote-account "$VOTE_PUBKEY" --url "$RPC_URL" >/dev/null 2>&1; then
        log_info "Vote account already exists: $VOTE_PUBKEY"
        exit 0
    fi
fi

log_info "Creating vote account for: $NODE_NAME"
log_info "RPC URL: $RPC_URL"

# Check RPC is available
if ! curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' >/dev/null 2>&1; then
    log_error "Cannot connect to RPC: $RPC_URL"
    exit 1
fi

# Get identity pubkey
IDENTITY_PUBKEY=$(get_pubkey "$IDENTITY_PATH")

# Fund identity if needed
IDENTITY_BALANCE=$(solana balance "$IDENTITY_PUBKEY" --url "$RPC_URL" 2>/dev/null | grep -o '[0-9.]* SOL' | head -1 || echo "0 SOL")
log_info "Identity balance: $IDENTITY_BALANCE"

# Create vote account (use identity as withdrawer with unsafe flag for private cluster)
log_info "Creating vote account..."
log_info "Vote keypair: $VOTE_PATH"
log_info "Identity keypair: $IDENTITY_PATH"
log_info "Withdrawer pubkey: $IDENTITY_PUBKEY"

# Use absolute paths and ensure they exist
[[ ! -f "$VOTE_PATH" ]] && { log_error "Vote keypair not found: $VOTE_PATH"; exit 1; }
[[ ! -f "$IDENTITY_PATH" ]] && { log_error "Identity keypair not found: $IDENTITY_PATH"; exit 1; }
[[ ! -f "$FAUCET_KEY" ]] && { log_error "Faucet keypair not found: $FAUCET_KEY"; exit 1; }

# Create temporary directory without spaces for keypairs (Solana CLI has issues with spaces in paths)
TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

# Copy keypairs to temp directory (without spaces in path)
cp "$VOTE_PATH" "$TEMP_DIR/vote.json"
cp "$IDENTITY_PATH" "$TEMP_DIR/identity.json"
cp "$FAUCET_KEY" "$TEMP_DIR/faucet.json"

# Change to temp directory to avoid path issues
cd "$TEMP_DIR"

log_info "Using temporary keypairs in: $TEMP_DIR"
solana create-vote-account \
    "$TEMP_DIR/vote.json" \
    "$TEMP_DIR/identity.json" \
    "$IDENTITY_PUBKEY" \
    --allow-unsafe-authorized-withdrawer \
    --fee-payer "$TEMP_DIR/faucet.json" \
    --url "$RPC_URL" || {
    log_error "Failed to create vote account"
    exit 1
}

log_success "Vote account created: $VOTE_PUBKEY"
