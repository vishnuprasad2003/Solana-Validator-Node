# Azure Configuration Guide

This guide covers Azure-specific configuration for the Solana production cluster.

## Overview

This guide helps you configure Azure resources for optimal Solana validator operation, including:

- Network Security Groups (NSG)
- Load Balancers (optional)
- Public IP configuration
- Disk optimization
- VM sizing recommendations

## Prerequisites

- Azure account with appropriate permissions
- Azure CLI installed (`az` command)
- Resource group created
- VM already provisioned

## VM Sizing Recommendations

### Minimum Requirements

- **Size:** Standard_D4s_v3 or equivalent
- **CPU:** 4 vCPUs
- **RAM:** 16 GB
- **Disk:** 128 GB SSD (Premium SSD recommended)
- **Network:** Standard network bandwidth

### Recommended for Production

- **Size:** Standard_D8s_v3 or equivalent
- **CPU:** 8 vCPUs
- **RAM:** 32 GB
- **Disk:** 512 GB Premium SSD
- **Network:** Accelerated networking enabled

### High-Performance Setup

- **Size:** Standard_D16s_v3 or equivalent
- **CPU:** 16 vCPUs
- **RAM:** 64 GB
- **Disk:** 1 TB Premium SSD
- **Network:** Accelerated networking enabled

## Network Security Group Configuration

### Create NSG Rule for RPC Port

```bash
# Set variables
RESOURCE_GROUP="your-resource-group"
NSG_NAME="your-nsg-name"
RPC_PORT=8899

# Create NSG rule for RPC (public access)
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name "solana-rpc" \
  --priority 1000 \
  --protocol Tcp \
  --destination-port-ranges $RPC_PORT \
  --access Allow \
  --description "Solana RPC endpoint - Public access"

# Create NSG rule for gossip port (if multi-node)
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name "solana-gossip" \
  --priority 1001 \
  --protocol Udp \
  --destination-port-ranges 8001 \
  --access Allow \
  --description "Solana gossip port - Multi-node cluster"
```

### Restrict RPC Access by IP (Recommended)

Instead of public access, restrict to specific IPs:

```bash
# Allow specific IP
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name "solana-rpc-restricted" \
  --priority 1000 \
  --protocol Tcp \
  --destination-port-ranges $RPC_PORT \
  --source-address-prefixes "YOUR_IP_ADDRESS" \
  --access Allow \
  --description "Solana RPC endpoint - Restricted access"

# Or allow IP range (CIDR)
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name "solana-rpc-cidr" \
  --priority 1000 \
  --protocol Tcp \
  --destination-port-ranges $RPC_PORT \
  --source-address-prefixes "192.168.1.0/24" \
  --access Allow \
  --description "Solana RPC endpoint - CIDR range"
```

### View NSG Rules

```bash
az network nsg rule list \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --output table
```

## Public IP Configuration

### Get Public IP Address

```bash
# Get VM public IP
VM_NAME="your-vm-name"
RESOURCE_GROUP="your-resource-group"

az vm show \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --show-details \
  --query publicIps \
  --output tsv
```

### Configure Static Public IP

If you need a static IP:

```bash
# Create public IP
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name "solana-validator-ip" \
  --allocation-method Static \
  --sku Standard

# Associate with VM network interface
NIC_NAME=$(az vm show \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --query networkProfile.networkInterfaces[0].id \
  --output tsv | cut -d'/' -f9)

az network nic ip-config update \
  --resource-group $RESOURCE_GROUP \
  --nic-name $NIC_NAME \
  --name ipconfig1 \
  --public-ip-address "solana-validator-ip"
```

## Load Balancer Configuration (Optional)

For high availability or multiple validators:

### Create Load Balancer

```bash
# Create public IP for load balancer
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name "solana-lb-ip" \
  --allocation-method Static \
  --sku Standard

# Create load balancer
az network lb create \
  --resource-group $RESOURCE_GROUP \
  --name "solana-lb" \
  --public-ip-address "solana-lb-ip" \
  --frontend-ip-name "solana-frontend" \
  --backend-pool-name "solana-backend"

# Create health probe
az network lb probe create \
  --resource-group $RESOURCE_GROUP \
  --lb-name "solana-lb" \
  --name "solana-health-probe" \
  --protocol Tcp \
  --port 8899

# Create load balancing rule
az network lb rule create \
  --resource-group $RESOURCE_GROUP \
  --lb-name "solana-lb" \
  --name "solana-rpc-rule" \
  --protocol Tcp \
  --frontend-port 8899 \
  --backend-port 8899 \
  --frontend-ip-name "solana-frontend" \
  --backend-pool-name "solana-backend" \
  --probe-name "solana-health-probe"
```

## Disk Configuration

### Resize Disk

If you need more disk space:

