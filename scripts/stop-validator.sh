#!/bin/bash

# Solana Production Cluster - Stop Validator Script
# Gracefully stops the Solana validator

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Stopping Solana validator..."

# Find validator processes
VALIDATOR_PIDS=$(pgrep -f "solana-test-validator" || true)

if [ -z "$VALIDATOR_PIDS" ]; then
    log_warning "No validator process found"
    exit 0
fi

# Try graceful shutdown first
log_info "Sending SIGTERM to validator processes..."
for PID in $VALIDATOR_PIDS; do
    log_info "Stopping process $PID..."
    kill -TERM "$PID" 2>/dev/null || true
done

# Wait for processes to stop
WAIT_TIME=0
MAX_WAIT=30
while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    REMAINING=$(pgrep -f "solana-test-validator" || true)
    if [ -z "$REMAINING" ]; then
        log_success "Validator stopped gracefully"
        exit 0
    fi
    sleep 1
    WAIT_TIME=$((WAIT_TIME + 1))
done

# Force kill if still running
REMAINING=$(pgrep -f "solana-test-validator" || true)
if [ -n "$REMAINING" ]; then
    log_warning "Validator did not stop gracefully, forcing shutdown..."
    for PID in $REMAINING; do
        kill -9 "$PID" 2>/dev/null || true
    done
    sleep 2
    
    # Verify stopped
    if pgrep -f "solana-test-validator" > /dev/null; then
        log_error "Failed to stop validator"
        exit 1
    else
        log_success "Validator stopped (forced)"
    fi
fi

