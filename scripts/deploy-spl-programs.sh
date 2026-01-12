#!/bin/bash
#
# Deploy SPL Token Programs to Private Cluster
# This script deploys essential SPL programs (Token, Token-2022, Associated Token, etc.)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
RPC_URL="${RPC_URL:-http://localhost:8899}"
FAUCET_KEY="${IDENTITY_KEY_DIR}/faucet.json"
PROGRAMS_DIR="${WORKSPACE_ROOT}/programs"

log_info "Deploying SPL Token Programs to Private Cluster"
log_info "RPC URL: $RPC_URL"

# Check if RPC is accessible
if ! curl -s -X POST "$RPC_URL" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' >/dev/null 2>&1; then
    log_error "Cannot connect to RPC endpoint: $RPC_URL"
    log_info "Please ensure the bootstrap validator is running"
    exit 1
fi

# Check if solana program deploy is available
if ! command_exists solana; then
    log_error "solana CLI not found. Please install Solana tools first."
    exit 1
fi

# Set cluster URL
export SOLANA_URL="$RPC_URL"

# Create programs directory
mkdir -p "$PROGRAMS_DIR"

log_info "SPL Token programs are typically included in genesis for development clusters."
log_info "However, if you need to deploy them manually, you can use:"
log_info ""
log_info "1. Download SPL programs:"
log_info "   git clone https://github.com/solana-labs/solana-program-library.git"
log_info ""
log_info "2. Build and deploy Token program:"
log_info "   cd solana-program-library/token/program"
log_info "   cargo build-sbf"
log_info "   solana program deploy target/deploy/spl_token.so --url $RPC_URL"
log_info ""
log_info "3. Build and deploy Token-2022 program:"
log_info "   cd solana-program-library/token/program-2022"
log_info "   cargo build-sbf"
log_info "   solana program deploy target/deploy/spl_token_2022.so --url $RPC_URL"
log_info ""
log_info "Note: For a private test cluster, SPL programs are usually pre-deployed in genesis."
log_info "Check with: solana program show --url $RPC_URL <program-id>"

# Check if programs are already deployed
log_info ""
log_info "Checking for existing SPL programs..."

# Token program ID: TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA
TOKEN_PROGRAM="TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
if solana program show "$TOKEN_PROGRAM" --url "$RPC_URL" >/dev/null 2>&1; then
    log_success "Token program is deployed"
else
    log_warn "Token program not found. It may need to be deployed."
fi

# Token-2022 program ID: TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb
TOKEN_2022_PROGRAM="TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
if solana program show "$TOKEN_2022_PROGRAM" --url "$RPC_URL" >/dev/null 2>&1; then
    log_success "Token-2022 program is deployed"
else
    log_warn "Token-2022 program not found. It may need to be deployed."
fi

# Associated Token program ID: ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL
ASSOCIATED_TOKEN_PROGRAM="ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
if solana program show "$ASSOCIATED_TOKEN_PROGRAM" --url "$RPC_URL" >/dev/null 2>&1; then
    log_success "Associated Token program is deployed"
else
    log_warn "Associated Token program not found. It may need to be deployed."
fi

log_info ""
log_info "For Metaplex programs, you'll need to deploy them separately:"
log_info "  - Metaplex Token Metadata: https://github.com/metaplex-foundation/metaplex-program-library"
log_info ""
log_info "To deploy custom programs, use:"
log_info "  solana program deploy <program.so> --url $RPC_URL --keypair <keypair.json>"
