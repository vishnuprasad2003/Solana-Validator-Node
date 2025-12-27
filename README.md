# Solana Validator Node

A production-ready repository for deploying, operating, maintaining, and upgrading a private Solana validator node on Azure Virtual Machines.

## 🎯 Overview

This repository provides everything needed to set up and operate a production-grade private Solana blockchain cluster. It is designed for:

- **Production use** - Safe defaults, error handling, and recovery procedures
- **Team operations** - Clear documentation and repeatable procedures
- **Long-term maintenance** - Upgrade paths and version management
- **External access** - Public RPC endpoints similar to Solana devnet/mainnet

## 📋 Prerequisites

- **Azure VMs**: Pre-provisioned Ubuntu 22.04 LTS (or compatible Linux)
- **Resources**: 
  - Minimum: 8GB RAM, 100GB SSD
  - Recommended: 16GB+ RAM, 500GB+ SSD
- **Network**: Static IP address, firewall access
- **Access**: SSH access with sudo privileges

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone <your-repo-url>
cd Solana-Validator-Node
chmod +x scripts/*.sh systemd/*.sh
```

### 2. Initial Setup

```bash
# Install dependencies and Solana CLI
./scripts/install.sh

# Configure the cluster
./scripts/setup-cluster.sh

# Configure Azure networking (public RPC access)
./scripts/configure-networking.sh
```

### 3. Start Services

```bash
# Install systemd service
sudo systemd/install-service.sh

# Start validator
sudo systemctl start solana-validator
sudo systemctl enable solana-validator
```

### 4. Verify Installation

```bash
./scripts/verify-setup.sh
```

## 📖 Documentation

- **[Initial Setup Guide](docs/01-initial-setup.md)** - Complete setup instructions
- **[Operations Manual](docs/02-operations.md)** - Day-to-day operations
- **[Upgrade Guide](docs/03-upgrades.md)** - Safe upgrade procedures
- **[Troubleshooting](docs/04-troubleshooting.md)** - Common issues and solutions
- **[Azure Configuration](docs/05-azure-configuration.md)** - Azure-specific setup

## 🏗️ Repository Structure

```
Solana-Validator-Node/
├── README.md                 # Main documentation
├── scripts/                  # Operational scripts
│   ├── install.sh            # Install dependencies
│   ├── setup-cluster.sh      # Initialize cluster
│   ├── start-validator.sh    # Start validator
│   ├── stop-validator.sh     # Stop validator
│   ├── upgrade.sh            # Upgrade Solana version
│   ├── recovery.sh           # Recovery procedures
│   ├── monitor.sh            # Health monitoring
│   ├── configure-networking.sh # Network setup
│   └── verify-setup.sh       # Verification
├── configs/                  # Configuration
│   └── config.env            # Main configuration
├── systemd/                  # Systemd service
│   ├── solana-validator.service
│   └── install-service.sh
└── docs/                     # Detailed documentation
    ├── 01-initial-setup.md
    ├── 02-operations.md
    ├── 03-upgrades.md
    ├── 04-troubleshooting.md
    └── 05-azure-configuration.md
```

## 🔧 Key Features

- ✅ **Production-ready defaults** - Safe configurations out of the box
- ✅ **Automated installation** - One-command setup
- ✅ **Public RPC access** - Accessible from anywhere (like devnet)
- ✅ **Safe upgrades** - Rollback capability and version management
- ✅ **Failure recovery** - Automated recovery procedures
- ✅ **Monitoring** - Health checks and status monitoring
- ✅ **Azure optimized** - Network security groups and load balancer configs
- ✅ **Multi-node support** - Cluster configuration for multiple validators

## 🔐 Security

- Firewall rules configured automatically
- Optional IP whitelist for RPC access
- Systemd service isolation
- Secure keypair management

## 💡 Important Notes

### Paths with Spaces

If your repository path contains spaces (e.g., `/path/to/Block Chain/Solana-Validator-Node`), always quote paths when using them in commands:

```bash
# ✅ Correct (with quotes)
tail -f "/home/user/Documents/Block Chain/Solana-Validator-Node/logs/validator.log"

# ✅ Better (use relative path)
cd Solana-Validator-Node
tail -f logs/validator.log

# ❌ Incorrect (will fail with spaces)
tail -f /home/user/Documents/Block Chain/Solana-Validator-Node/logs/validator.log
```

All scripts handle paths with spaces automatically, but when manually running commands, remember to quote paths.

## 📞 Support

For issues or questions:
1. Check [Troubleshooting Guide](docs/04-troubleshooting.md)
2. Review [Operations Manual](docs/02-operations.md)
3. Check logs: `sudo journalctl -u solana-validator -f` or `tail -f logs/validator.log`

## 📝 License

MIT License - See LICENSE file for details

