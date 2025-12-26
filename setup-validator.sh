#!/bin/bash

# Solana Validator Setup Script
# This script initializes and configures a local Solana validator

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Solana Validator Setup"
echo "=========================================="
echo ""

# Ensure Solana is in PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
else
    # Defaults if config.env doesn't exist
    RPC_PORT=8899
    FAUCET_PORT=9900
    RPC_BIND_ADDRESS="127.0.0.1"
    LEDGER_DIR="$HOME/solana-local-ledger"
fi

# Configuration variables
KEYPAIR_DIR="$HOME/.config/solana"

# Step 1: Create directories
echo -e "${YELLOW}[1/5] Creating directories...${NC}"
mkdir -p "$LEDGER_DIR"
mkdir -p "$KEYPAIR_DIR"
echo -e "${GREEN}✓ Directories created${NC}"
echo "  Ledger: $LEDGER_DIR"
echo "  Keypair: $KEYPAIR_DIR"

# Step 2: Generate validator keypair if it doesn't exist
echo ""
echo -e "${YELLOW}[2/5] Setting up validator keypair...${NC}"
VALIDATOR_KEYPAIR="$KEYPAIR_DIR/validator-keypair.json"

if [ ! -f "$VALIDATOR_KEYPAIR" ]; then
    echo -e "${YELLOW}Generating new validator keypair...${NC}"
    solana-keygen new --outfile "$VALIDATOR_KEYPAIR" --no-bip39-passphrase --force
    echo -e "${GREEN}✓ Validator keypair generated${NC}"
else
    echo -e "${GREEN}✓ Using existing validator keypair${NC}"
fi

# Step 3: Generate default keypair for transactions
echo ""
echo -e "${YELLOW}[3/5] Setting up default keypair...${NC}"
DEFAULT_KEYPAIR="$KEYPAIR_DIR/id.json"

if [ ! -f "$DEFAULT_KEYPAIR" ]; then
    echo -e "${YELLOW}Generating new default keypair...${NC}"
    solana-keygen new --outfile "$DEFAULT_KEYPAIR" --no-bip39-passphrase --force
    echo -e "${GREEN}✓ Default keypair generated${NC}"
else
    echo -e "${GREEN}✓ Using existing default keypair${NC}"
fi

# Step 4: Configure Solana CLI for local network
echo ""
echo -e "${YELLOW}[4/5] Configuring Solana CLI...${NC}"

# Set cluster to localhost
solana config set --url "http://127.0.0.1:$RPC_PORT"

# Set keypair
solana config set --keypair "$DEFAULT_KEYPAIR"

echo -e "${GREEN}✓ Solana CLI configured${NC}"
echo ""
echo "Current configuration:"
solana config get

# Step 5: Download Metaplex Token Metadata Program
echo ""
echo -e "${YELLOW}[5/6] Downloading Metaplex Token Metadata Program...${NC}"
PROGRAMS_DIR="$HOME/.local/share/solana-programs"
METADATA_PROGRAM_ID="metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
METADATA_PROGRAM_FILE="$PROGRAMS_DIR/mpl-token-metadata.so"

mkdir -p "$PROGRAMS_DIR"

if [ -f "$METADATA_PROGRAM_FILE" ]; then
    echo -e "${GREEN}✓ Token Metadata program already exists${NC}"
else
    echo -e "${YELLOW}Downloading Token Metadata program from mainnet...${NC}"
    if solana program dump -u m "$METADATA_PROGRAM_ID" "$METADATA_PROGRAM_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ Token Metadata program downloaded${NC}"
    else
        echo -e "${YELLOW}⚠ Could not download program (may need internet). You can download it later with:${NC}"
        echo "  scripts/download-metaplex-program.sh"
    fi
fi

