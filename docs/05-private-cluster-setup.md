# Private Solana Cluster Setup Guide

Complete guide for setting up a multi-node private Solana blockchain cluster from scratch.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Bootstrap Node Setup](#bootstrap-node-setup)
5. [Validator Node Setup](#validator-node-setup)
6. [Network Configuration](#network-configuration)
7. [Verification](#verification)
8. [Operations](#operations)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

---

## Overview

A private Solana cluster consists of multiple validator nodes that work together to maintain a private blockchain network. This setup provides:

- **Decentralization**: Multiple nodes validate transactions
- **Consensus**: All nodes participate in block production
- **Privacy**: Complete control over the network
- **Customization**: Configure network parameters as needed

### Key Concepts

- **Bootstrap Node**: The first node that initializes the cluster. Other nodes connect to it.
- **Validator Nodes**: Additional nodes that join the cluster and participate in consensus.
- **Gossip Protocol**: How nodes discover and communicate with each other (port 8001).
- **RPC Port**: How clients connect to nodes (port 8899).
- **Consensus**: All nodes validate transactions and produce blocks together.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Private Solana Cluster                    │
└─────────────────────────────────────────────────────────────┘

    ┌──────────────────┐      ┌──────────────────┐
    │  Bootstrap Node  │◄────►│ Validator Node 1 │
    │  (Node 1)        │      │  (Node 2)        │
    │  IP: 192.168.1.100│      │  IP: 192.168.1.101│
    │  Gossip: 8001    │      │  Gossip: 8001    │
    │  RPC: 8899       │      │  RPC: 8899       │
    └──────────────────┘      └──────────────────┘
           ▲                            ▲
           │                            │
           │      ┌──────────────────┐   │
           └─────►│ Validator Node 2 │◄──┘
                  │  (Node 3)        │
                  │  IP: 192.168.1.102│
                  │  Gossip: 8001    │
                  │  RPC: 8899       │
                  └──────────────────┘

All nodes communicate via Gossip Protocol (port 8001)
Clients connect via RPC (port 8899)
```

---

## Prerequisites

### Hardware Requirements (per node)

- **Minimum**: 8GB RAM, 100GB SSD, 2 CPU cores
- **Recommended**: 16GB+ RAM, 500GB+ SSD, 4+ CPU cores
- **Network**: Stable internet connection, low latency between nodes

### Software Requirements

- **OS**: Linux (Ubuntu 22.04+, Debian 11+, CentOS 8+, RHEL 8+)
- **Access**: SSH with sudo privileges
- **Network**: All nodes must be able to reach each other

### Network Planning

Before starting, determine:

1. **Node IPs**: Assign static IPs to each node (e.g., 192.168.1.100, 192.168.1.101, etc.)
2. **Ports**:
   - **Gossip Port**: 8001 (node-to-node communication)
   - **RPC Port**: 8899 (client connections)
   - **Dynamic Ports**: 8002-8012 (Solana internal use)
3. **Firewall**: Configure rules to allow these ports

---

## Bootstrap Node Setup

The bootstrap node is the first node that initializes the cluster. All other nodes will connect to it.

### Step 1: Clone and Prepare Repository

```bash
# On Node 1 (Bootstrap Node)
git clone <your-repo-url>
cd Solana-Validator-Node
chmod +x scripts/*.sh
```

### Step 2: Install Dependencies

```bash
# Install Rust, Solana CLI, and system dependencies
./scripts/install.sh

# This will:
# - Install Rust toolchain
# - Install Solana CLI
# - Install system packages (curl, git, build tools, etc.)
# - Configure shell profile
```

**Expected output:**
```
Installation Complete!
  Rust: rustc 1.xx.x
  Solana: solana-cli x.x.x
  Anchor: anchor-cli x.x.x
```

### Step 3: Setup Cluster

```bash
# Initialize the cluster (generates keypairs, downloads Metaplex program)
./scripts/setup-cluster.sh

# This will:
# - Create ledger directory
# - Generate validator keypair
# - Generate default keypair
# - Download Metaplex Token Metadata program
# - Configure Solana CLI
```

**Expected output:**
```
Setup Complete!
  Validator: <validator-address>
  Default: <default-address>
  RPC: http://127.0.0.1:8899
```

### Step 4: Configure for Bootstrap Node

Edit `configs/config.env`:

```bash
# Open config file
nano configs/config.env
```

**Set these values:**

```bash
# Enable cluster mode
CLUSTER_MODE=true

# Set role to bootstrap
NODE_ROLE=bootstrap

# Set network binding
# Use "0.0.0.0" to accept connections from any IP
# Or use your node's private IP (e.g., "192.168.1.100")
RPC_BIND_ADDRESS="0.0.0.0"

# Ports
RPC_PORT=8899
GOSSIP_PORT=8001
FAUCET_PORT=9900

# Leave bootstrap node empty (this IS the bootstrap node)
BOOTSTRAP_NODE=""
```

**Save and exit** (Ctrl+X, then Y, then Enter)

### Step 5: Configure Firewall

```bash
# Allow gossip port (UDP and TCP)
sudo ufw allow 8001/tcp
sudo ufw allow 8001/udp

# Allow RPC port
sudo ufw allow 8899/tcp

# Allow dynamic ports (Solana uses 8002-8012)
sudo ufw allow 8002:8012/tcp
sudo ufw allow 8002:8012/udp

# Enable firewall if not already enabled
sudo ufw enable

# Verify rules
sudo ufw status
```

### Step 6: Start Bootstrap Node

```bash
# Start the validator
./scripts/start-validator.sh
```

**Expected output:**
```
Starting Solana test validator...
  Mode: Cluster (bootstrap)
  RPC: http://0.0.0.0:8899
  Ledger: /home/user/solana-local-ledger
  ✓ Metaplex Token Metadata Program
```

### Step 7: Verify Bootstrap Node

```bash
# Check if validator is running
pgrep -f solana-test-validator

# Check cluster status
./scripts/list-nodes.sh

# Check health
./scripts/monitor.sh

# Test RPC endpoint
curl -X POST http://localhost:8899 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
```

**Expected response:**
```json
{"jsonrpc":"2.0","result":"ok","id":1}
```

### Step 8: Get Bootstrap Node Information

```bash
# Get node's public key
solana address -k ~/.config/solana/validator-keypair.json

# Get node's IP address
hostname -I | awk '{print $1}'

# Or if you know it:
echo "192.168.1.100"  # Replace with your bootstrap node's IP
```

**Record this information:**
- **Bootstrap Node IP**: `192.168.1.100` (example)
- **Gossip Port**: `8001`
- **Format for validator nodes**: `192.168.1.100:8001`

---

## Validator Node Setup

Repeat these steps for each additional validator node (Node 2, Node 3, etc.).

### Step 1: Clone and Prepare Repository

```bash
# On Node 2 (or Node 3, Node 4, etc.)
git clone <your-repo-url>
cd Solana-Validator-Node
chmod +x scripts/*.sh
```

### Step 2: Install Dependencies

```bash
# Install Rust, Solana CLI, and system dependencies
./scripts/install.sh
```

### Step 3: Setup Cluster

```bash
# Initialize the cluster
./scripts/setup-cluster.sh
```

### Step 4: Join the Cluster

Use the `add-node.sh` script to configure this node to join the cluster:

```bash
# Replace 192.168.1.100:8001 with your bootstrap node's IP:port
./scripts/add-node.sh 192.168.1.100:8001
```

**This script automatically:**
- Sets `CLUSTER_MODE=true`
- Sets `NODE_ROLE=validator`
- Sets `BOOTSTRAP_NODE="192.168.1.100:8001"`

**Expected output:**
```
Adding node to cluster...
  Bootstrap node: 192.168.1.100:8001

✓ Configuration updated
  CLUSTER_MODE=true
  NODE_ROLE=validator
  BOOTSTRAP_NODE=192.168.1.100:8001

Start validator with: ./scripts/start-validator.sh
```

### Step 5: Configure Network Binding

Edit `configs/config.env`:

```bash
nano configs/config.env
```

**Set these values:**

```bash
# Cluster mode should already be set by add-node.sh
CLUSTER_MODE=true
NODE_ROLE=validator
BOOTSTRAP_NODE="192.168.1.100:8001"  # Already set by add-node.sh

# Set network binding
# Use "0.0.0.0" to accept connections from any IP
# Or use this node's private IP (e.g., "192.168.1.101")
RPC_BIND_ADDRESS="0.0.0.0"

# Ports (must match bootstrap node)
RPC_PORT=8899
GOSSIP_PORT=8001
FAUCET_PORT=9900
```

**Save and exit**

### Step 6: Configure Firewall

```bash
# Allow gossip port (UDP and TCP)
sudo ufw allow 8001/tcp
sudo ufw allow 8001/udp

# Allow RPC port
sudo ufw allow 8899/tcp

# Allow dynamic ports
sudo ufw allow 8002:8012/tcp
sudo ufw allow 8002:8012/udp

# Enable firewall
sudo ufw enable

# Verify rules
sudo ufw status
```

### Step 7: Start Validator Node

```bash
# Start the validator
./scripts/start-validator.sh
```

**Expected output:**
```
Starting Solana test validator...
  Mode: Cluster (validator)
  RPC: http://0.0.0.0:8899
  Ledger: /home/user/solana-local-ledger
  ✓ Metaplex Token Metadata Program
```

### Step 8: Verify Validator Node

```bash
# Check if validator is running
pgrep -f solana-test-validator

# Check cluster status (should show all nodes)
./scripts/list-nodes.sh

# Check health
./scripts/monitor.sh

# Test RPC endpoint
curl -X POST http://localhost:8899 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
```

---

## Network Configuration

### Cloud VM Setup (Azure/AWS/GCP)

If your nodes are in cloud VMs, configure security groups/NSG rules:

#### Azure Network Security Group (NSG)

1. **Inbound Rules:**
   - Port 8001 (TCP/UDP) - Gossip protocol
   - Port 8899 (TCP) - RPC
   - Ports 8002-8012 (TCP/UDP) - Dynamic ports

2. **Source:** Allow from other node IPs or subnet

#### AWS Security Group

1. **Inbound Rules:**
   - Port 8001 (TCP/UDP) - From other node security groups
   - Port 8899 (TCP) - From your IP or 0.0.0.0/0
   - Ports 8002-8012 (TCP/UDP) - From other node security groups

### Local Network Setup

If nodes are on the same local network:

1. **Ensure nodes can ping each other:**
   ```bash
   ping 192.168.1.100  # From Node 2, ping Node 1
   ping 192.168.1.101  # From Node 1, ping Node 2
   ```

2. **Test port connectivity:**
   ```bash
   # From Node 2, test connection to Node 1's gossip port
   telnet 192.168.1.100 8001
   # Or use nc (netcat)
   nc -zv 192.168.1.100 8001
   ```

3. **Check firewall rules on all nodes:**
   ```bash
   sudo ufw status
   sudo iptables -L -n  # If using iptables
   ```

### Network Troubleshooting

```bash
# Check if ports are listening
sudo netstat -tulpn | grep -E '8001|8899'

# Check if firewall is blocking
sudo ufw status verbose

# Test connectivity between nodes
ping <other-node-ip>
telnet <other-node-ip> 8001
```

---

## Verification

### Check Cluster Status

**On any node:**

```bash
# List all nodes in cluster
./scripts/list-nodes.sh
```

**Expected output:**
```
Cluster Node Information

  Mode: Cluster
  Role: bootstrap  # or "validator"
  Bootstrap: 192.168.1.100:8001
  RPC: http://127.0.0.1:8899
  Gossip: 8001

Connected nodes:
[
  {
    "pubkey": "...",
    "gossip": "192.168.1.100:8001",
    "rpc": "192.168.1.100:8899",
    "tpu": "192.168.1.100:8002"
  },
  {
    "pubkey": "...",
    "gossip": "192.168.1.101:8001",
    "rpc": "192.168.1.101:8899",
    "tpu": "192.168.1.101:8002"
  }
]
```

### Check Individual Node Health

```bash
# On each node
./scripts/monitor.sh
```

**Expected output:**
```
Solana Validator Health Check

✓ Validator running
✓ RPC OK
  Disk: 45%
  Ledger: 2.1G
  Version: solana-cli 1.18.0

✓ All checks passed
```

### Verify Consensus

```bash
# Get current slot from each node
solana slot --url http://192.168.1.100:8899
solana slot --url http://192.168.1.101:8899
solana slot --url http://192.168.1.102:8899

# All should show similar slot numbers (within a few slots)
```

### Test Transactions

```bash
# Airdrop SOL on any node
./scripts/airdrop.sh <address> 10

# Check balance
solana balance <address> --url http://localhost:8899

# Create a transaction and verify it's seen by all nodes
```

---

## Operations

### Starting the Cluster

**Always start nodes in this order:**

1. **Bootstrap node first:**
   ```bash
   # On Node 1
   ./scripts/start-validator.sh
   ```

2. **Wait 10-15 seconds** for bootstrap node to initialize

3. **Start validator nodes:**
   ```bash
   # On Node 2
   ./scripts/start-validator.sh
   
   # On Node 3
   ./scripts/start-validator.sh
   ```

### Stopping the Cluster

**Stop in reverse order (validators first, then bootstrap):**

```bash
# On each validator node
./scripts/stop-validator.sh

# Finally, on bootstrap node
./scripts/stop-validator.sh
```

### Adding More Nodes

To add Node 4, Node 5, etc.:

```bash
# On new node
./scripts/install.sh
./scripts/setup-cluster.sh
./scripts/add-node.sh 192.168.1.100:8001  # Bootstrap node IP:port
./scripts/start-validator.sh
```

### Monitoring

**Set up automated monitoring:**

```bash
# Add to crontab (runs every 5 minutes)
crontab -e

# Add this line:
*/5 * * * * /path/to/Solana-Validator-Node/scripts/monitor.sh
```

---

## Troubleshooting

### Validator Node Can't Connect to Bootstrap

**Symptoms:**
- Validator starts but doesn't appear in cluster
- `list-nodes.sh` shows only bootstrap node

**Solutions:**

1. **Check bootstrap node is running:**
   ```bash
   # On bootstrap node
   pgrep -f solana-test-validator
   ./scripts/monitor.sh
   ```

2. **Verify network connectivity:**
   ```bash
   # From validator node, ping bootstrap
   ping 192.168.1.100
   
   # Test gossip port
   telnet 192.168.1.100 8001
   ```

3. **Check firewall rules:**
   ```bash
   # On both nodes
   sudo ufw status
   sudo ufw allow 8001/tcp
   sudo ufw allow 8001/udp
   ```

4. **Verify configuration:**
   ```bash
   # On validator node
   cat configs/config.env | grep BOOTSTRAP_NODE
   # Should show: BOOTSTRAP_NODE="192.168.1.100:8001"
   ```

5. **Check bootstrap node's RPC_BIND_ADDRESS:**
   ```bash
   # On bootstrap node
   cat configs/config.env | grep RPC_BIND_ADDRESS
   # Should NOT be "127.0.0.1" - use "0.0.0.0" or actual IP
   ```

### Nodes Show Different Slots

**Symptoms:**
- Nodes are connected but slots differ significantly

**Solutions:**

1. **Restart cluster in order:**
   ```bash
   # Stop all nodes
   ./scripts/stop-validator.sh  # On each node
   
   # Start bootstrap first
   ./scripts/start-validator.sh  # On Node 1
   
   # Wait 15 seconds
   sleep 15
   
   # Start validators
   ./scripts/start-validator.sh  # On Node 2, 3, etc.
   ```

2. **Check network latency:**
   ```bash
   ping <other-node-ip>
   # High latency can cause slot drift
   ```

### RPC Not Responding

**Symptoms:**
- `curl` requests timeout
- Clients can't connect

**Solutions:**

1. **Check validator is running:**
   ```bash
   pgrep -f solana-test-validator
   ```

2. **Check port is listening:**
   ```bash
   sudo netstat -tulpn | grep 8899
   ```

3. **Check firewall:**
   ```bash
   sudo ufw allow 8899/tcp
   ```

4. **Verify RPC_BIND_ADDRESS:**
   ```bash
   cat configs/config.env | grep RPC_BIND_ADDRESS
   # Use "0.0.0.0" to accept from any IP
   ```

### Validator Keeps Restarting

**Symptoms:**
- Process starts then immediately exits
- Can't maintain connection

**Solutions:**

1. **Check ledger corruption:**
   ```bash
   # Stop validator
   ./scripts/stop-validator.sh
   
   # Backup and reset ledger
   mv ~/solana-local-ledger ~/solana-local-ledger.backup
   mkdir ~/solana-local-ledger
   
   # Restart
   ./scripts/start-validator.sh
   ```

2. **Check disk space:**
   ```bash
   df -h
   # Ensure sufficient space
   ```

3. **Check system resources:**
   ```bash
   free -h  # Check RAM
   top      # Check CPU usage
   ```

### Common Error Messages

**"Blockhash not found":**
- Node is not synced with cluster
- Restart the node

**"Transaction timeout":**
- Network latency too high
- Check connectivity between nodes

**"Connection refused":**
- Firewall blocking port
- Validator not running
- Wrong IP address

---

## Best Practices

### 1. Node Ordering

- **Always start bootstrap node first**
- **Wait 10-15 seconds** before starting validators
- **Stop validators before bootstrap** when shutting down

### 2. Network Configuration

- Use **static IPs** for all nodes
- Configure **firewall rules** before starting nodes
- Test **network connectivity** between all nodes
- Use **private network** for gossip (port 8001)
- Expose **RPC port** (8899) only to trusted clients

### 3. Monitoring

- Set up **automated health checks** (cron job)
- Monitor **disk space** regularly
- Check **cluster status** daily
- Monitor **network latency** between nodes

### 4. Security

- **Don't expose gossip port** (8001) to internet
- Use **firewall rules** to restrict access
- Keep **Solana CLI updated**
- **Backup keypairs** securely
- Use **strong passwords** for SSH access

### 5. Backup and Recovery

- **Backup keypairs** regularly:
  ```bash
  cp ~/.config/solana/validator-keypair.json ~/backups/
  cp ~/.config/solana/id.json ~/backups/
  ```

- **Backup configuration:**
  ```bash
  cp configs/config.env ~/backups/config.env.$(date +%Y%m%d)
  ```

- **Document node information:**
  - IP addresses
  - Public keys
  - Port assignments

### 6. Performance

- Use **SSD storage** for ledger
- Allocate **sufficient RAM** (16GB+ recommended)
- Ensure **low latency** between nodes (<50ms ideal)
- Monitor **disk I/O** performance

### 7. Scaling

- Start with **2-3 nodes** for testing
- Add nodes **gradually** (one at a time)
- **Verify cluster health** after adding each node
- **Document** each node's configuration

---

## Example: Complete 3-Node Cluster

### Node 1 (Bootstrap) - 192.168.1.100

```bash
# Install
./scripts/install.sh
./scripts/setup-cluster.sh

# Configure
cat > configs/config.env <<EOF
CLUSTER_MODE=true
NODE_ROLE=bootstrap
RPC_BIND_ADDRESS="192.168.1.100"
RPC_PORT=8899
GOSSIP_PORT=8001
BOOTSTRAP_NODE=""
EOF

# Start
./scripts/start-validator.sh
```

### Node 2 (Validator) - 192.168.1.101

```bash
# Install
./scripts/install.sh
./scripts/setup-cluster.sh

# Join cluster
./scripts/add-node.sh 192.168.1.100:8001

# Configure
cat >> configs/config.env <<EOF
RPC_BIND_ADDRESS="192.168.1.101"
EOF

# Start
./scripts/start-validator.sh
```

### Node 3 (Validator) - 192.168.1.102

```bash
# Install
./scripts/install.sh
./scripts/setup-cluster.sh

# Join cluster
./scripts/add-node.sh 192.168.1.100:8001

# Configure
cat >> configs/config.env <<EOF
RPC_BIND_ADDRESS="192.168.1.102"
EOF

# Start
./scripts/start-validator.sh
```

### Verify Cluster

```bash
# On any node
./scripts/list-nodes.sh
# Should show all 3 nodes

# Check slots (should be similar)
solana slot --url http://192.168.1.100:8899
solana slot --url http://192.168.1.101:8899
solana slot --url http://192.168.1.102:8899
```

---

## Summary

Setting up a private Solana cluster involves:

1. **Bootstrap Node**: First node that initializes the cluster
2. **Validator Nodes**: Additional nodes that join the cluster
3. **Network Configuration**: Firewall rules and connectivity
4. **Verification**: Ensure all nodes are connected and synced
5. **Operations**: Starting, stopping, and monitoring the cluster

**Key Points:**
- Bootstrap node must start first
- All nodes use same gossip port (8001)
- Each node has its own ledger
- All nodes participate in consensus
- Network connectivity is critical

For additional help, refer to:
- `docs/02-operations.md` - Day-to-day operations
- `docs/04-troubleshooting.md` - Common issues and solutions
- `README.md` - Quick reference

