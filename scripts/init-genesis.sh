#!/bin/bash
#
# Initialize Genesis for Private Solana Cluster
# This script creates the genesis configuration for the bootstrap validator
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Bootstrap validator key paths
BOOTSTRAP_IDENTITY_KEY="${IDENTITY_KEY_DIR}/bootstrap-identity.json"
BOOTSTRAP_VOTE_KEY="${VOTE_KEY_DIR}/bootstrap-vote.json"
BOOTSTRAP_STAKE_KEY="${STAKE_KEY_DIR}/bootstrap-stake.json"
FAUCET_KEY="${IDENTITY_KEY_DIR}/faucet.json"

# Genesis configuration
LEDGER_DIR="${BOOTSTRAP_LEDGER_DIR}"
CLUSTER_TYPE="${CLUSTER_TYPE:-development}"

log_info "Initializing Genesis for Private Solana Cluster"
log_info "Cluster type: $CLUSTER_TYPE"
log_info "Ledger directory: $LEDGER_DIR"

# Check if Agave tools are installed
if ! command_exists solana-genesis; then
    log_error "solana-genesis not found. Please run install.sh first."
    exit 1
fi

# Check if genesis already exists
if [[ -d "$LEDGER_DIR" ]] && [[ -f "${LEDGER_DIR}/genesis.bin" ]]; then
    log_warn "Genesis already exists at ${LEDGER_DIR}"
    read -p "Do you want to recreate genesis? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping genesis creation"
        exit 0
    fi
    log_info "Removing existing genesis..."
    rm -rf "$LEDGER_DIR"
fi

# Create necessary directories
check_directory "$LEDGER_DIR"
check_directory "$(dirname "$BOOTSTRAP_IDENTITY_KEY")"
check_directory "$(dirname "$BOOTSTRAP_VOTE_KEY")"
check_directory "$(dirname "$BOOTSTRAP_STAKE_KEY")"
check_directory "$(dirname "$FAUCET_KEY")"

# Generate keypairs if they don't exist
log_info "Generating keypairs for bootstrap validator..."

generate_keypair "$BOOTSTRAP_IDENTITY_KEY" "identity" || exit 1
generate_keypair "$BOOTSTRAP_VOTE_KEY" "vote" || exit 1
generate_keypair "$BOOTSTRAP_STAKE_KEY" "stake" || exit 1
generate_keypair "$FAUCET_KEY" "faucet" || exit 1

# Get public keys
BOOTSTRAP_IDENTITY_PUBKEY=$(get_pubkey "$BOOTSTRAP_IDENTITY_KEY") || exit 1
BOOTSTRAP_VOTE_PUBKEY=$(get_pubkey "$BOOTSTRAP_VOTE_KEY") || exit 1
BOOTSTRAP_STAKE_PUBKEY=$(get_pubkey "$BOOTSTRAP_STAKE_KEY") || exit 1
FAUCET_PUBKEY=$(get_pubkey "$FAUCET_KEY") || exit 1

log_info "Bootstrap Identity: $BOOTSTRAP_IDENTITY_PUBKEY"
log_info "Bootstrap Vote: $BOOTSTRAP_VOTE_PUBKEY"
log_info "Bootstrap Stake: $BOOTSTRAP_STAKE_PUBKEY"
log_info "Faucet: $FAUCET_PUBKEY"

# Setup essential programs (SPL Token, Token-2022, Associated Token, Metaplex)
log_info "Setting up essential programs for genesis..."
if [[ -f "${SCRIPT_DIR}/setup-genesis-programs.sh" ]]; then
    "${SCRIPT_DIR}/setup-genesis-programs.sh" || {
        log_warn "Failed to setup programs. Continuing without them..."
        log_warn "You can deploy programs manually after cluster starts."
    }
else
    log_warn "setup-genesis-programs.sh not found. Skipping program setup."
fi

# Create genesis
log_info "Creating genesis configuration..."

# Standard program IDs (from mainnet)
TOKEN_PROGRAM_ID="TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
TOKEN_2022_PROGRAM_ID="TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
ASSOCIATED_TOKEN_PROGRAM_ID="ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
TOKEN_METADATA_PROGRAM_ID="metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"

# BPF Loader for upgradeable programs
BPF_LOADER="BPFLoaderUpgradeab1e11111111111111111111111"

# Programs directory
PROGRAMS_DIR="${WORKSPACE_ROOT}/programs"

