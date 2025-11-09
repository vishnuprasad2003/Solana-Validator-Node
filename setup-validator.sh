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

# Configuration variables
LEDGER_DIR="$HOME/solana-local-ledger"
KEYPAIR_DIR="$HOME/.config/solana"
RPC_PORT=8899
RPC_BIND_ADDRESS="0.0.0.0"  # Allow remote connections
FAUCET_PORT=9900

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

# Step 5: Create validator start script
echo ""
echo -e "${YELLOW}[5/5] Creating validator management scripts...${NC}"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create start script
cat > "$SCRIPT_DIR/start-validator.sh" << 'EOFSCRIPT'
#!/bin/bash
# Start Solana Test Validator

LEDGER_DIR="$HOME/solana-local-ledger"
RPC_PORT=8899
RPC_BIND_ADDRESS="0.0.0.0"
FAUCET_PORT=9900

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

echo "Starting Solana test validator..."
echo "  RPC: http://$RPC_BIND_ADDRESS:$RPC_PORT"
echo "  Ledger: $LEDGER_DIR"
echo ""

solana-test-validator \
    --ledger "$LEDGER_DIR" \
    --reset \
    --rpc-port "$RPC_PORT" \
    --bind-address "$RPC_BIND_ADDRESS" \
    --faucet-port "$FAUCET_PORT" \
    --quiet \
    --limit-ledger-size
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

