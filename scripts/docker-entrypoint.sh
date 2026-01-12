#!/bin/bash
#
# Docker Entrypoint Script
# Handles initialization and startup in containerized environments
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/app}"

# Source common functions
source "${SCRIPT_DIR}/common.sh"

log_info "Docker Entrypoint - Solana Validator"
log_info "Node: ${NODE_NAME:-unknown}"
log_info "Role: ${NODE_ROLE:-unknown}"

# Wait for bootstrap if this is a validator node
if [[ "${NODE_ROLE:-}" == "validator" ]] && [[ -n "${ENTRYPOINT_HOST:-}" ]]; then
    log_info "Waiting for bootstrap validator at ${ENTRYPOINT_HOST}:${ENTRYPOINT_PORT:-8001}..."
    
    max_attempts=60
    attempt=0
    while [[ $attempt -lt $max_attempts ]]; do
        if timeout 3 bash -c "echo > /dev/tcp/${ENTRYPOINT_HOST}/${ENTRYPOINT_PORT:-8001}" 2>/dev/null; then
            log_success "Bootstrap validator is reachable"
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        log_error "Bootstrap validator not reachable after $max_attempts attempts"
        exit 1
    fi
fi

# Execute the provided command
exec "$@"
