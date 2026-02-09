#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Solana Validator Node — Shared Utilities
# Sourced by every other script. Never executed directly.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# ─── Logging ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
_ts() { date '+%Y-%m-%d %H:%M:%S'; }
log_info()    { echo -e "${GREEN}[$(_ts)] INFO${NC}  $*" >&2; }
log_success() { echo -e "${GREEN}[$(_ts)]   OK${NC}  $*" >&2; }
log_warn()    { echo -e "${YELLOW}[$(_ts)] WARN${NC}  $*" >&2; }
log_error()   { echo -e "${RED}[$(_ts)] ERROR${NC} $*" >&2; }

# ─── Helpers ────────────────────────────────────────────────────────────────
command_exists() { command -v "$1" >/dev/null 2>&1; }

resolve_path() {
    local p="$1"
    [[ "$p" == /* ]] && echo "$p" || echo "${WORKSPACE_ROOT}/${p}"
}

generate_keypair() {
    local path="$1"
    [[ -f "$path" ]] && { log_warn "Keypair exists: $path"; return 0; }
    mkdir -p "$(dirname "$path")"
    solana-keygen new --no-bip39-passphrase -o "$path" --force >/dev/null 2>&1
    log_success "Generated: $path"
}

get_pubkey() {
    local path="$1"
    [[ ! -f "$path" ]] && { log_error "Not found: $path"; return 1; }
    local dir; dir=$(dirname "$path")
    local file; file=$(basename "$path")
    (cd "$dir" && solana-keygen pubkey "$file" 2>/dev/null)
}

get_validator_bin() {
    local bin_dir="$HOME/.local/share/solana/install/active_release/bin"
    for loc in "agave-validator" "$bin_dir/agave-validator" "/usr/local/bin/agave-validator" \
               "$bin_dir/solana-validator" "solana-validator"; do
        if [[ "$loc" == */* ]]; then
            [[ -f "$loc" ]] && { echo "$loc"; return 0; }
        else
            command_exists "$loc" && { echo "$loc"; return 0; }
        fi
    done
    log_error "Validator binary not found. Run: make install"; return 1
}

# Create every directory referenced in a config.
ensure_dirs() {
    local base="${BASE_DIR:?BASE_DIR not set}"
    mkdir -p "${base}/data" "${base}/logs" "${base}/keys" \
             "${base}/pids" "${base}/programs" "${base}/backups"
}

# ─── Process management ────────────────────────────────────────────────────
is_running() {
    local pf="${1:?pid file required}"
    [[ -f "$pf" ]] && kill -0 "$(cat "$pf")" 2>/dev/null && return 0
    rm -f "$pf" 2>/dev/null; return 1
}

graceful_stop() {
    local pf="${1:?pid file required}" name="${2:-process}" timeout="${3:-15}"
    is_running "$pf" || { log_warn "$name is not running"; return 0; }
    local pid; pid=$(cat "$pf")
    log_info "Stopping $name (PID $pid)..."
    kill "$pid" 2>/dev/null || true
    local i
    for ((i=0; i<timeout; i++)); do
        kill -0 "$pid" 2>/dev/null || { rm -f "$pf"; log_success "$name stopped"; return 0; }
        sleep 1
    done
    kill -9 "$pid" 2>/dev/null || true
    rm -f "$pf"
    log_warn "$name killed after ${timeout}s timeout"
}

wait_for_rpc() {
    local url="$1" max="${2:-30}"
    local i
    for ((i=0; i<max; i++)); do
        curl -s "$url" -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' >/dev/null 2>&1 && return 0
        sleep 2
    done
    return 1
}
