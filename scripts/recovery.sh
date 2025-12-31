#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -f "$REPO_ROOT/configs/config.env" ] && source "$REPO_ROOT/configs/config.env"

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

LEDGER_DIR="${LEDGER_DIR:-$HOME/solana-local-ledger}"

echo "Solana Validator Recovery"
echo ""

if pgrep -f "solana-test-validator" > /dev/null; then
    echo "Validator is running"
    read -p "Stop and recover? (yes/no): " confirm
    [ "$confirm" = "yes" ] && "$SCRIPT_DIR/stop-validator.sh" && sleep 2 || exit 0
fi

echo "Checking ledger..."
if [ -d "$LEDGER_DIR" ]; then
    if find "$LEDGER_DIR" -name "*.corrupt" 2>/dev/null | grep -q .; then
        echo "Corrupted files detected"
        read -p "Reset ledger? (yes/no): " reset_confirm
        [ "$reset_confirm" = "yes" ] && mv "$LEDGER_DIR" "${LEDGER_DIR}.backup-$(date +%Y%m%d-%H%M%S)" 2>/dev/null && mkdir -p "$LEDGER_DIR" && echo "✓ Ledger reset"
    fi
else
    echo "Ledger directory not found (will be created)"
fi

VALIDATOR_KEYPAIR="$HOME/.config/solana/validator-keypair.json"
[ ! -f "$VALIDATOR_KEYPAIR" ] && { echo "✗ Validator keypair not found"; read -p "Re-run setup? (yes/no): " setup_confirm && [ "$setup_confirm" = "yes" ] && "$SCRIPT_DIR/setup-cluster.sh" || exit 1; }

command -v solana > /dev/null || { echo "✗ Solana CLI not found"; read -p "Re-run installation? (yes/no): " install_confirm && [ "$install_confirm" = "yes" ] && "$SCRIPT_DIR/install.sh" || exit 1; }

echo "Starting validator..."
"$SCRIPT_DIR/start-validator.sh"

sleep 5
if pgrep -f "solana-test-validator" > /dev/null; then
    echo "✓ Validator started"
    sleep 3
    curl -s "http://${RPC_BIND_ADDRESS:-127.0.0.1}:${RPC_PORT:-8899}" > /dev/null 2>&1 && echo "✓ RPC responding" || echo "⚠ RPC not yet responding"
else
    echo "✗ Failed to start validator"
    exit 1
fi

echo ""
echo "Recovery complete"
echo "Next: ./scripts/monitor.sh"
