#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -f "$REPO_ROOT/configs/config.env" ] && source "$REPO_ROOT/configs/config.env"

LEDGER_DIR="${LEDGER_DIR:-$HOME/solana-local-ledger}"
RPC_PORT="${RPC_PORT:-8899}"
RPC_BIND_ADDRESS="${RPC_BIND_ADDRESS:-127.0.0.1}"
RPC_URL="http://$RPC_BIND_ADDRESS:$RPC_PORT"

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

ERRORS=0

echo "Verifying Solana validator setup..."
echo ""

command -v solana > /dev/null && echo "✓ Solana: $(solana --version 2>/dev/null | head -1)" || { echo "✗ Solana not found"; ERRORS=$((ERRORS+1)); }
command -v rustc > /dev/null && echo "✓ Rust: $(rustc --version 2>/dev/null)" || echo "⚠ Rust not found"
[ -f "$HOME/.config/solana/id.json" ] && echo "✓ Keypair: $(solana address 2>/dev/null || echo 'unknown')" || echo "⚠ Keypair not found"
[ -d "$LEDGER_DIR" ] && echo "✓ Ledger: $LEDGER_DIR" || echo "⚠ Ledger dir missing"
pgrep -f "solana-test-validator" > /dev/null && echo "✓ Validator running" || echo "⚠ Validator not running"
curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | grep -q '"result":"ok"' && echo "✓ RPC: $RPC_URL" || { echo "✗ RPC not responding"; ERRORS=$((ERRORS+1)); }

echo ""
[ $ERRORS -eq 0 ] && echo "✓ All checks passed" || echo "✗ $ERRORS check(s) failed"
exit $ERRORS
