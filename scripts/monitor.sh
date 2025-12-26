#!/bin/bash

# Continuous Monitoring Script
# Monitors validator health and sends alerts

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

RPC_URL="http://127.0.0.1:8899"
CHECK_INTERVAL=60  # seconds
ALERT_THRESHOLD_DISK=85  # percentage

check_health() {
    local issues=0
    
    # Check process
    if ! pgrep -f solana-test-validator > /dev/null; then
        echo -e "${RED}[ALERT] Validator process not running!${NC}"
        issues=$((issues + 1))
    fi
    
    # Check RPC
    if ! curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | grep -q "ok"; then
        echo -e "${RED}[ALERT] RPC endpoint not responding!${NC}"
        issues=$((issues + 1))
    fi
    
    # Check disk space
    DISK_USAGE=$(df "$HOME/solana-local-ledger" 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ -n "$DISK_USAGE" ] && [ "$DISK_USAGE" -gt "$ALERT_THRESHOLD_DISK" ]; then
        echo -e "${YELLOW}[WARNING] Disk usage: ${DISK_USAGE}%${NC}"
    fi
    
    return $issues
}

echo "=========================================="
echo "Solana Validator Monitor"
echo "=========================================="
echo "Monitoring validator health every ${CHECK_INTERVAL} seconds"
echo "Press Ctrl+C to stop"
echo ""

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] Checking health..."
    
    if check_health; then
        echo -e "${GREEN}✓ All checks passed${NC}"
    else
        echo -e "${RED}✗ Issues detected${NC}"
    fi
    
    echo ""
    sleep "$CHECK_INTERVAL"
done