# Step 6: Check port availability
echo ""
echo -e "${YELLOW}[6/7] Checking port availability...${NC}"
if [ -f "$SCRIPT_DIR/check-ports.sh" ]; then
    bash "$SCRIPT_DIR/check-ports.sh" || {
        echo -e "${YELLOW}⚠ Port conflicts detected. Please resolve before starting validator.${NC}"
    }
else
    echo -e "${YELLOW}⚠ Port checker not found. Skipping port check.${NC}"
fi

# Step 7: Create validator start script
echo ""
echo -e "${YELLOW}[7/7] Creating validator management scripts...${NC}"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create start script
cat > "$SCRIPT_DIR/start-validator.sh" << EOFSCRIPT
#!/bin/bash
# Start Solana Test Validator with Metaplex Token Metadata Program

# Load configuration from config.env if available
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
if [ -f "\$SCRIPT_DIR/config.env" ]; then
    source "\$SCRIPT_DIR/config.env"
fi

# Set defaults if not in config.env
LEDGER_DIR="\${LEDGER_DIR:-\$HOME/solana-local-ledger}"
RPC_PORT="\${RPC_PORT:-8899}"
RPC_BIND_ADDRESS="\${RPC_BIND_ADDRESS:-127.0.0.1}"
FAUCET_PORT="\${FAUCET_PORT:-9900}"
PROGRAMS_DIR="\${PROGRAMS_DIR:-\$HOME/.local/share/solana-programs}"
METADATA_PROGRAM_ID="\${METADATA_PROGRAM_ID:-metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s}"
METADATA_PROGRAM_FILE="\${METADATA_PROGRAM_FILE:-\$PROGRAMS_DIR/mpl-token-metadata.so}"

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

echo "Starting Solana test validator..."
echo "  RPC: http://$RPC_BIND_ADDRESS:$RPC_PORT"
echo "  Ledger: $LEDGER_DIR"
echo ""

# Build validator command
VALIDATOR_CMD="solana-test-validator \
    --ledger \"$LEDGER_DIR\" \
    --reset \
    --rpc-port $RPC_PORT \
    --bind-address $RPC_BIND_ADDRESS \
    --faucet-port $FAUCET_PORT \
    --quiet \
    --limit-ledger-size"

# Add Metaplex Token Metadata program if it exists
if [ -f "$METADATA_PROGRAM_FILE" ]; then
    echo "  Including: Metaplex Token Metadata Program"
    VALIDATOR_CMD="$VALIDATOR_CMD --bpf-program $METADATA_PROGRAM_ID $METADATA_PROGRAM_FILE"
else
    echo "  ⚠ Metaplex Token Metadata program not found at: $METADATA_PROGRAM_FILE"
    echo "     Run scripts/download-metaplex-program.sh to download it"
fi

echo ""

# Execute validator command
eval $VALIDATOR_CMD
EOFSCRIPT

chmod +x "$SCRIPT_DIR/start-validator.sh"
echo -e "${GREEN}✓ Created start-validator.sh${NC}"

# Create stop script
cat > "$SCRIPT_DIR/stop-validator.sh" << 'EOFSCRIPT'
#!/bin/bash
# Stop Solana Test Validator

echo "Stopping Solana test validator..."

# Kill solana-test-validator process
pkill -f solana-test-validator || echo "No validator process found"

echo "Validator stopped"
EOFSCRIPT

chmod +x "$SCRIPT_DIR/stop-validator.sh"
echo -e "${GREEN}✓ Created stop-validator.sh${NC}"

# Create reset script
cat > "$SCRIPT_DIR/reset-validator.sh" << 'EOFSCRIPT'
#!/bin/bash
# Reset Solana Test Validator (clears ledger)

LEDGER_DIR="$HOME/solana-local-ledger"

read -p "This will delete all ledger data. Are you sure? (yes/no): " confirm
if [ "$confirm" = "yes" ]; then
    echo "Stopping validator..."
    pkill -f solana-test-validator || true
    sleep 2
    
    echo "Removing ledger data..."
    rm -rf "$LEDGER_DIR"
    mkdir -p "$LEDGER_DIR"
    
    echo "✓ Validator reset complete"
    echo "Run ./start-validator.sh to start fresh"
