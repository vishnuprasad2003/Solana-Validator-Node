#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Start a Solana validator node
# Usage: ./scripts/start-validator.sh <config-file>
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
source "$(dirname "$0")/common.sh"

CONFIG="${1:?Usage: $0 <config-file>}"
[[ ! -f "$CONFIG" ]] && { log_error "Config not found: $CONFIG"; exit 1; }
source "$CONFIG"
ensure_dirs

log_info "Starting ${NODE_NAME} (type: ${NODE_TYPE})"

# ── Pre-flight ──────────────────────────────────────────────────────────────
[[ ! -f "$IDENTITY_KEY" ]] && { log_error "Identity key not found: $IDENTITY_KEY"; exit 1; }
[[ ! -f "$VOTE_KEY" ]]     && { log_error "Vote key not found: $VOTE_KEY"; exit 1; }

VALIDATOR=$(get_validator_bin) || exit 1
mkdir -p "$LEDGER_DIR" "$(dirname "$LOG_FILE")"

# ── Build command ───────────────────────────────────────────────────────────
CMD=("$VALIDATOR"
    --identity "$IDENTITY_KEY"
    --vote-account "$VOTE_KEY"
    --ledger "$LEDGER_DIR"
    --gossip-port "$GOSSIP_PORT"
    --rpc-port "$RPC_PORT"
    --rpc-bind-address "$RPC_BIND_ADDRESS"
    --dynamic-port-range "${DYNAMIC_PORT_RANGE_START}-${DYNAMIC_PORT_RANGE_END}"
    --log "$LOG_FILE"
    --full-snapshot-interval-slots 400
)

# Ledger size limit
if [[ -n "${LIMIT_LEDGER_SIZE:-}" ]] && \
   [[ "$LIMIT_LEDGER_SIZE" != "unlimited" ]] && \
   [[ "$LIMIT_LEDGER_SIZE" != "0" ]]; then
    CMD+=(--limit-ledger-size "$LIMIT_LEDGER_SIZE")
fi

CMD+=(--no-poh-speed-test --no-os-network-limits-test --full-rpc-api --allow-private-addr)

if [[ "$NODE_TYPE" == "bootstrap" ]]; then
    CMD+=(--no-wait-for-vote-to-start-leader)
else
    [[ -n "${ENTRYPOINT:-}" ]]           && CMD+=(--entrypoint "$ENTRYPOINT")
    [[ -n "${KNOWN_VALIDATOR:-}" ]]      && CMD+=(--known-validator "$KNOWN_VALIDATOR")
    [[ -n "${EXPECTED_GENESIS_HASH:-}" ]] && CMD+=(--expected-genesis-hash "$EXPECTED_GENESIS_HASH")
fi

log_info "Command: ${CMD[*]}"

# ── Launch ──────────────────────────────────────────────────────────────────
if [[ "${WORKSPACE_ROOT:-}" == "/app" ]]; then
    # Docker: foreground
    exec "${CMD[@]}"
else
    "${CMD[@]}" &
    echo "$!" > "$PID_FILE"
    log_success "Started PID $(cat "$PID_FILE")"
    log_info "Logs: tail -f $LOG_FILE"
    log_info "RPC:  http://${RPC_BIND_ADDRESS}:${RPC_PORT}"
    wait_for_rpc "http://127.0.0.1:${RPC_PORT}" 30 && log_success "RPC ready" || log_warn "RPC not ready yet"
fi
