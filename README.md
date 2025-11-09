# Solana Private Validator Node Setup

A production-ready setup script for deploying a private Solana blockchain validator node on Linux servers. Each deployment creates an independent private blockchain network.

## 🎯 Overview

This repository provides everything needed to set up a private Solana validator node. When deployed on different systems or servers, each instance runs as a **separate independent private blockchain network**.

### Features

- ✅ Automated installation of Rust, Solana CLI, and dependencies
- ✅ Persistent ledger storage
- ✅ RPC endpoint (local and remote access)
- ✅ **Multi-node cluster support** - Connect multiple validators
- ✅ **Security & access control** - IP whitelist, firewall rules
- ✅ **Maintenance tools** - Monitoring, health checks, backups
- ✅ Background process management (tmux/systemd)
- ✅ Production-ready for enterprise deployment

## 📋 Prerequisites

- **OS**: Ubuntu 22.04 LTS (or compatible Linux distribution)
- **RAM**: Minimum 4GB
- **Disk**: 20GB free space
- **Access**: sudo/root privileges for package installation
- **Network**: Internet connection for initial setup

## 🚀 Quick Start

### Step 1: Clone and Install

```bash
git clone <your-repo-url>
cd Solana-Validator-Node
chmod +x install.sh setup-validator.sh
./install.sh
source ~/.bashrc  # Reload shell
```

### Step 2: Setup Validator

```bash
./setup-validator.sh
```

This creates ledger directory, keypairs, and management scripts.

### Step 3: Start Validator

```bash
# Development (tmux)
./start-validator-tmux.sh

# Production (systemd)
sudo systemd/install-service.sh
sudo systemctl start solana-validator
sudo systemctl enable solana-validator
```

### Step 4: Verify

Wait 10-30 seconds, then:

```bash
./verify-setup.sh
```

## 📖 Detailed Setup Guide

### Installation Script (`install.sh`)

Installs all required dependencies:

```bash
./install.sh
```

**What it does:**
- Checks/installs Rust
- Installs Solana CLI
- Installs system packages (build-essential, libudev-dev, libssl-dev)
- Configures PATH in shell profile

**Verify installation:**
```bash
rustc --version
solana --version
```

### Validator Setup (`setup-validator.sh`)

Initializes the validator:

```bash
./setup-validator.sh
```

**What it creates:**
- `~/solana-local-ledger/` - Blockchain data storage
- `~/.config/solana/validator-keypair.json` - Validator identity
- `~/.config/solana/id.json` - Default keypair for transactions
- `~/.local/share/solana-programs/mpl-token-metadata.so` - Metaplex Token Metadata program (downloaded from mainnet)
- Management scripts (start, stop, reset, download-metaplex-program)

**Keypair addresses:**
```bash
# Validator keypair
solana address -k ~/.config/solana/validator-keypair.json

# Default keypair
solana address -k ~/.config/solana/id.json
```

### Starting the Validator

#### Method 1: Tmux (Background Process)

```bash
./start-validator-tmux.sh
```

**View logs:**
```bash
tmux attach -t solana-validator
```

**Detach from logs** (keeps validator running):
- Press `Ctrl+B`, then `D`

**Stop validator:**
```bash
./stop-validator.sh
```

#### Method 2: Systemd (Production)

```bash
# Install service
sudo systemd/install-service.sh

# Start validator
sudo systemctl start solana-validator

# Enable auto-start on boot
sudo systemctl enable solana-validator

# View logs
sudo journalctl -u solana-validator -f

# Stop validator
sudo systemctl stop solana-validator
```

#### Method 3: Foreground (Testing)

```bash
./start-validator.sh
```

Press `Ctrl+C` to stop.

### Metaplex Token Metadata Program

The validator automatically includes the **Metaplex Token Metadata Program** which enables:
- ✅ Creating on-chain metadata accounts for tokens
- ✅ Token name and symbol display in Solana Explorer
- ✅ Full compatibility with Metaplex standards

**Program Details:**
- **Program ID**: `metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s`
- **Location**: `~/.local/share/solana-programs/mpl-token-metadata.so`
- **Download**: Automatically during `setup-validator.sh`, or manually:
  ```bash
  ./download-metaplex-program.sh
  ```

**Note**: The program is downloaded from mainnet during setup. If download fails, you can run the download script manually later.

### Validator Configuration

The validator runs with these settings:

- **RPC Port**: 8899
- **Faucet Port**: 9900
- **Bind Address**: 0.0.0.0 (allows remote connections)
- **Ledger**: `~/solana-local-ledger`
- **Reset on Start**: Yes (use `--no-reset` in script to persist)
- **Included Programs**: Metaplex Token Metadata Program (if downloaded)

