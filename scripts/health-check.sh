#!/bin/bash
#
# Health Check Script
# For use with Docker/Kubernetes health checks
#

set -euo pipefail

RPC_URL="${RPC_URL:-http://localhost:8899}"

# Check if RPC is responding
if curl -s -f -X POST "$RPC_URL" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' >/dev/null 2>&1; then
    exit 0
fi

# If getHealth fails, try getSlot as fallback
if curl -s -f -X POST "$RPC_URL" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' >/dev/null 2>&1; then
    exit 0
fi

exit 1
