#!/usr/bin/env bash

# Solana Validator Node - Start Validator Script
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

# Load common functions
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
fi

# Load configuration
if [ -f "$REPO_ROOT/configs/config.env" ]; then
    source "$REPO_ROOT/configs/config.env"
else
    echo -e "${RED}Error: config.env not found${NC}"
    exit 1
fi

# Setup logging
mkdir -p "$REPO_ROOT/logs"
LOG_FILE="$REPO_ROOT/logs/start-validator.log"

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

# Ensure Solana is in PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Check if running from systemd (better detection)
IS_SYSTEMD=false
if [ -n "${SYSTEMD_EXEC_PID:-}" ] || [ -n "${INVOCATION_ID:-}" ] || [ "${1:-}" = "--systemd" ]; then
    IS_SYSTEMD=true
fi

# Check if validator is already running
if pgrep -f "solana-test-validator" > /dev/null; then
    if [ "$IS_SYSTEMD" = true ]; then
        # For systemd, if validator is already running, exit successfully (0) to prevent restart loop
        # This handles the case where validator was started manually or is already running
        log_info "Validator is already running, exiting successfully"
        exit 0
    else
        # For manual runs, warn and exit with error
        log_warning "Validator appears to be already running"
        echo "Use './scripts/stop-validator.sh' to stop it first"
        exit 1
    fi
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
PUBLIC_IP_DETECTED=""
DETECTED_IP=""

# Try to detect public IP (useful for Azure VMs)
if [ -n "${PUBLIC_IP:-}" ]; then
    PUBLIC_IP_DETECTED="$PUBLIC_IP"
    log_info "Using configured public IP: $PUBLIC_IP_DETECTED"
elif type detect_public_ip > /dev/null 2>&1; then
    # Try to detect public IP from external service using common.sh function
    PUBLIC_IP_DETECTED=$(detect_public_ip 2>/dev/null || echo "")
    if [ -n "$PUBLIC_IP_DETECTED" ]; then
        log_info "Detected public IP: $PUBLIC_IP_DETECTED"
    fi
elif command -v curl > /dev/null; then
    # Fallback: try curl directly
    PUBLIC_IP_DETECTED=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || curl -s --max-time 3 https://ifconfig.me 2>/dev/null || echo "")
    if [ -n "$PUBLIC_IP_DETECTED" ]; then
        log_info "Detected public IP: $PUBLIC_IP_DETECTED"
    fi
fi

if [ "$RPC_BIND_ADDRESS" = "0.0.0.0" ]; then
    # Try to detect the primary network interface IP (private IP for Azure VMs)
    if command -v ip > /dev/null; then
        DETECTED_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1)
    elif command -v hostname > /dev/null; then
        DETECTED_IP=$(hostname -I | awk '{print $1}')
    fi
    
    if [ -n "$DETECTED_IP" ] && [ "$DETECTED_IP" != "127.0.0.1" ]; then
        # Use private IP for binding (Azure will NAT public IP to private IP automatically)
        BIND_ADDRESS="$DETECTED_IP"
        log_info "Binding to private IP: $BIND_ADDRESS (for public access)"
        if [ -n "$PUBLIC_IP_DETECTED" ]; then
            log_info "Public IP: $PUBLIC_IP_DETECTED (Azure will NAT this to private IP $BIND_ADDRESS)"
            log_info "Access from anywhere using: http://$PUBLIC_IP_DETECTED:$RPC_PORT"
        else
            log_info "For public access, ensure Azure NSG allows inbound TCP on port $RPC_PORT"
        fi
    else
        # Fallback to localhost if detection fails
        BIND_ADDRESS="127.0.0.1"
        log_warning "Could not detect private IP, using localhost (127.0.0.1)"
        log_warning "For public access, set RPC_BIND_ADDRESS to your VM's private IP in config.env"
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

# Determine log destination based on configuration
if [ "${DISABLE_VALIDATOR_LOGS:-false}" = "true" ]; then
    VALIDATOR_LOG="/dev/null"
    log_info "Validator logs disabled (discarding output to save disk space)"
else
    VALIDATOR_LOG="$REPO_ROOT/logs/validator.log"
    log_info "Validator logs will be written to: $VALIDATOR_LOG"
fi

