#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FORCE_STOP=false
MASK_SERVICE=false
STOP_SERVICE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE_STOP=true; shift; ;;
        --mask) MASK_SERVICE=true; shift; ;;
        --service) STOP_SERVICE=true; shift; ;;
        *) echo "Usage: $0 [--force] [--mask] [--service]"; echo "  --force: Force kill validator process"; echo "  --mask: Mask systemd service (prevent auto-start)"; echo "  --service: Stop systemd service only"; exit 1; ;;
    esac
done

# Check if validator is running
if ! pgrep -f "solana-test-validator" > /dev/null; then
    echo "No validator running"
    exit 0
fi

# Handle systemd service
if command -v systemctl > /dev/null 2>&1 && systemctl list-units --full -all 2>/dev/null | grep -q "solana-validator.service"; then
    SERVICE_EXISTS=true
    
    if [ "$STOP_SERVICE" = "true" ] || [ "$FORCE_STOP" = "false" ]; then
        echo "Stopping systemd service..."
        sudo systemctl stop solana-validator.service 2>/dev/null && echo "✓ Service stopped" || echo "⚠ Service stop failed"
        sleep 2
    fi
    
    if [ "$MASK_SERVICE" = "true" ]; then
        echo "Masking systemd service (prevents auto-start)..."
        sudo systemctl mask solana-validator.service 2>/dev/null && echo "✓ Service masked" || echo "⚠ Service mask failed"
    fi
    
    if [ "$FORCE_STOP" = "true" ]; then
        echo "Disabling systemd service..."
        sudo systemctl disable solana-validator.service 2>/dev/null || true
    fi
else
    SERVICE_EXISTS=false
fi

# Stop validator processes gracefully first
echo "Stopping validator processes..."
for pid in $(pgrep -f "solana-test-validator"); do
    kill -TERM "$pid" 2>/dev/null && echo "  Sent TERM to PID $pid" || true
done

# Wait for graceful shutdown
sleep 3

# Check if still running
if ! pgrep -f "solana-test-validator" > /dev/null; then
    echo "✓ Validator stopped gracefully"
    exit 0
fi

# Force stop if requested or if graceful stop failed
if [ "$FORCE_STOP" = "true" ]; then
    echo "Force stopping validator processes..."
    for pid in $(pgrep -f "solana-test-validator"); do
        kill -9 "$pid" 2>/dev/null && echo "  Force killed PID $pid" || true
    done
    sleep 1
fi

# Final check
if pgrep -f "solana-test-validator" > /dev/null; then
    echo "✗ Failed to stop validator"
    exit 1
else
    echo "✓ Validator stopped"
    exit 0
fi
