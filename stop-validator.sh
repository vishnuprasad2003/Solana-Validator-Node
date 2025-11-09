#!/bin/bash
# Stop Solana Test Validator

echo "Stopping Solana test validator..."

# Kill solana-test-validator process
pkill -f solana-test-validator || echo "No validator process found"

echo "Validator stopped"
