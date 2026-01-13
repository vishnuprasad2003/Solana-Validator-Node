#!/bin/bash
# Stop validator node
# Usage: ./scripts/stop-validator.sh [node-name]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

NODE="${1:-}"
if [[ -n "$NODE" ]] && [[ -f "${WORKSPACE_ROOT}/${NODE}.pid" ]]; then
    PID=$(cat "${WORKSPACE_ROOT}/${NODE}.pid")
    kill "$PID" 2>/dev/null && echo "Stopped $NODE (PID: $PID)" || echo "Process not running"
    rm -f "${WORKSPACE_ROOT}/${NODE}.pid"
else
    pkill -f "agave-validator" 2>/dev/null || pkill -f "solana-validator" 2>/dev/null || echo "No validators running"
fi
