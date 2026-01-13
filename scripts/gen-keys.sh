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

generate_keypair "${WORKSPACE_ROOT}/${IDENTITY_KEY}"
generate_keypair "${WORKSPACE_ROOT}/${VOTE_KEY}"
generate_keypair "${WORKSPACE_ROOT}/${STAKE_KEY}"

log_success "Keys generated!"
log_info "Identity: $(get_pubkey "${WORKSPACE_ROOT}/${IDENTITY_KEY}")"
log_info "Vote: $(get_pubkey "${WORKSPACE_ROOT}/${VOTE_KEY}")"
