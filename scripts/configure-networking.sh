#!/usr/bin/env bash
#
# Solana Validator Node - Network Configuration Script
# Configures firewall and Azure networking for public RPC access
# Supports multiple firewall tools: UFW, firewalld, iptables
#

set -euo pipefail

# Script directory (handles spaces in path)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load common library
# shellcheck source=common.sh
if ! source "$SCRIPT_DIR/common.sh"; then
    echo "Error: Failed to load common library" >&2
    exit 1
fi

# Initialize common library
init_common

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Load configuration
if ! safe_source "$REPO_ROOT/configs/config.env"; then
    echo -e "${RED}Error: config.env not found${NC}" >&2
    exit 1
fi

# Setup logging
safe_mkdir "$REPO_ROOT/logs"
readonly LOG_FILE="$REPO_ROOT/logs/configure-networking.log"

# Override logging functions from common.sh
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

# Check prerequisites
check_sudo

echo "=========================================="
echo "Network Configuration"
echo "=========================================="
echo ""

# Detect public IP if not set
if [ -z "${PUBLIC_IP:-}" ]; then
    log_info "Detecting public IP address..."
    if PUBLIC_IP=$(detect_public_ip); then
        log_success "Detected public IP: $PUBLIC_IP"
    else
        log_warning "Could not auto-detect public IP"
        read -p "Enter public IP address: " PUBLIC_IP
    fi
fi

# Configure firewall (supports multiple firewall tools)
log_info "[1/3] Configuring firewall..."

configure_ufw() {
    log_info "Using UFW firewall..."
    
    # Install UFW if not available
    if ! command_exists ufw; then
        log_info "Installing UFW..."
        case "$PACKAGE_MANAGER" in
            apt)
                install_packages ufw
                ;;
            yum|dnf)
                install_packages ufw
                ;;
            *)
                log_warning "UFW not available via package manager. Please install manually."
                return 1
                ;;
        esac
    fi
    
    # Allow SSH (critical!)
    log_info "Allowing SSH..."
    sudo env HOME="$HOME" ufw allow 22/tcp > /dev/null 2>&1 || true
    
    # Allow RPC port
    log_info "Allowing RPC port $RPC_PORT..."
    sudo env HOME="$HOME" ufw allow "$RPC_PORT/tcp" > /dev/null 2>&1 || true
    
    # Allow gossip port (for multi-node)
    if [ "${CLUSTER_MODE:-false}" = "true" ]; then
        log_info "Allowing gossip port $GOSSIP_PORT..."
        sudo env HOME="$HOME" ufw allow "$GOSSIP_PORT/udp" > /dev/null 2>&1 || true
    fi
    
    # Enable UFW if not already enabled
    if ! sudo env HOME="$HOME" ufw status 2>/dev/null | grep -q "Status: active"; then
        log_warning "UFW is not active. Enabling..."
        echo "y" | sudo env HOME="$HOME" ufw enable > /dev/null 2>&1 || true
    fi
    
    return 0
}

configure_firewalld() {
    log_info "Using firewalld firewall..."
    
    # Install firewalld if not available
    if ! command_exists firewall-cmd; then
        log_info "Installing firewalld..."
        install_packages firewalld
        sudo systemctl enable firewalld > /dev/null 2>&1 || true
        sudo systemctl start firewalld > /dev/null 2>&1 || true
    fi
    
    # Ensure firewalld is running
    if ! sudo systemctl is-active --quiet firewalld; then
        sudo systemctl start firewalld > /dev/null 2>&1 || true
    fi
    
    # Allow SSH (critical!)
    log_info "Allowing SSH..."
    sudo firewall-cmd --permanent --add-service=ssh > /dev/null 2>&1 || true
    
    # Allow RPC port
    log_info "Allowing RPC port $RPC_PORT..."
    sudo firewall-cmd --permanent --add-port="$RPC_PORT/tcp" > /dev/null 2>&1 || true
    
    # Allow gossip port (for multi-node)
    if [ "${CLUSTER_MODE:-false}" = "true" ]; then
        log_info "Allowing gossip port $GOSSIP_PORT..."
        sudo firewall-cmd --permanent --add-port="$GOSSIP_PORT/udp" > /dev/null 2>&1 || true
    fi
    
    # Reload firewall
    sudo firewall-cmd --reload > /dev/null 2>&1 || true
    
    return 0
}

configure_iptables() {
    log_info "Using iptables firewall..."
    
    # Allow SSH (critical!)
    log_info "Allowing SSH..."
    sudo iptables -I INPUT -p tcp --dport 22 -j ACCEPT > /dev/null 2>&1 || true
    
    # Allow RPC port
    log_info "Allowing RPC port $RPC_PORT..."
    sudo iptables -I INPUT -p tcp --dport "$RPC_PORT" -j ACCEPT > /dev/null 2>&1 || true
    
    # Allow gossip port (for multi-node)
    if [ "${CLUSTER_MODE:-false}" = "true" ]; then
        log_info "Allowing gossip port $GOSSIP_PORT..."
        sudo iptables -I INPUT -p udp --dport "$GOSSIP_PORT" -j ACCEPT > /dev/null 2>&1 || true
    fi
    
    # Save iptables rules (distribution-specific)
    case "$OS_FAMILY" in
        debian)
            if command_exists iptables-save; then
                sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
                sudo sh -c "iptables-save > /etc/iptables/rules.v4" 2>/dev/null || true
            fi
            ;;
        rhel)
            if command_exists iptables-save; then
                sudo service iptables save > /dev/null 2>&1 || \
                sudo iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
            fi
            ;;
    esac
    
    return 0
}

# Configure firewall based on detected tool
FIREWALL_CONFIGURED=false
case "$FIREWALL" in
    ufw)
        if configure_ufw; then
            FIREWALL_CONFIGURED=true
        fi
        ;;
    firewalld)
        if configure_firewalld; then
            FIREWALL_CONFIGURED=true
        fi
        ;;
    iptables)
        if configure_iptables; then
            FIREWALL_CONFIGURED=true
        fi
        ;;
    none)
        log_warning "No firewall tool detected. Please configure firewall manually."
        log_info "Required ports:"
        log_info "  - SSH: 22/tcp"
        log_info "  - RPC: $RPC_PORT/tcp"
        if [ "${CLUSTER_MODE:-false}" = "true" ]; then
            log_info "  - Gossip: $GOSSIP_PORT/udp"
        fi
        ;;
esac

if [ "$FIREWALL_CONFIGURED" = true ]; then
    log_success "Firewall configured using $FIREWALL"
else
    log_warning "Firewall configuration may be incomplete"
fi

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
FORMATTED_IP=$(format_ip_for_url "${PUBLIC_IP:-}")
echo "Configuration Summary:"
echo "  Public IP: $PUBLIC_IP"
echo "  RPC Endpoint: http://$FORMATTED_IP:$RPC_PORT"
echo "  RPC Bind Address: $RPC_BIND_ADDRESS"
echo "  Firewall: UFW configured"
if [ "$ENABLE_RPC_WHITELIST" = true ]; then
    echo "  IP Whitelist: Enabled ($RPC_WHITELIST_FILE)"
else
    echo "  IP Whitelist: Disabled (public access)"
fi
echo ""
echo "Test RPC endpoint:"
echo "  curl http://$FORMATTED_IP:$RPC_PORT -X POST -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getHealth\"}'"
echo ""

