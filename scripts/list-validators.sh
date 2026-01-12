#!/bin/bash
#
# List Running Validators
# This script lists all running validators and their status
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Checking running validators..."

# Check bootstrap validator
BOOTSTRAP_PID_FILE="${WORKSPACE_ROOT}/bootstrap.pid"
if [[ -f "$BOOTSTRAP_PID_FILE" ]]; then
    PID=$(cat "$BOOTSTRAP_PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        log_success "Bootstrap validator: RUNNING (PID: $PID)"
        
        # Try to get RPC info
        RPC_URL="http://localhost:${RPC_PORT:-8899}"
        if command_exists curl; then
            HEALTH=$(curl -s -X POST "$RPC_URL" \
                -H "Content-Type: application/json" \
                -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' 2>/dev/null || echo "unreachable")
            if [[ "$HEALTH" != "unreachable" ]]; then
                log_info "  RPC Health: OK"
            else
                log_warn "  RPC Health: Unreachable"
            fi
        fi
    else
        log_warn "Bootstrap validator: STOPPED (stale PID file)"
        rm -f "$BOOTSTRAP_PID_FILE"
    fi
else
    log_info "Bootstrap validator: NOT RUNNING"
fi

# Check additional validators
VALIDATOR_COUNT=0
for pid_file in "${WORKSPACE_ROOT}"/validator-*.pid; do
    if [[ -f "$pid_file" ]]; then
        NODE_NAME=$(basename "$pid_file" .pid)
        PID=$(cat "$pid_file")
        if ps -p "$PID" > /dev/null 2>&1; then
            VALIDATOR_COUNT=$((VALIDATOR_COUNT + 1))
            log_success "${NODE_NAME}: RUNNING (PID: $PID)"
        else
            log_warn "${NODE_NAME}: STOPPED (stale PID file)"
            rm -f "$pid_file"
        fi
    fi
done

if [[ $VALIDATOR_COUNT -eq 0 ]]; then
    log_info "No additional validators running"
else
    log_info "Total additional validators: $VALIDATOR_COUNT"
fi

# Summary
TOTAL_RUNNING=$(ps aux | grep -cE "[a]gave-validator|[s]olana-validator" || echo "0")
if [[ -z "$TOTAL_RUNNING" ]]; then
    TOTAL_RUNNING=0
fi
log_info ""
log_info "Total validator processes: $TOTAL_RUNNING"
