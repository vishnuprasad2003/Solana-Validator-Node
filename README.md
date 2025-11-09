# Solana Private Validator Node Setup

A production-ready setup script for deploying a private Solana blockchain validator node on Linux servers. Each deployment creates an independent private blockchain network.

## 🎯 Overview

This repository provides everything needed to set up a private Solana validator node. When deployed on different systems or servers, each instance runs as a **separate independent private blockchain network**.

### Features

- ✅ Automated installation of Rust, Solana CLI, and dependencies
- ✅ Persistent ledger storage
- ✅ RPC endpoint (local and remote access)
- ✅ Background process management (tmux/systemd)
- ✅ Firewall configuration
- ✅ Production-ready setup

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
- Management scripts (start, stop, reset)

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

### Validator Configuration

The validator runs with these settings:

- **RPC Port**: 8899
- **Faucet Port**: 9900
- **Bind Address**: 0.0.0.0 (allows remote connections)
- **Ledger**: `~/solana-local-ledger`
- **Reset on Start**: Yes (use `--no-reset` in script to persist)

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
├── install.sh              # Installation script
├── setup-validator.sh      # Validator setup script
├── start-validator.sh      # Start validator (created by setup)
├── start-validator-tmux.sh # Start in tmux (created by setup)
├── stop-validator.sh       # Stop validator (created by setup)
├── reset-validator.sh      # Reset ledger (created by setup)
├── verify-setup.sh         # Verification script
├── firewall-setup.sh       # Firewall configuration (optional)
├── systemd/                 # Systemd service files
│   ├── install-service.sh
│   └── solana-validator.service
├── .gitignore              # Git ignore rules
└── README.md               # This file
```

**Note**: Test directories (`examples/`, `my_program/`) are excluded via `.gitignore` and should not be committed. These are only for local testing. Use Solana Playground for program deployment.

## 🔄 Multiple Deployments

Each deployment of this repository creates an **independent private blockchain network**:

- **Separate ledgers**: Each node has its own `~/solana-local-ledger`
- **Unique keypairs**: Each setup generates new validator keypairs
- **Isolated networks**: Nodes don't communicate with each other
- **Independent state**: Each blockchain maintains its own state

**Use cases:**
- Development environments
- Testing different scenarios
- Isolated production networks
- Multi-tenant deployments

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