**RPC Endpoints:**
- Local: `http://127.0.0.1:8899`
- Remote: `http://<server-ip>:8899`

## 🔧 Management Commands

### Start Validator

```bash
./start-validator.sh          # Foreground
./start-validator-tmux.sh    # Background (tmux)
sudo systemctl start solana-validator  # Systemd
```

### Stop Validator

```bash
./stop-validator.sh           # Kill process
tmux kill-session -t solana-validator  # Kill tmux session
sudo systemctl stop solana-validator   # Systemd
```

### Reset Validator (Clear All Data)

```bash
./reset-validator.sh
```

⚠️ **Warning**: This deletes all ledger data and starts fresh.

### View Logs

**Tmux:**
```bash
tmux attach -t solana-validator
```

**Systemd:**
```bash
sudo journalctl -u solana-validator -f
```

**Check if running:**
```bash
pgrep -f solana-test-validator
```

## 📋 Logging & Monitoring

### Understanding Validator Logs

The Solana validator generates detailed logs that help monitor blockchain operations, transactions, and system health.

### Viewing Logs

#### Method 1: Tmux Session (Development)

If validator is running in tmux:

```bash
# Attach to tmux session
tmux attach -t solana-validator

# View last 100 lines
tmux capture-pane -t solana-validator -p | tail -100

# Follow logs in real-time
tmux attach -t solana-validator
# Press Ctrl+B, then Shift+S to scroll
```

**Detach from tmux** (keeps validator running):
- Press `Ctrl+B`, then `D`

#### Method 2: Systemd Journal (Production)

```bash
# Follow logs in real-time
sudo journalctl -u solana-validator -f

# View last 100 lines
sudo journalctl -u solana-validator -n 100

# View logs from today
sudo journalctl -u solana-validator --since today

# View logs with timestamps
sudo journalctl -u solana-validator -f --no-pager

# Export logs to file
sudo journalctl -u solana-validator > validator-logs.txt
```

#### Method 3: Maintenance Script

```bash
# Interactive log viewer
./maintenance.sh
# Select option 4: View Logs
```

#### Method 4: Direct Process Output

If running in foreground:
```bash
./start-validator.sh
# Logs appear directly in terminal
```

### Log Analysis

#### Common Log Patterns

**1. Validator Starting:**
```
Starting validator...
Identity: <validator-pubkey>
Genesis Hash: <hash>
RPC: http://0.0.0.0:8899
```

**2. Transaction Processing:**
```
Processing transaction: <tx-signature>
Slot: <slot-number>
```

**3. Block Production:**
```
Produced block <slot> in <time>ms
```

**4. Errors/Warnings:**
```
ERROR: <error-message>
WARN: <warning-message>
```

**5. RPC Requests:**
```
RPC request: <method>
Response: <status>
```

### Log Filtering & Search

#### Using journalctl (Systemd)

```bash
# Filter by log level
sudo journalctl -u solana-validator -p err    # Errors only
sudo journalctl -u solana-validator -p warning # Warnings and above

# Search for specific text
sudo journalctl -u solana-validator | grep "ERROR"
sudo journalctl -u solana-validator | grep "transaction"

# Search within time range
sudo journalctl -u solana-validator --since "2024-01-01 00:00:00" --until "2024-01-01 23:59:59"

# Count errors
sudo journalctl -u solana-validator | grep -c "ERROR"
```

#### Using grep (Tmux/File Logs)

```bash
# Search tmux logs
tmux capture-pane -t solana-validator -p | grep "ERROR"

# Search exported logs
cat validator-logs.txt | grep "transaction"
cat validator-logs.txt | grep -i "error" | tail -20
```

### Log Rotation & Management

#### Systemd Log Rotation

Systemd automatically manages log rotation. Configure in `/etc/systemd/journald.conf`:

```ini
[Journal]
SystemMaxUse=1G
SystemKeepFree=2G
MaxRetentionSec=1month
```

#### Manual Log Export

```bash
# Export recent logs
sudo journalctl -u solana-validator --since "1 hour ago" > recent-logs.txt

# Export with timestamps
sudo journalctl -u solana-validator -o short-precise > detailed-logs.txt

# Compress old logs
sudo journalctl -u solana-validator --since "30 days ago" | gzip > old-logs.gz
```

### Monitoring Logs in Real-Time

#### Continuous Monitoring Script

```bash
# Use the built-in monitor script
./monitor.sh
```

This script:
- Continuously checks validator health
- Monitors logs for errors
- Alerts on issues
- Displays key metrics

