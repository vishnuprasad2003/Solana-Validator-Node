#!/bin/bash
# Generate keypairs for a node
# Usage: ./scripts/gen-keys.sh [config-file]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

CONFIG="${1:-${WORKSPACE_ROOT}/configs/node.conf}"
[[ ! -f "$CONFIG" ]] && { log_error "Config not found: $CONFIG"; exit 1; }
source "$CONFIG"

log_info "Generating keys for: $NODE_NAME"

IDENTITY_KEY_RESOLVED=$(resolve_path "$IDENTITY_KEY")
VOTE_KEY_RESOLVED=$(resolve_path "$VOTE_KEY")
STAKE_KEY_RESOLVED=$(resolve_path "$STAKE_KEY")

generate_keypair "$IDENTITY_KEY_RESOLVED"
generate_keypair "$VOTE_KEY_RESOLVED"
generate_keypair "$STAKE_KEY_RESOLVED"

log_success "Keys generated!"
log_info "Identity: $(get_pubkey "$IDENTITY_KEY_RESOLVED")"
log_info "Vote: $(get_pubkey "$VOTE_KEY_RESOLVED")"