# Build solana-genesis command
# Note: bootstrap-validator expects: IDENTITY_PUBKEY VOTE_PUBKEY STAKE_PUBKEY (space-separated)
# Use array to properly handle paths with spaces
GENESIS_ARGS=(
    --bootstrap-validator
    "${BOOTSTRAP_IDENTITY_PUBKEY}"
    "${BOOTSTRAP_VOTE_PUBKEY}"
    "${BOOTSTRAP_STAKE_PUBKEY}"
    --ledger
    "${LEDGER_DIR}"
    --faucet-pubkey
    "${FAUCET_PUBKEY}"
    --faucet-lamports
    "${FAUCET_LAMPORTS}"
    --cluster-type
    "${CLUSTER_TYPE}"
)

# Add SPL and Metaplex programs to genesis
# Format: --upgradeable-program <PROGRAM_ID> <LOADER_ID> <PROGRAM_FILE> <UPGRADE_AUTHORITY>
# Use faucet as upgrade authority for private cluster
UPGRADE_AUTHORITY="${FAUCET_PUBKEY}"

if [[ -f "${PROGRAMS_DIR}/spl_token.so" ]]; then
    GENESIS_ARGS+=(--upgradeable-program "$TOKEN_PROGRAM_ID" "$BPF_LOADER" "${PROGRAMS_DIR}/spl_token.so" "$UPGRADE_AUTHORITY")
    log_info "Including SPL Token program in genesis"
fi

if [[ -f "${PROGRAMS_DIR}/spl_token_2022.so" ]]; then
    GENESIS_ARGS+=(--upgradeable-program "$TOKEN_2022_PROGRAM_ID" "$BPF_LOADER" "${PROGRAMS_DIR}/spl_token_2022.so" "$UPGRADE_AUTHORITY")
    log_info "Including SPL Token-2022 program in genesis"
fi

if [[ -f "${PROGRAMS_DIR}/spl_associated_token_account.so" ]]; then
    GENESIS_ARGS+=(--upgradeable-program "$ASSOCIATED_TOKEN_PROGRAM_ID" "$BPF_LOADER" "${PROGRAMS_DIR}/spl_associated_token_account.so" "$UPGRADE_AUTHORITY")
    log_info "Including Associated Token Account program in genesis"
fi

if [[ -f "${PROGRAMS_DIR}/mpl_token_metadata.so" ]]; then
    GENESIS_ARGS+=(--upgradeable-program "$TOKEN_METADATA_PROGRAM_ID" "$BPF_LOADER" "${PROGRAMS_DIR}/mpl_token_metadata.so" "$UPGRADE_AUTHORITY")
    log_info "Including Metaplex Token Metadata program in genesis"
fi

# Note: --lamports flag doesn't exist in solana-genesis
# Use --bootstrap-validator-lamports if you want to customize bootstrap validator lamports
# if [[ -n "${BOOTSTRAP_VALIDATOR_LAMPORTS:-}" ]]; then
#     GENESIS_ARGS+=(--bootstrap-validator-lamports "${BOOTSTRAP_VALIDATOR_LAMPORTS}")
# fi

log_info "Running: solana-genesis ${GENESIS_ARGS[*]}"

# Execute genesis creation
solana-genesis "${GENESIS_ARGS[@]}" || {
    log_error "Failed to create genesis"
    exit 1
}

# Verify genesis was created
if [[ ! -f "${LEDGER_DIR}/genesis.bin" ]]; then
    log_error "Genesis file not found after creation"
    exit 1
fi

log_success "Genesis created successfully!"
log_info "Genesis location: ${LEDGER_DIR}/genesis.bin"
log_info ""
log_info "Bootstrap validator configuration:"
log_info "  Identity key: ${BOOTSTRAP_IDENTITY_KEY}"
log_info "  Vote key: ${BOOTSTRAP_VOTE_KEY}"
log_info "  Stake key: ${BOOTSTRAP_STAKE_KEY}"
log_info "  Ledger: ${LEDGER_DIR}"
log_info ""
log_info "Faucet configuration:"
log_info "  Faucet key: ${FAUCET_KEY}"
log_info "  Faucet pubkey: ${FAUCET_PUBKEY}"
log_info ""
log_info "You can now start the bootstrap validator using:"
log_info "  ./scripts/start-bootstrap.sh"
