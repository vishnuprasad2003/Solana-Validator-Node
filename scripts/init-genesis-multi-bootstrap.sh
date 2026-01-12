#!/bin/bash
#
# Initialize Genesis with Multiple Bootstrap Validators
# This creates a genesis with both bootstrap and validator-1 as bootstrap validators
# This allows both to start from genesis without needing snapshots
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source common.sh with error handling
set +u  # Temporarily allow unset variables for sourcing
source "${SCRIPT_DIR}/common.sh"
set -u  # Re-enable strict mode

log_info "Initializing Genesis with Multiple Bootstrap Validators"
log_info "This will create a genesis with bootstrap + validator-1 as bootstrap validators"

# Check if validator-1 keys exist
VALIDATOR_1_IDENTITY_KEY="${IDENTITY_KEY_DIR}/validator-1-identity.json"
VALIDATOR_1_VOTE_KEY="${VOTE_KEY_DIR}/validator-1-vote.json"
VALIDATOR_1_STAKE_KEY="${STAKE_KEY_DIR}/validator-1-stake.json"

if [[ ! -f "$VALIDATOR_1_IDENTITY_KEY" ]] || [[ ! -f "$VALIDATOR_1_VOTE_KEY" ]] || [[ ! -f "$VALIDATOR_1_STAKE_KEY" ]]; then
    log_info "Generating validator-1 keys..."
    ./scripts/gen-keys.sh validator-1 all || {
        log_error "Failed to generate validator-1 keys"
        exit 1
    }
fi

# Define bootstrap key paths (from cluster.conf or defaults)
BOOTSTRAP_IDENTITY_KEY="${BOOTSTRAP_IDENTITY_KEY:-${IDENTITY_KEY_DIR}/bootstrap-identity.json}"
BOOTSTRAP_VOTE_KEY="${BOOTSTRAP_VOTE_KEY:-${VOTE_KEY_DIR}/bootstrap-vote.json}"
BOOTSTRAP_STAKE_KEY="${BOOTSTRAP_STAKE_KEY:-${STAKE_KEY_DIR}/bootstrap-stake.json}"
FAUCET_KEY="${FAUCET_KEY:-${IDENTITY_KEY_DIR}/faucet.json}"

# Get public keys
BOOTSTRAP_IDENTITY_PUBKEY=$(get_pubkey "$BOOTSTRAP_IDENTITY_KEY") || exit 1
BOOTSTRAP_VOTE_PUBKEY=$(get_pubkey "$BOOTSTRAP_VOTE_KEY") || exit 1
BOOTSTRAP_STAKE_PUBKEY=$(get_pubkey "$BOOTSTRAP_STAKE_KEY") || exit 1

VALIDATOR_1_IDENTITY_PUBKEY=$(get_pubkey "$VALIDATOR_1_IDENTITY_KEY") || exit 1
VALIDATOR_1_VOTE_PUBKEY=$(get_pubkey "$VALIDATOR_1_VOTE_KEY") || exit 1
VALIDATOR_1_STAKE_PUBKEY=$(get_pubkey "$VALIDATOR_1_STAKE_KEY") || exit 1

FAUCET_PUBKEY=$(get_pubkey "$FAUCET_KEY") || exit 1

log_info "Bootstrap Identity: $BOOTSTRAP_IDENTITY_PUBKEY"
log_info "Bootstrap Vote: $BOOTSTRAP_VOTE_PUBKEY"
log_info "Validator-1 Identity: $VALIDATOR_1_IDENTITY_PUBKEY"
log_info "Validator-1 Vote: $VALIDATOR_1_VOTE_PUBKEY"
log_info "Faucet: $FAUCET_PUBKEY"

# Backup existing genesis if it exists
if [[ -f "${BOOTSTRAP_LEDGER_DIR}/genesis.bin" ]]; then
    log_warn "Existing genesis found. Backing up..."
    cp "${BOOTSTRAP_LEDGER_DIR}/genesis.bin" "${BOOTSTRAP_LEDGER_DIR}/genesis.bin.backup.$(date +%Y%m%d_%H%M%S)"
    rm -rf "${BOOTSTRAP_LEDGER_DIR}"
fi

# Create genesis with multiple bootstrap validators
log_info "Creating genesis with multiple bootstrap validators..."

GENESIS_ARGS=(
    --bootstrap-validator
    "${BOOTSTRAP_IDENTITY_PUBKEY}"
    "${BOOTSTRAP_VOTE_PUBKEY}"
    "${BOOTSTRAP_STAKE_PUBKEY}"
    --bootstrap-validator
    "${VALIDATOR_1_IDENTITY_PUBKEY}"
    "${VALIDATOR_1_VOTE_PUBKEY}"
    "${VALIDATOR_1_STAKE_PUBKEY}"
    --ledger
    "${BOOTSTRAP_LEDGER_DIR}"
    --faucet-pubkey
    "${FAUCET_PUBKEY}"
    --faucet-lamports
    "${FAUCET_LAMPORTS}"
    --cluster-type
    "${CLUSTER_TYPE}"
)

log_info "Running: solana-genesis ${GENESIS_ARGS[*]}"

solana-genesis "${GENESIS_ARGS[@]}" || {
    log_error "Failed to create genesis"
    exit 1
}

log_success "Genesis created successfully with multiple bootstrap validators!"

# Copy genesis to validator-1 ledger directory
log_info "Setting up validator-1 ledger..."
mkdir -p "${VALIDATOR_LEDGER_DIR}/validator-1"
cp "${BOOTSTRAP_LEDGER_DIR}/genesis.bin" "${VALIDATOR_LEDGER_DIR}/validator-1/genesis.bin"
log_success "Validator-1 ledger prepared"

log_info ""
log_info "Both validators can now start from genesis:"
log_info "1. Start bootstrap: make start-bootstrap"
log_info "2. Start validator-1: make start-validator NODE=validator-1"
log_info ""
log_info "Note: Both validators will start from slot 0 and produce blocks together"
log_info "      No entrypoint needed - both are bootstrap validators!"
