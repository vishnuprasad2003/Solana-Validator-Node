#!/bin/bash

# Solana Production Cluster - Start Validator Script
# Safely starts the Solana validator with proper configuration

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

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Ensure Solana is in PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Check if validator is already running
if pgrep -f "solana-test-validator" > /dev/null; then
    log_warning "Validator appears to be already running"
    echo "Use './scripts/stop-validator.sh' to stop it first"
    exit 1
fi

# Verify Solana is installed
if ! command -v solana &> /dev/null; then
    log_error "Solana CLI not found. Please run ./scripts/install.sh first"
    exit 1
fi

# Verify setup is complete
VALIDATOR_KEYPAIR="$HOME/.config/solana/validator-keypair.json"
if [ ! -f "$VALIDATOR_KEYPAIR" ]; then
    log_error "Validator not set up. Please run ./scripts/setup-cluster.sh first"
    exit 1
fi

log_info "Starting Solana validator..."

# Detect actual IP address if bind address is 0.0.0.0
# solana-test-validator doesn't accept 0.0.0.0, needs specific IP
BIND_ADDRESS="$RPC_BIND_ADDRESS"
if [ "$RPC_BIND_ADDRESS" = "0.0.0.0" ]; then
    # Try to detect the primary network interface IP
    if command -v ip > /dev/null; then
        DETECTED_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1)
    elif command -v hostname > /dev/null; then
        DETECTED_IP=$(hostname -I | awk '{print $1}')
    fi
    
    if [ -n "$DETECTED_IP" ] && [ "$DETECTED_IP" != "127.0.0.1" ]; then
        BIND_ADDRESS="$DETECTED_IP"
        log_info "Detected IP address: $BIND_ADDRESS (for public access, RPC will still bind to 0.0.0.0)"
    else
        # Fallback to localhost if detection fails
        BIND_ADDRESS="127.0.0.1"
        log_warning "Could not detect IP, using localhost. For public access, set RPC_BIND_ADDRESS to your actual IP in config.env"
    fi
fi

# Build validator command
VALIDATOR_CMD="solana-test-validator"

# Add ledger directory (required)
VALIDATOR_CMD="$VALIDATOR_CMD --ledger $LEDGER_DIR"

# Add bind address (must be specific IP, not 0.0.0.0)
VALIDATOR_CMD="$VALIDATOR_CMD --bind-address $BIND_ADDRESS"

# Add RPC port
VALIDATOR_CMD="$VALIDATOR_CMD --rpc-port $RPC_PORT"

# Add gossip port (if cluster mode)
if [ "$CLUSTER_MODE" = true ]; then
    VALIDATOR_CMD="$VALIDATOR_CMD --gossip-port $GOSSIP_PORT"
fi

# Limit ledger size if enabled (convert GB to approximate shred count)
# Note: --limit-ledger-size takes shred count, roughly 1GB ≈ 10000 shreds
if [ "$LIMIT_LEDGER_SIZE" = true ]; then
    SHRED_COUNT=$((MAX_LEDGER_SIZE_GB * 10000))
    VALIDATOR_CMD="$VALIDATOR_CMD --limit-ledger-size $SHRED_COUNT"
fi

# Reset on start (only if explicitly enabled)
if [ "$RESET_ON_START" = true ]; then
    log_warning "RESET_ON_START is enabled - ledger will be reset!"
    VALIDATOR_CMD="$VALIDATOR_CMD --reset"
fi

# Add Metaplex program if available (use --bpf-program, not --clone)
if [ "$DOWNLOAD_METAPLEX_PROGRAM" = true ] && [ -f "$METADATA_PROGRAM_FILE" ]; then
    VALIDATOR_CMD="$VALIDATOR_CMD --bpf-program $METADATA_PROGRAM_ID $METADATA_PROGRAM_FILE"
fi

# Enable faucet if configured
if [ "$ENABLE_FAUCET" = true ]; then
    VALIDATOR_CMD="$VALIDATOR_CMD --faucet-port $FAUCET_PORT"
fi

# Cluster mode configuration (entrypoint for joining existing cluster)
if [ "$CLUSTER_MODE" = true ] && [ -n "$ENTRYPOINT_ADDRESS" ] && [ "$IS_ENTRYPOINT" != true ]; then
    VALIDATOR_CMD="$VALIDATOR_CMD --entrypoint $ENTRYPOINT_ADDRESS:$GOSSIP_PORT"
fi

# Create logs directory
mkdir -p "$REPO_ROOT/logs"

# Check if running from systemd (better detection)
if [ -n "${SYSTEMD_EXEC_PID:-}" ] || [ -n "${INVOCATION_ID:-}" ] || [ "${1:-}" = "--systemd" ]; then
    # Running from systemd - run in foreground
    log_info "Running from systemd - starting validator in foreground"
    log_info "Executing: $VALIDATOR_CMD"
    exec $VALIDATOR_CMD
else
    # Running manually - run in background
    log_info "Executing: $VALIDATOR_CMD"
    log_info "Logs will be written to: $REPO_ROOT/logs/validator.log"
    echo ""

    # Run validator in background and redirect output
    nohup $VALIDATOR_CMD > "$REPO_ROOT/logs/validator.log" 2>&1 &
    VALIDATOR_PID=$!

    # Wait a moment for validator to start
    sleep 3

    # Check if validator is still running
    if ps -p $VALIDATOR_PID > /dev/null; then
        log_success "Validator started successfully (PID: $VALIDATOR_PID)"
        echo ""
        echo "Validator Information:"
        echo "  PID: $VALIDATOR_PID"
        echo "  RPC Endpoint: http://$RPC_BIND_ADDRESS:$RPC_PORT"
        echo "  Logs: $REPO_ROOT/logs/validator.log"
        echo ""
        echo "To view logs: tail -f $REPO_ROOT/logs/validator.log"
        echo "To stop: ./scripts/stop-validator.sh"
        echo ""
        
        # Wait a bit more and verify RPC is responding
        sleep 5
        if curl -s "http://$RPC_BIND_ADDRESS:$RPC_PORT" > /dev/null 2>&1; then
            log_success "RPC endpoint is responding"
        else
            log_warning "RPC endpoint not yet responding (may need more time)"
        fi
    else
        log_error "Validator failed to start"
        echo "Check logs: $REPO_ROOT/logs/validator.log"
        exit 1
    fi
fi

