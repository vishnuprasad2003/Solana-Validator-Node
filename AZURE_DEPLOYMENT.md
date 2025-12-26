# Azure VM Deployment Guide

Complete guide for deploying Solana Validator Node on Azure VM with public RPC access.

## Quick Start

```bash
# 1. Clone repository
git clone <your-repo-url>
cd Solana-Validator-Node

# 2. Run Azure setup
chmod +x *.sh scripts/*.sh
./azure-setup.sh

# 3. Install dependencies
./install.sh
source ~/.bashrc

# 4. Setup validator
./setup-validator.sh

# 5. Start validator
./start-validator-tmux.sh
# OR for production:
sudo systemd/install-service.sh
sudo systemctl start solana-validator
sudo systemctl enable solana-validator
```

## Prerequisites

- Azure account with active subscription
- SSH access to Azure VM
- Ubuntu 22.04 LTS VM

## Step-by-Step Deployment

### 1. Create Azure VM

**Via Azure Portal:**
1. Go to Azure Portal → Virtual Machines → Create
2. Choose Ubuntu 22.04 LTS
3. Select VM size: **Standard_B2s** (2 vCPU, 4GB RAM) minimum
4. Configure networking:
   - Create new Virtual Network
   - Create new Network Security Group (NSG)
5. Configure public IP: **Create new** (required)
6. Enable SSH access (port 22)
7. Create and download SSH key pair

**Via Azure CLI:**
```bash
# Create resource group
az group create --name solana-validator-rg --location eastus

# Create VM
az vm create \
  --resource-group solana-validator-rg \
  --name solana-validator-vm \
  --image Ubuntu2204 \
  --size Standard_B2s \
  --admin-username azureuser \
  --generate-ssh-keys \
  --public-ip-sku Standard
```

### 2. Configure Azure Network Security Group (NSG)

**CRITICAL:** You must allow inbound traffic on port 8899.

**Via Azure Portal:**
1. Go to your VM → Networking
2. Click on Network Security Group
3. Add inbound rule:
   - **Name**: `solana-rpc`
   - **Priority**: 1000
   - **Source**: `Any` (or specific IPs for security)
   - **Source port ranges**: `*`
   - **Destination**: `Any`
   - **Destination port ranges**: `8899`
   - **Protocol**: `TCP`
   - **Action**: `Allow`
4. Click **Add**

**Via Azure CLI:**
```bash
# Get NSG name
NSG_NAME=$(az vm show -g solana-validator-rg -n solana-validator-vm \
  --query networkProfile.networkInterfaces[0].id -o tsv | \
  xargs -I {} az network nic show --ids {} \
  --query networkSecurityGroup.id -o tsv | \
  xargs -I {} az network nsg show --ids {} --query name -o tsv)

# Add inbound rule for RPC
az network nsg rule create \
  --resource-group solana-validator-rg \
  --nsg-name $NSG_NAME \
  --name solana-rpc \
  --priority 1000 \
  --protocol Tcp \
  --destination-port-ranges 8899 \
  --access Allow
```

### 3. Connect to Azure VM

```bash
ssh azureuser@<your-public-ip>
```

### 4. Clone and Setup

```bash
# Install git if needed
sudo apt update
sudo apt install -y git

# Clone repository
git clone <your-repo-url>
cd Solana-Validator-Node

# Make scripts executable
chmod +x *.sh scripts/*.sh systemd/*.sh

# Run Azure setup (configures IP, firewall, etc.)
./azure-setup.sh
```

### 5. Install Dependencies

```bash
./install.sh
source ~/.bashrc

# Verify installation
solana --version
rustc --version
```

### 6. Setup Validator

```bash
./setup-validator.sh
```

This creates:
- Ledger directory
- Keypairs
- Management scripts

### 7. Configure for Public Access

The `azure-setup.sh` script already configured this, but you can verify:

```bash
./configure-rpc-public.sh
```

This will:
- Detect VM's private IP (for binding)
- Detect VM's public IP (for access)
- Update configuration files

### 8. Start Validator

**Development (tmux):**
```bash
./start-validator-tmux.sh

# View logs
tmux attach -t solana-validator
```

