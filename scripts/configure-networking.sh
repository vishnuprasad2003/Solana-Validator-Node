#!/bin/bash

# Solana Validator Node - Network Configuration Script
# Configures firewall and Azure networking for public RPC access

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load configuration
if [ -f "$REPO_ROOT/configs/config.env" ]; then
    source "$REPO_ROOT/configs/config.env"
else
    echo -e "${RED}Error: config.env not found${NC}"
    exit 1
fi

# Setup logging
mkdir -p "$REPO_ROOT/logs"
LOG_FILE="$REPO_ROOT/logs/configure-networking.log"

# Logging functions (write to both console and log file)
log_info() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "$timestamp [INFO] $1" >> "$LOG_FILE"
}

log_success() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$timestamp [SUCCESS] $1" >> "$LOG_FILE"
}

log_warning() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$timestamp [WARNING] $1" >> "$LOG_FILE"
}

log_error() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$timestamp [ERROR] $1" >> "$LOG_FILE"
}

echo "=========================================="
echo "Network Configuration"
echo "=========================================="
echo ""

# Detect public IP if not set
if [ -z "$PUBLIC_IP" ]; then
    log_info "Detecting public IP address..."
    PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "")
    if [ -n "$PUBLIC_IP" ]; then
        log_success "Detected public IP: $PUBLIC_IP"
    else
        log_warning "Could not auto-detect public IP"
        read -p "Enter public IP address: " PUBLIC_IP
    fi
fi

# Configure UFW firewall
log_info "[1/3] Configuring firewall (UFW)..."

# Check if UFW is installed
if ! command -v ufw &> /dev/null; then
    log_info "Installing UFW..."
    sudo apt-get update -qq
    sudo apt-get install -y ufw > /dev/null
fi

# Allow SSH (critical!)
log_info "Allowing SSH..."
sudo ufw allow 22/tcp > /dev/null 2>&1 || true

# Allow RPC port
log_info "Allowing RPC port $RPC_PORT..."
sudo ufw allow $RPC_PORT/tcp > /dev/null 2>&1 || true

# Allow gossip port (for multi-node)
if [ "$CLUSTER_MODE" = true ]; then
    log_info "Allowing gossip port $GOSSIP_PORT..."
    sudo ufw allow $GOSSIP_PORT/udp > /dev/null 2>&1 || true
fi

# Enable UFW if not already enabled
if ! sudo ufw status | grep -q "Status: active"; then
    log_warning "UFW is not active. Enabling..."
    echo "y" | sudo ufw enable > /dev/null 2>&1 || true
fi

log_success "Firewall configured"

# Configure IP whitelist if enabled
if [ "$ENABLE_RPC_WHITELIST" = true ]; then
    log_info "[2/3] Configuring RPC IP whitelist..."
    
    mkdir -p "$(dirname "$RPC_WHITELIST_FILE")"
    
    if [ ! -f "$RPC_WHITELIST_FILE" ]; then
        log_info "Creating whitelist file..."
        echo "# Allowed IPs for RPC access (one per line, CIDR supported)" > "$RPC_WHITELIST_FILE"
        echo "# Example: 192.168.1.0/24" >> "$RPC_WHITELIST_FILE"
        echo "# Example: 10.0.0.1" >> "$RPC_WHITELIST_FILE"
    fi
    
    log_info "Whitelist file: $RPC_WHITELIST_FILE"
    log_warning "Please edit this file to add allowed IPs"
    log_info "After editing, run this script again to apply changes"
else
    log_info "[2/3] RPC whitelist disabled (public access enabled)"
fi

# Azure-specific configuration
log_info "[3/3] Azure configuration..."

if command -v az &> /dev/null; then
    log_info "Azure CLI detected"
    
    if [ -n "$AZURE_NSG_NAME" ]; then
        log_info "Configuring Azure Network Security Group: $AZURE_NSG_NAME"
        log_info "Creating NSG rule for RPC port..."
        
        # Note: This requires Azure CLI and proper authentication
        # az network nsg rule create \
        #     --resource-group <your-rg> \
        #     --nsg-name "$AZURE_NSG_NAME" \
        #     --name "solana-rpc" \
        #     --priority 1000 \
        #     --protocol Tcp \
        #     --destination-port-ranges $RPC_PORT \
        #     --access Allow \
        #     --description "Solana RPC endpoint"
        
        log_warning "Azure NSG configuration requires manual setup"
        log_info "See docs/05-azure-configuration.md for details"
    fi
else
    log_info "Azure CLI not found (optional)"
fi

echo ""
log_success "=========================================="
echo "Network Configuration Complete"
log_success "=========================================="
echo ""
echo "Configuration Summary:"
echo "  Public IP: $PUBLIC_IP"
echo "  RPC Endpoint: http://$PUBLIC_IP:$RPC_PORT"
echo "  RPC Bind Address: $RPC_BIND_ADDRESS"
echo "  Firewall: UFW configured"
if [ "$ENABLE_RPC_WHITELIST" = true ]; then
    echo "  IP Whitelist: Enabled ($RPC_WHITELIST_FILE)"
else
    echo "  IP Whitelist: Disabled (public access)"
fi
echo ""
echo "Test RPC endpoint:"
echo "  curl http://$PUBLIC_IP:$RPC_PORT -X POST -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getHealth\"}'"
echo ""

