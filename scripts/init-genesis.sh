#!/bin/bash
# Initialize genesis for bootstrap validator
# Usage: ./scripts/init-genesis.sh [config-file]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

CONFIG="${1:-${WORKSPACE_ROOT}/configs/node.conf}"
[[ ! -f "$CONFIG" ]] && { log_error "Config not found: $CONFIG"; exit 1; }
source "$CONFIG"

[[ "$NODE_TYPE" != "bootstrap" ]] && { log_error "NODE_TYPE must be 'bootstrap'"; exit 1; }

log_info "Initializing genesis for: $NODE_NAME"

# Resolve paths
IDENTITY="${WORKSPACE_ROOT}/${IDENTITY_KEY}"
VOTE="${WORKSPACE_ROOT}/${VOTE_KEY}"
STAKE="${WORKSPACE_ROOT}/${STAKE_KEY}"
FAUCET="${WORKSPACE_ROOT}/${FAUCET_KEY}"
LEDGER="${WORKSPACE_ROOT}/${LEDGER_DIR}"

# Clean existing
[[ -f "${LEDGER}/genesis.bin" ]] && { log_warn "Genesis exists, removing..."; rm -rf "$LEDGER"; }
mkdir -p "$LEDGER" "$(dirname "$IDENTITY")" "$(dirname "$VOTE")" "$(dirname "$FAUCET")"

# Generate keys
generate_keypair "$IDENTITY"
generate_keypair "$VOTE"
generate_keypair "$STAKE"
generate_keypair "$FAUCET"

IDENTITY_PUB=$(get_pubkey "$IDENTITY")
VOTE_PUB=$(get_pubkey "$VOTE")
STAKE_PUB=$(get_pubkey "$STAKE")
FAUCET_PUB=$(get_pubkey "$FAUCET")

log_info "Identity: $IDENTITY_PUB"
log_info "Vote: $VOTE_PUB"
log_info "Faucet: $FAUCET_PUB"

# Download programs if needed
"${SCRIPT_DIR}/setup-genesis-programs.sh" || log_warn "Programs setup failed"

# Build genesis command
PROGRAMS_DIR="${WORKSPACE_ROOT}/programs"
BPF_LOADER="BPFLoaderUpgradeab1e11111111111111111111111"
# Use config value or default to 1000 SOL
BOOTSTRAP_STAKE_LAMPORTS="${BOOTSTRAP_STAKE_LAMPORTS:-1000000000000}"
ARGS=(--bootstrap-validator "$IDENTITY_PUB" "$VOTE_PUB" "$STAKE_PUB"
      --bootstrap-validator-stake-lamports "$BOOTSTRAP_STAKE_LAMPORTS"
      --ledger "$LEDGER" --faucet-pubkey "$FAUCET_PUB"
      --faucet-lamports "$GENESIS_LAMPORTS" --cluster-type "$CLUSTER_TYPE")

# Add programs
[[ -f "${PROGRAMS_DIR}/spl_token.so" ]] && \
    ARGS+=(--upgradeable-program "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA" "$BPF_LOADER" "${PROGRAMS_DIR}/spl_token.so" "$FAUCET_PUB")
[[ -f "${PROGRAMS_DIR}/spl_token_2022.so" ]] && \
    ARGS+=(--upgradeable-program "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb" "$BPF_LOADER" "${PROGRAMS_DIR}/spl_token_2022.so" "$FAUCET_PUB")
[[ -f "${PROGRAMS_DIR}/spl_associated_token_account.so" ]] && \
    ARGS+=(--upgradeable-program "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL" "$BPF_LOADER" "${PROGRAMS_DIR}/spl_associated_token_account.so" "$FAUCET_PUB")
[[ -f "${PROGRAMS_DIR}/mpl_token_metadata.so" ]] && \
    ARGS+=(--upgradeable-program "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s" "$BPF_LOADER" "${PROGRAMS_DIR}/mpl_token_metadata.so" "$FAUCET_PUB")

# Create genesis and capture output
GENESIS_OUTPUT=$(solana-genesis "${ARGS[@]}" 2>&1) || { log_error "Genesis failed"; exit 1; }

# Extract genesis hash from output (format: "Genesis hash: XXXXX")
GENESIS_HASH=$(echo "$GENESIS_OUTPUT" | grep -i "genesis hash" | grep -oE '[A-Za-z0-9]{32,}' | head -1 || echo "")

log_success "Genesis created!"
if [[ -n "$GENESIS_HASH" ]]; then
    log_info "Hash: $GENESIS_HASH"
else
    log_warn "Could not extract genesis hash from output"
    log_info "You can find it in the genesis output above"
fi
log_info "Faucet: $FAUCET_PUB ($(echo "$GENESIS_LAMPORTS / 1000000000" | bc) SOL)"

# Save faucet info
cat > "${WORKSPACE_ROOT}/faucet.txt" <<EOF
FAUCET_PUBKEY=$FAUCET_PUB
FAUCET_KEY=$FAUCET_KEY
GENESIS_HASH=$GENESIS_HASH
BOOTSTRAP_IDENTITY=$IDENTITY_PUB
EOF
log_info "Faucet info saved to: faucet.txt"