**Production (systemd):**
```bash
sudo systemd/install-service.sh
sudo systemctl start solana-validator
sudo systemctl enable solana-validator

# View logs
sudo journalctl -u solana-validator -f
```

### 9. Verify Setup

```bash
# Wait 30 seconds for initialization
sleep 30

# Test locally
./verify-setup.sh

# Test RPC
curl -X POST http://127.0.0.1:8899 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
```

### 10. Test Public Access

**Get Public IP:**
```bash
# From Azure Portal → VM → Overview → Public IP address
# Or from VM:
curl -s https://api.ipify.org
```

**Test from external machine:**
```bash
curl -X POST http://<your-azure-public-ip>:8899 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
```

**Expected Response:**
```json
{"jsonrpc":"2.0","result":"ok","id":1}
```

## Understanding IP Addresses

- **Private IP** (e.g., `10.0.0.5`): Used for validator binding (required)
- **Public IP** (e.g., `20.123.45.67`): Used for external access

The validator binds to the **private IP**, but you access it via the **public IP**. Azure automatically routes public IP → private IP.

## RPC Endpoint URLs

- **Local (on VM)**: `http://127.0.0.1:8899`
- **Private Network**: `http://<private-ip>:8899`
- **Public Internet**: `http://<public-ip>:8899` ← Use this in Postman Web

## Security Best Practices

1. **IP Whitelisting** (Recommended):
   ```bash
   sudo scripts/security-setup.sh
   nano ~/solana-cluster-config/allowed-ips.txt
   # Add trusted IPs, one per line
   sudo scripts/security-setup.sh  # Apply
   ```

2. **Restrict NSG** to specific IPs:
   ```bash
   az network nsg rule create \
     --resource-group solana-validator-rg \
     --nsg-name $NSG_NAME \
     --name solana-rpc-restricted \
     --priority 1000 \
     --source-address-prefixes "203.0.113.0/32" \
     --protocol Tcp \
     --destination-port-ranges 8899 \
     --access Allow
   ```

3. **SSH Security**:
   - Use SSH key authentication
   - Disable password authentication
   - Consider changing SSH port

4. **Monitoring**:
   ```bash
   scripts/monitor.sh
   sudo journalctl -u solana-validator -f
   ```

## Troubleshooting

### RPC Not Accessible from Internet

1. **Check Azure NSG:**
   ```bash
   az network nsg rule list \
     --resource-group solana-validator-rg \
     --nsg-name $NSG_NAME -o table
   ```

2. **Check VM Firewall:**
   ```bash
   sudo ufw status
   ```

3. **Verify Validator is Running:**
   ```bash
   pgrep -f solana-test-validator
   sudo systemctl status solana-validator
   ```

4. **Check Port Binding:**
   ```bash
   sudo netstat -tlnp | grep 8899
   # Should show: 0.0.0.0:8899
   ```

### Connection Timeout

- Verify Azure NSG rule is configured correctly
- Check if VM has a public IP assigned
- Verify firewall on VM allows port 8899
- Check if validator is running and bound correctly

### Connection Refused

- Validator may not be running
- Validator may be bound to wrong IP
- Firewall may be blocking the connection

## Cost Optimization

- Use **Spot VMs** for development/testing (up to 90% discount)
- Use **Reserved Instances** for production (1-3 year commitment)
- Monitor VM usage and scale down if not needed 24/7

## Production Checklist

- [ ] Azure VM created with appropriate size
- [ ] Public IP assigned to VM
- [ ] Azure NSG configured to allow port 8899
- [ ] Repository cloned on VM
- [ ] `azure-setup.sh` executed
- [ ] Validator installed and configured
- [ ] VM firewall (UFW) configured
- [ ] IP whitelist configured (if restricting access)
- [ ] Systemd service installed and enabled
- [ ] Validator running and healthy
- [ ] RPC endpoint accessible from external network
- [ ] SSH security hardened
- [ ] Monitoring configured
- [ ] Backup strategy in place

## Additional Resources

- [Azure VM Documentation](https://docs.microsoft.com/azure/virtual-machines/)
- [Azure NSG Documentation](https://docs.microsoft.com/azure/virtual-network/network-security-groups-overview)
- [Solana RPC API Reference](https://docs.solana.com/api/http)

