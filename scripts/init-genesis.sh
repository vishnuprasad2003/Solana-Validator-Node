#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Initialise genesis for the bootstrap validator
# Usage: ./scripts/init-genesis.sh <config-file>
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
source "$(dirname "$0")/common.sh"

CONFIG="${1:?Usage: $0 <config-file>}"
[[ ! -f "$CONFIG" ]] && { log_error "Config not found: $CONFIG"; exit 1; }
source "$CONFIG"

[[ "$NODE_TYPE" != "bootstrap" ]] && { log_error "NODE_TYPE must be 'bootstrap'"; exit 1; }

log_info "Initialising genesis for: $NODE_NAME"
ensure_dirs

# ── Clean existing ──────────────────────────────────────────────────────────
[[ -f "${LEDGER_DIR}/genesis.bin" ]] && { log_warn "Genesis exists — removing..."; rm -rf "$LEDGER_DIR"; }
mkdir -p "$LEDGER_DIR"

# ── Keys ────────────────────────────────────────────────────────────────────
generate_keypair "$IDENTITY_KEY"
generate_keypair "$VOTE_KEY"
generate_keypair "$STAKE_KEY"
generate_keypair "$FAUCET_KEY"

IDENTITY_PUB=$(get_pubkey "$IDENTITY_KEY")
VOTE_PUB=$(get_pubkey "$VOTE_KEY")
STAKE_PUB=$(get_pubkey "$STAKE_KEY")
FAUCET_PUB=$(get_pubkey "$FAUCET_KEY")

log_info "Identity: $IDENTITY_PUB"
log_info "Vote:     $VOTE_PUB"
log_info "Faucet:   $FAUCET_PUB"

# ── Download SPL programs if needed ─────────────────────────────────────────
"${SCRIPT_DIR}/setup-genesis-programs.sh" "$CONFIG" || log_warn "Programs setup had issues"

# ── Build genesis args ──────────────────────────────────────────────────────
BPF_LOADER="BPFLoaderUpgradeab1e11111111111111111111111"
ARGS=(
    --bootstrap-validator "$IDENTITY_PUB" "$VOTE_PUB" "$STAKE_PUB"
    --bootstrap-validator-stake-lamports "${BOOTSTRAP_STAKE_LAMPORTS:-1000000000000}"
    --ledger "$LEDGER_DIR"
    --faucet-pubkey "$FAUCET_PUB"
    --faucet-lamports "$GENESIS_LAMPORTS"
    --cluster-type "$CLUSTER_TYPE"
)

# Add programs from PROGRAMS_DIR
declare -A GENESIS_PROGRAMS=(
    ["spl_token.so"]="TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    ["spl_token_2022.so"]="TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
    ["spl_associated_token_account.so"]="ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
    ["mpl_token_metadata.so"]="metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
)
for prog_file in "${!GENESIS_PROGRAMS[@]}"; do
    local_path="${PROGRAMS_DIR}/${prog_file}"
    [[ -f "$local_path" ]] && \
        ARGS+=(--upgradeable-program "${GENESIS_PROGRAMS[$prog_file]}" "$BPF_LOADER" "$local_path" "$FAUCET_PUB")
done

# ── Create genesis ──────────────────────────────────────────────────────────
GENESIS_OUTPUT=$(solana-genesis "${ARGS[@]}" 2>&1) || { log_error "Genesis failed"; echo "$GENESIS_OUTPUT"; exit 1; }
GENESIS_HASH=$(echo "$GENESIS_OUTPUT" | grep -i "genesis hash" | grep -oE '[A-Za-z0-9]{32,}' | head -1 || echo "")

log_success "Genesis created!"
[[ -n "$GENESIS_HASH" ]] && log_info "Hash: $GENESIS_HASH" || log_warn "Could not extract genesis hash"
log_info "Faucet: $FAUCET_PUB ($(echo "$GENESIS_LAMPORTS / 1000000000" | bc) SOL)"

# ── Save faucet info ────────────────────────────────────────────────────────
cat > "${BASE_DIR}/keys/faucet.txt" <<EOF
FAUCET_PUBKEY=$FAUCET_PUB
FAUCET_KEY=$FAUCET_KEY
GENESIS_HASH=$GENESIS_HASH
BOOTSTRAP_IDENTITY=$IDENTITY_PUB
EOF
log_info "Faucet info → ${BASE_DIR}/keys/faucet.txt"
