#!/bin/bash
#
# Deploy Essential Programs to Private Cluster
# Deploys SPL Token, Token-2022, Associated Token, and Metaplex programs
# to their standard mainnet addresses
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
RPC_URL="${RPC_URL:-http://localhost:8899}"
FAUCET_KEY="${IDENTITY_KEY_DIR}/faucet.json"
PROGRAMS_DIR="${WORKSPACE_ROOT}/programs"

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

log_info "Deploying Essential Programs to Private Cluster"
log_info "RPC URL: $RPC_URL"

# Check if RPC is accessible
if ! curl -s -X POST "$RPC_URL" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' >/dev/null 2>&1; then
    log_error "Cannot connect to RPC endpoint: $RPC_URL"
    log_info "Please ensure the bootstrap validator is running"
    exit 1
fi

# Check if solana CLI is available
if ! command_exists solana; then
    log_error "solana CLI not found. Please install Solana tools first."
    exit 1
fi

# Check if programs directory exists
if [[ ! -d "$PROGRAMS_DIR" ]]; then
    log_info "Programs directory not found. Running setup script..."
    "${SCRIPT_DIR}/setup-genesis-programs.sh" || {
        log_error "Failed to setup programs"
        exit 1
    }
fi

# Set cluster URL
export SOLANA_URL="$RPC_URL"

# Check faucet balance
FAUCET_PUBKEY=$(get_pubkey "$FAUCET_KEY" 2>/dev/null || echo "")
if [[ -z "$FAUCET_PUBKEY" ]]; then
    log_error "Cannot get faucet public key"
    exit 1
fi

FAUCET_BALANCE=$(solana balance "$FAUCET_PUBKEY" --url "$RPC_URL" 2>/dev/null | grep -o '[0-9.]* SOL' | head -1 || echo "0 SOL")
log_info "Faucet balance: $FAUCET_BALANCE"

# Deploy programs
log_info ""
log_info "Deploying programs to standard addresses..."

DEPLOYED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for PROGRAM_NAME in "${!PROGRAMS[@]}"; do
    PROGRAM_ID="${PROGRAMS[$PROGRAM_NAME]}"
    PROGRAM_FILE="${PROGRAM_FILES[$PROGRAM_NAME]}"
    PROGRAM_PATH="${PROGRAMS_DIR}/${PROGRAM_FILE}"
    
    # Check if program already exists
    if solana program show "$PROGRAM_ID" --url "$RPC_URL" >/dev/null 2>&1; then
        log_info "✓ $PROGRAM_NAME already deployed at $PROGRAM_ID"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi
    
    # Check if program file exists
    if [[ ! -f "$PROGRAM_PATH" ]]; then
        log_warn "Program file not found: $PROGRAM_FILE"
        log_info "Downloading $PROGRAM_NAME..."
        if ! solana program dump "$PROGRAM_ID" "$PROGRAM_PATH" --url https://api.mainnet-beta.solana.com 2>/dev/null; then
            log_error "Failed to download $PROGRAM_NAME"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            continue
        fi
    fi
    
    # Deploy program
    log_info "Deploying $PROGRAM_NAME to $PROGRAM_ID..."
    
    if solana program deploy "$PROGRAM_PATH" \
        --program-id "$PROGRAM_ID" \
        --keypair "$FAUCET_KEY" \
        --url "$RPC_URL" \
        --max-signatures 1 \
        --skip-fee-payer-check \
        2>&1 | tee /tmp/deploy_${PROGRAM_NAME}.log; then
        
        # Verify deployment
        sleep 2
        if solana program show "$PROGRAM_ID" --url "$RPC_URL" >/dev/null 2>&1; then
            log_success "✓ $PROGRAM_NAME deployed successfully"
            DEPLOYED_COUNT=$((DEPLOYED_COUNT + 1))
        else
            log_warn "⚠ $PROGRAM_NAME deployment may have failed (verification failed)"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    else
        log_error "✗ Failed to deploy $PROGRAM_NAME"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    
    echo ""
done

# Summary
log_info ""
log_info "Deployment Summary:"
log_info "  Deployed: $DEPLOYED_COUNT"
log_info "  Already existed: $SKIPPED_COUNT"
log_info "  Failed: $FAILED_COUNT"

if [[ $FAILED_COUNT -gt 0 ]]; then
    log_warn "Some programs failed to deploy. Check logs above."
    exit 1
fi

log_success "All essential programs deployed successfully!"
log_info ""
log_info "Programs available:"
for PROGRAM_NAME in "${!PROGRAMS[@]}"; do
    PROGRAM_ID="${PROGRAMS[$PROGRAM_NAME]}"
    if solana program show "$PROGRAM_ID" --url "$RPC_URL" >/dev/null 2>&1; then
        log_info "  ✓ $PROGRAM_NAME: $PROGRAM_ID"
    fi
done
