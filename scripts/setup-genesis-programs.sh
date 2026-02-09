#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Download essential SPL programs from mainnet for genesis
# Usage: ./scripts/setup-genesis-programs.sh [config-file]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
source "$(dirname "$0")/common.sh"

CONFIG="${1:-${WORKSPACE_ROOT}/configs/bootstrap.conf}"
[[ -f "$CONFIG" ]] && source "$CONFIG"

PROGRAMS_DIR="${PROGRAMS_DIR:-${BASE_DIR:-/solana}/programs}"
mkdir -p "$PROGRAMS_DIR"

# Also check workspace programs as fallback source
WS_PROGRAMS="${WORKSPACE_ROOT}/programs"

declare -A PROGRAMS=(
    ["spl_token.so"]="TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    ["spl_token_2022.so"]="TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
    ["spl_associated_token_account.so"]="ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
    ["mpl_token_metadata.so"]="metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
)

log_info "Setting up SPL programs in ${PROGRAMS_DIR}"

for FILE in "${!PROGRAMS[@]}"; do
    DEST="${PROGRAMS_DIR}/${FILE}"
    # Already exists in target dir
    [[ -f "$DEST" ]] && { log_info "  ✓ $FILE"; continue; }
    # Copy from workspace programs dir
    if [[ -f "${WS_PROGRAMS}/${FILE}" ]]; then
        cp "${WS_PROGRAMS}/${FILE}" "$DEST"
        log_info "  ✓ $FILE (copied from workspace)"
        continue
    fi
    # Download from mainnet
    log_info "  Downloading $FILE..."
    solana program dump "${PROGRAMS[$FILE]}" "$DEST" --url https://api.mainnet-beta.solana.com 2>/dev/null || \
        { log_warn "  ✗ Failed: $FILE"; continue; }
    log_info "  ✓ $FILE (downloaded)"
done

log_success "Programs ready"