else
    echo "Reset cancelled"
fi
EOFSCRIPT

chmod +x "$SCRIPT_DIR/reset-validator.sh"
echo -e "${GREEN}✓ Created reset-validator.sh${NC}"

# Create tmux management script
cat > "$SCRIPT_DIR/start-validator-tmux.sh" << 'EOFSCRIPT'
#!/bin/bash
# Start validator in tmux session

SESSION_NAME="solana-validator"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo "tmux is not installed. Installing..."
    sudo apt-get update
    sudo apt-get install -y tmux
fi

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Validator session already exists. Attaching..."
    tmux attach-session -t "$SESSION_NAME"
else
    echo "Starting validator in tmux session: $SESSION_NAME"
    tmux new-session -d -s "$SESSION_NAME" -c "$HOME" "$SCRIPT_DIR/start-validator.sh"
    echo "Validator started in tmux session: $SESSION_NAME"
    echo "To attach: tmux attach -t $SESSION_NAME"
    echo "To detach: Press Ctrl+B, then D"
    echo "To view logs: tmux attach -t $SESSION_NAME"
fi
EOFSCRIPT

chmod +x "$SCRIPT_DIR/start-validator-tmux.sh"
echo -e "${GREEN}✓ Created start-validator-tmux.sh${NC}"

# Create download script for Metaplex program
cat > "$SCRIPT_DIR/download-metaplex-program.sh" << 'EOFDOWNLOAD'
#!/bin/bash
# Download Metaplex Token Metadata Program

set -e

PROGRAMS_DIR="$HOME/.local/share/solana-programs"
METADATA_PROGRAM_ID="metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
METADATA_PROGRAM_FILE="$PROGRAMS_DIR/mpl-token-metadata.so"

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

mkdir -p "$PROGRAMS_DIR"

if [ -f "$METADATA_PROGRAM_FILE" ]; then
    echo "Token Metadata program already exists. Removing old version..."
    rm -f "$METADATA_PROGRAM_FILE"
fi

echo "Downloading Token Metadata program from mainnet..."
echo "  Program ID: $METADATA_PROGRAM_ID"
echo "  Output: $METADATA_PROGRAM_FILE"

if solana program dump -u m "$METADATA_PROGRAM_ID" "$METADATA_PROGRAM_FILE"; then
    echo "✓ Token Metadata program downloaded successfully"
    echo "  File: $METADATA_PROGRAM_FILE"
    echo "  Size: $(du -h "$METADATA_PROGRAM_FILE" | cut -f1)"
    echo ""
    echo "The program will be automatically loaded when you restart the validator."
else
    echo "✗ Failed to download Token Metadata program"
    echo "  Make sure you have internet connection and Solana CLI is installed"
    exit 1
fi
EOFDOWNLOAD

chmod +x "$SCRIPT_DIR/download-metaplex-program.sh"
echo -e "${GREEN}✓ Created download-metaplex-program.sh${NC}"

echo ""
echo -e "${GREEN}=========================================="
echo "Validator Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Keypair addresses:"
echo "  Validator: $(solana address -k $VALIDATOR_KEYPAIR)"
echo "  Default:   $(solana address -k $DEFAULT_KEYPAIR)"
echo ""
echo "Next steps:"
echo "1. Start validator: ./start-validator.sh"
echo "   Or in tmux: ./start-validator-tmux.sh"
echo "2. Wait for validator to initialize (about 10-30 seconds)"
echo "3. Run verification: ./verify-setup.sh"
echo ""
echo "RPC Endpoint: http://127.0.0.1:$RPC_PORT"
echo "             http://$(hostname -I | awk '{print $1}'):$RPC_PORT (remote access)"
echo ""

