#!/usr/bin/env bash

# Solana Validator Node - Verification Script
# Verifies that the cluster is properly set up and running

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

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Setup logging
mkdir -p "$REPO_ROOT/logs"
LOG_FILE="$REPO_ROOT/logs/verify-setup.log"

# Logging functions (write to both console and log file)
log_info() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "$timestamp [INFO] $1" >> "$LOG_FILE"
}

log_success() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${GREEN}[✓]${NC} $1"
    echo "$timestamp [OK] $1" >> "$LOG_FILE"
}

log_warning() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${YELLOW}[⚠]${NC} $1"
    echo "$timestamp [WARN] $1" >> "$LOG_FILE"
}

log_error() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${RED}[✗]${NC} $1"
    echo "$timestamp [ERROR] $1" >> "$LOG_FILE"
}

echo "=========================================="
echo "Solana Cluster Verification"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

# Check Solana installation
log_info "Checking Solana installation..."
if command -v solana &> /dev/null; then
    VERSION=$(solana --version 2>/dev/null | head -1)
    log_success "Solana CLI installed: $VERSION"
else
    log_error "Solana CLI not found"
    ERRORS=$((ERRORS + 1))
fi

# Check Rust installation
log_info "Checking Rust installation..."
if command -v rustc &> /dev/null; then
    RUST_VERSION=$(rustc --version)
    log_success "Rust installed: $RUST_VERSION"
else
    log_error "Rust not found"
    ERRORS=$((ERRORS + 1))
fi

# Check validator keypair
log_info "Checking validator keypair..."
VALIDATOR_KEYPAIR="$HOME/.config/solana/validator-keypair.json"
if [ -f "$VALIDATOR_KEYPAIR" ]; then
    VALIDATOR_ADDRESS=$(solana address -k "$VALIDATOR_KEYPAIR" 2>/dev/null || echo "N/A")
    log_success "Validator keypair found: $VALIDATOR_ADDRESS"
else
    log_error "Validator keypair not found"
    ERRORS=$((ERRORS + 1))
fi

# Check ledger directory
log_info "Checking ledger directory..."
if [ -d "$LEDGER_DIR" ]; then
    log_success "Ledger directory exists: $LEDGER_DIR"
else
    log_warning "Ledger directory not found (will be created on first start)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check validator process
log_info "Checking validator process..."
if pgrep -f "solana-test-validator" > /dev/null; then
    log_success "Validator process is running"
    
    # Check RPC endpoint
    log_info "Checking RPC endpoint..."
    sleep 2
    if curl -s -X POST "http://$RPC_BIND_ADDRESS:$RPC_PORT" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' \
        > /dev/null 2>&1; then
        log_success "RPC endpoint is responding"
        
        # Get cluster info
        if command -v solana &> /dev/null; then
            SLOT=$(solana slot --url "http://$RPC_BIND_ADDRESS:$RPC_PORT" 2>/dev/null || echo "N/A")
            log_info "Current slot: $SLOT"
        fi
    else
        log_warning "RPC endpoint not responding (may need more time)"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    log_warning "Validator process is not running"
    WARNINGS=$((WARNINGS + 1))
fi

# Check firewall
log_info "Checking firewall..."
if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q "$RPC_PORT/tcp"; then
        log_success "Firewall rule for RPC port exists"
    else
        log_warning "Firewall rule for RPC port not found"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Summary
# Detect actual RPC endpoint
RPC_ENDPOINT="http://$RPC_BIND_ADDRESS:$RPC_PORT"
if [ "$RPC_BIND_ADDRESS" = "0.0.0.0" ]; then
    # Try to detect actual IP
    if command -v ip > /dev/null; then
        ACTUAL_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1)
    elif command -v hostname > /dev/null; then
        ACTUAL_IP=$(hostname -I | awk '{print $1}')
    fi
    
    if [ -n "$ACTUAL_IP" ] && [ "$ACTUAL_IP" != "127.0.0.1" ]; then
        RPC_ENDPOINT="http://$ACTUAL_IP:$RPC_PORT"
    fi
fi

echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    log_success "All checks passed!"
    echo ""
    echo "Your Solana cluster is ready!"
    echo "  RPC Endpoint: $RPC_ENDPOINT"
    if [ "$RPC_BIND_ADDRESS" = "0.0.0.0" ]; then
        echo "  (Accessible from network)"
    fi
    exit 0
elif [ $ERRORS -eq 0 ]; then
    log_warning "Verification complete with $WARNINGS warning(s)"
    echo ""
    echo "Your Solana cluster is operational!"
    echo "  RPC Endpoint: $RPC_ENDPOINT"
    echo ""
    echo "Review warnings above and address as needed"
    exit 0
else
    log_error "Verification failed with $ERRORS error(s) and $WARNINGS warning(s)"
    echo ""
    echo "Please address the errors above before proceeding"
    exit 1
fi

