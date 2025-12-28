# Initial Setup Guide

This guide provides step-by-step instructions for setting up a Solana production cluster on any Linux system (Azure, AWS, GCP, or local VMs).

## Prerequisites

Before beginning, ensure you have:

- **Linux Distribution**: Ubuntu 22.04+, Debian 11+, CentOS 8+, RHEL 8+, Fedora 38+, Arch Linux, or compatible
- **Resources**: 
  - Minimum: 8GB RAM, 100GB SSD
  - Recommended: 16GB+ RAM, 500GB+ SSD
- **Network**: Static IP address assigned to VM
- **Access**: SSH access with sudo privileges
- **Firewall**: Scripts automatically detect and configure UFW, firewalld, or iptables

> **Note**: All scripts are cross-platform and automatically detect your OS, package manager, and firewall tool. See [Portability Guide](../docs/06-portability.md) for details.

## Step 1: Prepare the VM

> **Note**: The installation script (`install.sh`) automatically handles system updates and package installation for your distribution. You can skip manual preparation steps if desired.

### 1.1 Update System

The installation script will handle this automatically, but you can manually update:

**Debian/Ubuntu:**
```bash
sudo apt-get update
sudo apt-get upgrade -y
```

**RHEL/CentOS/Fedora:**
```bash
sudo dnf update -y  # or: sudo yum update -y
```

**Arch Linux:**
```bash
sudo pacman -Syu
```

### 1.2 Install Basic Tools

The installation script will install required packages automatically, but you can install basic tools manually:

**Debian/Ubuntu:**
```bash
sudo apt-get install -y git curl wget jq
```

**RHEL/CentOS/Fedora:**
```bash
sudo dnf install -y git curl wget jq  # or: sudo yum install -y git curl wget jq
```

**Arch Linux:**
```bash
sudo pacman -S git curl wget jq
```

## Step 2: Clone Repository

```bash
cd ~
git clone <your-repo-url> Solana-Validator-Node
cd Solana-Validator-Node
chmod +x scripts/*.sh systemd/*.sh
```

## Step 3: Review Configuration

Before proceeding, review and adjust the configuration file:

```bash
nano configs/config.env
```

**Key settings to review:**

- `SOLANA_VERSION`: Version to install (default: "stable")
- `RPC_BIND_ADDRESS`: Set to "0.0.0.0" for public access
- `RPC_PORT`: RPC port (default: 8899)
- `ENABLE_RPC_WHITELIST`: Enable IP whitelist for security
- `LEDGER_DIR`: Location for blockchain data
- `MAX_LEDGER_SIZE_GB`: Maximum ledger size (default: 500GB)

## Step 4: Install Dependencies

Run the installation script:

```bash
./scripts/install.sh
```

This script will:
- Update system packages
- Install Rust compiler
- Install Solana CLI
- Install Anchor framework (optional)
- Configure shell environment

**Expected duration:** 10-15 minutes

After installation, reload your shell:

```bash
source ~/.bashrc
```

Verify installation:

```bash
solana --version
rustc --version
```

## Step 5: Setup Cluster

Initialize the validator node:

```bash
./scripts/setup-cluster.sh
```

This script will:
- Create necessary directories
- Generate validator keypair
- Generate default keypair for transactions
- Configure Solana CLI
- Download Metaplex Token Metadata program (if enabled)

**Important:** Save the validator address displayed - you'll need it for cluster operations.

## Step 6: Configure Networking

Configure firewall and Azure networking:

```bash
./scripts/configure-networking.sh
```

This script will:
- Configure UFW firewall
- Set up RPC port access
- Detect public IP address
- Optionally configure Azure Network Security Groups

**For Azure NSG configuration:**

If you want to configure Azure Network Security Groups, you'll need:
- Azure CLI installed (`az` command)
- Proper authentication configured
- Resource group and NSG name

See `docs/05-azure-configuration.md` for detailed Azure setup.

## Step 7: Start Validator

### Option A: Manual Start (Testing)

```bash
./scripts/start-validator.sh
```

### Option B: Systemd Service (Production)

```bash
# Install systemd service
sudo systemd/install-service.sh

# Start and enable service
sudo systemctl start solana-validator
sudo systemctl enable solana-validator

# Check status
sudo systemctl status solana-validator

# View logs
sudo journalctl -u solana-validator -f
```

## Step 8: Verify Installation

Run the verification script:

```bash
./scripts/verify-setup.sh
```

This will check:
- Solana CLI installation
- Rust installation
- Validator keypair
- Ledger directory
- Validator process status
- RPC endpoint responsiveness
- Firewall configuration

## Step 9: Test RPC Access

### Local Test

```bash
curl http://localhost:8899 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
```

### External Test

From another machine:

```bash
curl http://<YOUR_PUBLIC_IP>:8899 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
```

Replace `<YOUR_PUBLIC_IP>` with your VM's public IP address.

## Step 10: Configure IP Whitelist (Optional but Recommended)

If you enabled `ENABLE_RPC_WHITELIST` in `config.env`:

1. Edit the whitelist file:

```bash
nano ~/solana-security-config/allowed-ips.txt
```

2. Add allowed IPs (one per line, CIDR supported):

```
192.168.1.0/24
10.0.0.1
```

3. Re-run networking configuration:

```bash
./scripts/configure-networking.sh
```

## Troubleshooting

### Validator Won't Start

1. Check logs:
   ```bash
   tail -f logs/validator.log
   ```

2. Check if port is in use:
   ```bash
   sudo netstat -tulpn | grep 8899
   ```

3. Verify configuration:
   ```bash
   ./scripts/verify-setup.sh
   ```

### RPC Not Accessible

1. Check firewall:
   ```bash
   sudo ufw status
   ```

2. Check Azure NSG rules (if using Azure)

3. Verify bind address in `config.env` is `0.0.0.0`

### Disk Space Issues

Monitor disk usage:

```bash
df -h
du -sh ~/solana-ledger
```

If ledger is too large, consider:
- Increasing `MAX_LEDGER_SIZE_GB` in `config.env`
- Archiving old ledger data
- Using a larger disk

## Next Steps

After successful setup:

1. **Monitor the cluster**: `./scripts/monitor.sh`
2. **Review operations guide**: `docs/02-operations.md`
3. **Set up backups**: See operations guide
4. **Configure monitoring**: See operations guide

## Security Checklist

- [ ] Firewall configured
- [ ] IP whitelist configured (if using)
- [ ] SSH key-based authentication enabled
- [ ] System updates applied
- [ ] Validator keypair backed up securely
- [ ] RPC endpoint tested and working
- [ ] Systemd service installed (for production)

## Support

If you encounter issues:

1. Check `docs/04-troubleshooting.md`
2. Review logs: `logs/validator.log`
3. Run verification: `./scripts/verify-setup.sh`
4. Check systemd logs: `sudo journalctl -u solana-validator`

