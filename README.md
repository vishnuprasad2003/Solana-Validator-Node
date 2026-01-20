# Solana Private Validator Cluster

Production-grade Solana private cluster setup with Docker support. Each validator runs independently with centralized configuration.

**Pure Bash Implementation**: All scripts use bash/Python - no Node.js dependencies required.

## Table of Contents

- [Architecture](#architecture)
- [How It Works](#how-it-works)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Configuration](#configuration)
- [Docker Deployment](#docker-deployment)
- [External Access](#external-access)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Architecture

### Overview

This setup creates a private Solana blockchain cluster with:
- **Bootstrap Validator**: Initial validator that creates the genesis block
- **Validator Nodes**: Additional validators that join the cluster
- **Centralized Configuration**: One config file per node
- **Docker Support**: Containerized deployment ready for Kubernetes

### Components

```
┌─────────────────────────────────────────────────────────┐
│                    Solana Cluster                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐      ┌──────────────┐               │
│  │  Bootstrap   │◄────►│  Validator-1 │               │
│  │  Validator    │      │              │               │
│  │  (Port 8001) │      │  (Port 8026) │               │
│  └──────────────┘      └──────────────┘               │
│         │                      │                       │
│         └──────────┬───────────┘                       │
│                    │                                   │
│            ┌───────▼────────┐                          │
│            │  Gossip Network │                          │
│            │   (UDP)         │                          │
│            └────────────────┘                          │
│                                                         │
│  RPC Endpoints:                                        │
│  - Bootstrap:  http://localhost:8899                  │
│  - Validator-1: http://localhost:8901                  │
└─────────────────────────────────────────────────────────┘
```

### Key Concepts

- **Genesis**: Initial blockchain state created by bootstrap validator
- **Gossip Protocol**: How validators communicate (UDP)
- **RPC API**: HTTP/JSON interface for querying and submitting transactions
- **Vote Account**: Validator's voting account for consensus participation
- **Stake Account**: SOL delegated to validator for consensus weight

## How It Works

### Bootstrap Validator

1. **Genesis Creation**: Creates initial blockchain state with:
   - 1 billion SOL in faucet account
   - Bootstrap validator identity, vote, and stake accounts
   - Essential SPL programs (Token, Token-2022, Associated Token, Metaplex)

2. **Block Production**: Starts producing blocks immediately (no waiting for votes)

3. **Network Entry Point**: Other validators connect to bootstrap's gossip port

### Validator Nodes

1. **Configuration**: Each validator has unique ports and references bootstrap
2. **Genesis Sync**: Downloads genesis from bootstrap via snapshots
3. **Vote Account**: Creates vote account to participate in consensus
4. **Cluster Join**: Connects to bootstrap via gossip protocol
5. **Block Sync**: Syncs blocks from the cluster

### Consensus Flow

1. **Leader Schedule**: Bootstrap creates initial leader schedule
2. **Block Production**: Current leader produces blocks
3. **Voting**: Validators vote on blocks they see
4. **Finalization**: Blocks are finalized when supermajority votes
5. **Fork Resolution**: Validators choose the heaviest fork (most stake)

### Data Flow

```
Transaction → RPC Endpoint → Validator → Gossip Network → All Validators
                                                              ↓
                                                      Consensus & Finalization
```

## Quick Start

### Prerequisites

```bash
# Check current system limits
ulimit -n  # Should show 1000000 (or higher)
ulimit -l  # Should show unlimited

# System limits (run once, requires logout/login)
sudo bash -c 'echo "* soft nofile 1000000" >> /etc/security/limits.conf'
sudo bash -c 'echo "* hard nofile 1000000" >> /etc/security/limits.conf'

# Install Solana CLI & Agave validator
make install

# Add to PATH (add to ~/.bashrc)
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
source ~/.bashrc
```

### Bootstrap Node

```bash
# 1. Create bootstrap config
cp configs/node.conf configs/bootstrap.conf
vim configs/bootstrap.conf  # Set NODE_NAME=bootstrap, NODE_TYPE=bootstrap

# 2. Generate keys & create genesis
make gen-keys CONFIG=bootstrap
make init-genesis CONFIG=bootstrap

# 3. Start bootstrap
make start CONFIG=bootstrap

# 4. Set Solana CLI to use faucet account
mkdir -p ~/.solana-keys
ln -sf "$(realpath keys/faucet.json)" ~/.solana-keys/faucet.json
solana config set --keypair ~/.solana-keys/faucet.json --url http://localhost:8899

# 5. Check faucet.txt for bootstrap info
cat faucet.txt
```

### Add Validator Node

```bash
# 1. Create validator config
cp configs/node.conf configs/validator-1.conf
vim configs/validator-1.conf
# Set: NODE_NAME=validator-1, NODE_TYPE=validator, ports, ENTRYPOINT, KNOWN_VALIDATOR, EXPECTED_GENESIS_HASH

# 2. Generate keys
make gen-keys CONFIG=validator-1

# 3. Fund identity & create vote account
IDENTITY=$(solana-keygen pubkey keys/validator-1-identity.json)
solana transfer $IDENTITY 10 --allow-unfunded-recipient
./scripts/create-vote-account.sh validator-1

# 4. Start validator
make start CONFIG=validator-1
```

### Verify Cluster

See [Testing](#testing) section for comprehensive test commands.

## Detailed Setup

### Step 1: System Configuration

```bash
# Check current system limits before applying changes
ulimit -n  # Check file descriptor limit (should be 1000000 or higher)
ulimit -l  # Check memory lock limit (should be unlimited)

# File descriptors (required for Solana)
sudo bash -c 'cat >> /etc/security/limits.conf <<EOF
* soft nofile 1000000
* hard nofile 1000000
* soft memlock unlimited
* hard memlock unlimited
EOF'

# Logout and login for limits to take effect
# After login, verify with: ulimit -n and ulimit -l
```

### Step 2: Install Solana Tools

```bash
make install

# Verify installation
solana --version
agave-validator --version
```

### Step 3: Bootstrap Configuration

Edit `configs/bootstrap.conf`:

```bash
NODE_NAME="bootstrap"
NODE_TYPE="bootstrap"
GOSSIP_PORT=8001
RPC_PORT=8899
RPC_BIND_ADDRESS="0.0.0.0"
DYNAMIC_PORT_RANGE_START=8000
DYNAMIC_PORT_RANGE_END=8025
GENESIS_LAMPORTS=1000000000000000000  # 1 billion SOL
BOOTSTRAP_STAKE_LAMPORTS=1000000000000  # 1000 SOL staked
LIMIT_LEDGER_SIZE=50000000
```

### Step 4: Initialize Bootstrap

```bash
# Generate keypairs
make gen-keys CONFIG=bootstrap

# Create genesis (includes SPL programs)
make init-genesis CONFIG=bootstrap

# Start bootstrap validator
make start CONFIG=bootstrap

# Wait for RPC to be ready (check logs)
tail -f /solana/logs/bootstrap.log
```

### Step 5: Validator Configuration

Create `configs/validator-1.conf`:

```bash
NODE_NAME="validator-1"
NODE_TYPE="validator"
GOSSIP_PORT=8026          # Unique port
RPC_PORT=8901             # Unique port
RPC_BIND_ADDRESS="0.0.0.0"
DYNAMIC_PORT_RANGE_START=8030
DYNAMIC_PORT_RANGE_END=8055
ENTRYPOINT="localhost:8001"  # Bootstrap gossip address
KNOWN_VALIDATOR="<BOOTSTRAP_IDENTITY>"  # From faucet.txt
EXPECTED_GENESIS_HASH="<GENESIS_HASH>"  # From faucet.txt
LIMIT_LEDGER_SIZE=50000000
```

### Step 6: Add Validator to Cluster

```bash
# Generate keys
make gen-keys CONFIG=validator-1

# Fund identity account (requires bootstrap running)
IDENTITY=$(solana-keygen pubkey keys/validator-1-identity.json)
solana transfer $IDENTITY 10 --allow-unfunded-recipient

# Create vote account
./scripts/create-vote-account.sh validator-1

# Start validator
make start CONFIG=validator-1
```

## Configuration

### Config File Structure

Each validator has its own `configs/<node-name>.conf` file:

```bash
# Node Identity
NODE_NAME="bootstrap"
NODE_TYPE="bootstrap"  # or "validator"

# Key Paths
IDENTITY_KEY="keys/${NODE_NAME}-identity.json"
VOTE_KEY="keys/${NODE_NAME}-vote.json"
STAKE_KEY="keys/${NODE_NAME}-stake.json"

# Network Ports
GOSSIP_PORT=8001
RPC_PORT=8899
RPC_BIND_ADDRESS="0.0.0.0"
DYNAMIC_PORT_RANGE_START=8000
DYNAMIC_PORT_RANGE_END=8025

# Genesis (Bootstrap only)
GENESIS_LAMPORTS=1000000000000000000
BOOTSTRAP_STAKE_LAMPORTS=1000000000000

# Cluster Connection (Validators only)
ENTRYPOINT="localhost:8001"
KNOWN_VALIDATOR="<bootstrap-identity>"
EXPECTED_GENESIS_HASH="<genesis-hash>"

# Performance
LIMIT_LEDGER_SIZE=50000000

# Log Storage
# Logs are automatically stored in Azure File Share (/solana/logs/)
# Relative LOG_FILE paths resolve to /solana/logs/<filename>
# Absolute LOG_FILE paths are used as-is
LOG_FILE="logs/${NODE_NAME}.log"  # Stored in /solana/logs/${NODE_NAME}.log
```

### Azure File Share Log Storage

**Logs are automatically stored in Azure File Share** mounted at `/solana`:

- **Log Location**: `/solana/logs/` (Azure File Share)
- **Other Data**: Keys, ledger, and configs remain in project directories (local storage)
- **Automatic Resolution**: Relative `LOG_FILE` paths automatically resolve to `/solana/logs/<filename>`
- **Custom Paths**: Absolute `LOG_FILE` paths are used as-is (e.g., `/custom/path/logs/node.log`)

**Example**:
```bash
# In config file:
LOG_FILE="logs/bootstrap.log"  # Relative path

# Resolves to:
# /solana/logs/bootstrap.log  (Azure File Share)

# Or use absolute path:
LOG_FILE="/solana/logs/bootstrap.log"  # Explicit Azure File Share path
```

**Benefits**:
- Centralized log storage and backup
- Accessible from multiple VMs
- Persistent across VM restarts
- Easy log aggregation and monitoring

### Port Planning

| Node | Gossip | RPC | Dynamic Range |
|------|--------|-----|---------------|
| bootstrap | 8001 | 8899 | 8000-8025 |
| validator-1 | 8026 | 8901 | 8030-8055 |
| validator-2 | 8056 | 8902 | 8060-8085 |
| validator-3 | 8086 | 8903 | 8090-8115 |

**Important**: Each validator must have unique ports to avoid conflicts.

## Docker Deployment

### Build Image

```bash
make build
```

### Run Single Container

```bash
# Bootstrap
docker run -d \
  --name solana-bootstrap \
  --network host \
  -e NODE_NAME=bootstrap \
  -v "$(pwd)/configs:/app/configs" \
  -v "$(pwd)/keys:/app/keys" \
  -v "$(pwd)/data:/app/data" \
  -v "$(pwd)/logs:/app/logs" \
  -v "$(pwd)/programs:/app/programs" \
  solana-validator:latest

# Validator-1
docker run -d \
  --name solana-validator-1 \
  --network host \
  -e NODE_NAME=validator-1 \
  -v "$(pwd)/configs:/app/configs" \
  -v "$(pwd)/keys:/app/keys" \
  -v "$(pwd)/data:/app/data" \
  -v "$(pwd)/logs:/app/logs" \
  -v "$(pwd)/programs:/app/programs" \
  solana-validator:latest
```

### Docker Compose

```bash
# Start cluster
make docker-up

# Stop cluster
make docker-down
```

## External Access

### Firewall Configuration

For external internet access via static public IP:

```bash
# Allow RPC port from anywhere
sudo ufw allow 8899/tcp  # Bootstrap RPC
sudo ufw allow 8901/tcp  # Validator-1 RPC

# Allow gossip port (UDP) - needed for validator communication
sudo ufw allow 8001/udp  # Bootstrap Gossip
sudo ufw allow 8026/udp  # Validator-1 Gossip

# Enable firewall
sudo ufw enable
```

### Cloud Provider Security Groups

**AWS/Azure/GCP**: Allow inbound TCP port 8899 (and other RPC ports) from `0.0.0.0/0` or specific IPs.

### Security Recommendations

1. **Use Reverse Proxy**: Set up nginx/Caddy with rate limiting
2. **IP Whitelisting**: Restrict access to known IPs in production
3. **HTTPS**: Use reverse proxy with SSL/TLS
4. **Monitor Access**: Set up logging and monitoring

### Testing External Access

```bash
# From external machine
solana config set --url http://<PUBLIC_IP>:8899
solana cluster-version
solana get-slot

# Or use curl
curl -s http://<PUBLIC_IP>:8899 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | jq
```

## Commands

```bash
# Installation
make install              # Install Solana CLI & Agave

# Setup
make gen-keys CONFIG=...  # Generate keypairs
make init-genesis CONFIG=bootstrap  # Create genesis
make create-vote-account NODE=validator-1  # Create vote account

# Operations
make start CONFIG=...     # Start validator
make stop NODE=...        # Stop validator

# Docker
make build                # Build Docker image
make docker-up            # Start Docker cluster
make docker-down          # Stop Docker cluster

# Utilities
make clean                # Remove data/logs
make faucet-private-key   # Get faucet private key (base58)
```

## Project Structure

```
.
├── configs/
│   ├── bootstrap.conf          # Bootstrap validator config
│   └── node.conf               # Config template (copy for each node)
├── scripts/
│   ├── common.sh               # Shared utilities (includes Azure File Share log resolution)
│   ├── install.sh              # Install Solana CLI & Agave validator
│   ├── gen-keys.sh             # Generate keypairs
│   ├── init-genesis.sh         # Create genesis (bootstrap only)
│   ├── create-vote-account.sh  # Create vote account (validators)
│   ├── start-validator.sh      # Start validator
│   ├── stop-validator.sh       # Stop validator
│   ├── get-faucet-private-key.sh  # Extract faucet private key (base58)
│   ├── upgrade.sh              # Upgrade dependencies
│   └── docker-entrypoint.sh    # Docker entrypoint
├── docker/
│   ├── Dockerfile              # Docker image
│   └── docker-compose.yml      # Compose setup
├── programs/                   # SPL program binaries
├── keys/                       # Keypairs (LOCAL storage - NOT in Azure File Share)
├── data/                       # Ledger data (LOCAL storage - NOT in Azure File Share)
├── programs/                   # SPL program binaries (LOCAL storage - NOT in Azure File Share)
└── /solana/logs/               # Logs (Azure File Share - ONLY logs go here!)
│   ├── spl_token.so
│   ├── spl_token_2022.so
│   ├── spl_associated_token_account.so
│   └── mpl_token_metadata.so
├── Makefile                    # Common commands
├── README.md                   # This file
├── .gitignore                  # Git ignore rules
└── .dockerignore              # Docker ignore rules
```

**Note**: Runtime directories (`data/`, `logs/`, `keys/`, `backups/`) are gitignored and created automatically.

## Testing

Comprehensive testing commands to verify your cluster is running correctly.

### Basic Health Checks

#### Check RPC Health (curl)

```bash
# Bootstrap RPC health
curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | jq

# Validator-1 RPC health
curl -s http://localhost:8901 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | jq

# Expected output: "ok"
```

#### Check Cluster Nodes (curl)

```bash
# Get all cluster nodes (should show all validators)
curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq

# Count nodes
curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq '.result | length'

# Expected: Number of validators (e.g., 2 for bootstrap + validator-1)
```

#### Check Slot Progression (curl)

```bash
# Get current slot from bootstrap
curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq

# Get current slot from validator-1
curl -s http://localhost:8901 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq

# Compare slots (should be close, within a few slots)
echo "Bootstrap: $(curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq -r '.result')"
echo "Validator-1: $(curl -s http://localhost:8901 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq -r '.result')"
```

### Solana CLI Testing

#### Basic Cluster Info

```bash
# Set Solana CLI to use bootstrap RPC
solana config set --url http://localhost:8899

# Get cluster version
solana cluster-version

# Get current slot
solana get-slot

# Get block height
solana block-height

# Get epoch info
solana epoch-info

# Get validator info
solana validator-info
```

#### Account Testing

```bash
# Check faucet balance
solana balance

# Get faucet address
solana address

# Create a test account
solana-keygen new --no-bip39-passphrase -o /tmp/test-account.json
TEST_ADDRESS=$(solana-keygen pubkey /tmp/test-account.json)
echo "Test account: $TEST_ADDRESS"

# Transfer SOL to test account
solana transfer $TEST_ADDRESS 5 --allow-unfunded-recipient

# Check test account balance
solana balance $TEST_ADDRESS

# Check balance from validator-1 RPC (cross-node verification)
solana balance $TEST_ADDRESS --url http://localhost:8901
```

#### Vote Account Testing

```bash
# Check bootstrap vote account
BOOTSTRAP_VOTE=$(grep BOOTSTRAP_IDENTITY faucet.txt | cut -d= -f2)
solana vote-account $BOOTSTRAP_VOTE

# Check validator-1 vote account
VALIDATOR1_VOTE=$(solana-keygen pubkey keys/validator-1-vote.json)
solana vote-account $VALIDATOR1_VOTE

# List all vote accounts
solana vote-accounts
```

#### Transaction Testing

```bash
# Create two test accounts
solana-keygen new --no-bip39-passphrase -o /tmp/account1.json
solana-keygen new --no-bip39-passphrase -o /tmp/account2.json
ACCOUNT1=$(solana-keygen pubkey /tmp/account1.json)
ACCOUNT2=$(solana-keygen pubkey /tmp/account2.json)

# Fund both accounts
solana transfer $ACCOUNT1 10 --allow-unfunded-recipient
solana transfer $ACCOUNT2 5 --allow-unfunded-recipient

# Transfer from account1 to account2
solana transfer $ACCOUNT2 3 --keypair /tmp/account1.json --allow-unfunded-recipient

# Verify balances
solana balance $ACCOUNT1
solana balance $ACCOUNT2

# Check transaction history
solana confirm -v $(solana transfer $ACCOUNT2 1 --keypair /tmp/account1.json --allow-unfunded-recipient)
```

### Cross-Node Data Verification

#### Test Data Replication

```bash
# Create account via bootstrap RPC
solana config set --url http://localhost:8899
solana-keygen new --no-bip39-passphrase -o /tmp/cross-test.json
CROSS_TEST=$(solana-keygen pubkey /tmp/cross-test.json)
solana transfer $CROSS_TEST 10 --allow-unfunded-recipient

# Wait a few seconds for propagation
sleep 5

# Query from validator-1 RPC (should show same balance)
curl -s http://localhost:8901 -X POST -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getBalance\",\"params\":[\"$CROSS_TEST\"]}" | jq

# Or use Solana CLI
solana balance $CROSS_TEST --url http://localhost:8901
```

#### Test Transaction Propagation

```bash
# Send transaction via bootstrap
solana config set --url http://localhost:8899
TX_SIG=$(solana transfer $CROSS_TEST 1 --keypair /tmp/cross-test.json --allow-unfunded-recipient)
echo "Transaction: $TX_SIG"

# Wait for confirmation
sleep 3

# Check transaction status from validator-1
curl -s http://localhost:8901 -X POST -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getSignatureStatuses\",\"params\":[[\"$TX_SIG\"]]}" | jq

# Or use Solana CLI
solana confirm $TX_SIG --url http://localhost:8901
```

### Advanced Testing

#### Check Validator Performance

```bash
# Get validator performance samples
curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getRecentPerformanceSamples","params":[5]}' | jq

# Get block production stats
curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getBlockProduction"}' | jq
```

#### Check Network Information

```bash
# Get cluster info
curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterInfo"}' | jq

# Get version info
curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getVersion"}' | jq

# Get genesis hash
curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getGenesisHash"}' | jq
```

#### Monitor Slot Progression

```bash
# Watch slots in real-time
watch -n 1 'echo "Bootstrap: $(curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getSlot\"}" | jq -r ".result")" && echo "Validator-1: $(curl -s http://localhost:8901 -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getSlot\"}" | jq -r ".result")"'
```

### Complete Test Script

Run this comprehensive test to verify everything:

```bash
#!/bin/bash
echo "=== Solana Cluster Test ==="

# 1. Health checks
echo -e "\n[1] Health Checks"
echo "Bootstrap: $(curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | jq -r '.result')"
echo "Validator-1: $(curl -s http://localhost:8901 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | jq -r '.result')"

# 2. Cluster nodes
echo -e "\n[2] Cluster Nodes"
NODE_COUNT=$(curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq '.result | length')
echo "Total nodes: $NODE_COUNT"

# 3. Slot sync
echo -e "\n[3] Slot Synchronization"
BOOTSTRAP_SLOT=$(curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq -r '.result')
VALIDATOR1_SLOT=$(curl -s http://localhost:8901 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq -r '.result')
echo "Bootstrap slot: $BOOTSTRAP_SLOT"
echo "Validator-1 slot: $VALIDATOR1_SLOT"
SLOT_DIFF=$((BOOTSTRAP_SLOT - VALIDATOR1_SLOT))
echo "Slot difference: $SLOT_DIFF (should be < 10)"

# 4. Account creation and transfer
echo -e "\n[4] Account & Transaction Test"
solana config set --url http://localhost:8899 > /dev/null 2>&1
solana-keygen new --no-bip39-passphrase -o /tmp/test-$(date +%s).json > /dev/null 2>&1
TEST_ACCOUNT=$(solana-keygen pubkey /tmp/test-*.json | head -1)
solana transfer $TEST_ACCOUNT 5 --allow-unfunded-recipient > /dev/null 2>&1
sleep 2
BALANCE=$(solana balance $TEST_ACCOUNT --url http://localhost:8901 2>/dev/null | grep -o '[0-9.]* SOL' || echo "0 SOL")
echo "Test account balance (from validator-1): $BALANCE"

# 5. Vote accounts
echo -e "\n[5] Vote Accounts"
VOTE_COUNT=$(solana vote-accounts --url http://localhost:8899 2>/dev/null | grep -c "Identity:" || echo "0")
echo "Active vote accounts: $VOTE_COUNT"

echo -e "\n=== Test Complete ==="
```

Save as `test-cluster.sh`, make executable (`chmod +x test-cluster.sh`), and run: `./test-cluster.sh`

## Troubleshooting

### Validator Won't Start

1. **Check config file exists**: `configs/<node-name>.conf`
2. **Verify keypairs exist**: `ls keys/<node-name>-*.json`
3. **Check ports available**: `ss -tuln | grep <port>`
4. **Review logs**: `tail -f /solana/logs/<node-name>.log`

### Validator Not Joining Cluster

1. **Verify ENTRYPOINT**: Must be `IP:PORT` format (no http://)
2. **Check KNOWN_VALIDATOR**: Must match bootstrap identity from `faucet.txt`
3. **Verify EXPECTED_GENESIS_HASH**: Must match bootstrap genesis hash
4. **Ensure bootstrap is running**: `ps aux | grep bootstrap-identity`

### RPC Not Responding

1. **Check validator is running**: `ps aux | grep agave-validator`
2. **Verify RPC port**: `netstat -tlnp | grep 8899`
3. **Check firewall**: `sudo ufw status`
4. **Review logs**: `tail -f /solana/logs/<node-name>.log | grep -i rpc`

### Genesis Hash Not Found

The genesis hash is shown in `solana-genesis` output. If `faucet.txt` has empty `GENESIS_HASH`, check the genesis creation output or extract manually.

### Snapshot Errors

If validator crashes with snapshot errors (e.g., "sending on a disconnected channel", "failed to load bank"):
```bash
# Stop the validator first
make stop NODE=<node-name>

# Remove corrupted snapshots and accounts
rm -rf data/<node-name>/snapshots
rm -rf data/<node-name>/incremental-snapshots
rm -rf data/<node-name>/accounts
rm -rf data/<node-name>/accounts_hash_cache
rm -rf data/<node-name>/accounts_index

# Keep genesis.bin - validator will rebuild from genesis
# Restart validator (will rebuild from genesis)
make start CONFIG=<node-name>
```

**Note**: This will cause the validator to rebuild from genesis, which may take a few minutes. All previous transaction history will be lost, but the validator will continue operating.

### Cross-Node Data Not Syncing

1. **Verify cluster nodes**: `curl ... getClusterNodes` should show all nodes
2. **Check slots**: Both nodes should have similar slot numbers
3. **Wait for sync**: New transactions may take a few seconds to propagate
4. **Check gossip connectivity**: Validators must be able to communicate via UDP

### Getting Faucet Private Key

To get the faucet private key in base58 format (for use in external applications):

```bash
# Get faucet private key
make faucet-private-key

# Or specify a different keypair file
./scripts/get-faucet-private-key.sh keys/my-keypair.json
```

**Requirements:**
- Python3 with `base58` module: `pip install base58`
- OR Node.js with `bs58` module: `npm install -g bs58`

The script will automatically detect and use the available tool.

## Upgrading Dependencies

The upgrade script provides production-grade dependency management with backup, verification, and rollback support.

### Full Upgrade (Recommended)

Upgrade all dependencies while preserving data:

```bash
# Full upgrade with automatic backup
make upgrade

# Or directly:
./scripts/upgrade.sh all
```

This will:
- ✅ Create automatic backup of binaries, configs, keys, and programs
- ✅ Upgrade Solana CLI tools
- ✅ Upgrade Agave validator (or Solana validator as fallback)
- ✅ Update SPL programs (if available)
- ✅ Verify all upgrades
- ✅ Clean up old backups (keeps last 5)

**Important**: All validator data, keys, configs, and ledger data are preserved. Only binaries and dependencies are updated.

### Selective Upgrades

Upgrade specific components:

```bash
# Check current versions
make upgrade-check

# Upgrade only Solana CLI
./scripts/upgrade.sh update-cli

# Upgrade only Agave validator
./scripts/upgrade.sh update-validator

# Upgrade Solana CLI and validator together
./scripts/upgrade.sh update

# Update SPL programs
./scripts/upgrade.sh update-programs
```

### Backup & Rollback

```bash
# Create manual backup
make backup

# List available backups
./scripts/upgrade.sh list-backups

# Rollback to specific backup
./scripts/upgrade.sh rollback backups/20260115_120000

# Clean old backups (keep last 5)
./scripts/upgrade.sh cleanup 5
```

### Status & Verification

```bash
# Show current status
make upgrade-status

# Verify installation
./scripts/upgrade.sh verify
```

### Production Best Practices

1. **Always backup before upgrading**:
   ```bash
   make backup
   ```

2. **Stop validators before upgrading**:
   ```bash
   make stop NODE=bootstrap
   make stop NODE=validator-1
   make upgrade
   make start CONFIG=bootstrap
   make start CONFIG=validator-1
   ```

3. **Monitor after upgrade**:
   ```bash
   tail -f /solana/logs/bootstrap.log
   # Check RPC health
   curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | jq
   ```

4. **Keep backups**: The script automatically keeps the last 5 backups

5. **Rollback if needed**: Use the rollback command if issues occur

6. **Test in staging first** (if available)

### What Gets Upgraded

| Component | Command | Data Affected |
|-----------|---------|---------------|
| Solana CLI | `update-cli` | Binary only (data preserved) |
| Agave Validator | `update-validator` | Binary only (data preserved) |
| SPL Programs | `update-programs` | Program binaries only |

**All validator data, keys, configs, and ledger data are preserved during upgrades.**

### Upgrade Process Flow

```
1. Check prerequisites (curl, wget, jq)
2. Stop running validators (with confirmation)
3. Create backup (binaries, configs, keys, programs)
4. Upgrade Solana CLI
5. Upgrade Agave validator
6. Update SPL programs
7. Verify all upgrades
8. Clean old backups
9. Ready to restart validators
```

## Notes

- **Genesis**: Created once for bootstrap, shared via snapshots
- **Keys**: Stored in `keys/` directory (gitignored, never committed)
- **Data**: Stored in `data/` directory (gitignored, ledger data)
- **Logs**: Stored in `logs/` directory (gitignored)
- **Backups**: Created by upgrade script in `backups/` (gitignored)
- **Faucet info**: Saved to `faucet.txt` after genesis (gitignored)
- **No Node.js dependencies**: All scripts use bash/Python (no package.json needed)

## Security

- Keys are never committed to git
- Use environment variables for sensitive data in production
- Restrict RPC access via firewall in production
- Regularly backup `keys/` and `data/` directories
- Use reverse proxy with rate limiting for external access
