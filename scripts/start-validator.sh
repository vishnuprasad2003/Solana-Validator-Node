#!/bin/bash
#
# Start Additional Validator Node
# This script starts an additional validator that joins the existing cluster
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Parse arguments
NODE_NAME="${1:-}"
if [[ -z "$NODE_NAME" ]]; then
    log_error "Usage: $0 <node-name>"
    log_info "Example: $0 validator-1"
    exit 1
fi

# Load node-specific configuration if it exists
NODE_CONFIG="${WORKSPACE_ROOT}/configs/${NODE_NAME}.conf"
if [[ -f "$NODE_CONFIG" ]]; then
    log_info "Loading node configuration: $NODE_CONFIG"
    source "$NODE_CONFIG"
else
    log_warn "Node configuration not found: $NODE_CONFIG"
    log_info "Using default configuration"
fi

# Node-specific paths
NODE_IDENTITY_KEY="${NODE_IDENTITY_KEY:-${IDENTITY_KEY_DIR}/${NODE_NAME}-identity.json}"
NODE_VOTE_KEY="${NODE_VOTE_KEY:-${VOTE_KEY_DIR}/${NODE_NAME}-vote.json}"
NODE_STAKE_KEY="${NODE_STAKE_KEY:-${STAKE_KEY_DIR}/${NODE_NAME}-stake.json}"
NODE_LEDGER_DIR="${NODE_LEDGER_DIR:-${VALIDATOR_LEDGER_DIR}/${NODE_NAME}}"
NODE_LOG_FILE="${NODE_LOG_FILE:-${LOG_DIR}/${NODE_NAME}.log}"
NODE_PID_FILE="${WORKSPACE_ROOT}/${NODE_NAME}.pid"

# Ports (can be overridden in node config)
NODE_GOSSIP_PORT="${NODE_GOSSIP_PORT:-${GOSSIP_PORT}}"
NODE_RPC_PORT="${NODE_RPC_PORT:-${RPC_PORT}}"
NODE_RPC_WEBSOCKET_PORT="${NODE_RPC_WEBSOCKET_PORT:-${RPC_WEBSOCKET_PORT}}"
NODE_TPU_PORT="${NODE_TPU_PORT:-${TPU_PORT}}"
NODE_TPU_FORWARD_PORT="${NODE_TPU_FORWARD_PORT:-${TPU_FORWARD_PORT}}"
NODE_METRICS_PORT="${NODE_METRICS_PORT:-${METRICS_PORT}}"

# Entrypoint will be determined after checking if this is a bootstrap validator
# Don't set it here - will be set later if needed
ENTRYPOINT_HOST="${ENTRYPOINT_HOST:-}"
ENTRYPOINT_PORT="${ENTRYPOINT_PORT:-}"
ENTRYPOINT=""

