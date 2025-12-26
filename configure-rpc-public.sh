#!/bin/bash

# Configure RPC for Public Access
# This script configures the validator to accept RPC connections from any IP (0.0.0.0)
# Use this when you want to expose the RPC endpoint publicly (e.g., on cloud VMs)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Configure RPC for Public Access"
echo "=========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if config.env exists
if [ ! -f "$SCRIPT_DIR/config.env" ]; then
    echo -e "${RED}Error: config.env not found${NC}"
    exit 1
fi

# Step 1: Update config.env for public access
echo -e "${YELLOW}[1/3] Configuring RPC_BIND_ADDRESS for public access...${NC}"

# Auto-detect the machine's PRIVATE IP address (for binding)
# IMPORTANT: Validator must bind to PRIVATE IP, not public IP
# Public IP is only for external access (Azure/cloud handles routing)

MACHINE_IP=""
PUBLIC_IP=""

# Detect Private IP (for binding)
# Method 1: hostname -I (most reliable for local network IP)
if [ -z "$MACHINE_IP" ]; then
    MACHINE_IP=$(hostname -I 2>/dev/null | awk '{print $1}' | grep -v '^$')
fi

# Method 2: ip route (get default route source IP)
if [ -z "$MACHINE_IP" ]; then
    MACHINE_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | head -1)
fi

# Method 3: ifconfig (fallback)
if [ -z "$MACHINE_IP" ]; then
    MACHINE_IP=$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
fi

# Try to detect Public IP (for reference only, not for binding)
PUBLIC_IP=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || \
            curl -s --max-time 3 https://ifconfig.me 2>/dev/null || \
            curl -s --max-time 3 https://icanhazip.com 2>/dev/null || \
            echo "")

# If still no private IP found, prompt user
if [ -z "$MACHINE_IP" ]; then
    echo -e "${YELLOW}⚠ Could not auto-detect IP address${NC}"
    echo ""
    echo "Please enter your machine's PRIVATE IP address:"
    echo "  - For local network: Use your LAN IP (e.g., 192.168.x.x)"
    echo "  - For cloud VM: Use the VM's PRIVATE IP (not public IP)"
    echo "    Example: Azure VM private IP might be 10.0.0.5"
    echo ""
    read -p "Private IP address: " MACHINE_IP
    if [ -z "$MACHINE_IP" ]; then
        echo -e "${RED}Error: IP address is required${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}✓ Auto-detected Private IP: $MACHINE_IP${NC}"
if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "$MACHINE_IP" ]; then
    echo -e "${BLUE}  Detected Public IP: $PUBLIC_IP${NC}"
    echo -e "${YELLOW}  ⚠ Use PUBLIC IP in Postman Web: http://$PUBLIC_IP:8899${NC}"
fi
echo ""
echo -e "${BLUE}Important:${NC}"
echo "  • Validator binds to PRIVATE IP: $MACHINE_IP (required for gossip protocol)"
echo "  • Access via PRIVATE IP on local network: http://$MACHINE_IP:8899"
if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "$MACHINE_IP" ]; then
    echo "  • Access via PUBLIC IP from internet: http://$PUBLIC_IP:8899"
    echo "  • For Postman Web, use: http://$PUBLIC_IP:8899"
fi
echo "  • solana-test-validator requires a specific IP (not 0.0.0.0)"
echo ""

# Check current bind address
CURRENT_BIND=$(grep "^RPC_BIND_ADDRESS=" "$SCRIPT_DIR/config.env" | cut -d'=' -f2 | tr -d '"')

if [ "$CURRENT_BIND" = "$MACHINE_IP" ] || [ "$CURRENT_BIND" = "0.0.0.0" ]; then
    if [ "$CURRENT_BIND" != "$MACHINE_IP" ]; then
        echo "Updating RPC_BIND_ADDRESS from $CURRENT_BIND to $MACHINE_IP"
        sed -i "s/^RPC_BIND_ADDRESS=.*/RPC_BIND_ADDRESS=\"$MACHINE_IP\"/" "$SCRIPT_DIR/config.env"
        echo -e "${GREEN}✓ Updated config.env${NC}"
    else
        echo -e "${GREEN}✓ RPC_BIND_ADDRESS already set to $MACHINE_IP (public access)${NC}"
    fi
elif [ "$CURRENT_BIND" = "127.0.0.1" ]; then
    echo "Updating RPC_BIND_ADDRESS from 127.0.0.1 to $MACHINE_IP"
    sed -i "s/^RPC_BIND_ADDRESS=\"127\.0\.0\.1\"/RPC_BIND_ADDRESS=\"$MACHINE_IP\"/" "$SCRIPT_DIR/config.env"
    echo -e "${GREEN}✓ Updated config.env${NC}"
