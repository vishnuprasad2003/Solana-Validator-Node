#!/bin/bash
# Get faucet private key in base58 format
# Usage: ./scripts/get-faucet-private-key.sh [keyfile]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Default to faucet key (stored locally, NOT in Azure File Share)
KEY_FILE="${1:-${WORKSPACE_ROOT}/keys/faucet.json}"

# Resolve path if relative
[[ "$KEY_FILE" != /* ]] && KEY_FILE="${WORKSPACE_ROOT}/${KEY_FILE}"

# Check if key file exists
[[ ! -f "$KEY_FILE" ]] && { 
    log_error "Keypair file not found: $KEY_FILE"
    log_info "Usage: $0 [keyfile]"
    log_info "Default: keys/faucet.json"
    exit 1
}

log_info "Extracting private key from: $KEY_FILE"

# Method 1: Use Python (most reliable, usually available)
if command_exists python3; then
    KEY_FILE_PATH="$KEY_FILE" python3 <<'PYTHON_SCRIPT'
import json
import sys
import os

key_file = os.environ.get('KEY_FILE_PATH', '')

try:
    # Try importing base58
    try:
        import base58
    except ImportError:
        print("ERROR: base58 module not found", file=sys.stderr)
        print("Install with: pip install base58", file=sys.stderr)
        sys.exit(1)
    
    # Read the keypair file
    with open(key_file, "r") as f:
        secret_key_array = json.load(f)
    
    # Convert to bytes
    secret_key = bytes(secret_key_array)
    
    # Encode as base58
    private_key_base58 = base58.b58encode(secret_key).decode('utf-8')
    print(private_key_base58)
    
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
    
    if [[ $? -eq 0 ]]; then
        exit 0
    fi
fi

# Method 2: Use Node.js (if Python failed and Node.js is available)
if command_exists node; then
    node <<EOF
const fs = require('fs');
const bs58 = require('bs58');

try {
    const secretKeyArray = JSON.parse(fs.readFileSync("$KEY_FILE", "utf8"));
    const secretKey = Uint8Array.from(secretKeyArray);
    const privateKeyBase58 = bs58.encode(secretKey);
    console.log(privateKeyBase58);
} catch (error) {
    console.error("ERROR:", error.message);
    process.exit(1);
}
EOF
    
    if [[ $? -eq 0 ]]; then
        exit 0
    fi
fi

# Method 3: Try using solana-keygen (if it supports outputting private key)
if command_exists solana-keygen; then
    # Check if solana-keygen has a command to output private key
    # Note: This might not be available in all versions
    log_warn "Python and Node.js not available, trying solana-keygen..."
    log_warn "Note: solana-keygen may not support private key extraction"
    
    # Try to use solana-keygen pubkey to at least verify the key works
    solana-keygen pubkey "$KEY_FILE" >/dev/null 2>&1 || {
        log_error "Keypair file is invalid"
        exit 1
    }
    
    log_error "Cannot extract private key: Python or Node.js required"
    log_info "Install Python base58: pip install base58"
    log_info "Or install Node.js bs58: npm install bs58"
    exit 1
fi

# If we get here, no suitable tool was found
log_error "No suitable tool found to extract private key"
log_info "Required: Python3 with base58 module OR Node.js with bs58 module"
log_info ""
log_info "Install Python base58:"
log_info "  pip install base58"
log_info ""
log_info "Or install Node.js bs58:"
log_info "  npm install -g bs58"
exit 1
