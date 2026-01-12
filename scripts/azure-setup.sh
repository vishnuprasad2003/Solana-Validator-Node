#!/bin/bash
#
# Azure VM Setup Script
# Complete setup for Azure VM deployment
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

PUBLIC_IP="${PUBLIC_IP:-}"
NUM_VALIDATORS="${NUM_VALIDATORS:-2}"

log_info "Azure VM Setup for Solana Private Cluster"
log_info "=========================================="

# Check if running as root for some operations
if [[ $EUID -eq 0 ]]; then
    log_warn "Running as root. Some operations may need non-root user."
fi

# Step 1: Configure system limits
log_info ""
log_info "Step 1: Configuring system limits..."
if sudo -n true 2>/dev/null; then
    sudo ./scripts/configure-limits.sh || {
        log_error "Failed to configure system limits"
        exit 1
    }
else
    log_warn "Cannot run sudo without password. Please run manually:"
    log_info "  sudo ./scripts/configure-limits.sh"
    read -p "Press Enter after configuring limits..."
fi

# Step 2: Install Agave validator
log_info ""
log_info "Step 2: Installing Agave validator..."
./scripts/install.sh || {
    log_error "Failed to install Agave validator"
    exit 1
}

# Step 3: Initialize genesis
log_info ""
log_info "Step 3: Initializing genesis..."
if [[ ! -f "${BOOTSTRAP_LEDGER_DIR}/genesis.bin" ]]; then
    ./scripts/init-genesis.sh || {
        log_error "Failed to initialize genesis"
        exit 1
    }
else
    log_warn "Genesis already exists, skipping..."
fi

# Step 4: Configure external access
if [[ -n "$PUBLIC_IP" ]]; then
    log_info ""
    log_info "Step 4: Configuring external access..."
    PUBLIC_IP="$PUBLIC_IP" ./scripts/setup-external-access.sh || {
        log_error "Failed to configure external access"
        exit 1
    }
else
    log_warn "PUBLIC_IP not set, skipping external access configuration"
    log_info "To configure later: PUBLIC_IP=<ip> ./scripts/setup-external-access.sh"
fi

# Step 5: Initialize multi-node cluster
if [[ "${NUM_VALIDATORS:-0}" -gt 0 ]]; then
    log_info ""
    log_info "Step 5: Initializing multi-node cluster ($NUM_VALIDATORS validators)..."
    ./scripts/init-multi-node.sh "$NUM_VALIDATORS" || {
        log_error "Failed to initialize multi-node cluster"
        exit 1
    }
fi

log_success "Azure VM setup complete!"
log_info ""
log_info "Next steps:"
log_info "1. Log out and log back in for system limits to take effect"
log_info "2. Start bootstrap validator: make start-bootstrap"
if [[ "${NUM_VALIDATORS:-0}" -gt 0 ]]; then
    log_info "3. Start additional validators:"
    for i in $(seq 1 "$NUM_VALIDATORS"); do
        log_info "   make start-validator NODE=validator-${i}"
    done
fi
log_info ""
log_info "For external access, configure Azure NSG firewall rules (see DEPLOYMENT.md)"
