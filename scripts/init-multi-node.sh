#!/bin/bash
#
# Initialize Multi-Node Cluster
# This script sets up keys and configurations for multiple validators
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

NUM_VALIDATORS="${1:-2}"

log_info "Initializing Multi-Node Cluster"
log_info "Number of additional validators: $NUM_VALIDATORS"

# Ensure genesis exists
if [[ ! -f "${BOOTSTRAP_LEDGER_DIR}/genesis.bin" ]]; then
    log_error "Genesis not found. Please run init-genesis.sh first."
    exit 1
fi

# Generate keys for each validator
for i in $(seq 1 "$NUM_VALIDATORS"); do
    NODE_NAME="validator-${i}"
    log_info "Setting up $NODE_NAME..."
    
    # Generate keys
    ./scripts/gen-keys.sh "$NODE_NAME" all || {
        log_error "Failed to generate keys for $NODE_NAME"
        exit 1
    }
    
    # Create node configuration
    NODE_CONFIG="${WORKSPACE_ROOT}/configs/${NODE_NAME}.conf"
    if [[ ! -f "$NODE_CONFIG" ]]; then
        cp "${WORKSPACE_ROOT}/configs/node.conf.template" "$NODE_CONFIG"
        
        # Update node-specific settings
        sed -i "s/NODE_NAME=.*/NODE_NAME=\"${NODE_NAME}\"/" "$NODE_CONFIG"
        sed -i "s/NODE_ROLE=.*/NODE_ROLE=\"validator\"/" "$NODE_CONFIG"
        
        # Set unique ports (increment by node index)
        GOSSIP_PORT=$((GOSSIP_PORT + i))
        RPC_PORT=$((RPC_PORT + i))
        RPC_WS_PORT=$((RPC_WEBSOCKET_PORT + i))
        
        sed -i "s/NODE_GOSSIP_PORT=.*/NODE_GOSSIP_PORT=${GOSSIP_PORT}/" "$NODE_CONFIG"
        sed -i "s/NODE_RPC_PORT=.*/NODE_RPC_PORT=${RPC_PORT}/" "$NODE_CONFIG"
        sed -i "s/NODE_RPC_WEBSOCKET_PORT=.*/NODE_RPC_WEBSOCKET_PORT=${RPC_WS_PORT}/" "$NODE_CONFIG"
        
        log_success "Created configuration: $NODE_CONFIG"
    fi
done

log_success "Multi-node cluster initialization complete!"
log_info ""
log_info "Next steps:"
log_info "1. Start bootstrap validator: ./scripts/start-bootstrap.sh"
log_info "2. Start additional validators:"
for i in $(seq 1 "$NUM_VALIDATORS"); do
    log_info "   ./scripts/start-validator.sh validator-${i}"
done
