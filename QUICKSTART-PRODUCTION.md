# Production-Grade Quick Start Guide

## Standard Single-Bootstrap Pattern (Recommended)

This is the **production-grade approach** used by companies for private Solana clusters.

### Step 1: Initialize Genesis (Single Bootstrap)

```bash
make init-genesis
```

This creates a genesis with **one bootstrap validator** (the standard pattern).

### Step 2: Start Cluster (Automated)

```bash
make start-cluster
```

This script will:
1. Start bootstrap validator
2. Wait for snapshots to be generated
3. Start additional validators automatically

### Step 3: Manual Startup (Alternative)

If you prefer manual control:

```bash
# 1. Start bootstrap
make start-bootstrap

# 2. Wait for snapshots (check periodically)
ls -la data/bootstrap/snapshots/*.tar.zst

# 3. Start validators (they will copy snapshots automatically)
make start-validator NODE=validator-1
make start-validator NODE=validator-2
```

### Verify Cluster

```bash
# Check all validators are running
make list

# Check cluster nodes
curl http://localhost:8899 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq

# Check slots
curl http://localhost:8899 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}'
```

## Why This Works

- ✅ **Standard Pattern**: Matches how Solana mainnet/testnet/devnet work
- ✅ **Reliable**: Single bootstrap ensures deterministic startup
- ✅ **Scalable**: Easy to add/remove validators
- ✅ **Production-Proven**: Used by companies worldwide

## Troubleshooting

If validators fail to start:
1. Ensure bootstrap is running: `ps aux | grep agave-validator`
2. Check snapshots exist: `ls -la data/bootstrap/snapshots/`
3. Check logs: `tail -f logs/validator-1.log`

See `docs/PRODUCTION-SETUP.md` for detailed documentation.
