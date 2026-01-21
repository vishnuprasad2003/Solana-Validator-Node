#!/bin/bash
# Common utilities for Solana validator scripts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# Resolve path: if absolute (starts with /), use as-is; if relative, prepend WORKSPACE_ROOT
resolve_path() {
    local path="$1"
    if [[ "$path" == /* ]]; then
        # Absolute path - use as-is
        echo "$path"
    else
        # Relative path - prepend WORKSPACE_ROOT
        echo "${WORKSPACE_ROOT}/${path}"
    fi
}

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log_info() { echo -e "[INFO] $*" >&2; }
log_success() { echo -e "${GREEN}[OK]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

generate_keypair() {
    local path=$1
    [[ -f "$path" ]] && { log_warn "Keypair exists: $path"; return 0; }
    mkdir -p "$(dirname "$path")"
    solana-keygen new --no-bip39-passphrase -o "$path" --force >/dev/null 2>&1
    log_success "Generated: $path"
}

get_pubkey() {
    local path=$1
    [[ ! -f "$path" ]] && { log_error "Not found: $path"; return 1; }
    # Handle paths with spaces by cd-ing to directory first
    local dir=$(dirname "$path")
    local file=$(basename "$path")
    (cd "$dir" && solana-keygen pubkey "$file" 2>/dev/null)
}

get_validator_bin() {
    # Check multiple locations for agave-validator (preferred)
    local install_bin="$HOME/.local/share/solana/install/active_release/bin"
    
    # Check PATH first
    if command_exists agave-validator; then
        echo "agave-validator"
        return 0
    fi
    
    # Check standard install location
    if [[ -f "$install_bin/agave-validator" ]]; then
        echo "$install_bin/agave-validator"
        return 0
    fi
    
    # Check /usr/local/bin (where Anza installer sometimes puts it)
    if [[ -f "/usr/local/bin/agave-validator" ]]; then
        echo "/usr/local/bin/agave-validator"
        return 0
    fi
    
    # Fallback to solana-validator
    if [[ -f "$install_bin/solana-validator" ]]; then
        echo "$install_bin/solana-validator"
        return 0
    fi
    
    if command_exists solana-validator; then
        echo "solana-validator"
        return 0
    fi
    
    log_error "Validator binary not found. Run: make install"
    return 1
}

wait_for_rpc() {
    local url=$1 max=${2:-30} i=0
    while [[ $i -lt $max ]]; do
        curl -s "$url" -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' >/dev/null 2>&1 && return 0
        sleep 2; ((i++))
    done
    return 1
}