# Check if running from systemd (use the flag we set earlier)
if [ "$IS_SYSTEMD" = true ]; then
    # Running from systemd - run in foreground but also log to file
    log_info "Running from systemd - starting validator in foreground"
    log_info "Executing: $VALIDATOR_CMD"
    # Redirect output to both journald (via systemd) and log file (or /dev/null)
    # Use exec to replace shell process with validator (required for systemd)
    exec $VALIDATOR_CMD >> "$VALIDATOR_LOG" 2>&1
    # This line should never be reached, but if it is, exit with error
    exit 1
else
    # Running manually - run in background
    log_info "Executing: $VALIDATOR_CMD"
    echo ""

    # Run validator in background and redirect output
    nohup $VALIDATOR_CMD > "$VALIDATOR_LOG" 2>&1 &
    VALIDATOR_PID=$!

    # Wait a moment for validator to start
    sleep 3

    # Check if validator is still running
    if ps -p $VALIDATOR_PID > /dev/null; then
        log_success "Validator started successfully (PID: $VALIDATOR_PID)"
        echo ""
        # Detect actual RPC endpoint for display
        LOCAL_RPC_ENDPOINT="http://127.0.0.1:$RPC_PORT"
        PRIVATE_RPC_ENDPOINT=""
        PUBLIC_RPC_ENDPOINT=""
        
        if [ "$RPC_BIND_ADDRESS" = "0.0.0.0" ] && [ -n "$BIND_ADDRESS" ] && [ "$BIND_ADDRESS" != "0.0.0.0" ]; then
            PRIVATE_RPC_ENDPOINT="http://$BIND_ADDRESS:$RPC_PORT"
        elif [ "$RPC_BIND_ADDRESS" != "0.0.0.0" ] && [ "$RPC_BIND_ADDRESS" != "127.0.0.1" ]; then
            PRIVATE_RPC_ENDPOINT="http://$RPC_BIND_ADDRESS:$RPC_PORT"
        fi
        
        if [ -n "$PUBLIC_IP_DETECTED" ]; then
            PUBLIC_RPC_ENDPOINT="http://$PUBLIC_IP_DETECTED:$RPC_PORT"
        fi
        
        echo "Validator Information:"
        echo "  PID: $VALIDATOR_PID"
        echo "  Local RPC Endpoint: $LOCAL_RPC_ENDPOINT"
        if [ -n "$PRIVATE_RPC_ENDPOINT" ]; then
            echo "  Private IP RPC Endpoint: $PRIVATE_RPC_ENDPOINT"
        fi
        if [ -n "$PUBLIC_RPC_ENDPOINT" ]; then
            echo "  Public IP RPC Endpoint: $PUBLIC_RPC_ENDPOINT"
            echo ""
            echo "  ⚠️  IMPORTANT FOR AZURE VMs:"
            echo "  - Ensure Azure NSG allows inbound TCP on port $RPC_PORT"
            echo "  - Ensure OS firewall allows port $RPC_PORT"
            echo "  - Use public IP endpoint from anywhere: $PUBLIC_RPC_ENDPOINT"
        fi
        if [ "${DISABLE_VALIDATOR_LOGS:-false}" != "true" ]; then
            echo "  Logs: \"$REPO_ROOT/logs/validator.log\""
            echo ""
            echo "To view logs: tail -f \"$REPO_ROOT/logs/validator.log\""
        else
            echo "  Logs: Disabled (output discarded)"
        fi
        echo "To stop: ./scripts/stop-validator.sh"
        echo ""
        
        # Wait a bit more and verify RPC is responding
        sleep 5
        # Test localhost endpoint
        if curl -s "$LOCAL_RPC_ENDPOINT" > /dev/null 2>&1; then
            log_success "RPC endpoint is responding locally at $LOCAL_RPC_ENDPOINT"
            if [ -n "$PUBLIC_IP_DETECTED" ]; then
                log_info "For public access, test: curl $PUBLIC_RPC_ENDPOINT"
                log_warning "If public access fails, check Azure NSG and OS firewall rules"
            fi
        else
            log_warning "RPC endpoint not yet responding (may need more time)"
            log_info "Test with: curl $LOCAL_RPC_ENDPOINT"
        fi
    else
        log_error "Validator failed to start"
        if [ "${DISABLE_VALIDATOR_LOGS:-false}" != "true" ]; then
            echo "Check logs: \"$REPO_ROOT/logs/validator.log\""
        else
            echo "Logs are disabled. Check validator process: ps aux | grep solana-test-validator"
        fi
        exit 1
    fi
fi

