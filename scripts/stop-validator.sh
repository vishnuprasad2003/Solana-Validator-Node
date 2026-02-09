#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Stop a Solana validator node
# Usage: ./scripts/stop-validator.sh <config-file>
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
source "$(dirname "$0")/common.sh"

CONFIG="${1:?Usage: $0 <config-file>}"
[[ ! -f "$CONFIG" ]] && { log_error "Config not found: $CONFIG"; exit 1; }
source "$CONFIG"

graceful_stop "$PID_FILE" "$NODE_NAME" 15
