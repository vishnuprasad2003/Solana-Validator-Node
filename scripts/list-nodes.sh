#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -f "$REPO_ROOT/configs/config.env" ] && source "$REPO_ROOT/configs/config.env"

RPC_URL="http://${RPC_BIND_ADDRESS:-127.0.0.1}:${RPC_PORT:-8899}"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

echo "Cluster Node Information"
echo ""

[ "$CLUSTER_MODE" = "true" ] && echo "  Mode: Cluster" || echo "  Mode: Single node"
[ "$CLUSTER_MODE" = "true" ] && echo "  Role: ${NODE_ROLE:-bootstrap}"
[ "$CLUSTER_MODE" = "true" ] && [ -n "${BOOTSTRAP_NODE:-}" ] && echo "  Bootstrap: $BOOTSTRAP_NODE"
echo "  RPC: $RPC_URL"
echo "  Gossip: ${GOSSIP_PORT:-8001}"

if command -v solana > /dev/null; then
    CLUSTER_RESPONSE=$(curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' 2>/dev/null)
    if echo "$CLUSTER_RESPONSE" | grep -q "result"; then
        echo ""
        echo "Connected nodes:"
        echo "$CLUSTER_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$CLUSTER_RESPONSE"
    fi
fi

