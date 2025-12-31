#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -f "$REPO_ROOT/configs/config.env" ] && source "$REPO_ROOT/configs/config.env"

[ $# -lt 1 ] && { echo "Usage: $0 <bootstrap_node_ip:gossip_port>"; echo "Example: $0 192.168.1.100:8001"; exit 1; }

BOOTSTRAP="$1"
CONFIG_FILE="$REPO_ROOT/configs/config.env"

[ ! -f "$CONFIG_FILE" ] && { echo "Error: Config file not found: $CONFIG_FILE"; exit 1; }

echo "Adding node to cluster..."
echo "  Bootstrap node: $BOOTSTRAP"
echo ""

# Update configuration safely
sed -i "s/^CLUSTER_MODE=.*/CLUSTER_MODE=true/" "$CONFIG_FILE" 2>/dev/null || echo "CLUSTER_MODE=true" >> "$CONFIG_FILE"
sed -i "s/^NODE_ROLE=.*/NODE_ROLE=validator/" "$CONFIG_FILE" 2>/dev/null || echo "NODE_ROLE=validator" >> "$CONFIG_FILE"
sed -i "s|^BOOTSTRAP_NODE=.*|BOOTSTRAP_NODE=\"$BOOTSTRAP\"|" "$CONFIG_FILE" 2>/dev/null || echo "BOOTSTRAP_NODE=\"$BOOTSTRAP\"" >> "$CONFIG_FILE"

echo "✓ Configuration updated"
echo "  CLUSTER_MODE=true"
echo "  NODE_ROLE=validator"
echo "  BOOTSTRAP_NODE=$BOOTSTRAP"
echo ""
echo "Start validator with: ./scripts/start-validator.sh"

