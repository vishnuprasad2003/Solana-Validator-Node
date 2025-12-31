# Solana Validator Node

A production-ready repository for deploying, operating, maintaining, and upgrading a private Solana validator node on Azure Virtual Machines.

## 🎯 Overview

This repository provides everything needed to set up and operate a production-grade private Solana blockchain cluster. It is designed for:

- **Production use** - Safe defaults, error handling, and recovery procedures
- **Team operations** - Clear documentation and repeatable procedures
- **Long-term maintenance** - Upgrade paths and version management
- **External access** - Public RPC endpoints similar to Solana devnet/mainnet

## 📋 Prerequisites

- **Linux Distribution**: Ubuntu 22.04+, Debian 11+, CentOS 8+, RHEL 8+, Fedora 38+, Arch Linux, or compatible
- **Resources**: 
  - Minimum: 8GB RAM, 100GB SSD
  - Recommended: 16GB+ RAM, 500GB+ SSD
- **Network**: Static IP address, firewall access
- **Access**: SSH access with sudo privileges
- **Cloud Providers**: Works on Azure, AWS, GCP, or any Linux VM

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

# Setup log rotation (optional, keeps logs minimal)
sudo ./scripts/setup-log-rotation.sh
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
- **[Portability Guide](docs/06-portability.md)** - Cross-platform compatibility and best practices

## 🏗️ Repository Structure

```
Solana-Validator-Node/
├── README.md                 # Main documentation
├── scripts/                  # Operational scripts
│   ├── common.sh             # Common library (OS detection, portability)
│   ├── install.sh            # Install dependencies (cross-platform)
│   ├── setup-cluster.sh      # Initialize cluster
│   ├── start-validator.sh    # Start validator
│   ├── stop-validator.sh     # Stop validator
│   ├── upgrade.sh            # Upgrade Solana version
│   ├── recovery.sh           # Recovery procedures
│   ├── monitor.sh            # Health monitoring
│   ├── configure-networking.sh # Network setup (multi-firewall)
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
    ├── 05-azure-configuration.md
    └── 06-portability.md     # Cross-platform compatibility
```

## 🔧 Key Features

- ✅ **Cross-platform** - Works on Ubuntu, Debian, CentOS, RHEL, Fedora, Arch Linux
- ✅ **Production-ready defaults** - Safe configurations out of the box
- ✅ **Automated installation** - One-command setup with automatic OS detection
- ✅ **Public RPC access** - Accessible from anywhere (like devnet)
- ✅ **Safe upgrades** - Rollback capability and version management
- ✅ **Failure recovery** - Automated recovery procedures
- ✅ **Monitoring** - Health checks and status monitoring
- ✅ **Multi-firewall support** - Automatically configures UFW, firewalld, or iptables
- ✅ **Multi-node support** - Cluster configuration for multiple validators
- ✅ **Portable scripts** - Handles paths with spaces, different shells, and architectures

## 🔐 Security

- Firewall rules configured automatically
- Optional IP whitelist for RPC access
- Systemd service isolation
- Secure keypair management

## 💡 Important Notes

### Cross-Platform Compatibility

All scripts are designed to work across different Linux distributions:
- **Automatic OS detection** - Detects your Linux distribution
- **Package manager detection** - Uses apt, yum, dnf, pacman, or zypper automatically
- **Firewall detection** - Configures UFW, firewalld, or iptables based on what's available
- **Architecture support** - Works on x86_64, ARM64, and ARM architectures

See [Portability Guide](docs/06-portability.md) for detailed information.

### Paths with Spaces

All scripts handle paths with spaces automatically. When manually running commands, always quote paths:

```bash
# ✅ Correct (with quotes)
tail -f "/home/user/Documents/Block Chain/Solana-Validator-Node/logs/validator.log"

# ✅ Better (use relative path)
cd Solana-Validator-Node
tail -f logs/validator.log

# ❌ Incorrect (will fail with spaces)
tail -f /home/user/Documents/Block Chain/Solana-Validator-Node/logs/validator.log
```

## 📞 Support

For issues or questions:
1. Check [Troubleshooting Guide](docs/04-troubleshooting.md)
2. Review [Operations Manual](docs/02-operations.md)
3. Check logs: `sudo journalctl -u solana-validator -f` or `tail -f logs/validator.log`

## 📝 License

MIT License - See LICENSE file for details

