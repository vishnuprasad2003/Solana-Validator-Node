#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -f "$REPO_ROOT/configs/config.env" ] && source "$REPO_ROOT/configs/config.env"

RPC_URL="http://${RPC_BIND_ADDRESS:-127.0.0.1}:${RPC_PORT:-8899}"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

EXIT_CODE=0

echo "Solana Validator Health Check"
echo ""

pgrep -f "solana-test-validator" > /dev/null && echo "✓ Validator running" || { echo "✗ Validator not running"; EXIT_CODE=1; }
curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | grep -q '"result":"ok"' && echo "✓ RPC OK" || { echo "✗ RPC not responding"; EXIT_CODE=1; }
command -v df > /dev/null && echo "  Disk: $(df -h "$REPO_ROOT" 2>/dev/null | tail -1 | awk '{print $5}')"
[ -d "${LEDGER_DIR:-$HOME/solana-local-ledger}" ] && command -v du > /dev/null && echo "  Ledger: $(du -sh "${LEDGER_DIR:-$HOME/solana-local-ledger}" 2>/dev/null | awk '{print $1}')"
command -v solana > /dev/null && echo "  Version: $(solana --version 2>/dev/null | head -1)"

echo ""
[ $EXIT_CODE -eq 0 ] && echo "✓ All checks passed" || echo "✗ Some checks failed"
exit $EXIT_CODE
