#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -f "$REPO_ROOT/configs/config.env" ] && source "$REPO_ROOT/configs/config.env"

RPC_URL="http://${RPC_BIND_ADDRESS:-127.0.0.1}:${RPC_PORT:-8899}"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

[ $# -lt 1 ] && { echo "Usage: $0 <address> [amount]"; exit 1; }
ADDRESS="$1"
AMOUNT="${2:-1}"

[ ${#ADDRESS} -lt 32 ] || [ ${#ADDRESS} -gt 44 ] && { echo "Error: Invalid address"; exit 1; }
curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | grep -q '"result":"ok"' || { echo "Error: Validator not running"; exit 1; }

command -v solana > /dev/null || { echo "Error: Solana CLI not found"; exit 1; }

echo "Airdropping $AMOUNT SOL to $ADDRESS..."
solana airdrop "$AMOUNT" "$ADDRESS" --url "$RPC_URL" && echo "✓ Airdrop successful" || { echo "✗ Airdrop failed"; exit 1; }
