#!/bin/bash
#
# Stop Validator Safely
# This script stops a running validator gracefully
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Parse arguments
NODE_NAME="${1:-bootstrap}"
SIGNAL="${2:-TERM}"  # TERM (graceful) or KILL (force)

# Determine PID file
if [[ "$NODE_NAME" == "bootstrap" ]]; then
    PID_FILE="${WORKSPACE_ROOT}/bootstrap.pid"
    LOG_FILE="${LOG_DIR}/bootstrap.log"
else
    PID_FILE="${WORKSPACE_ROOT}/${NODE_NAME}.pid"
    LOG_FILE="${LOG_DIR}/${NODE_NAME}.log"
fi

log_info "Stopping validator: $NODE_NAME"

# Check if PID file exists
if [[ ! -f "$PID_FILE" ]]; then
    log_warn "PID file not found: $PID_FILE"
    log_info "Validator may not be running or was started differently"
    
    # Try to find process by name
    if command_exists pgrep; then
        PIDS=$(pgrep -f "(agave-validator|solana-validator).*--identity.*${NODE_NAME}" || true)
        if [[ -n "$PIDS" ]]; then
            log_info "Found validator processes: $PIDS"
            read -p "Do you want to stop these processes? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                for pid in $PIDS; do
                    log_info "Stopping process $pid..."
                    kill -"$SIGNAL" "$pid" 2>/dev/null || true
                done
            fi
        else
            log_info "No running validator processes found"
        fi
    fi
    exit 0
fi

# Read PID
PID=$(cat "$PID_FILE")

# Check if process is running
if ! ps -p "$PID" > /dev/null 2>&1; then
    log_warn "Process $PID is not running (stale PID file)"
    rm -f "$PID_FILE"
    exit 0
fi

log_info "Found validator process: $PID"

# Send signal
if [[ "$SIGNAL" == "KILL" ]]; then
    log_warn "Force killing validator (SIGKILL)..."
    kill -9 "$PID" 2>/dev/null || {
        log_error "Failed to kill process $PID"
        exit 1
    }
else
    log_info "Stopping validator gracefully (SIGTERM)..."
    kill -TERM "$PID" 2>/dev/null || {
        log_error "Failed to send TERM signal to process $PID"
        exit 1
    }
    
    # Wait for graceful shutdown (max 30 seconds)
    local wait_time=0
    local max_wait=30
    while ps -p "$PID" > /dev/null 2>&1 && [[ $wait_time -lt $max_wait ]]; do
        sleep 1
        wait_time=$((wait_time + 1))
        if [[ $((wait_time % 5)) -eq 0 ]]; then
            log_info "Waiting for validator to stop... (${wait_time}s/${max_wait}s)"
        fi
    done
    
    # Check if still running
    if ps -p "$PID" > /dev/null 2>&1; then
        log_warn "Validator did not stop gracefully, force killing..."
        kill -9 "$PID" 2>/dev/null || true
    fi
fi

# Verify process is stopped
sleep 1
if ps -p "$PID" > /dev/null 2>&1; then
    log_error "Failed to stop validator process $PID"
    exit 1
fi

# Remove PID file
rm -f "$PID_FILE"

log_success "Validator '$NODE_NAME' stopped successfully"
log_info "Logs are available at: $LOG_FILE"
