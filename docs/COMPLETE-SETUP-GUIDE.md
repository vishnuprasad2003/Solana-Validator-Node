# Complete Setup Guide - Production Solana Private Cluster

This guide provides step-by-step instructions to set up a production-grade private Solana cluster from scratch on a new system.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [System Requirements](#system-requirements)
3. [Initial Setup](#initial-setup)
4. [Genesis Creation](#genesis-creation)
5. [Starting the Cluster](#starting-the-cluster)
6. [Adding Validator Nodes](#adding-validator-nodes)
7. [Token Operations](#token-operations)
8. [External Access](#external-access)
9. [Monitoring & Maintenance](#monitoring--maintenance)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **Linux** (Ubuntu 20.04+ recommended)
- **Bash** 4.0+
- **curl** and **wget**
- **jq** (JSON processor)
- **Git**
- **Rust** (for building Solana tools, if needed)

### Install Basic Dependencies

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y curl wget jq git build-essential

# Verify installations
curl --version
jq --version
git --version
```

---

## System Requirements

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 4 cores | 8+ cores |
| RAM | 8 GB | 16+ GB |
| Storage | 100 GB SSD | 500+ GB NVMe SSD |
| Network | 100 Mbps | 1 Gbps+ |

### System Limits Configuration

Solana validators require high file descriptor limits. Configure them:

```bash
# Edit limits configuration
sudo nano /etc/security/limits.conf

# Add these lines:
* soft nofile 1000000
* hard nofile 1000000
* soft memlock unlimited
* hard memlock unlimited

# Save and exit, then log out and log back in
# Or use the provided script:
sudo make setup-limits
```

**Verify limits:**
```bash
ulimit -Hn  # Should show 1000000
ulimit -Sn  # Should show 1000000
```

---

## Initial Setup

### Step 1: Clone/Download the Repository

```bash
# If using git
git clone <repository-url>
cd Solana-Validator-Node

# Or extract from archive
# cd to the extracted directory
```

### Step 2: Install Solana CLI Tools

The setup script will install Agave validator and Solana CLI tools:

```bash
# Install Agave validator and Solana CLI
make install

# Or manually:
./scripts/install.sh
```

**What this installs:**
- `agave-validator` - The validator binary
- `solana` - Solana CLI tools
- `solana-genesis` - Genesis creation tool
- `spl-token` - SPL Token CLI (if available)

**Verify installation:**
```bash
agave-validator --version
solana --version
solana-genesis --version
```

### Step 3: Configure Cluster Settings

Edit `configs/cluster.conf` if needed:

```bash
# View current configuration
cat configs/cluster.conf

# Key settings:
# - CLUSTER_TYPE: "development" (default)
# - RPC_PORT: 8899 (default)
# - GOSSIP_PORT: 8001 (default)
# - RPC_BIND_ADDRESS: "0.0.0.0" (allows external access)
```

**For external access (Azure VM, etc.):**
```bash
# Set your public IP
export PUBLIC_IP="your.public.ip.address"

# Run setup script
./scripts/setup-external-access.sh

# Or manually edit configs/cluster.conf:
# BOOTSTRAP_VALIDATOR_IP="your.public.ip.address"
```

---

## Genesis Creation

### Step 1: Create Genesis with Essential Programs

The genesis creation process automatically:
- Generates bootstrap validator keypairs
- Creates faucet account
- Downloads SPL and Metaplex programs from mainnet
- Includes programs in genesis at standard addresses

```bash
# Create genesis (will prompt if exists)
make init-genesis

# Or force recreation:
rm -rf data/bootstrap/*
make init-genesis
```

**What happens:**
1. **Keypair Generation**: Creates bootstrap identity, vote, stake, and faucet keys
2. **Program Download**: Downloads from mainnet:
   - SPL Token Program
   - SPL Token-2022 Program
   - Associated Token Account Program
   - Metaplex Token Metadata Program
3. **Genesis Creation**: Creates `data/bootstrap/genesis.bin` with all programs included

**Output:**
```
[INFO] Bootstrap Identity: 4g68JKMQm1X7P7cCbvMHWvYPDtdkahoriQFA2y7V5xWd
[INFO] Bootstrap Vote: 4VeRgwNxzZBZeQGkTocK5WFKhfUD9eUNhBfCnQXaVo9U
[INFO] Bootstrap Stake: GqP463J1WgEuDNDzXvE1QiQqpCCgq8Uz3xz4gkyfuZYF
[INFO] Faucet: Hjckuz4ngUPdhGrbq4QXXQehoVbSzZyyziLvesRqpuCs
[SUCCESS] Genesis created successfully!
```

**Verify programs:**
```bash
# Check programs directory
ls -lh programs/

# Should see:
# - spl_token.so
# - spl_token_2022.so
# - spl_associated_token_account.so
# - mpl_token_metadata.so
```

---

## Starting the Cluster

### Option 1: Automated Cluster Startup (Recommended)

```bash
# Start entire cluster (bootstrap + validators)
make start-cluster
```

**What this does:**
1. Starts bootstrap validator
2. Waits for bootstrap to be ready
3. Waits for snapshots (slot 400)
4. Checks/verifies essential programs
5. Starts additional validators (validator-1, etc.)
6. Verifies cluster status

**Expected output:**
```
[INFO] Starting Production-Grade Solana Cluster
[SUCCESS] Bootstrap validator is ready!
[SUCCESS] Snapshot found: snapshot-400-...
[INFO] Essential programs already available
[SUCCESS] Validator validator-1 started successfully
[SUCCESS] Cluster verification complete
[INFO] Cluster nodes detected: 2
```

### Option 2: Manual Startup

```bash
# Step 1: Start bootstrap
make start-bootstrap

# Step 2: Wait for snapshot (check every 5 seconds)
watch -n 5 'ls -lh data/bootstrap/snapshot-*.tar.zst 2>/dev/null | tail -1'

# Step 3: Start validator-1
make start-validator NODE=validator-1

# Step 4: Start additional validators
make start-validator NODE=validator-2
```

### Verify Cluster Status

```bash
# Check cluster nodes
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq

# Check slots
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq

# List running validators
make list
```

---

## Adding Validator Nodes

### Step 1: Create Validator Configuration

Create a new configuration file for each validator:

```bash
# Copy template
cp configs/node.conf.template configs/validator-2.conf

# Edit configuration
nano configs/validator-2.conf
```

**Key settings in `configs/validator-2.conf`:**
```bash
# Validator name
NODE_NAME="validator-2"

# Ports (must be unique, not overlapping)
NODE_GOSSIP_PORT=8027
NODE_RPC_PORT=8902
NODE_TPU_PORT=8056
NODE_TPU_FORWARD_PORT=8057
NODE_METRICS_PORT=9092

# Dynamic port range (25 ports needed)
NODE_DYNAMIC_PORT_RANGE_START=8056
NODE_DYNAMIC_PORT_RANGE_END=8081

# Bootstrap connection
BOOTSTRAP_VALIDATOR_IP="127.0.0.1"  # or your public IP
BOOTSTRAP_VALIDATOR_GOSSIP_PORT=8001
```

### Step 2: Generate Validator Keypairs

Keypairs are automatically generated when starting the validator, but you can pre-generate:

```bash
# Generate identity key
solana-keygen new --outfile keys/identity/validator-2-identity.json --no-bip39-passphrase

# Generate vote key
solana-keygen new --outfile keys/vote/validator-2-vote.json --no-bip39-passphrase

# Generate stake key
solana-keygen new --outfile keys/stake/validator-2-stake.json --no-bip39-passphrase

# Get public keys
solana-keygen pubkey keys/identity/validator-2-identity.json
solana-keygen pubkey keys/vote/validator-2-vote.json
solana-keygen pubkey keys/stake/validator-2-stake.json
```

### Step 3: Fund Validator Identity

```bash
VALIDATOR2_IDENTITY=$(solana-keygen pubkey keys/identity/validator-2-identity.json)

# Transfer SOL from faucet
solana transfer $VALIDATOR2_IDENTITY 10 \
  --allow-unfunded-recipient \
  --keypair keys/identity/faucet.json \
  --url http://localhost:8899
```

### Step 4: Create Vote Account

```bash
# Create vote account
solana create-vote-account \
  keys/vote/validator-2-vote.json \
  keys/identity/validator-2-identity.json \
  keys/stake/validator-2-stake.json \
  --fee-payer keys/identity/validator-2-identity.json \
  --url http://localhost:8899

# Verify vote account
VALIDATOR2_VOTE=$(solana-keygen pubkey keys/vote/validator-2-vote.json)
solana vote-account $VALIDATOR2_VOTE --url http://localhost:8899
```

### Step 5: Prepare Validator Data Directory

```bash
# Clean validator data directory
rm -rf data/validator-2/*

# Copy genesis from bootstrap
cp data/bootstrap/genesis.bin data/validator-2/

# Wait for snapshot from bootstrap
# (Snapshot should be at slot 400, 800, 1200, etc.)
LATEST_SNAPSHOT=$(find data/bootstrap -maxdepth 1 -name "snapshot-*.tar.zst" -type f | sort -r | head -1)

if [ -n "$LATEST_SNAPSHOT" ]; then
    cp "$LATEST_SNAPSHOT" data/validator-2/
    echo "Snapshot copied: $(basename $LATEST_SNAPSHOT)"
else
    echo "No snapshot found. Wait for bootstrap to produce snapshots."
    exit 1
fi
```

### Step 6: Start the New Validator

```bash
# Start validator-2
make start-validator NODE=validator-2

# Or manually:
./scripts/start-validator.sh validator-2
```

### Step 7: Verify Validator Joined

```bash
# Check cluster nodes
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq

# Should see validator-2 in the list

# Check validator-2 RPC
curl http://localhost:8902 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq
```

---

## Token Operations

### Setup

```bash
# Set cluster URL
export SOLANA_URL="http://localhost:8899"
solana config set --url $SOLANA_URL

# Fund your wallet (if needed)
YOUR_WALLET=$(solana address)
solana transfer $YOUR_WALLET 100 \
  --allow-unfunded-recipient \
  --keypair keys/identity/faucet.json \
  --url $SOLANA_URL
```

### Create Token Mint

```bash
# Create token
spl-token create-token

# Output:
# Creating token ABC123... under program TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA
# Address: ABC123...
# Decimals: 9
```

### Create Token Account

```bash
# Create token account for the mint
spl-token create-account <MINT_ADDRESS>

# Example:
spl-token create-account ABC123...
```

### Mint Tokens

```bash
# Mint tokens to your account
spl-token mint <MINT_ADDRESS> 1000

# Example:
spl-token mint ABC123... 1000
```

### Transfer Tokens

```bash
# Transfer tokens to another account
spl-token transfer <MINT_ADDRESS> <AMOUNT> <RECIPIENT_TOKEN_ACCOUNT>

# Example:
spl-token transfer ABC123... 100 RECIPIENT_TOKEN_ACCOUNT_ADDRESS
```

### Approve Delegate

```bash
# Approve delegate to spend tokens
spl-token approve <MINT_ADDRESS> <AMOUNT> <DELEGATE_ADDRESS>

# Example:
spl-token approve ABC123... 50 DELEGATE_ADDRESS
```

### Check Token Balance

```bash
# Check your token balance
spl-token balance <MINT_ADDRESS>

# Via curl:
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "getTokenAccountBalance",
    "params": ["TOKEN_ACCOUNT_ADDRESS"]
  }'
```

### Get Mint Information

```bash
# Get mint account info
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "getAccountInfo",
    "params": ["MINT_ADDRESS", {"encoding": "jsonParsed"}]
  }'

# Get token supply
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "getTokenSupply",
    "params": ["MINT_ADDRESS"]
  }'
```

---

## External Access

### Configure for Azure VM / Public IP

```bash
# Set your public IP
export PUBLIC_IP="your.azure.vm.ip.address"

# Configure cluster
./scripts/setup-external-access.sh

# Or manually edit configs/cluster.conf:
# BOOTSTRAP_VALIDATOR_IP="your.azure.vm.ip.address"
```

### Firewall Rules (Azure Network Security Group)

Add these inbound rules:

| Protocol | Port Range | Source | Description |
|----------|------------|--------|-------------|
| UDP | 8001 | Any | Gossip (Bootstrap) |
| TCP | 8001 | Any | Gossip (Bootstrap) |
| TCP | 8899 | Any | RPC (Bootstrap) |
| TCP | 8900 | Any | RPC WebSocket |
| UDP | 8000-8025 | Any | Dynamic ports (Bootstrap) |
| TCP | 8901+ | Any | RPC (Additional validators) |
| UDP | 8026+ | Any | Gossip (Additional validators) |

### Connect from External Client

```bash
# Set cluster URL
export SOLANA_URL="http://YOUR_PUBLIC_IP:8899"
solana config set --url $SOLANA_URL

# Verify connection
solana cluster-version
solana slot

# Test token operations
spl-token create-token
```

---

## Monitoring & Maintenance

### Check Cluster Status

```bash
# List all validators
make list

# Monitor specific validator
make monitor NODE=bootstrap

# Monitor all validators
make monitor NODE=all

# View logs
tail -f logs/bootstrap.log
tail -f logs/validator-1.log
```

### Check Validator Health

```bash
# Health check
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'

# Get slot (should be advancing)
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}'

# Get cluster nodes
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq
```

### Stop Validators

```bash
# Stop all validators
make stop

# Stop specific validator
./scripts/stop-validator.sh bootstrap
./scripts/stop-validator.sh validator-1
```

### Restart Cluster

```bash
# Stop all
make stop

# Start cluster
make start-cluster
```

---

## Troubleshooting

### Validator Won't Start

**Symptoms:** Validator process dies immediately or fails to start

**Solutions:**
1. **Check system limits:**
   ```bash
   ulimit -Hn  # Should be 1000000
   ulimit -Sn  # Should be 1000000
   ```

2. **Check logs:**
   ```bash
   tail -50 logs/bootstrap.log | grep -E "ERROR|WARN|panic"
   ```

3. **Check ports:**
   ```bash
   ss -tuln | grep -E "8899|8001|8901"
   ```

4. **Verify genesis:**
   ```bash
   ls -la data/bootstrap/genesis.bin
   ```

### Genesis Mismatch Error

**Symptoms:** `Bank snapshot genesis creation time does not match genesis.bin`

**Solution:**
```bash
# Stop validators
make stop

# Clean validator data
rm -rf data/validator-1/*

# Copy fresh genesis
cp data/bootstrap/genesis.bin data/validator-1/

# Copy latest snapshot
LATEST_SNAPSHOT=$(find data/bootstrap -maxdepth 1 -name "snapshot-*.tar.zst" -type f | sort -r | head -1)
cp "$LATEST_SNAPSHOT" data/validator-1/

# Start validator
make start-validator NODE=validator-1
```

### Validator Not Joining Cluster

**Symptoms:** Only 1 node detected, validator-1 not visible

**Solutions:**
1. **Check vote account exists:**
   ```bash
   VALIDATOR1_VOTE=$(solana-keygen pubkey keys/vote/validator-1-vote.json)
   solana vote-account $VALIDATOR1_VOTE --url http://localhost:8899
   ```

2. **Create vote account if missing:**
   ```bash
   solana create-vote-account \
     keys/vote/validator-1-vote.json \
     keys/identity/validator-1-identity.json \
     keys/stake/validator-1-stake.json \
     --fee-payer keys/identity/validator-1-identity.json \
     --url http://localhost:8899
   ```

3. **Check entrypoint:**
   ```bash
   # Verify bootstrap is reachable
   curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
   ```

### Slot Stuck / Not Producing Blocks

**Symptoms:** Slot number doesn't advance

**Solutions:**
1. **Check validator logs:**
   ```bash
   tail -100 logs/bootstrap.log | grep -E "vote|leader|slot"
   ```

2. **Restart bootstrap:**
   ```bash
   make stop
   make start-bootstrap
   ```

3. **Check if vote account is voting:**
   ```bash
   solana vote-account <VOTE_ACCOUNT> --url http://localhost:8899
   ```

### Token Program Not Found

**Symptoms:** `spl-token create-token` fails with "Program not found"

**Solutions:**
1. **Verify programs are deployed:**
   ```bash
   solana program show TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA --url http://localhost:8899
   ```

2. **Deploy programs if missing:**
   ```bash
   make deploy-programs
   ```

3. **Recreate genesis with programs:**
   ```bash
   make stop
   rm -rf data/bootstrap/*
   make init-genesis
   make start-cluster
   ```

### External Access Not Working

**Symptoms:** Cannot connect from outside

**Solutions:**
1. **Verify RPC bind address:**
   ```bash
   grep RPC_BIND_ADDRESS configs/cluster.conf
   # Should be: RPC_BIND_ADDRESS="0.0.0.0"
   ```

2. **Check firewall rules** (Azure NSG, AWS Security Groups, etc.)

3. **Test locally first:**
   ```bash
   curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
   ```

4. **Test from external:**
   ```bash
   curl http://YOUR_PUBLIC_IP:8899 -X POST -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
   ```

---

## Quick Reference

### Essential Commands

```bash
# Setup
make setup-limits          # Configure system limits
make install              # Install Agave validator
make init-genesis         # Create genesis with programs

# Cluster Management
make start-cluster        # Start entire cluster
make start-bootstrap      # Start bootstrap only
make start-validator NODE=validator-1  # Start validator
make stop                 # Stop all validators
make list                 # List running validators

# Monitoring
make monitor              # Monitor cluster
tail -f logs/bootstrap.log  # View logs

# Programs
make setup-programs       # Download programs
make deploy-programs      # Deploy programs to cluster

# External Access
make setup-external IP=1.2.3.4  # Configure external access
```

### Key File Locations

```
keys/identity/           # Identity keypairs
keys/vote/               # Vote account keypairs
keys/stake/               # Stake account keypairs
data/bootstrap/           # Bootstrap ledger
data/validator-1/         # Validator-1 ledger
logs/                     # Log files
programs/                 # Program binaries
configs/cluster.conf      # Cluster configuration
configs/validator-*.conf  # Validator configurations
```

### Important Addresses

- **Bootstrap RPC:** `http://localhost:8899`
- **Bootstrap Gossip:** `127.0.0.1:8001`
- **Token Program:** `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA`
- **Token-2022:** `TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb`
- **Associated Token:** `ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL`
- **Metaplex Metadata:** `metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s`

---

## Next Steps

- [Production Deployment Guide](PRODUCTION-SETUP.md)
- [Programs Setup Guide](PROGRAMS-SETUP.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Architecture Documentation](../ARCHITECTURE.md)
