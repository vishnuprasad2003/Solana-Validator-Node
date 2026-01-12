#!/bin/bash
#
# Start Bootstrap Validator
# This script starts the bootstrap validator for the private cluster
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Bootstrap validator configuration
BOOTSTRAP_IDENTITY_KEY="${IDENTITY_KEY_DIR}/bootstrap-identity.json"
BOOTSTRAP_VOTE_KEY="${VOTE_KEY_DIR}/bootstrap-vote.json"
BOOTSTRAP_STAKE_KEY="${STAKE_KEY_DIR}/bootstrap-stake.json"
LEDGER_DIR="${BOOTSTRAP_LEDGER_DIR}"
LOG_FILE="${LOG_DIR}/bootstrap.log"
PID_FILE="${WORKSPACE_ROOT}/bootstrap.pid"

# Ports
GOSSIP_PORT="${GOSSIP_PORT:-8001}"
RPC_PORT="${RPC_PORT:-8899}"
RPC_WEBSOCKET_PORT="${RPC_WEBSOCKET_PORT:-8900}"
TPU_PORT="${TPU_PORT:-8003}"
TPU_FORWARD_PORT="${TPU_FORWARD_PORT:-8004}"
METRICS_PORT="${METRICS_PORT:-9090}"

# Check if validator is already running
if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        log_warn "Bootstrap validator is already running (PID: $PID)"
        log_info "To stop it, run: ./scripts/stop-validator.sh bootstrap"
        exit 0
    else
        log_warn "Stale PID file found, removing..."
        rm -f "$PID_FILE"
    fi
fi

# Validate prerequisites
log_info "Validating prerequisites..."

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

# Check if genesis exists
if [[ ! -f "${LEDGER_DIR}/genesis.bin" ]]; then
    log_error "Genesis not found at ${LEDGER_DIR}/genesis.bin"
    log_info "Please run init-genesis.sh first"
    exit 1
fi

# Validate keypairs
validate_keypair "$BOOTSTRAP_IDENTITY_KEY" || exit 1
validate_keypair "$BOOTSTRAP_VOTE_KEY" || exit 1
validate_keypair "$BOOTSTRAP_STAKE_KEY" || exit 1

# Check ports
for port in "$GOSSIP_PORT" "$RPC_PORT" "$RPC_WEBSOCKET_PORT" "$TPU_PORT" "$TPU_FORWARD_PORT" "$METRICS_PORT"; do
    if ! port_available "$port"; then
        log_error "Port $port is already in use"
        exit 1
    fi
done

# Setup logging
setup_log_rotation "$LOG_FILE"
check_directory "$(dirname "$LOG_FILE")"

# Get public keys for logging
BOOTSTRAP_IDENTITY_PUBKEY=$(get_pubkey "$BOOTSTRAP_IDENTITY_KEY")
BOOTSTRAP_VOTE_PUBKEY=$(get_pubkey "$BOOTSTRAP_VOTE_KEY")

log_info "Starting Bootstrap Validator"
log_info "Identity: $BOOTSTRAP_IDENTITY_PUBKEY"
log_info "Vote: $BOOTSTRAP_VOTE_PUBKEY"
log_info "Ledger: $LEDGER_DIR"
log_info "Log: $LOG_FILE"

# Build validator command using array to properly handle paths with spaces
VALIDATOR_ARGS=(
    --identity
    "${BOOTSTRAP_IDENTITY_KEY}"
    --vote-account
    "${BOOTSTRAP_VOTE_KEY}"
    --ledger
    "${LEDGER_DIR}"
    --gossip-port
    "${GOSSIP_PORT}"
    --rpc-port
    "${RPC_PORT}"
    --rpc-bind-address
    "${RPC_BIND_ADDRESS:-0.0.0.0}"
    --dynamic-port-range
    "${DYNAMIC_PORT_RANGE_START:-8000}-${DYNAMIC_PORT_RANGE_END:-8020}"
)

# Metrics - Agave validator doesn't have separate metrics flags
# Metrics are enabled by default and use the RPC port
# If you need separate metrics, configure via RPC settings

# Logging
VALIDATOR_ARGS+=(
    --log
    "${LOG_FILE}"
)

# Performance tuning
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
    --no-wait-for-vote-to-start-leader
    --allow-private-addr
)

