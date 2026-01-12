#!/bin/bash
#
# Setup Essential Programs for Genesis
# Downloads and prepares SPL and Metaplex programs for inclusion in genesis
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Programs directory
PROGRAMS_DIR="${WORKSPACE_ROOT}/programs"
mkdir -p "$PROGRAMS_DIR"

# Standard program IDs (from mainnet)
declare -A PROGRAMS=(
    ["Token"]="TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    ["Token2022"]="TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
    ["AssociatedToken"]="ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
    ["TokenMetadata"]="metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
)

# Program file names
declare -A PROGRAM_FILES=(
    ["Token"]="spl_token.so"
    ["Token2022"]="spl_token_2022.so"
    ["AssociatedToken"]="spl_associated_token_account.so"
    ["TokenMetadata"]="mpl_token_metadata.so"
)

log_info "Setting up essential programs for genesis"
log_info "Programs directory: $PROGRAMS_DIR"

# Check if solana CLI is available
if ! command_exists solana; then
    log_error "solana CLI not found. Please install Solana tools first."
    exit 1
fi

# Download programs from mainnet
log_info "Downloading programs from mainnet..."

for PROGRAM_NAME in "${!PROGRAMS[@]}"; do
    PROGRAM_ID="${PROGRAMS[$PROGRAM_NAME]}"
    PROGRAM_FILE="${PROGRAM_FILES[$PROGRAM_NAME]}"
    PROGRAM_PATH="${PROGRAMS_DIR}/${PROGRAM_FILE}"
    
    if [[ -f "$PROGRAM_PATH" ]]; then
        log_info "Program $PROGRAM_NAME already exists: $PROGRAM_FILE"
        continue
    fi
    
    log_info "Downloading $PROGRAM_NAME (${PROGRAM_ID})..."
    
    if solana program dump "$PROGRAM_ID" "$PROGRAM_PATH" --url https://api.mainnet-beta.solana.com 2>/dev/null; then
        if [[ -f "$PROGRAM_PATH" ]] && [[ -s "$PROGRAM_PATH" ]]; then
            FILE_SIZE=$(stat -f%z "$PROGRAM_PATH" 2>/dev/null || stat -c%s "$PROGRAM_PATH" 2>/dev/null || echo "0")
            if [[ "$FILE_SIZE" -gt 1000 ]]; then
                log_success "Downloaded $PROGRAM_NAME: $(ls -lh "$PROGRAM_PATH" | awk '{print $5}')"
            else
                log_warn "Downloaded file seems too small, retrying..."
                rm -f "$PROGRAM_PATH"
                solana program dump "$PROGRAM_ID" "$PROGRAM_PATH" --url https://api.mainnet-beta.solana.com
            fi
        else
            log_error "Failed to download $PROGRAM_NAME"
            exit 1
        fi
    else
        log_error "Failed to download $PROGRAM_NAME from mainnet"
        exit 1
    fi
done

log_success "All programs downloaded successfully!"
log_info ""
log_info "Programs ready for genesis:"
for PROGRAM_NAME in "${!PROGRAMS[@]}"; do
    PROGRAM_FILE="${PROGRAM_FILES[$PROGRAM_NAME]}"
    PROGRAM_PATH="${PROGRAMS_DIR}/${PROGRAM_FILE}"
    if [[ -f "$PROGRAM_PATH" ]]; then
        FILE_SIZE=$(stat -f%z "$PROGRAM_PATH" 2>/dev/null || stat -c%s "$PROGRAM_PATH" 2>/dev/null || echo "0")
        log_info "  ✓ $PROGRAM_NAME: ${PROGRAMS[$PROGRAM_NAME]} ($(ls -lh "$PROGRAM_PATH" | awk '{print $5}'))"
    fi
done