# Check if validator is already running
if [[ -f "$NODE_PID_FILE" ]]; then
    PID=$(cat "$NODE_PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        log_warn "Validator '$NODE_NAME' is already running (PID: $PID)"
        log_info "To stop it, run: ./scripts/stop-validator.sh $NODE_NAME"
        exit 0
    else
        log_warn "Stale PID file found, removing..."
        rm -f "$NODE_PID_FILE"
    fi
fi

# Validate prerequisites
log_info "Validating prerequisites for validator: $NODE_NAME"

if ! check_agave_installed; then
    log_error "Agave validator not found. Please run install.sh first."
    exit 1
fi

# Check file descriptor limits
if ! check_file_descriptor_limits 1000000; then
    log_error "File descriptor limits are insufficient for validator operation"
    log_info "The validator requires at least 1,000,000 file descriptors"
    log_info "Please configure system limits before starting the validator"
    exit 1
fi

AGAVE_BINARY=$(get_agave_binary)

# Check if bootstrap validator is reachable (only if entrypoint is configured)
# Skip this check for bootstrap validators
if [[ -n "${ENTRYPOINT_HOST:-}" ]] && [[ -n "${ENTRYPOINT_PORT:-}" ]]; then
    log_info "Checking bootstrap validator at ${ENTRYPOINT_HOST}:${ENTRYPOINT_PORT}..."
    # Try TCP connection first
    if timeout 3 bash -c "echo > /dev/tcp/${ENTRYPOINT_HOST}/${ENTRYPOINT_PORT}" 2>/dev/null; then
        log_success "Bootstrap validator is reachable"
    elif command_exists nc; then
        # Try netcat as fallback
        if nc -z -w 3 "${ENTRYPOINT_HOST}" "${ENTRYPOINT_PORT}" 2>/dev/null; then
            log_success "Bootstrap validator is reachable (via netcat)"
        else
            log_warn "Cannot verify bootstrap validator connectivity"
            log_info "Will attempt to connect anyway (may work in Docker/K8s networks)"
        fi
    else
        log_warn "Cannot verify bootstrap validator connectivity (no nc command)"
        log_info "Will attempt to connect anyway"
    fi
else
    log_info "No entrypoint configured - will check if this is a bootstrap validator"
fi

# Generate keypairs if they don't exist
log_info "Checking keypairs for $NODE_NAME..."

generate_keypair "$NODE_IDENTITY_KEY" "identity" || exit 1
generate_keypair "$NODE_VOTE_KEY" "vote" || exit 1
generate_keypair "$NODE_STAKE_KEY" "stake" || exit 1

# Validate keypairs
validate_keypair "$NODE_IDENTITY_KEY" || exit 1
validate_keypair "$NODE_VOTE_KEY" || exit 1
validate_keypair "$NODE_STAKE_KEY" || exit 1

# Check ports (only check if ports are set and not empty)
PORTS_TO_CHECK=("$NODE_GOSSIP_PORT" "$NODE_RPC_PORT" "$NODE_RPC_WEBSOCKET_PORT")
[[ -n "${NODE_TPU_PORT:-}" ]] && PORTS_TO_CHECK+=("$NODE_TPU_PORT")
[[ -n "${NODE_TPU_FORWARD_PORT:-}" ]] && PORTS_TO_CHECK+=("$NODE_TPU_FORWARD_PORT")
[[ -n "${NODE_METRICS_PORT:-}" ]] && PORTS_TO_CHECK+=("$NODE_METRICS_PORT")

for port in "${PORTS_TO_CHECK[@]}"; do
    if [[ -n "$port" ]] && ! port_available "$port"; then
        log_error "Port $port is already in use"
        exit 1
    fi
done

# Setup logging
setup_log_rotation "$NODE_LOG_FILE"
check_directory "$(dirname "$NODE_LOG_FILE")"
check_directory "$NODE_LEDGER_DIR"

# PRODUCTION PATTERN: Regular validators need genesis + snapshot to join existing cluster
# ALWAYS copy genesis from bootstrap to ensure it's in sync (prevents genesis hash mismatch)
if [[ -f "${BOOTSTRAP_LEDGER_DIR}/genesis.bin" ]]; then
    mkdir -p "${NODE_LEDGER_DIR}"
    
    # Check if genesis needs to be updated
    if [[ -f "${NODE_LEDGER_DIR}/genesis.bin" ]]; then
        BOOTSTRAP_GENESIS_HASH=$(sha256sum "${BOOTSTRAP_LEDGER_DIR}/genesis.bin" 2>/dev/null | awk '{print $1}')
        VALIDATOR_GENESIS_HASH=$(sha256sum "${NODE_LEDGER_DIR}/genesis.bin" 2>/dev/null | awk '{print $1}')
        
        if [[ "$BOOTSTRAP_GENESIS_HASH" != "$VALIDATOR_GENESIS_HASH" ]]; then
            log_warn "Genesis mismatch detected! Updating genesis from bootstrap..."
            cp "${BOOTSTRAP_LEDGER_DIR}/genesis.bin" "${NODE_LEDGER_DIR}/genesis.bin"
            log_success "Genesis updated to match bootstrap"
        else
            log_info "Genesis is in sync with bootstrap"
        fi
    else
        log_info "Copying genesis from bootstrap validator..."
        cp "${BOOTSTRAP_LEDGER_DIR}/genesis.bin" "${NODE_LEDGER_DIR}/genesis.bin"
        log_success "Genesis copied to ${NODE_LEDGER_DIR}"
    fi
fi

# CRITICAL: Clean validator ledger to ensure fresh start with correct genesis
# This prevents "genesis creation time mismatch" errors from stale data
log_info "Cleaning validator ledger for fresh start..."

# Remove ALL old snapshots (they may be from different genesis)
OLD_SNAPSHOTS=$(find "${NODE_LEDGER_DIR}" -maxdepth 1 -name "snapshot-*.tar.zst" -type f 2>/dev/null)
if [[ -n "$OLD_SNAPSHOTS" ]]; then
    log_info "Removing old snapshots from validator ledger..."
    rm -f "${NODE_LEDGER_DIR}"/snapshot-*.tar.zst
fi

# Remove snapshots subdirectory if exists
if [[ -d "${NODE_LEDGER_DIR}/snapshots" ]]; then
    rm -rf "${NODE_LEDGER_DIR}/snapshots"
fi

# Remove blockstore (rocksdb) to avoid conflicts
if [[ -d "${NODE_LEDGER_DIR}/rocksdb" ]]; then
    log_info "Removing old blockstore..."
    rm -rf "${NODE_LEDGER_DIR}/rocksdb"
fi

# Remove accounts database (may contain stale state)
if [[ -d "${NODE_LEDGER_DIR}/accounts" ]]; then
    log_info "Removing old accounts database..."
    rm -rf "${NODE_LEDGER_DIR}/accounts"
fi

# Remove run directory (runtime state)
if [[ -d "${NODE_LEDGER_DIR}/run" ]]; then
    rm -rf "${NODE_LEDGER_DIR}/run"
fi

log_success "Validator ledger cleaned"

# CRITICAL: Copy fresh snapshot from bootstrap
log_info "Looking for snapshot in bootstrap ledger..."
SNAPSHOT_COPIED=false

# First check root ledger directory (Agave's default location)
LATEST_SNAPSHOT=$(find "${BOOTSTRAP_LEDGER_DIR}" -maxdepth 1 -name "snapshot-*.tar.zst" -type f 2>/dev/null | sort -r | head -1)

# If not found, check snapshots/ subdirectory
if [[ -z "$LATEST_SNAPSHOT" ]] && [[ -d "${BOOTSTRAP_LEDGER_DIR}/snapshots" ]]; then
    LATEST_SNAPSHOT=$(find "${BOOTSTRAP_LEDGER_DIR}/snapshots" -name "*.tar.zst" -type f 2>/dev/null | sort -r | head -1)
fi

if [[ -n "$LATEST_SNAPSHOT" ]] && [[ -f "$LATEST_SNAPSHOT" ]]; then
    log_info "Found snapshot: $(basename "$LATEST_SNAPSHOT")"
    # Copy snapshot to validator's ledger directory (root level)
    cp "$LATEST_SNAPSHOT" "${NODE_LEDGER_DIR}/"
    SNAPSHOT_COPIED=true
    log_success "Snapshot copied to ${NODE_LEDGER_DIR}"
fi

# Warn if no snapshot found (validator may fail to start)
if [[ "$SNAPSHOT_COPIED" == "false" ]]; then
    log_warn "No snapshot found in bootstrap ledger!"
    log_warn "Validator may fail to start. Bootstrap must produce snapshots first."
    log_info "Waiting 10 seconds for bootstrap to generate snapshot..."
    sleep 10
    # Try one more time
    LATEST_SNAPSHOT=$(find "${BOOTSTRAP_LEDGER_DIR}" -maxdepth 1 -name "snapshot-*.tar.zst" -type f 2>/dev/null | sort -r | head -1)
    if [[ -n "$LATEST_SNAPSHOT" ]] && [[ -f "$LATEST_SNAPSHOT" ]]; then
        cp "$LATEST_SNAPSHOT" "${NODE_LEDGER_DIR}/"
        log_success "Snapshot found and copied after wait"
    else
        log_error "Still no snapshot found. Bootstrap validator must produce blocks first."
        log_info "Check bootstrap logs: tail -f logs/bootstrap.log"
        log_info "Or wait for bootstrap to produce snapshots, then retry."
    fi
fi

# Get public keys for logging
NODE_IDENTITY_PUBKEY=$(get_pubkey "$NODE_IDENTITY_KEY")
NODE_VOTE_PUBKEY=$(get_pubkey "$NODE_VOTE_KEY")

# Get bootstrap identity pubkey for --known-validator
BOOTSTRAP_IDENTITY_PUBKEY=$(get_pubkey "${IDENTITY_KEY_DIR}/bootstrap-identity.json" 2>/dev/null || echo "")

log_info "Starting Validator: $NODE_NAME"
log_info "Identity: $NODE_IDENTITY_PUBKEY"
log_info "Vote: $NODE_VOTE_PUBKEY"
log_info "Ledger: $NODE_LEDGER_DIR"
if [[ -n "$BOOTSTRAP_IDENTITY_PUBKEY" ]]; then
    log_info "Bootstrap validator: $BOOTSTRAP_IDENTITY_PUBKEY"
fi
log_info "Log: $NODE_LOG_FILE"

# Build validator command using array to properly handle paths with spaces
VALIDATOR_ARGS=(
    --identity
    "${NODE_IDENTITY_KEY}"
    --vote-account
    "${NODE_VOTE_KEY}"
    --ledger
    "${NODE_LEDGER_DIR}"
    --gossip-port
    "${NODE_GOSSIP_PORT}"
)

# PRODUCTION PATTERN: Regular validators ALWAYS need entrypoint and known-validator
# Add known-validator (required for private clusters)
if [[ -n "$BOOTSTRAP_IDENTITY_PUBKEY" ]]; then
    VALIDATOR_ARGS+=(
        --known-validator
        "$BOOTSTRAP_IDENTITY_PUBKEY"
    )
    log_info "Added known-validator: $BOOTSTRAP_IDENTITY_PUBKEY"
fi

# Set entrypoint from config or defaults
ENTRYPOINT_HOST="${ENTRYPOINT_HOST:-${BOOTSTRAP_VALIDATOR_IP:-localhost}}"
ENTRYPOINT_PORT="${ENTRYPOINT_PORT:-${BOOTSTRAP_VALIDATOR_GOSSIP_PORT:-8001}}"
ENTRYPOINT="${ENTRYPOINT_HOST}:${ENTRYPOINT_PORT}"

# Add entrypoint (REQUIRED for validators to discover the cluster)
VALIDATOR_ARGS+=(
    --entrypoint
    "${ENTRYPOINT}"
)
log_info "Added entrypoint: ${ENTRYPOINT}"

# Allow private addresses for local clusters
VALIDATOR_ARGS+=(
    --allow-private-addr
)

# Continue with RPC and other settings
VALIDATOR_ARGS+=(
    --rpc-port
    "${NODE_RPC_PORT}"
    --rpc-bind-address
    "${RPC_BIND_ADDRESS:-0.0.0.0}"
    --dynamic-port-range
    "${NODE_DYNAMIC_PORT_START:-8030}-${NODE_DYNAMIC_PORT_END:-8055}"
)

# Metrics - Agave validator doesn't have separate metrics flags
# Metrics are enabled by default and use the RPC port
# If you need separate metrics, configure via RPC settings

# Logging
VALIDATOR_ARGS+=(
    --log
    "${NODE_LOG_FILE}"
)

# Performance tuning (same as bootstrap)
if [[ "${ENABLE_ACCOUNTS_DB_CACHING:-true}" == "true" ]]; then
    VALIDATOR_ARGS+=(
        --accounts-db-cache-limit-mb
        "${ACCOUNTS_DB_CACHE_SIZE_MB:-2048}"
    )
fi

# Snapshot configuration
if [[ -n "${SNAPSHOT_INTERVAL_SLOTS:-}" ]]; then
    VALIDATOR_ARGS+=(
        --full-snapshot-interval-slots
        "${SNAPSHOT_INTERVAL_SLOTS}"
    )
fi

# Account index configuration
if [[ "${ACCOUNT_INDEX_INCLUDE_KEY:-false}" == "true" ]]; then
    VALIDATOR_ARGS+=(--account-index-include-key)
fi

# Additional production flags
VALIDATOR_ARGS+=(
    --limit-ledger-size
    "50000000"
    --no-poh-speed-test
    --no-os-network-limits-test
    --full-rpc-api
    --no-untrusted-rpc
)

# RPC configuration
if [[ "${ENABLE_RPC_COMPRESSION:-true}" == "true" ]]; then
    VALIDATOR_ARGS+=(
        --rpc-max-multiple-accounts
        "${RPC_MAX_MULTIPLE_ACCOUNTS:-100}"
    )
fi

# Export environment
export_validator_env

log_info "Starting validator with command:"
log_info "${AGAVE_BINARY} ${VALIDATOR_ARGS[*]}"
log_info ""

# Start validator in background
# Use a subshell to ensure proper array expansion with paths containing spaces
# Try to set file descriptor limit for the validator process if prlimit is available
if command_exists prlimit; then
    # Use prlimit to set nofile limit for the validator process
    (
        cd "$WORKSPACE_ROOT"
        nohup prlimit --nofile=1000000:1000000 -- "$AGAVE_BINARY" "${VALIDATOR_ARGS[@]}" >> "$NODE_LOG_FILE" 2>&1 &
        echo $! > "$NODE_PID_FILE"
    )
elif command_exists systemd-run; then
    # Use systemd-run to set limits
    (
        cd "$WORKSPACE_ROOT"
        nohup systemd-run --user --scope -p LimitNOFILE=1000000:1000000 -- "$AGAVE_BINARY" "${VALIDATOR_ARGS[@]}" >> "$NODE_LOG_FILE" 2>&1 &
        echo $! > "$NODE_PID_FILE"
    )
else
    # Fallback: try to increase limit in subshell (may not work if hard limit is too low)
    (
        cd "$WORKSPACE_ROOT"
        ulimit -n 1000000 2>/dev/null || true
        nohup "$AGAVE_BINARY" "${VALIDATOR_ARGS[@]}" >> "$NODE_LOG_FILE" 2>&1 &
        echo $! > "$NODE_PID_FILE"
    )
fi
VALIDATOR_PID=$(cat "$NODE_PID_FILE")

# Save PID
echo "$VALIDATOR_PID" > "$NODE_PID_FILE"

log_info "Validator started with PID: $VALIDATOR_PID"
log_info "Logs are being written to: $NODE_LOG_FILE"
log_info ""
log_info "To view logs in real-time:"
log_info "  tail -f $NODE_LOG_FILE"
log_info ""
log_info "To stop the validator:"
log_info "  ./scripts/stop-validator.sh $NODE_NAME"
log_info ""

# Wait a moment and check if process is still running
sleep 3
if ! ps -p "$VALIDATOR_PID" > /dev/null 2>&1; then
    log_error "Validator process died immediately. Check logs: $NODE_LOG_FILE"
    rm -f "$NODE_PID_FILE"
    exit 1
fi

# Wait for validator to be ready
RPC_URL="http://localhost:${NODE_RPC_PORT}"
if wait_for_validator "$RPC_URL" 30; then
    log_success "Validator '$NODE_NAME' is ready!"
    log_info "RPC endpoint: $RPC_URL"
    log_info "Gossip endpoint: ${ENTRYPOINT_HOST}:${NODE_GOSSIP_PORT}"
else
    log_warn "Validator started but may not be fully ready yet"
    log_info "Check logs at: $NODE_LOG_FILE"
fi
