#!/bin/bash
# Docker entrypoint
set -euo pipefail
CONFIG="/app/configs/${NODE_NAME:-bootstrap}.conf"
[[ ! -f "$CONFIG" ]] && { echo "Config not found: $CONFIG"; exit 1; }
exec /app/scripts/start-validator.sh "$CONFIG"
