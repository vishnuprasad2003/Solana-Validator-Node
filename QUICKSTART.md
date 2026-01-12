# Quick Start Guide

Get your private Solana cluster running in minutes!

## Prerequisites

- Linux (Ubuntu 20.04+ recommended)
- sudo access (for system limits)
- Internet connection (to download programs)

## 5-Minute Setup

### Step 1: Configure System Limits

```bash
sudo make setup-limits
# Log out and log back in for limits to take effect
```

### Step 2: Install Tools

```bash
make install
```

This installs:
- Agave validator
- Solana CLI tools
- SPL Token CLI

### Step 3: Create Genesis

```bash
make init-genesis
```

**What this does:**
- Generates bootstrap validator keypairs
- Creates faucet account
- Downloads SPL & Metaplex programs from mainnet
- Creates genesis with all programs included

### Step 4: Start Cluster

```bash
make start-cluster
```

**What this does:**
- Starts bootstrap validator
- Waits for snapshots (~2-3 minutes)
- Starts validator-1
- Verifies cluster status

### Step 5: Verify & Test

```bash
# Check cluster nodes
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq

# Test token creation
spl-token create-token --url http://localhost:8899
```

## That's It! 🎉

Your cluster is now running with:
- ✅ Bootstrap validator (RPC: 8899)
- ✅ Validator-1 (RPC: 8901)
- ✅ SPL Token programs ready
- ✅ Metaplex programs ready

## Next Steps

- **Add more validators:** See [Adding Validators Guide](docs/ADDING-VALIDATORS.md)
- **External access:** See [Complete Setup Guide](docs/COMPLETE-SETUP-GUIDE.md#external-access)
- **Token operations:** See [Complete Setup Guide](docs/COMPLETE-SETUP-GUIDE.md#token-operations)

## Common Commands

```bash
# Start cluster
make start-cluster

# Stop cluster
make stop

# List validators
make list

# Monitor cluster
make monitor

# View logs
tail -f logs/bootstrap.log
```

## Troubleshooting

**Validator won't start?**
- Check system limits: `ulimit -Hn` (should be 1000000)
- Check logs: `tail -f logs/bootstrap.log`

**Programs not found?**
- Programs are included in genesis automatically
- If missing, run: `make deploy-programs`

**Need help?**
- See [Complete Setup Guide](docs/COMPLETE-SETUP-GUIDE.md)
- See [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