else
    echo -e "${YELLOW}⚠ RPC_BIND_ADDRESS is set to: $CURRENT_BIND${NC}"
    read -p "Change to $MACHINE_IP? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        sed -i "s/^RPC_BIND_ADDRESS=.*/RPC_BIND_ADDRESS=\"$MACHINE_IP\"/" "$SCRIPT_DIR/config.env"
        echo -e "${GREEN}✓ Updated config.env${NC}"
    fi
fi

# Step 2: Update start script if validator is already set up
if [ -f "$SCRIPT_DIR/start-validator.sh" ]; then
    echo ""
    echo -e "${YELLOW}[2/3] Updating start-validator.sh...${NC}"
    
    # Check if start-validator.sh uses hardcoded value
    if grep -q 'RPC_BIND_ADDRESS="127.0.0.1"' "$SCRIPT_DIR/start-validator.sh"; then
        # Backup existing script
        cp "$SCRIPT_DIR/start-validator.sh" "$SCRIPT_DIR/start-validator.sh.backup"
        echo "Backed up start-validator.sh to start-validator.sh.backup"
        
        # Update the hardcoded value
        sed -i "s/RPC_BIND_ADDRESS=\"127\.0\.0\.1\"/RPC_BIND_ADDRESS=\"$MACHINE_IP\"/" "$SCRIPT_DIR/start-validator.sh"
        echo -e "${GREEN}✓ Updated start-validator.sh${NC}"
    elif grep -q "RPC_BIND_ADDRESS=\"$MACHINE_IP\"" "$SCRIPT_DIR/start-validator.sh" || grep -q 'RPC_BIND_ADDRESS="0.0.0.0"' "$SCRIPT_DIR/start-validator.sh"; then
        # Update 0.0.0.0 to actual IP if needed
        if grep -q 'RPC_BIND_ADDRESS="0.0.0.0"' "$SCRIPT_DIR/start-validator.sh"; then
            sed -i "s/RPC_BIND_ADDRESS=\"0\.0\.0\.0\"/RPC_BIND_ADDRESS=\"$MACHINE_IP\"/" "$SCRIPT_DIR/start-validator.sh"
            echo -e "${GREEN}✓ Updated start-validator.sh (changed 0.0.0.0 to $MACHINE_IP)${NC}"
        else
            echo -e "${GREEN}✓ start-validator.sh already configured for public access${NC}"
        fi
    elif grep -q 'source.*config.env' "$SCRIPT_DIR/start-validator.sh" || grep -q 'config.env' "$SCRIPT_DIR/start-validator.sh"; then
        echo -e "${GREEN}✓ start-validator.sh uses config.env (will use updated value)${NC}"
    else
        echo -e "${YELLOW}⚠ start-validator.sh may need manual update${NC}"
    fi
else
    echo ""
    echo -e "${YELLOW}[2/3] Validator not set up yet. Run ./setup-validator.sh first.${NC}"
fi

# Step 3: Display configuration summary and next steps
echo ""
echo -e "${YELLOW}[3/3] Configuration Summary${NC}"
echo ""
echo -e "${GREEN}✓ RPC configured for public access (0.0.0.0)${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "1. Configure firewall to allow port 8899:"
echo "   sudo scripts/firewall-setup.sh"
echo ""
echo "2. Restart validator to apply changes:"
echo "   ./stop-validator.sh"
echo "   ./start-validator.sh"
echo "   # OR for production:"
echo "   sudo systemctl restart solana-validator"
echo ""
echo "4. Test RPC endpoint:"
echo "   curl -X POST http://<your-ip>:8899 \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getHealth\"}'"
echo ""
echo -e "${YELLOW}⚠ Security Note:${NC}"
echo "   Exposing RPC publicly makes it accessible from anywhere."
echo "   Consider using IP whitelisting or VPN for better security."
echo ""
echo -e "${GREEN}=========================================="
echo "Configuration Complete!"
echo "==========================================${NC}"
echo ""
echo "RPC Binding Configuration:"
echo "  • Validator binds to: $MACHINE_IP (PRIVATE IP)"
echo "  • Access on local network: http://$MACHINE_IP:8899"
if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "$MACHINE_IP" ]; then
    echo "  • Access from internet: http://$PUBLIC_IP:8899"
    echo "  • For Postman Web: http://$PUBLIC_IP:8899"
fi
echo ""
echo -e "${BLUE}Understanding IP Addresses:${NC}"
echo "  • PRIVATE IP ($MACHINE_IP): Used for validator binding (required)"
echo "  • PUBLIC IP: Used for external access (cloud routing handles this)"
echo "  • Validator MUST bind to private IP, not public IP"
echo ""
echo -e "${YELLOW}For Postman Web Testing:${NC}"
if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "$MACHINE_IP" ]; then
    echo "  Use: http://$PUBLIC_IP:8899"
else
    echo "  • Use Postman Desktop (can access private IPs)"
    echo "  • Or deploy on cloud VM with public IP"
fi
echo ""
echo "To revert to local-only access, run: ./configure-rpc-local.sh"
echo ""