#### Custom Log Monitoring

```bash
# Watch for errors in real-time
sudo journalctl -u solana-validator -f | grep --line-buffered "ERROR"

# Monitor transaction processing
sudo journalctl -u solana-validator -f | grep --line-buffered "transaction"

# Track RPC requests
sudo journalctl -u solana-validator -f | grep --line-buffered "RPC"
```

### Log Locations Summary

| Method | Log Location | Access Command |
|--------|-------------|----------------|
| **Tmux** | Tmux session buffer | `tmux attach -t solana-validator` |
| **Systemd** | Systemd journal | `sudo journalctl -u solana-validator -f` |
| **Foreground** | Terminal output | Direct (when running `./start-validator.sh`) |
| **Maintenance** | Via script | `./maintenance.sh` (option 4) |

### Troubleshooting with Logs

#### Validator Not Starting

```bash
# Check for startup errors
sudo journalctl -u solana-validator -n 50 | grep -i error
```

#### RPC Issues

```bash
# Check RPC-related logs
sudo journalctl -u solana-validator | grep -i rpc
```

#### Transaction Failures

```bash
# Search for failed transactions
sudo journalctl -u solana-validator | grep -i "failed\|error\|reject"
```

#### Performance Issues

```bash
# Check for slow operations
sudo journalctl -u solana-validator | grep -i "slow\|timeout\|delay"
```

### Best Practices

1. **Regular Monitoring**: Check logs daily for errors
2. **Log Retention**: Keep logs for at least 30 days
3. **Error Alerts**: Set up alerts for critical errors
4. **Log Analysis**: Review logs weekly for patterns
5. **Backup Logs**: Export important logs before rotation
6. **Documentation**: Document any recurring issues found in logs

### Integration with Monitoring Tools

For enterprise deployments, integrate with monitoring systems:

```bash
# Export logs for external monitoring
sudo journalctl -u solana-validator -o json > logs.json

# Send to log aggregation service
sudo journalctl -u solana-validator -f | nc log-server.example.com 514
```

### Verify Status

```bash
./verify-setup.sh
```

This checks:
- Validator process status
- RPC connectivity
- Solana CLI configuration
- Cluster version
- Account balance

## 🌐 Remote Access

### Firewall Configuration

Allow RPC access from remote machines:

```bash
sudo ./firewall-setup.sh
```

This opens:
- Port 8899 (RPC)
- Port 9900 (Faucet)

**Manual firewall setup:**
```bash
sudo ufw allow 8899/tcp
sudo ufw allow 9900/tcp
```

### Security Considerations

⚠️ **Important**: Opening RPC to the internet exposes your validator.

**Recommended practices:**

1. **Restrict by IP:**
   ```bash
   sudo ufw allow from <trusted-ip> to any port 8899
   ```

2. **Use SSH Tunnel:**
   ```bash
   ssh -L 8899:localhost:8899 user@server
   ```

3. **Use VPN** for secure access

4. **Consider authentication** if exposing publicly

## 💾 Data Management

### Ledger Location

All blockchain data is stored in: `~/solana-local-ledger`

### Backup Ledger

```bash
# Stop validator
./stop-validator.sh

# Create backup
tar -czf solana-ledger-backup-$(date +%Y%m%d).tar.gz ~/solana-local-ledger

# Restore
tar -xzf solana-ledger-backup-YYYYMMDD.tar.gz -C ~/
```

### Reset Ledger

```bash
./reset-validator.sh
```

Or manually:
```bash
./stop-validator.sh
rm -rf ~/solana-local-ledger
mkdir -p ~/solana-local-ledger
./start-validator.sh
```

## 🔍 Verification & Testing

### Check Validator Status

```bash
# Check process
pgrep -f solana-test-validator

# Check RPC health
curl -X POST http://127.0.0.1:8899 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'

# Check cluster version
solana cluster-version

# Check account balance
solana balance
```

### Full Verification

```bash
./verify-setup.sh
```

## 🐛 Troubleshooting

### Validator Won't Start

1. **Check port availability:**
   ```bash
   sudo lsof -i :8899
   # Kill process if needed: sudo kill -9 <PID>
   ```

2. **Check disk space:**
   ```bash
   df -h ~/solana-local-ledger
   ```

3. **Check logs:**
   ```bash
   tmux attach -t solana-validator  # Tmux
   sudo journalctl -u solana-validator -f  # Systemd
   ```

### RPC Not Responding

1. **Wait for initialization** (10-30 seconds after start)

2. **Check validator is running:**
   ```bash
   pgrep -f solana-test-validator
   ```

3. **Test RPC directly:**
   ```bash
   curl http://127.0.0.1:8899
   ```

