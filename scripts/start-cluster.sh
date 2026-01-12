#!/bin/bash
#
# Production-Grade Cluster Startup Script
# Starts bootstrap validator, waits for snapshots, then starts additional validators
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
BOOTSTRAP_LEDGER_DIR="${BOOTSTRAP_LEDGER_DIR:-${LEDGER_BASE_DIR}/bootstrap}"
SNAPSHOT_WAIT_TIMEOUT="${SNAPSHOT_WAIT_TIMEOUT:-300}"  # 5 minutes
SNAPSHOT_CHECK_INTERVAL=5  # Check every 5 seconds
VALIDATORS_TO_START="${VALIDATORS_TO_START:-validator-1}"  # Space-separated list

log_info "Starting Production-Grade Solana Cluster"
log_info "This script follows the standard single-bootstrap pattern"

# Step 1: Start Bootstrap Validator
log_info "Step 1: Starting bootstrap validator..."
if ! "${SCRIPT_DIR}/start-bootstrap.sh"; then
    log_error "Failed to start bootstrap validator"
    exit 1
fi

# Step 2: Wait for Bootstrap to be Ready
log_info "Step 2: Waiting for bootstrap validator to be ready..."
BOOTSTRAP_READY=false
for i in {1..30}; do
    if curl -s -X POST http://localhost:8899 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' \
        > /dev/null 2>&1; then
        BOOTSTRAP_READY=true
        break
    fi
    sleep 2
done

if [[ "$BOOTSTRAP_READY" == "false" ]]; then
    log_error "Bootstrap validator failed to become ready"
    exit 1
fi
log_success "Bootstrap validator is ready"

# Step 3: Wait for Snapshots
log_info "Step 3: Waiting for bootstrap to produce snapshots..."
log_info "This is required for additional validators to join the cluster"
log_info "Timeout: ${SNAPSHOT_WAIT_TIMEOUT} seconds"

SNAPSHOT_FOUND=false
ELAPSED=0
while [[ $ELAPSED -lt $SNAPSHOT_WAIT_TIMEOUT ]]; do
    # Check for snapshot files (both in snapshots/ subdirectory and root ledger directory)
    LATEST_SNAPSHOT=$(find "${BOOTSTRAP_LEDGER_DIR}" -maxdepth 1 -name "snapshot-*.tar.zst" -type f 2>/dev/null | sort -r | head -1)
    if [[ -z "$LATEST_SNAPSHOT" ]]; then
        LATEST_SNAPSHOT=$(find "${BOOTSTRAP_LEDGER_DIR}/snapshots" -name "*.tar.zst" -type f 2>/dev/null | sort -r | head -1)
    fi
    
    if [[ -n "$LATEST_SNAPSHOT" ]] && [[ -f "$LATEST_SNAPSHOT" ]]; then
        SNAPSHOT_FOUND=true
        log_success "Snapshot found: $(basename "$LATEST_SNAPSHOT")"
        break
    fi
    
    # Also check via RPC
    SNAPSHOT_SLOT=$(curl -s -X POST http://localhost:8899 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getHighestSnapshotSlot"}' \
        2>/dev/null | jq -r '.result.slot // empty' 2>/dev/null || echo "")
    
    if [[ -n "$SNAPSHOT_SLOT" ]] && [[ "$SNAPSHOT_SLOT" != "null" ]] && [[ "$SNAPSHOT_SLOT" != "0" ]]; then
        SNAPSHOT_FOUND=true
        log_success "Snapshot slot found: $SNAPSHOT_SLOT"
        break
    fi
    
    CURRENT_SLOT=$(curl -s -X POST http://localhost:8899 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' \
        2>/dev/null | jq -r '.result // 0' 2>/dev/null || echo "0")
    
    log_info "Waiting for snapshot... (Current slot: $CURRENT_SLOT, Elapsed: ${ELAPSED}s)"
    sleep $SNAPSHOT_CHECK_INTERVAL
    ELAPSED=$((ELAPSED + SNAPSHOT_CHECK_INTERVAL))
done

if [[ "$SNAPSHOT_FOUND" == "false" ]]; then
    log_error "Timeout waiting for snapshot. Bootstrap may not be producing blocks."
    log_info "Check bootstrap logs: tail -f logs/bootstrap.log"
    log_info "You can manually start validators later when snapshots are available."
    exit 1
fi

# Step 4: Deploy Essential Programs (if not already in genesis)
log_info "Step 4: Checking essential programs..."
if [[ -f "${SCRIPT_DIR}/deploy-essential-programs.sh" ]]; then
    # Check if Token program exists
    TOKEN_PROGRAM="TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    if ! curl -s -X POST http://localhost:8899 \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getAccountInfo\",\"params\":[\"$TOKEN_PROGRAM\",{\"encoding\":\"base64\"}]}" \
        | jq -e '.result.value' >/dev/null 2>&1; then
        log_info "Essential programs not found. Deploying..."
        if "${SCRIPT_DIR}/deploy-essential-programs.sh"; then
            log_success "Essential programs deployed"
        else
            log_warn "Program deployment failed. You can deploy manually later with: make deploy-programs"
        fi
    else
        log_info "Essential programs already available"
    fi
else
    log_warn "deploy-essential-programs.sh not found. Skipping program deployment."
fi

# Step 5: Start Additional Validators
log_info "Step 4: Starting additional validators..."
for VALIDATOR_NAME in $VALIDATORS_TO_START; do
    log_info "Starting validator: $VALIDATOR_NAME"
    if "${SCRIPT_DIR}/start-validator.sh" "$VALIDATOR_NAME"; then
        log_success "Validator $VALIDATOR_NAME started successfully"
    else
        log_error "Failed to start validator $VALIDATOR_NAME"
        # Continue with other validators
    fi
done

# Step 6: Verify Cluster
log_info "Step 5: Verifying cluster..."
sleep 10  # Give validators time to start

CLUSTER_NODES=$(curl -s -X POST http://localhost:8899 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' \
    2>/dev/null | jq -r '.result | length' 2>/dev/null || echo "0")

log_success "Cluster verification complete"
log_info "Cluster nodes detected: $CLUSTER_NODES"
log_info ""
log_info "Cluster is ready!"
log_info "Bootstrap RPC: http://localhost:8899"
log_info ""
log_info "To check cluster status:"
log_info "  make list"
log_info "  curl http://localhost:8899 -X POST -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getClusterNodes\"}'"
