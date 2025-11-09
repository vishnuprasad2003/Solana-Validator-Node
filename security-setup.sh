#!/bin/bash

# Security Setup Script for Private Solana Network
# Configures firewall, access control, and security settings

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Security Configuration for Private Network"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}This script must be run as root (use sudo)${NC}"
   exit 1
fi

RPC_PORT=8899
FAUCET_PORT=9900
GOSSIP_PORT=8001

# Step 1: Configure Firewall
echo -e "${YELLOW}[1/4] Configuring firewall...${NC}"

# Check if UFW is installed
if ! command -v ufw &> /dev/null; then
    echo "Installing UFW..."
    apt-get update
    apt-get install -y ufw
fi

# Default deny
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (important!)
ufw allow 22/tcp comment "SSH"

# Allow RPC only from specific IPs (if configured)
if [ -f "$HOME/solana-cluster-config/allowed-ips.txt" ]; then
    echo "Configuring IP whitelist for RPC..."
    while IFS= read -r ip; do
        [ -z "$ip" ] && continue
        ufw allow from "$ip" to any port "$RPC_PORT" comment "Solana RPC from $ip"
    done < "$HOME/solana-cluster-config/allowed-ips.txt"
else
    echo -e "${YELLOW}No IP whitelist found. Allowing RPC from all IPs (not recommended for production).${NC}"
    echo "Create $HOME/solana-cluster-config/allowed-ips.txt to restrict access."
    read -p "Allow RPC from all IPs? (yes/no): " allow_all
    if [ "$allow_all" = "yes" ]; then
        ufw allow "$RPC_PORT/tcp" comment "Solana RPC"
    fi
fi

# Allow gossip port for cluster communication
ufw allow "$GOSSIP_PORT/udp" comment "Solana Gossip"

# Enable firewall
ufw --force enable

echo -e "${GREEN}✓ Firewall configured${NC}"

# Step 2: Create IP whitelist template
echo ""
echo -e "${YELLOW}[2/4] Creating IP whitelist template...${NC}"

mkdir -p "$HOME/solana-cluster-config"

if [ ! -f "$HOME/solana-cluster-config/allowed-ips.txt" ]; then
    cat > "$HOME/solana-cluster-config/allowed-ips.txt" << 'EOF'
# Allowed IPs for RPC Access
# Add one IP address per line
# Example:
# 192.168.1.100
# 10.0.0.50
EOF
    echo -e "${GREEN}✓ IP whitelist template created${NC}"
    echo "  File: $HOME/solana-cluster-config/allowed-ips.txt"
    echo "  Add allowed IPs to this file and run this script again"
else
    echo -e "${GREEN}✓ IP whitelist exists${NC}"
fi

# Step 3: Create access control script
echo ""
echo -e "${YELLOW}[3/4] Creating access control helper...${NC}"

cat > /usr/local/bin/solana-allow-ip << 'EOFSCRIPT'
#!/bin/bash
# Add IP to Solana RPC whitelist

if [ -z "$1" ]; then
    echo "Usage: solana-allow-ip <ip-address>"
    exit 1
fi

IP="$1"
ALLOWED_IPS="$HOME/solana-cluster-config/allowed-ips.txt"

if ! grep -q "^$IP$" "$ALLOWED_IPS" 2>/dev/null; then
    echo "$IP" >> "$ALLOWED_IPS"
    echo "Added $IP to whitelist"
    echo "Run: sudo ./security-setup.sh to apply changes"
else
    echo "$IP is already in whitelist"
fi
EOFSCRIPT

chmod +x /usr/local/bin/solana-allow-ip
echo -e "${GREEN}✓ Access control helper created${NC}"

# Step 4: Security recommendations
echo ""
echo -e "${YELLOW}[4/4] Security recommendations...${NC}"
echo ""
echo -e "${BLUE}Security Best Practices:${NC}"
echo "1. ✅ Firewall configured"
echo "2. ✅ IP whitelist template created"
echo "3. ⚠️  Configure IP whitelist: Edit $HOME/solana-cluster-config/allowed-ips.txt"
echo "4. ⚠️  Use VPN for remote access (recommended)"
echo "5. ⚠️  Enable SSH key authentication (disable password auth)"
echo "6. ⚠️  Regular security updates: apt-get update && apt-get upgrade"
echo "7. ⚠️  Monitor logs: journalctl -u solana-validator -f"
echo "8. ⚠️  Use HTTPS reverse proxy for RPC (optional)"
echo ""

echo -e "${GREEN}=========================================="
echo "Security Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Firewall status:"
ufw status
echo ""
echo "To add allowed IPs:"
echo "  solana-allow-ip <ip-address>"
echo "  sudo ./security-setup.sh"
echo ""

