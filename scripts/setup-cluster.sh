#!/bin/bash

# Solana Validator Node - Cluster Setup Script
# Initializes the validator node and prepares it for operation

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
LOG_FILE="$REPO_ROOT/logs/setup.log"

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

# Verify Solana is installed
if ! command -v solana &> /dev/null; then
    log_error "Solana CLI not found. Please run ./scripts/install.sh first"
    exit 1
fi

echo "=========================================="
echo "Solana Validator Node - Setup"
echo "=========================================="
echo ""

# Step 1: Create directories
log_info "[1/6] Creating directories..."
mkdir -p "$LEDGER_DIR"
mkdir -p "$HOME/.config/solana"
mkdir -p "$PROGRAMS_DIR"
mkdir -p "$BACKUP_DIR"
log_success "Directories created"
echo "  Ledger: $LEDGER_DIR"
echo "  Config: $HOME/.config/solana"
echo "  Programs: $PROGRAMS_DIR"

# Step 2: Generate validator keypair
log_info "[2/6] Setting up validator keypair..."
VALIDATOR_KEYPAIR="$HOME/.config/solana/validator-keypair.json"

if [ ! -f "$VALIDATOR_KEYPAIR" ]; then
    log_info "Generating new validator keypair..."
    solana-keygen new --outfile "$VALIDATOR_KEYPAIR" --no-bip39-passphrase --force
    VALIDATOR_ADDRESS=$(solana address -k "$VALIDATOR_KEYPAIR")
    log_success "Validator keypair generated"
    echo "  Address: $VALIDATOR_ADDRESS"
else
    VALIDATOR_ADDRESS=$(solana address -k "$VALIDATOR_KEYPAIR")
    log_success "Using existing validator keypair"
    echo "  Address: $VALIDATOR_ADDRESS"
fi

# Step 3: Generate default keypair for transactions
log_info "[3/6] Setting up default keypair..."
DEFAULT_KEYPAIR="$HOME/.config/solana/id.json"

if [ ! -f "$DEFAULT_KEYPAIR" ]; then
    log_info "Generating new default keypair..."
    solana-keygen new --outfile "$DEFAULT_KEYPAIR" --no-bip39-passphrase --force
    DEFAULT_ADDRESS=$(solana address -k "$DEFAULT_KEYPAIR")
    log_success "Default keypair generated"
    echo "  Address: $DEFAULT_ADDRESS"
else
    DEFAULT_ADDRESS=$(solana address -k "$DEFAULT_KEYPAIR")
    log_success "Using existing default keypair"
    echo "  Address: $DEFAULT_ADDRESS"
fi

# Step 4: Configure Solana CLI for local network
log_info "[4/6] Configuring Solana CLI..."
solana config set --url "http://$RPC_BIND_ADDRESS:$RPC_PORT" > /dev/null 2>&1 || true
log_success "Solana CLI configured for local network"

# Step 5: Download Metaplex Token Metadata program (if enabled)
if [ "$DOWNLOAD_METAPLEX_PROGRAM" = true ]; then
    log_info "[5/6] Downloading Metaplex Token Metadata program..."
    
    if [ ! -f "$METADATA_PROGRAM_FILE" ]; then
        log_info "Downloading from mainnet..."
        mkdir -p "$PROGRAMS_DIR"
        
        # Download from mainnet
        solana program dump "$METADATA_PROGRAM_ID" "$METADATA_PROGRAM_FILE" --url https://api.mainnet-beta.solana.com
        
        if [ -f "$METADATA_PROGRAM_FILE" ]; then
            log_success "Metaplex Token Metadata program downloaded"
            echo "  Location: $METADATA_PROGRAM_FILE"
        else
            log_warning "Failed to download Metaplex program (non-critical)"
        fi
    else
        log_success "Metaplex Token Metadata program already exists"
    fi
else
    log_info "[5/6] Skipping Metaplex program download (disabled in config)"
fi

# Step 6: Create validator configuration
log_info "[6/6] Creating validator configuration..."

# Generate validator config JSON
VALIDATOR_CONFIG="$HOME/.config/solana/validator-config.json"
cat > "$VALIDATOR_CONFIG" <<EOF
{
  "identity": "$VALIDATOR_KEYPAIR",
  "vote_account": "",
  "authorized_voter": "",
  "authorized_withdrawer": "",
  "commission": 0,
  "rpc_bind_address": "$RPC_BIND_ADDRESS",
  "rpc_port": $RPC_PORT,
  "gossip_port": $GOSSIP_PORT,
  "dynamic_port_range": "8002-8012",
  "entrypoint": "",
  "expected_genesis_hash": "",
  "expected_shred_version": null,
  "known_validators": [],
  "only_known_rpc": false,
  "ledger": "$LEDGER_DIR",
  "log": "$REPO_ROOT/logs/validator.log",
  "limit_ledger_size": $MAX_LEDGER_SIZE_GB,
  "no_os_network_stats_warning": false,
  "no_port_check": false,
  "require_tower": false,
  "rpc_max_multiple_accounts": 100,
  "rpc_max_multiple_accounts_bytes": 1000000,
  "account_index_includes": [],
  "account_index_excludes": [],
  "rpc_threads": 4,
  "rpc_max_request_body_size": 50000000,
  "enable_rpc_transaction_history": true,
  "enable_extended_tx_metadata_storage": true,
  "enable_rpc_bigtable_ledger_storage": false,
  "enable_bigtable_ledger_upload": false,
  "enable_bigtable_ledger_compression": false,
  "enable_bigtable_transaction_scan": false,
  "rpc_bigtable_timeout": 300,
  "enable_cpi_and_log_storage": true,
  "enable_rpc_obsolete_snapshot_downloads": false,
  "enable_udp": true,
  "enable_tcp": true,
  "wal_recovery_mode": "skip_any_corrupted_record",
  "no_wait_for_vote_to_start_leader": false,
  "tpu_use_quic": true,
  "tpu_enable_udp": true,
  "use_quic": true,
  "streamer_buffer_size": 16777216,
  "tpu_coalesce_ms": 5,
  "rpc_pubsub_enable_block_subscription": true,
  "rpc_pubsub_max_active_subscriptions": 100000,
  "rpc_pubsub_max_active_web_sockets": 25000,
  "rpc_pubsub_notification_threads": 1,
  "rpc_pubsub_polling_interval_ms": 100,
  "rpc_pubsub_max_pending_notifications": 1000000,
  "rpc_pubsub_enable_block_subscription": true,
  "rpc_pubsub_max_active_subscriptions": 100000,
  "rpc_pubsub_max_active_web_sockets": 25000,
  "rpc_pubsub_notification_threads": 1,
  "rpc_pubsub_polling_interval_ms": 100,
  "rpc_pubsub_max_pending_notifications": 1000000
}
EOF

log_success "Validator configuration created"
echo "  Config: $VALIDATOR_CONFIG"

echo ""
log_success "=========================================="
echo "Cluster Setup Complete!"
log_success "=========================================="
echo ""
echo "Validator Information:"
echo "  Validator Address: $VALIDATOR_ADDRESS"
echo "  Default Address: $DEFAULT_ADDRESS"
echo "  RPC Endpoint: http://$RPC_BIND_ADDRESS:$RPC_PORT"
echo ""
echo "Next steps:"
echo "1. Configure networking: ./scripts/configure-networking.sh"
echo "2. Start validator: ./scripts/start-validator.sh"
echo "   Or install systemd service: sudo systemd/install-service.sh"
echo ""

