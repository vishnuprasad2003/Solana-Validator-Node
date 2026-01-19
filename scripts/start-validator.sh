#!/bin/bash
# Start validator node
# Usage: ./scripts/start-validator.sh [config-file]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

CONFIG="${1:-${WORKSPACE_ROOT}/configs/node.conf}"
[[ ! -f "$CONFIG" ]] && { log_error "Config not found: $CONFIG"; exit 1; }
source "$CONFIG"

log_info "Starting: $NODE_NAME (type: $NODE_TYPE)"

# Resolve paths
IDENTITY="${WORKSPACE_ROOT}/${IDENTITY_KEY}"
VOTE="${WORKSPACE_ROOT}/${VOTE_KEY}"
LEDGER="${WORKSPACE_ROOT}/${LEDGER_DIR}"
LOG="${WORKSPACE_ROOT}/${LOG_FILE}"

[[ ! -f "$IDENTITY" ]] && { log_error "Identity key not found: $IDENTITY"; exit 1; }
[[ ! -f "$VOTE" ]] && { log_error "Vote key not found: $VOTE"; exit 1; }

mkdir -p "$LEDGER" "$(dirname "$LOG")"

VALIDATOR=$(get_validator_bin) || exit 1

# Build command - conditionally add limit-ledger-size flag
CMD=("$VALIDATOR"
    --identity "$IDENTITY"
    --vote-account "$VOTE"
    --ledger "$LEDGER"
    --gossip-port "$GOSSIP_PORT"
    --rpc-port "$RPC_PORT"
    --rpc-bind-address "$RPC_BIND_ADDRESS"
    --dynamic-port-range "${DYNAMIC_PORT_RANGE_START}-${DYNAMIC_PORT_RANGE_END}"
    --log "$LOG"
    --full-snapshot-interval-slots 400)

# Add --limit-ledger-size only if LIMIT_LEDGER_SIZE is set and not "unlimited" or "0"
if [[ -n "${LIMIT_LEDGER_SIZE:-}" ]] && [[ "${LIMIT_LEDGER_SIZE}" != "unlimited" ]] && [[ "${LIMIT_LEDGER_SIZE}" != "0" ]]; then
    CMD+=(--limit-ledger-size "$LIMIT_LEDGER_SIZE")
fi

CMD+=(--no-poh-speed-test
    --no-os-network-limits-test
    --full-rpc-api
    --allow-private-addr)

if [[ "$NODE_TYPE" == "bootstrap" ]]; then
    CMD+=(--no-wait-for-vote-to-start-leader)
else
    [[ -n "${ENTRYPOINT:-}" ]] && CMD+=(--entrypoint "$ENTRYPOINT")
    [[ -n "${KNOWN_VALIDATOR:-}" ]] && CMD+=(--known-validator "$KNOWN_VALIDATOR")
    [[ -n "${EXPECTED_GENESIS_HASH:-}" ]] && CMD+=(--expected-genesis-hash "$EXPECTED_GENESIS_HASH")
fi

log_info "Command: ${CMD[*]}"

# Check if running in Docker (WORKSPACE_ROOT=/app) or locally
if [[ "${WORKSPACE_ROOT:-}" == "/app" ]]; then
    # Docker: run in foreground (exec replaces shell process)
    log_info "Running in Docker mode (foreground)"
    exec "${CMD[@]}"
else
    # Local: run in background
    "${CMD[@]}" &
    PID=$!
    echo "$PID" > "${WORKSPACE_ROOT}/${NODE_NAME}.pid"
    log_success "Started PID: $PID"
    log_info "Logs: $LOG"
    log_info "RPC: http://${RPC_BIND_ADDRESS}:${RPC_PORT}"
    wait_for_rpc "http://127.0.0.1:${RPC_PORT}" 30 && log_success "RPC ready!" || log_warn "RPC not ready yet"
fi