4. **Check firewall:**
   ```bash
   sudo ufw status
   ```

### Connection Refused (Remote)

1. **Verify bind address** in `start-validator.sh` is `0.0.0.0`

2. **Check firewall:**
   ```bash
   sudo ufw allow 8899/tcp
   ```

3. **Verify server IP:**
   ```bash
   hostname -I
   ```

## 📁 Project Structure

```
Solana-Validator-Node/
├── install.sh                  # Installation script
├── setup-validator.sh          # Single node setup (default)
├── setup-cluster.sh            # Multi-node cluster setup
├── add-validator.sh            # Add node to cluster
├── start-validator.sh          # Start validator (created by setup)
├── start-validator-tmux.sh     # Start in tmux (created by setup)
├── start-cluster-validator.sh  # Start as cluster node (created by cluster setup)
├── stop-validator.sh           # Stop validator (created by setup)
├── reset-validator.sh          # Reset ledger (created by setup)
├── download-metaplex-program.sh # Download Metaplex Token Metadata program
├── verify-setup.sh             # Verification script
├── security-setup.sh           # Security & access control
├── maintenance.sh              # Maintenance & monitoring menu
├── monitor.sh                  # Continuous monitoring
├── firewall-setup.sh           # Firewall configuration
├── cluster-info.sh             # Cluster information (created by cluster setup)
├── systemd/                     # Systemd service files
│   ├── install-service.sh
│   └── solana-validator.service
├── .gitignore                  # Git ignore rules
└── README.md                   # This file
```

**Note**: Test directories (`examples/`, `my_program/`) are excluded via `.gitignore` and should not be committed. These are only for local testing. Use Solana Playground for program deployment.

### Script Descriptions

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `install.sh` | Install Rust, Solana CLI, dependencies | First-time setup |
| `setup-validator.sh` | Initialize single validator node | Default setup |
| `setup-cluster.sh` | Initialize multi-node cluster | Production cluster |
| `add-validator.sh` | Add node to existing cluster | Adding validators |
| `start-validator.sh` | Start validator (foreground) | Testing/debugging |
| `start-validator-tmux.sh` | Start validator (background) | Development |
| `start-cluster-validator.sh` | Start cluster node | Cluster mode |
| `stop-validator.sh` | Stop validator process | Maintenance |
| `reset-validator.sh` | Clear all ledger data | Fresh start |
| `download-metaplex-program.sh` | Download Metaplex Token Metadata program | Setup metadata support |
| `verify-setup.sh` | Verify installation & status | Health check |
| `security-setup.sh` | Configure firewall & access | Security setup |
| `maintenance.sh` | Interactive maintenance menu | Daily operations |
| `monitor.sh` | Continuous monitoring | Production monitoring |
| `firewall-setup.sh` | Configure UFW firewall | Network setup |
| `cluster-info.sh` | Display cluster information | Cluster management |

## 🌐 Multi-Node Cluster Setup

This repository supports **two deployment modes**:

### Mode 1: Independent Networks (Default)
Each deployment creates a **separate independent private blockchain network**:
- Separate ledgers
- Unique keypairs
- Isolated networks
- Independent state

**Use cases**: Development, testing, isolated environments

### Mode 2: Private Cluster Network (Production)
Multiple nodes can be configured to work together in a private network:

#### Setup Bootstrap Validator (First Node)

```bash
# On the first node (bootstrap validator)
./setup-cluster.sh
./start-cluster-validator.sh
```

This creates:
- Bootstrap validator keypair
- Cluster configuration
- Validator list

#### Add Additional Validators

```bash
# On additional nodes
./add-validator.sh
./start-cluster-validator.sh
```

**Note**: `solana-test-validator` is designed for local testing. For a true production multi-node cluster with consensus, consider using the full Solana validator software. However, this setup provides:
- ✅ Network configuration for multiple nodes
- ✅ Security and access control
- ✅ Maintenance and monitoring tools
- ✅ Production-ready infrastructure

**Cluster Architecture:**
- **Bootstrap Validator**: First node that initializes the network
- **Regular Validators**: Additional nodes in the network
- **Gossip Protocol**: Port 8001 for validator communication
- **RPC Access**: Port 8899 on each node
- **Security**: IP whitelist and firewall protection

## 🔒 Security & Access Control

### Security Setup

```bash
sudo ./security-setup.sh
```

**Security Features:**
- ✅ Firewall configuration (UFW)
- ✅ IP whitelist for RPC access
- ✅ Port restrictions
- ✅ Access control helpers

### IP Whitelist Configuration

