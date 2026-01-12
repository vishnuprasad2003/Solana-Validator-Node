#!/bin/bash
#
# Generate Keypairs for Validator
# Helper script to generate identity, vote, and stake keypairs
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Parse arguments
NODE_NAME="${1:-}"
KEY_TYPE="${2:-all}"  # Options: identity, vote, stake, all

if [[ -z "$NODE_NAME" ]] && [[ "$KEY_TYPE" != "faucet" ]]; then
    log_error "Usage: $0 <node-name> [identity|vote|stake|all]"
    log_info "Example: $0 validator-1 all"
    log_info "Example: $0 faucet faucet"
    exit 1
fi

# Determine key paths
case "$KEY_TYPE" in
    identity)
        KEY_PATH="${IDENTITY_KEY_DIR}/${NODE_NAME}-identity.json"
        ;;
    vote)
        KEY_PATH="${VOTE_KEY_DIR}/${NODE_NAME}-vote.json"
        ;;
    stake)
        KEY_PATH="${STAKE_KEY_DIR}/${NODE_NAME}-stake.json"
        ;;
    faucet)
        KEY_PATH="${IDENTITY_KEY_DIR}/faucet.json"
        NODE_NAME="faucet"
        ;;
    all)
        # Generate all keys
        log_info "Generating all keypairs for: $NODE_NAME"
        generate_keypair "${IDENTITY_KEY_DIR}/${NODE_NAME}-identity.json" "identity" || exit 1
        generate_keypair "${VOTE_KEY_DIR}/${NODE_NAME}-vote.json" "vote" || exit 1
        generate_keypair "${STAKE_KEY_DIR}/${NODE_NAME}-stake.json" "stake" || exit 1
        
        log_success "All keypairs generated for: $NODE_NAME"
        log_info ""
        log_info "Public keys:"
        log_info "  Identity: $(get_pubkey "${IDENTITY_KEY_DIR}/${NODE_NAME}-identity.json")"
        log_info "  Vote: $(get_pubkey "${VOTE_KEY_DIR}/${NODE_NAME}-vote.json")"
        log_info "  Stake: $(get_pubkey "${STAKE_KEY_DIR}/${NODE_NAME}-stake.json")"
        exit 0
        ;;
    *)
        log_error "Invalid key type: $KEY_TYPE"
        log_info "Valid types: identity, vote, stake, all, faucet"
        exit 1
        ;;
esac

# Generate single keypair
generate_keypair "$KEY_PATH" "$KEY_TYPE" || exit 1

log_success "Keypair generated: $KEY_PATH"
log_info "Public key: $(get_pubkey "$KEY_PATH")"
