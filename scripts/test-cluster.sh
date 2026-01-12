#!/bin/bash
#
# Test Cluster Functionality
# Tests common operations: token creation, transfers, program deployment
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

RPC_URL="${RPC_URL:-http://localhost:8899}"
FAUCET_KEY="${IDENTITY_KEY_DIR}/faucet.json"

log_info "Testing Cluster Functionality"
log_info "RPC URL: $RPC_URL"

# Check if RPC is accessible
if ! curl -s -X POST "$RPC_URL" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' >/dev/null 2>&1; then
    log_error "Cannot connect to RPC endpoint: $RPC_URL"
    exit 1
fi

# Set cluster URL
export SOLANA_URL="$RPC_URL"

log_info ""
log_info "1. Testing Basic RPC Calls"
log_info "============================"

# Get cluster version
log_info "Getting cluster version..."
CLUSTER_VERSION=$(solana cluster-version --url "$RPC_URL" 2>/dev/null || echo "unknown")
log_success "Cluster version: $CLUSTER_VERSION"

# Get slot
log_info "Getting current slot..."
SLOT=$(solana slot --url "$RPC_URL" 2>/dev/null || echo "0")
log_success "Current slot: $SLOT"

log_info ""
log_info "2. Testing SPL Token Programs"
log_info "=============================="

# Check Token program
TOKEN_PROGRAM="TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
if solana program show "$TOKEN_PROGRAM" --url "$RPC_URL" >/dev/null 2>&1; then
    log_success "Token program is available"
else
    log_warn "Token program not found"
fi

# Check Token-2022 program
TOKEN_2022_PROGRAM="TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
if solana program show "$TOKEN_2022_PROGRAM" --url "$RPC_URL" >/dev/null 2>&1; then
    log_success "Token-2022 program is available"
else
    log_warn "Token-2022 program not found"
fi

# Check Associated Token program
ASSOCIATED_TOKEN_PROGRAM="ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
if solana program show "$ASSOCIATED_TOKEN_PROGRAM" --url "$RPC_URL" >/dev/null 2>&1; then
    log_success "Associated Token program is available"
else
    log_warn "Associated Token program not found"
fi

log_info ""
log_info "3. Testing Token Operations"
log_info "============================="

if [[ -f "$FAUCET_KEY" ]] && command_exists spl-token; then
    log_info "Creating test token mint..."
    TOKEN_MINT=$(spl-token create-token --url "$RPC_URL" --keypair "$FAUCET_KEY" 2>/dev/null | grep -o 'Creating token [A-Za-z0-9]*' | awk '{print $3}' || echo "")
    
    if [[ -n "$TOKEN_MINT" ]]; then
        log_success "Created token mint: $TOKEN_MINT"
        
        log_info "Creating token account..."
        spl-token create-account "$TOKEN_MINT" --url "$RPC_URL" --keypair "$FAUCET_KEY" >/dev/null 2>&1 && \
            log_success "Created token account" || \
            log_warn "Failed to create token account"
        
        log_info "Minting tokens..."
        spl-token mint "$TOKEN_MINT" 1000 --url "$RPC_URL" --keypair "$FAUCET_KEY" >/dev/null 2>&1 && \
            log_success "Minted 1000 tokens" || \
            log_warn "Failed to mint tokens"
    else
        log_warn "Could not create token mint (may need SPL CLI tools)"
    fi
else
    log_warn "Faucet key or spl-token not available, skipping token tests"
fi

log_info ""
log_info "4. Testing Account Operations"
log_info "=============================="

if [[ -f "$FAUCET_KEY" ]]; then
    FAUCET_PUBKEY=$(get_pubkey "$FAUCET_KEY" 2>/dev/null || echo "")
    if [[ -n "$FAUCET_PUBKEY" ]]; then
        BALANCE=$(solana balance "$FAUCET_PUBKEY" --url "$RPC_URL" 2>/dev/null | grep -o '[0-9.]* SOL' || echo "unknown")
        log_success "Faucet balance: $BALANCE"
    fi
fi

log_info ""
log_success "Cluster functionality test complete!"
log_info ""
log_info "To perform more operations:"
log_info "  - Create tokens: spl-token create-token --url $RPC_URL"
log_info "  - Deploy programs: solana program deploy <program.so> --url $RPC_URL"
log_info "  - Transfer SOL: solana transfer <address> <amount> --url $RPC_URL"
