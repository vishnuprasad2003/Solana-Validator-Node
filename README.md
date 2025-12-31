# Solana Validator Node

Production-ready repository for deploying and operating private Solana validator nodes with multi-node cluster support.

## 🎯 Overview

This repository provides everything needed to set up and operate production-grade private Solana blockchain validators. Supports both single-node and multi-node cluster configurations with consensus mechanism.

**Features:**
- ✅ Single-node validator for local development
- ✅ Multi-node cluster with consensus mechanism
- ✅ Compact, maintainable scripts
- ✅ Clean, minimal output
- ✅ Automated setup and management

## 📋 Prerequisites

- **Linux**: Ubuntu 22.04+, Debian 11+, CentOS 8+, RHEL 8+, Fedora 38+, Arch Linux
- **Resources**: 
  - Minimum: 8GB RAM, 100GB SSD
  - Recommended: 16GB+ RAM, 500GB+ SSD
- **Access**: SSH with sudo privileges

## 🚀 Quick Start

### Single Node Setup

```bash
# Clone repository
git clone <your-repo-url>
cd Solana-Validator-Node
chmod +x scripts/*.sh

# Install dependencies
./scripts/install.sh

# Setup cluster
./scripts/setup-cluster.sh

# Start validator
./scripts/start-validator.sh

# Verify
./scripts/verify-setup.sh
```

### Multi-Node Cluster Setup

#### Bootstrap Node (First Node)

```bash
# On first node
./scripts/install.sh
./scripts/setup-cluster.sh

# Edit configs/config.env
CLUSTER_MODE=true
NODE_ROLE=bootstrap
GOSSIP_PORT=8001

# Start bootstrap node
./scripts/start-validator.sh

# Get node info
./scripts/list-nodes.sh
```

#### Additional Validator Nodes

```bash
# On each additional node
./scripts/install.sh
./scripts/setup-cluster.sh

# Add to cluster (replace with bootstrap node IP)
./scripts/add-node.sh <bootstrap_ip>:8001

# Start validator
./scripts/start-validator.sh
```

## 🏗️ Repository Structure

```
Solana-Validator-Node/
├── README.md
├── configs/
│   └── config.env                    # Main configuration
├── scripts/
│   ├── common.sh                     # Shared library functions
│   ├── install.sh                   # Install dependencies
│   ├── setup-cluster.sh             # Initialize cluster
│   ├── start-validator.sh           # Start validator
│   ├── stop-validator.sh            # Stop validator
│   ├── verify-setup.sh              # Verify installation
│   ├── monitor.sh                   # Health monitoring
│   ├── airdrop.sh                   # Airdrop SOL
│   ├── add-node.sh                  # Add node to cluster
│   ├── list-nodes.sh                # List cluster nodes
│   ├── upgrade.sh                   # Upgrade Solana
│   └── recovery.sh                  # Recovery procedures
├── systemd/
│   ├── solana-validator.service
│   └── install-service.sh
└── docs/
    ├── 01-initial-setup.md
    ├── 02-operations.md
    ├── 03-upgrades.md
    ├── 04-troubleshooting.md
    └── 05-private-cluster-setup.md
```

## 🔧 Configuration

Edit `configs/config.env` for configuration:

### Single Node
```bash
CLUSTER_MODE=false
RPC_PORT=8899
RPC_BIND_ADDRESS="127.0.0.1"
```

### Multi-Node Cluster

**Bootstrap Node:**
```bash
CLUSTER_MODE=true
NODE_ROLE=bootstrap
GOSSIP_PORT=8001
RPC_PORT=8899
```

**Validator Nodes:**
```bash
CLUSTER_MODE=true
NODE_ROLE=validator
BOOTSTRAP_NODE="<bootstrap_ip>:8001"
GOSSIP_PORT=8001
RPC_PORT=8899
```

## 📝 Scripts

### Core Scripts
- **`start-validator.sh`** - Start validator (supports single/cluster mode)
- **`stop-validator.sh`** - Stop validator (`--force` for force kill)
- **`verify-setup.sh`** - Verify installation
- **`monitor.sh`** - Health check

### Cluster Scripts
- **`add-node.sh <bootstrap_ip:port>`** - Configure node to join cluster
- **`list-nodes.sh`** - List cluster nodes and status

### Utility Scripts
- **`airdrop.sh <address> [amount]`** - Airdrop SOL
- **`install.sh`** - Install dependencies
- **`setup-cluster.sh`** - Initialize cluster

## 💡 Usage Examples

### Single Node
```bash
./scripts/start-validator.sh
./scripts/monitor.sh
./scripts/airdrop.sh <address> 10
```

### Multi-Node Cluster

**Bootstrap Node:**
```bash
# Start bootstrap
./scripts/start-validator.sh

# Check status
./scripts/list-nodes.sh
```

**Add Validator Node:**
```bash
# Configure to join cluster
./scripts/add-node.sh 192.168.1.100:8001

# Start validator
./scripts/start-validator.sh

# Verify cluster
./scripts/list-nodes.sh
```

## 🔐 Consensus Mechanism

The cluster uses Solana's built-in consensus mechanism:
- **Bootstrap Node**: First node that initializes the cluster
- **Validator Nodes**: Additional nodes that join the cluster
- **Gossip Protocol**: Nodes communicate via gossip port (default: 8001)
- **Consensus**: All nodes participate in transaction validation and block production


## 🔍 Troubleshooting

1. **Validator not starting**: Check `./scripts/verify-setup.sh`
2. **Cluster not connecting**: Verify bootstrap node IP and gossip port
3. **Transaction timeouts**: Check validator is running and RPC is accessible
4. **Health check**: Use `./scripts/monitor.sh`

## 📚 Documentation

- **Quick Start**: See above
- **Private Cluster Setup**: `docs/05-private-cluster-setup.md` - Complete guide for multi-node cluster
- **Operations**: `docs/02-operations.md` - Day-to-day operations
- **Troubleshooting**: `docs/04-troubleshooting.md` - Common issues and solutions

## 📝 License

MIT License
