#!/bin/bash

# Azure VM Quick Setup Script
# This script prepares the Solana Validator Node for Azure VM deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Azure VM Setup for Solana Validator"
echo "=========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step 1: Detect Azure VM environment
echo -e "${YELLOW}[1/5] Detecting Azure VM environment...${NC}"

# Check if running on Azure VM
IS_AZURE=false
if [ -f /sys/class/dmi/id/bios_version ] && grep -q "Microsoft Corporation" /sys/class/dmi/id/bios_version 2>/dev/null; then
    IS_AZURE=true
elif [ -f /sys/class/dmi/id/sys_vendor ] && grep -qi "Microsoft" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
    IS_AZURE=true
fi

if [ "$IS_AZURE" = true ]; then
    echo -e "${GREEN}✓ Running on Azure VM${NC}"
else
    echo -e "${YELLOW}⚠ Not detected as Azure VM (may still work)${NC}"
fi

# Detect private IP (for validator binding)
PRIVATE_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || \
             ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || \
             echo "")

if [ -z "$PRIVATE_IP" ]; then
    echo -e "${RED}Error: Could not detect private IP${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Detected Private IP: $PRIVATE_IP${NC}"

# Try to get public IP (for reference)
PUBLIC_IP=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || \
            curl -s --max-time 3 https://ifconfig.me 2>/dev/null || \
            echo "")

if [ -n "$PUBLIC_IP" ]; then
    echo -e "${GREEN}✓ Detected Public IP: $PUBLIC_IP${NC}"
else
    echo -e "${YELLOW}⚠ Could not detect public IP (check Azure Portal)${NC}"
fi

# Step 2: Configure RPC for public access
echo ""
echo -e "${YELLOW}[2/5] Configuring RPC for public access...${NC}"

if [ -f "$SCRIPT_DIR/config.env" ]; then
    # Update config.env with private IP
    CURRENT_BIND=$(grep "^RPC_BIND_ADDRESS=" "$SCRIPT_DIR/config.env" | cut -d'=' -f2 | tr -d '"')
    
    if [ "$CURRENT_BIND" != "$PRIVATE_IP" ]; then
        sed -i "s/^RPC_BIND_ADDRESS=.*/RPC_BIND_ADDRESS=\"$PRIVATE_IP\"/" "$SCRIPT_DIR/config.env"
        echo -e "${GREEN}✓ Updated config.env: RPC_BIND_ADDRESS=\"$PRIVATE_IP\"${NC}"
    else
        echo -e "${GREEN}✓ RPC_BIND_ADDRESS already configured${NC}"
    fi
else
    echo -e "${RED}Error: config.env not found${NC}"
    exit 1
fi

# Step 3: Setup firewall
echo ""
echo -e "${YELLOW}[3/5] Configuring firewall...${NC}"

if command -v ufw &> /dev/null; then
    echo "Configuring UFW firewall..."
    sudo ufw allow 22/tcp comment "SSH" 2>/dev/null || true
    sudo ufw allow 8899/tcp comment "Solana RPC" 2>/dev/null || true
    sudo ufw allow 9900/tcp comment "Solana Faucet" 2>/dev/null || true
    
    if ! sudo ufw status | grep -q "Status: active"; then
        echo -e "${YELLOW}Enabling UFW firewall...${NC}"
        echo "y" | sudo ufw enable 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Firewall configured${NC}"
else
    echo -e "${YELLOW}⚠ UFW not installed. Install with: sudo apt install ufw${NC}"
fi

# Step 4: Azure NSG reminder
echo ""
echo -e "${YELLOW}[4/5] Azure Network Security Group (NSG) Configuration${NC}"
echo ""
echo -e "${BLUE}IMPORTANT: Configure Azure NSG to allow port 8899${NC}"
echo ""
echo "Steps:"
echo "1. Go to Azure Portal → Your VM → Networking"
echo "2. Click on Network Security Group"
echo "3. Add inbound rule:"
echo "   - Name: solana-rpc"
echo "   - Priority: 1000"
echo "   - Source: Any (or specific IPs)"
echo "   - Destination port: 8899"
echo "   - Protocol: TCP"
echo "   - Action: Allow"
echo ""
echo "Or use Azure CLI:"
echo "  az network nsg rule create \\"
echo "    --resource-group <your-rg> \\"
echo "    --nsg-name <your-nsg> \\"
echo "    --name solana-rpc \\"
echo "    --priority 1000 \\"
echo "    --protocol Tcp \\"
echo "    --destination-port-ranges 8899 \\"
echo "    --access Allow"
echo ""

# Step 5: Installation status
echo ""
echo -e "${YELLOW}[5/5] Installation Status${NC}"

if [ -f "$SCRIPT_DIR/start-validator.sh" ]; then
    echo -e "${GREEN}✓ Validator scripts ready${NC}"
else
    echo -e "${YELLOW}⚠ Run ./setup-validator.sh to initialize${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Azure VM Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Configuration Summary:"
echo "  • Private IP (for binding): $PRIVATE_IP"
if [ -n "$PUBLIC_IP" ]; then
    echo "  • Public IP (for access): $PUBLIC_IP"
fi
echo "  • RPC Port: 8899"
echo ""
echo "Next Steps:"
echo "1. Configure Azure NSG (see above)"
echo "2. Initialize validator: ./install.sh && ./setup-validator.sh"
echo "3. Start validator: ./start-validator-tmux.sh"
echo "   OR for production: sudo systemd/install-service.sh"
echo "4. Test RPC:"
if [ -n "$PUBLIC_IP" ]; then
    echo "   curl -X POST http://$PUBLIC_IP:8899 \\"
else
    echo "   curl -X POST http://<your-public-ip>:8899 \\"
fi
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getHealth\"}'"
echo ""
echo "For Postman Web, use: http://$PUBLIC_IP:8899"
echo ""