```bash
# Stop VM (required for disk resize)
az vm deallocate \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME

# Resize disk
DISK_NAME=$(az vm show \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --query storageProfile.osDisk.name \
  --output tsv)

az disk update \
  --resource-group $RESOURCE_GROUP \
  --name $DISK_NAME \
  --size-gb 512

# Start VM
az vm start \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME

# After VM starts, resize filesystem (SSH into VM)
sudo resize2fs /dev/sda1
```

### Use Premium SSD

For better performance:

```bash
# Create premium disk
az disk create \
  --resource-group $RESOURCE_GROUP \
  --name "solana-premium-disk" \
  --size-gb 512 \
  --sku Premium_LRS

# Attach to VM (requires VM stop)
az vm disk attach \
  --resource-group $RESOURCE_GROUP \
  --vm-name $VM_NAME \
  --disk "solana-premium-disk"
```

## VM Optimization

### Enable Accelerated Networking

```bash
# Stop VM
az vm deallocate \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME

# Get NIC name
NIC_ID=$(az vm show \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --query networkProfile.networkInterfaces[0].id \
  --output tsv)

NIC_NAME=$(echo $NIC_ID | cut -d'/' -f9)

# Enable accelerated networking
az network nic update \
  --resource-group $RESOURCE_GROUP \
  --name $NIC_NAME \
  --accelerated-networking true

# Start VM
az vm start \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME
```

### Configure Auto-Shutdown (Optional)

To save costs during non-production hours:

```bash
az vm auto-shutdown \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --time "1900" \
  --email "your-email@example.com"
```

## Monitoring Setup

### Enable Azure Monitor

```bash
# Enable VM insights
az vm extension set \
  --resource-group $RESOURCE_GROUP \
  --vm-name $VM_NAME \
  --name "AzureMonitorLinuxAgent" \
  --publisher "Microsoft.Azure.Monitor"
```

### Create Alert Rules

```bash
# Alert for high CPU
az monitor metrics alert create \
  --name "solana-high-cpu" \
  --resource-group $RESOURCE_GROUP \
  --scopes "/subscriptions/SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/$VM_NAME" \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m
```

## Backup Configuration

### Configure Azure Backup

```bash
# Create recovery services vault
az backup vault create \
  --resource-group $RESOURCE_GROUP \
  --name "solana-backup-vault" \
  --location "eastus"

# Enable backup for VM
az backup protection enable-for-vm \
  --resource-group $RESOURCE_GROUP \
  --vault-name "solana-backup-vault" \
  --vm $VM_NAME \
  --policy-name "DefaultPolicy"
```

## Security Best Practices

### 1. Use Managed Identity

```bash
# Enable system-assigned managed identity
az vm identity assign \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME
```

### 2. Enable Azure Security Center

```bash
# Enable security center (if not already enabled)
az security pricing create \
  --name "VirtualMachines" \
  --tier "Standard"
```

### 3. Restrict SSH Access

Configure NSG to only allow SSH from trusted IPs:

```bash
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name "ssh-restricted" \
  --priority 100 \
  --protocol Tcp \
  --destination-port-ranges 22 \
  --source-address-prefixes "YOUR_TRUSTED_IP" \
  --access Allow
```

## Cost Optimization

### Use Spot Instances (Development Only)

```bash
# Create spot VM (not recommended for production)
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --image Ubuntu2204 \
  --priority Spot \
  --max-price -1
```

### Use Reserved Instances (Production)

Purchase reserved instances through Azure Portal for cost savings.

### Monitor Costs

```bash
# View VM costs
az consumption usage list \
  --start-date $(date -d "1 month ago" +%Y-%m-%d) \
  --end-date $(date +%Y-%m-%d)
```

## Troubleshooting Azure Issues

### VM Not Accessible

1. Check NSG rules
2. Check VM status: `az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME --show-details`
3. Check boot diagnostics: Azure Portal → VM → Boot diagnostics

### Network Issues

1. Check NSG rules: `az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME`
2. Check route table
3. Verify public IP configuration

### Performance Issues

1. Check VM metrics in Azure Portal
2. Verify disk performance tier
3. Check network bandwidth
4. Review VM size recommendations

## Integration with Repository Scripts

Update `configs/config.env` with Azure-specific values:

```bash
# Azure Configuration
AZURE_NSG_NAME="your-nsg-name"
AZURE_LB_NAME="your-lb-name"  # If using load balancer
PUBLIC_IP="your-public-ip"    # Will be auto-detected if empty
```

Then run:

```bash
./scripts/configure-networking.sh
```

This will attempt to configure Azure resources if Azure CLI is available.

## Additional Resources

- [Azure VM Documentation](https://docs.microsoft.com/azure/virtual-machines/)
- [Azure Networking Documentation](https://docs.microsoft.com/azure/networking/)
- [Azure Security Best Practices](https://docs.microsoft.com/azure/security/fundamentals/best-practices-and-patterns)

