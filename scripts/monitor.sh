#!/bin/bash

# Solana Validator Node - Monitoring Script
# Monitors validator health and performance

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

# Setup logging
mkdir -p "$REPO_ROOT/logs"
LOG_FILE="$REPO_ROOT/logs/monitor.log"

# Logging functions (write to both console and log file)
log_info() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "$timestamp [INFO] $1" >> "$LOG_FILE"
}

log_success() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${GREEN}[OK]${NC} $1"
    echo "$timestamp [OK] $1" >> "$LOG_FILE"
}

log_warning() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "$timestamp [WARN] $1" >> "$LOG_FILE"
}

log_error() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$timestamp [ERROR] $1" >> "$LOG_FILE"
}

# Check if validator is running
check_process() {
    if pgrep -f "solana-test-validator" > /dev/null; then
        log_success "Validator process is running"
        return 0
    else
        log_error "Validator process is NOT running"
        return 1
    fi
}

# Check RPC endpoint
check_rpc() {
    # Detect actual IP if bind address is 0.0.0.0
    local RPC_TEST_ADDRESS="$RPC_BIND_ADDRESS"
    if [ "$RPC_BIND_ADDRESS" = "0.0.0.0" ]; then
        if command -v ip > /dev/null; then
            RPC_TEST_ADDRESS=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1)
        elif command -v hostname > /dev/null; then
            RPC_TEST_ADDRESS=$(hostname -I | awk '{print $1}')
        fi
        [ -z "$RPC_TEST_ADDRESS" ] && RPC_TEST_ADDRESS="127.0.0.1"
    fi
    
    local RPC_URL="http://$RPC_TEST_ADDRESS:$RPC_PORT"
    
    if curl -s -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' \
        > /dev/null 2>&1; then
        log_success "RPC endpoint is responding at $RPC_URL"
        return 0
    else
        log_error "RPC endpoint is NOT responding at $RPC_URL"
        return 1
    fi
}

# Check disk space
check_disk() {
    local LEDGER_DIR_DISK=$(df -h "$LEDGER_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$LEDGER_DIR_DISK" -lt 80 ]; then
        log_success "Disk usage: ${LEDGER_DIR_DISK}%"
        return 0
    elif [ "$LEDGER_DIR_DISK" -lt 90 ]; then
        log_warning "Disk usage: ${LEDGER_DIR_DISK}% (approaching limit)"
        return 1
    else
        log_error "Disk usage: ${LEDGER_DIR_DISK}% (CRITICAL)"
        return 2
    fi
}

# Check ledger size
check_ledger_size() {
    if [ -d "$LEDGER_DIR" ]; then
        local LEDGER_SIZE=$(du -sh "$LEDGER_DIR" 2>/dev/null | awk '{print $1}')
        log_info "Ledger size: $LEDGER_SIZE"
    else
        log_warning "Ledger directory not found"
    fi
}

# Get validator info
get_validator_info() {
    if command -v solana &> /dev/null; then
        # Detect actual IP if bind address is 0.0.0.0
        local RPC_TEST_ADDRESS="$RPC_BIND_ADDRESS"
        if [ "$RPC_BIND_ADDRESS" = "0.0.0.0" ]; then
            if command -v ip > /dev/null; then
                RPC_TEST_ADDRESS=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1)
            elif command -v hostname > /dev/null; then
                RPC_TEST_ADDRESS=$(hostname -I | awk '{print $1}')
            fi
            [ -z "$RPC_TEST_ADDRESS" ] && RPC_TEST_ADDRESS="127.0.0.1"
        fi
        
        local RPC_URL="http://$RPC_TEST_ADDRESS:$RPC_PORT"
        
        # Get slot
        local SLOT=$(solana slot --url "$RPC_URL" 2>/dev/null || echo "N/A")
        log_info "Current slot: $SLOT"
        
        # Get version
        local VERSION=$(solana --version 2>/dev/null | head -1 || echo "N/A")
        log_info "Solana version: $VERSION"
    fi
}

# Main monitoring function
main() {
    echo "=========================================="
    echo "Solana Validator Health Check"
    echo "=========================================="
    echo ""
    
    local EXIT_CODE=0
    
    # Check process
    if ! check_process; then
        EXIT_CODE=1
    fi
    
    # Check RPC
    if ! check_rpc; then
        EXIT_CODE=1
    fi
    
    # Check disk
    check_disk
    DISK_EXIT=$?
    if [ $DISK_EXIT -eq 2 ]; then
        EXIT_CODE=2
    elif [ $DISK_EXIT -eq 1 ]; then
        EXIT_CODE=1
    fi
    
    # Check ledger size
    check_ledger_size
    
    # Get validator info
    get_validator_info
    
    echo ""
    if [ $EXIT_CODE -eq 0 ]; then
        log_success "All checks passed"
    elif [ $EXIT_CODE -eq 1 ]; then
        log_warning "Some checks failed - review above"
    else
        log_error "Critical issues detected - immediate action required"
    fi
    
    exit $EXIT_CODE
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