1. **Edit allowed IPs:**
   ```bash
   nano ~/solana-cluster-config/allowed-ips.txt
   # Add one IP per line:
   # 192.168.1.100
   # 10.0.0.50
   ```

2. **Or use helper:**
   ```bash
   solana-allow-ip <ip-address>
   sudo ./security-setup.sh
   ```

3. **Apply changes:**
   ```bash
   sudo ./security-setup.sh
   ```

### Security Best Practices

1. **Firewall Rules**: Restrict RPC access to trusted IPs only
2. **VPN Access**: Use VPN for remote access (recommended)
3. **SSH Security**: Enable key-based authentication
4. **Regular Updates**: Keep system and Solana CLI updated
5. **Monitoring**: Monitor logs and access patterns
6. **Backups**: Regular ledger backups

## 🛠️ Maintenance & Monitoring

### Maintenance Script

Interactive maintenance menu:

```bash
./maintenance.sh
```

**Features:**
- Health checks
- Status monitoring
- Disk usage monitoring
- Log viewing
- Backup creation
- Validator restart
- Network status
- Performance metrics

### Continuous Monitoring

```bash
./monitor.sh
```

Monitors validator health continuously and alerts on issues:
- Process status
- RPC health
- Disk usage
- Automatic alerts

### Manual Maintenance Tasks

**Backup Ledger:**
```bash
./maintenance.sh  # Select option 5
# Or manually:
tar -czf backup-$(date +%Y%m%d).tar.gz ~/solana-local-ledger
```

**View Logs:**
```bash
# Tmux
tmux attach -t solana-validator

# Systemd
sudo journalctl -u solana-validator -f
```

**Check Health:**
```bash
./verify-setup.sh
./maintenance.sh  # Select option 1
```

**Restart Validator:**
```bash
./maintenance.sh  # Select option 6
# Or manually:
./stop-validator.sh
./start-validator-tmux.sh
```

## 🏢 Production Deployment Guide

### For Company/Enterprise Use

This repository is production-ready for enterprise deployment:

#### 1. Network Architecture

```
┌─────────────────┐
│ Bootstrap Node  │ (Primary validator)
│ 192.168.1.10    │
└────────┬────────┘
         │
    ┌────┴────┬──────────┬──────────┐
    │         │          │          │
┌───▼───┐ ┌──▼───┐  ┌───▼───┐  ┌───▼───┐
│Node 2 │ │Node 3│  │Node 4 │  │Node 5 │
│  .11  │ │ .12  │  │  .13  │  │  .14  │
└───────┘ └──────┘  └───────┘  └───────┘
```

#### 2. Deployment Steps

**Step 1: Setup Bootstrap Node**
```bash
# On first server
git clone <repo-url>
cd Solana-Validator-Node
./install.sh
./setup-cluster.sh
sudo ./security-setup.sh
sudo systemd/install-service.sh
sudo systemctl start solana-validator
sudo systemctl enable solana-validator
```

**Step 2: Add Additional Validators**
```bash
# On each additional server
git clone <repo-url>
cd Solana-Validator-Node
./install.sh
./add-validator.sh  # Enter bootstrap node IP
sudo ./security-setup.sh
sudo systemd/install-service.sh
sudo systemctl start solana-validator
sudo systemctl enable solana-validator
```

**Step 3: Configure Security**
```bash
# On all nodes
# Edit allowed IPs
nano ~/solana-cluster-config/allowed-ips.txt
# Add company IP ranges

# Apply security
sudo ./security-setup.sh
```

**Step 4: Setup Monitoring**
```bash
# Setup monitoring on management server
./monitor.sh  # Or integrate with company monitoring system
```

#### 3. Production Checklist

- ✅ All nodes installed and configured
- ✅ Cluster network established
- ✅ Security (firewall, IP whitelist) configured
- ✅ Systemd services enabled (auto-start on boot)
- ✅ Monitoring setup
- ✅ Backup strategy implemented
- ✅ Access control configured
- ✅ Documentation for team

#### 4. Maintenance Schedule

**Daily:**
- Monitor health: `./maintenance.sh`
- Check logs for errors

**Weekly:**
- Review disk usage
- Check performance metrics
- Verify backups

**Monthly:**
- Full ledger backup
- Security audit
- Update Solana CLI if needed

## 📚 Additional Resources

- [Solana Documentation](https://docs.solana.com/)
- [Solana CLI Reference](https://docs.solana.com/cli)
- [Test Validator Guide](https://docs.solana.com/developing/test-validator)

## 📄 License

MIT License - Feel free to use and modify for your projects.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

**Need Help?** Check the troubleshooting section or review the Solana documentation.
