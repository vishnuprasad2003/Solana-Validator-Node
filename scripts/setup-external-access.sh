#!/bin/bash
#
# Configure External Access for Azure VM Deployment
# This script helps configure the cluster for external access via public IP
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

PUBLIC_IP="${PUBLIC_IP:-}"
BOOTSTRAP_GOSSIP_PORT="${GOSSIP_PORT:-8001}"
BOOTSTRAP_RPC_PORT="${RPC_PORT:-8899}"

log_info "Configuring External Access for Solana Cluster"

if [[ -z "$PUBLIC_IP" ]]; then
    log_warn "PUBLIC_IP not set. Attempting to detect..."
    
    # Try to detect public IP
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "")
    
    if [[ -z "$PUBLIC_IP" ]]; then
        log_error "Cannot detect public IP. Please set PUBLIC_IP environment variable."
        log_info "Usage: PUBLIC_IP=<your-ip> ./scripts/setup-external-access.sh"
        exit 1
    fi
fi

log_info "Detected/Using Public IP: $PUBLIC_IP"

# Update cluster configuration
log_info "Updating cluster configuration for external access..."

# Backup original config
if [[ -f "${WORKSPACE_ROOT}/configs/cluster.conf" ]]; then
    cp "${WORKSPACE_ROOT}/configs/cluster.conf" \
       "${WORKSPACE_ROOT}/configs/cluster.conf.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Update bootstrap validator IP in config
sed -i "s|BOOTSTRAP_VALIDATOR_IP=.*|BOOTSTRAP_VALIDATOR_IP=\"${PUBLIC_IP}\"|" \
    "${WORKSPACE_ROOT}/configs/cluster.conf"

log_success "Configuration updated"

log_info ""
log_info "External Access Configuration:"
log_info "  Public IP: $PUBLIC_IP"
log_info "  Gossip Port: $BOOTSTRAP_GOSSIP_PORT (UDP/TCP)"
log_info "  RPC Port: $BOOTSTRAP_RPC_PORT (HTTP)"
log_info ""
log_info "Firewall Rules Required (Azure Network Security Group):"
log_info "  - Allow UDP $BOOTSTRAP_GOSSIP_PORT from Any"
log_info "  - Allow TCP $BOOTSTRAP_GOSSIP_PORT from Any"
log_info "  - Allow TCP $BOOTSTRAP_RPC_PORT from Any (for RPC access)"
log_info "  - Allow TCP 8900 from Any (for WebSocket)"
log_info "  - Allow UDP 8000-8025 from Any (dynamic port range)"
log_info ""
log_info "To connect from external clients:"
log_info "  export SOLANA_URL=http://${PUBLIC_IP}:${BOOTSTRAP_RPC_PORT}"
log_info "  solana config set --url http://${PUBLIC_IP}:${BOOTSTRAP_RPC_PORT}"
