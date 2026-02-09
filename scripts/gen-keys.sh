#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Generate keypairs for a validator node
# Usage: ./scripts/gen-keys.sh <config-file>
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
source "$(dirname "$0")/common.sh"

CONFIG="${1:?Usage: $0 <config-file>}"
[[ ! -f "$CONFIG" ]] && { log_error "Config not found: $CONFIG"; exit 1; }
source "$CONFIG"
ensure_dirs

log_info "Generating keys for: $NODE_NAME"

generate_keypair "$IDENTITY_KEY"
generate_keypair "$VOTE_KEY"
generate_keypair "$STAKE_KEY"

log_success "Keys generated"
log_info "Identity: $(get_pubkey "$IDENTITY_KEY")"
log_info "Vote:     $(get_pubkey "$VOTE_KEY")"
