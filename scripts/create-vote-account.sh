#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Create a vote account for a validator node
# Usage: ./scripts/create-vote-account.sh <config-file> [rpc-url]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
source "$(dirname "$0")/common.sh"

CONFIG="${1:?Usage: $0 <config-file> [rpc-url]}"
RPC_URL="${2:-http://localhost:8899}"
[[ ! -f "$CONFIG" ]] && { log_error "Config not found: $CONFIG"; exit 1; }
source "$CONFIG"

[[ "$NODE_TYPE" == "bootstrap" ]] && { log_info "Bootstrap vote account is created during genesis"; exit 0; }

[[ ! -f "$IDENTITY_KEY" ]] && { log_error "Identity key not found: $IDENTITY_KEY"; exit 1; }
[[ ! -f "$VOTE_KEY" ]]     && { log_error "Vote key not found: $VOTE_KEY"; exit 1; }
[[ ! -f "$FAUCET_KEY" ]]   && { log_error "Faucet key not found: $FAUCET_KEY"; exit 1; }

VOTE_PUBKEY=$(get_pubkey "$VOTE_KEY" 2>/dev/null || echo "")
if [[ -n "$VOTE_PUBKEY" ]] && solana vote-account "$VOTE_PUBKEY" --url "$RPC_URL" >/dev/null 2>&1; then
    log_info "Vote account already exists: $VOTE_PUBKEY"; exit 0
    fi

IDENTITY_PUBKEY=$(get_pubkey "$IDENTITY_KEY")
log_info "Creating vote account for: $NODE_NAME"
log_info "RPC: $RPC_URL"

# Use temp dir for keypairs (Solana CLI has issues with spaces in paths)
TEMP_DIR=$(mktemp -d); trap "rm -rf '$TEMP_DIR'" EXIT
cp "$VOTE_KEY" "$TEMP_DIR/vote.json"
cp "$IDENTITY_KEY" "$TEMP_DIR/identity.json"
cp "$FAUCET_KEY" "$TEMP_DIR/faucet.json"

solana create-vote-account \
    "$TEMP_DIR/vote.json" "$TEMP_DIR/identity.json" "$IDENTITY_PUBKEY" \
    --allow-unsafe-authorized-withdrawer \
    --fee-payer "$TEMP_DIR/faucet.json" \
    --url "$RPC_URL" || { log_error "Failed to create vote account"; exit 1; }

log_success "Vote account created: $VOTE_PUBKEY"
