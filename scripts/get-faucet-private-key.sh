#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Extract faucet private key in base58 format
# Usage: ./scripts/get-faucet-private-key.sh [keyfile]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
source "$(dirname "$0")/common.sh"

KEY_FILE="${1:-}"
if [[ -z "$KEY_FILE" ]]; then
    # Try BASE_DIR first, then workspace
    if [[ -f "/solana/keys/faucet.json" ]]; then KEY_FILE="/solana/keys/faucet.json"
    elif [[ -f "${WORKSPACE_ROOT}/keys/faucet.json" ]]; then KEY_FILE="${WORKSPACE_ROOT}/keys/faucet.json"
    else log_error "Faucet key not found"; exit 1; fi
fi
[[ "$KEY_FILE" != /* ]] && KEY_FILE="${WORKSPACE_ROOT}/${KEY_FILE}"
[[ ! -f "$KEY_FILE" ]] && { log_error "Not found: $KEY_FILE"; exit 1; }

log_info "Extracting from: $KEY_FILE"

if command_exists python3; then
    KEY_FILE_PATH="$KEY_FILE" python3 -c '
import json, sys, os
try:
    import base58
except ImportError:
    print("ERROR: pip install base58", file=sys.stderr)
    sys.exit(1)
with open(os.environ["KEY_FILE_PATH"]) as f:
    data = json.load(f)
    print(base58.b58encode(bytes(data)).decode())
' && exit 0
fi

if command_exists node; then
    node -e "
const fs=require('fs'), bs58=require('bs58');
console.log(bs58.encode(Uint8Array.from(JSON.parse(fs.readFileSync('$KEY_FILE','utf8')))));
" 2>/dev/null && exit 0
fi

log_error "Requires Python3+base58 or Node.js+bs58"
exit 1
