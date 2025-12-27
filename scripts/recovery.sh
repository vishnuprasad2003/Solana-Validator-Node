#!/bin/bash

# Solana Validator Node - Recovery Script
# Handles failure scenarios and recovery procedures

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
LOG_FILE="$REPO_ROOT/logs/recovery.log"

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

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

echo "=========================================="
echo "Solana Validator Recovery"
echo "=========================================="
echo ""

# Check current status
log_info "Checking validator status..."

# Check if validator is running
if pgrep -f "solana-test-validator" > /dev/null; then
    log_warning "Validator appears to be running"
    read -p "Stop it and attempt recovery? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        "$SCRIPT_DIR/stop-validator.sh"
        sleep 2
    else
        log_info "Recovery cancelled"
        exit 0
    fi
fi

# Check for corrupted ledger
log_info "Checking ledger integrity..."
if [ -d "$LEDGER_DIR" ]; then
    LEDGER_SIZE=$(du -sh "$LEDGER_DIR" 2>/dev/null | awk '{print $1}')
    log_info "Ledger size: $LEDGER_SIZE"
    
    # Check for common corruption indicators
    if find "$LEDGER_DIR" -name "*.corrupt" 2>/dev/null | grep -q .; then
        log_warning "Corrupted files detected in ledger"
        read -p "Reset ledger? (yes/no): " reset_confirm
        if [ "$reset_confirm" = "yes" ]; then
            log_warning "Backing up current ledger..."
            BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
            mv "$LEDGER_DIR" "${LEDGER_DIR}.backup-${BACKUP_TIMESTAMP}" 2>/dev/null || true
            mkdir -p "$LEDGER_DIR"
            log_success "Ledger reset (backup created)"
        fi
    fi
else
    log_info "Ledger directory not found - will be created on start"
fi

# Check configuration files
log_info "Checking configuration..."
VALIDATOR_KEYPAIR="$HOME/.config/solana/validator-keypair.json"
if [ ! -f "$VALIDATOR_KEYPAIR" ]; then
    log_error "Validator keypair not found"
    read -p "Re-run setup? (yes/no): " setup_confirm
    if [ "$setup_confirm" = "yes" ]; then
        "$SCRIPT_DIR/setup-cluster.sh"
    else
        log_error "Cannot proceed without validator keypair"
        exit 1
    fi
else
    log_success "Validator keypair found"
fi

# Check Solana installation
log_info "Checking Solana installation..."
if ! command -v solana &> /dev/null; then
    log_error "Solana CLI not found"
    read -p "Re-run installation? (yes/no): " install_confirm
    if [ "$install_confirm" = "yes" ]; then
        "$SCRIPT_DIR/install.sh"
    else
        log_error "Cannot proceed without Solana CLI"
        exit 1
    fi
else
    log_success "Solana CLI found"
    solana --version
fi

# Attempt to start validator
log_info "Attempting to start validator..."
"$SCRIPT_DIR/start-validator.sh"

# Wait and verify
sleep 5
if pgrep -f "solana-test-validator" > /dev/null; then
    log_success "Validator started successfully"
    
    # Check RPC
    sleep 3
    if curl -s "http://$RPC_BIND_ADDRESS:$RPC_PORT" > /dev/null 2>&1; then
        log_success "RPC endpoint is responding"
    else
        log_warning "RPC endpoint not yet responding (may need more time)"
    fi
else
    log_error "Failed to start validator"
    log_info "Check logs: \"$REPO_ROOT/logs/validator.log\""
    exit 1
fi

echo ""
log_success "Recovery complete"
echo ""
echo "Next steps:"
echo "1. Monitor logs: tail -f \"$REPO_ROOT/logs/validator.log\""
echo "2. Run health check: ./scripts/monitor.sh"
echo ""

