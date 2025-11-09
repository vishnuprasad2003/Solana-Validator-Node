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
