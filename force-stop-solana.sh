#!/usr/bin/env bash
#
# Force Stop Solana Validator
# This script forcefully stops and prevents Solana from auto-restarting
#

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo "=========================================="
echo "Force Stop Solana Validator"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}This script requires sudo privileges.${NC}"
    echo -e "${YELLOW}You will be prompted for your password.${NC}"
    echo ""
fi

# Step 1: Stop the service
echo -e "${BLUE}[1/4]${NC} Stopping solana-validator.service..."
if sudo systemctl stop solana-validator.service 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Service stopped"
else
    echo -e "${YELLOW}⚠${NC} Service may not be running"
fi
sleep 2

# Step 2: Mask the service (prevents any start, even manual)
echo -e "${BLUE}[2/4]${NC} Masking service (prevents auto-restart)..."
if sudo systemctl mask solana-validator.service 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Service masked"
else
    echo -e "${RED}✗${NC} Failed to mask service"
fi

# Step 3: Disable the service (prevents start on boot)
echo -e "${BLUE}[3/4]${NC} Disabling service (prevents start on boot)..."
if sudo systemctl disable solana-validator.service 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Service disabled"
else
    echo -e "${YELLOW}⚠${NC} Service may already be disabled"
fi

# Step 4: Kill any remaining processes
echo -e "${BLUE}[4/4]${NC} Killing any remaining processes..."
SOLANA_PIDS=$(pgrep -f "solana-test-validator" 2>/dev/null || true)

if [ -z "$SOLANA_PIDS" ]; then
    echo -e "${GREEN}✓${NC} No processes found"
else
    echo -e "${YELLOW}Found processes: $SOLANA_PIDS${NC}"
    # Try graceful kill first
    for pid in $SOLANA_PIDS; do
        kill -TERM "$pid" 2>/dev/null || true
    done
    sleep 2
    
    # Force kill if still running
    SOLANA_PIDS=$(pgrep -f "solana-test-validator" 2>/dev/null || true)
    if [ -n "$SOLANA_PIDS" ]; then
        echo -e "${YELLOW}Force killing remaining processes...${NC}"
        for pid in $SOLANA_PIDS; do
            kill -9 "$pid" 2>/dev/null || true
        done
    fi
    echo -e "${GREEN}✓${NC} All processes killed"
fi

# Also check for solana-validator processes (without test-validator)
SOLANA_VALIDATOR_PIDS=$(pgrep -f "solana-validator" 2>/dev/null | grep -v "test-validator" || true)
if [ -n "$SOLANA_VALIDATOR_PIDS" ]; then
    echo -e "${YELLOW}Found additional solana-validator processes: $SOLANA_VALIDATOR_PIDS${NC}"
    for pid in $SOLANA_VALIDATOR_PIDS; do
        kill -9 "$pid" 2>/dev/null || true
    done
    echo -e "${GREEN}✓${NC} Additional processes killed"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Stop Complete!${NC}"
echo "=========================================="
echo ""

# Verify status
echo "Verifying status..."
sleep 1
if systemctl is-active --quiet solana-validator.service 2>/dev/null; then
    echo -e "${RED}✗${NC} Service is still active!"
    echo -e "${YELLOW}Try running: sudo systemctl stop solana-validator.service${NC}"
else
    echo -e "${GREEN}✓${NC} Service is stopped"
fi

if systemctl is-enabled --quiet solana-validator.service 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC} Service is still enabled (will start on boot)"
else
    echo -e "${GREEN}✓${NC} Service is disabled (will not start on boot)"
fi

# Check if masked
if systemctl is-enabled solana-validator.service 2>&1 | grep -q "masked"; then
    echo -e "${GREEN}✓${NC} Service is masked (cannot be started)"
else
    echo -e "${YELLOW}⚠${NC} Service is not masked"
fi

# Check for remaining processes
REMAINING=$(pgrep -f "solana-test-validator\|solana-validator" 2>/dev/null || true)
if [ -z "$REMAINING" ]; then
    echo -e "${GREEN}✓${NC} No processes running"
else
    echo -e "${RED}✗${NC} Processes still running: $REMAINING"
fi

echo ""
echo "To verify manually:"
echo "  systemctl status solana-validator.service"
echo "  pgrep -f solana-test-validator"
echo ""