# Add known-validator for validator-1 if it exists (for multi-bootstrap cluster)
VALIDATOR_1_IDENTITY_KEY="${IDENTITY_KEY_DIR}/validator-1-identity.json"
if [[ -f "$VALIDATOR_1_IDENTITY_KEY" ]]; then
    VALIDATOR_1_IDENTITY_PUBKEY=$(get_pubkey "$VALIDATOR_1_IDENTITY_KEY" 2>/dev/null || echo "")
    if [[ -n "$VALIDATOR_1_IDENTITY_PUBKEY" ]]; then
        VALIDATOR_ARGS+=(
            --known-validator
            "$VALIDATOR_1_IDENTITY_PUBKEY"
        )
        log_info "Added validator-1 as known validator for faster cluster discovery"
    fi
fi

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
# Try to set file descriptor and memlock limits for the validator process if prlimit is available
CURRENT_HARD_LIMIT=$(ulimit -Hn 2>/dev/null || echo "0")
CURRENT_MEMLOCK_RAW=$(ulimit -Hl 2>/dev/null || echo "0")

# Handle "unlimited" for memlock
if [[ "$CURRENT_MEMLOCK_RAW" == "unlimited" ]]; then
    CURRENT_MEMLOCK_LIMIT=999999999999  # Very large number to represent unlimited
else
    CURRENT_MEMLOCK_LIMIT=$CURRENT_MEMLOCK_RAW
fi

# Check if limits are sufficient (nofile >= 1000000, memlock >= 2GB or unlimited)
LIMITS_SUFFICIENT=true
if [[ $CURRENT_HARD_LIMIT -lt 1000000 ]]; then
    LIMITS_SUFFICIENT=false
fi
# Check memlock - if unlimited or >= 2GB, it's sufficient
if [[ "$CURRENT_MEMLOCK_RAW" != "unlimited" ]] && [[ $CURRENT_MEMLOCK_LIMIT -lt 2147483648 ]]; then
    LIMITS_SUFFICIENT=false
fi

# Start validator - if limits are sufficient, start normally
# Otherwise try to use prlimit/systemd-run (though they may not work without proper permissions)
if [[ "$LIMITS_SUFFICIENT" == "true" ]]; then
    # Limits are sufficient, start normally
    (
        cd "$WORKSPACE_ROOT"
        nohup "$AGAVE_BINARY" "${VALIDATOR_ARGS[@]}" >> "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
    )
elif command_exists prlimit && [[ $CURRENT_HARD_LIMIT -ge 1000000 ]]; then
    # Try prlimit for nofile only (memlock may fail if hard limit is unlimited)
    log_info "Using prlimit to set nofile limit..."
    (
        cd "$WORKSPACE_ROOT"
        nohup prlimit --nofile=1000000:1000000 -- "$AGAVE_BINARY" "${VALIDATOR_ARGS[@]}" >> "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
    )
else
    # Standard startup - limits should be set via limits.conf
    (
        cd "$WORKSPACE_ROOT"
        nohup "$AGAVE_BINARY" "${VALIDATOR_ARGS[@]}" >> "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
    )
fi
VALIDATOR_PID=$(cat "$PID_FILE")

# Save PID
echo "$VALIDATOR_PID" > "$PID_FILE"

log_info "Validator started with PID: $VALIDATOR_PID"
log_info "Logs are being written to: $LOG_FILE"
log_info ""
log_info "To view logs in real-time:"
log_info "  tail -f $LOG_FILE"
log_info ""
log_info "To stop the validator:"
log_info "  ./scripts/stop-validator.sh bootstrap"
log_info ""

# Wait a moment and check if process is still running
sleep 3
if ! ps -p "$VALIDATOR_PID" > /dev/null 2>&1; then
    log_error "Validator process died immediately. Check logs: $LOG_FILE"
    rm -f "$PID_FILE"
    exit 1
fi

# Wait for validator to be ready
RPC_URL="http://localhost:${RPC_PORT}"
if wait_for_validator "$RPC_URL" 30; then
    log_success "Bootstrap validator is ready!"
    log_info "RPC endpoint: $RPC_URL"
    log_info "Gossip endpoint: ${BOOTSTRAP_VALIDATOR_IP:-127.0.0.1}:${GOSSIP_PORT}"
else
    log_warn "Validator started but may not be fully ready yet"
    log_info "Check logs at: $LOG_FILE"
fi
