# Adding Validator Nodes to Existing Cluster

This guide explains how to add new validator nodes to an existing Solana private cluster.

## Prerequisites

- Bootstrap validator is running and producing blocks
- Bootstrap has produced at least one snapshot (slot 400+)
- Essential programs are deployed (Token, Token-2022, Associated Token, Metaplex)

## Quick Steps

```bash
# 1. Create validator configuration
cp configs/node.conf.template configs/validator-N.conf
# Edit configs/validator-N.conf with unique ports

# 2. Start validator (automatically handles everything)
make start-validator NODE=validator-N
```

## Detailed Step-by-Step Guide

### Step 1: Create Validator Configuration

Create a new configuration file for your validator:

```bash
# Copy template
cp configs/node.conf.template configs/validator-2.conf

# Edit the configuration
nano configs/validator-2.conf
```

**Required Configuration:**

```bash
# Validator identification
NODE_NAME="validator-2"

# Network ports (MUST be unique, not overlapping with other validators)
NODE_GOSSIP_PORT=8027          # Unique gossip port
NODE_RPC_PORT=8902             # Unique RPC port
NODE_TPU_PORT=8056            # Unique TPU port
NODE_TPU_FORWARD_PORT=8057    # Unique TPU forward port
NODE_METRICS_PORT=9092        # Unique metrics port

# Dynamic port range (needs 25 consecutive ports)
NODE_DYNAMIC_PORT_RANGE_START=8056
NODE_DYNAMIC_PORT_RANGE_END=8081

# Bootstrap connection (for joining existing cluster)
BOOTSTRAP_VALIDATOR_IP="127.0.0.1"  # Use public IP if external
BOOTSTRAP_VALIDATOR_GOSSIP_PORT=8001
ENTRYPOINT_HOST="127.0.0.1"         # Bootstrap gossip address
ENTRYPOINT_PORT=8001
```

**Port Planning:**

| Validator | Gossip | RPC | TPU | TPU Forward | Metrics | Dynamic Range |
|-----------|--------|-----|-----|-------------|---------|---------------|
| Bootstrap | 8001   | 8899| 8003| 8004        | 9090    | 8000-8025     |
| Validator-1| 8026  | 8901| 8032| 8033        | 9091    | 8030-8055     |
| Validator-2| 8027  | 8902| 8056| 8057        | 9092    | 8056-8081     |
| Validator-3| 8028  | 8903| 8082| 8083        | 9093    | 8082-8107     |

### Step 2: Generate Validator Keypairs

Keypairs are automatically generated when starting the validator, but you can pre-generate:

```bash
# Generate identity keypair
solana-keygen new \
  --outfile keys/identity/validator-2-identity.json \
  --no-bip39-passphrase

# Generate vote account keypair
solana-keygen new \
  --outfile keys/vote/validator-2-vote.json \
  --no-bip39-passphrase

# Generate stake account keypair
solana-keygen new \
  --outfile keys/stake/validator-2-stake.json \
  --no-bip39-passphrase

# Get public keys
echo "Identity: $(solana-keygen pubkey keys/identity/validator-2-identity.json)"
echo "Vote: $(solana-keygen pubkey keys/vote/validator-2-vote.json)"
echo "Stake: $(solana-keygen pubkey keys/stake/validator-2-stake.json)"
```

**Save these public keys** - you'll need them for vote account creation.

### Step 3: Fund Validator Identity Account

The validator needs SOL to pay for transactions (vote account creation, etc.):

```bash
VALIDATOR2_IDENTITY=$(solana-keygen pubkey keys/identity/validator-2-identity.json)

# Transfer SOL from faucet
solana transfer $VALIDATOR2_IDENTITY 10 \
  --allow-unfunded-recipient \
  --keypair keys/identity/faucet.json \
  --url http://localhost:8899

# Verify balance
solana balance $VALIDATOR2_IDENTITY --url http://localhost:8899
```

### Step 4: Create Vote Account

Validators need a vote account to participate in consensus:

```bash
# Create vote account
solana create-vote-account \
  keys/vote/validator-2-vote.json \
  keys/identity/validator-2-identity.json \
  keys/stake/validator-2-stake.json \
  --fee-payer keys/identity/validator-2-identity.json \
  --url http://localhost:8899

# Verify vote account was created
VALIDATOR2_VOTE=$(solana-keygen pubkey keys/vote/validator-2-vote.json)
solana vote-account $VALIDATOR2_VOTE --url http://localhost:8899
```

**Expected output:**
```
Vote Account: Cn52Ls73HKXbEFJ6PQcmRRFMzBj4nxGnSP3G6MVDAUi2
...
```

### Step 5: Prepare Validator Data Directory

The validator needs genesis and a snapshot to start:

```bash
# Create validator data directory
mkdir -p data/validator-2

# Clean any existing data
rm -rf data/validator-2/*

# Copy genesis from bootstrap (MUST match)
cp data/bootstrap/genesis.bin data/validator-2/

# Wait for bootstrap to produce a snapshot
# Snapshots are created at slots 400, 800, 1200, etc.
LATEST_SNAPSHOT=$(find data/bootstrap -maxdepth 1 -name "snapshot-*.tar.zst" -type f 2>/dev/null | sort -r | head -1)

if [ -n "$LATEST_SNAPSHOT" ] && [ -f "$LATEST_SNAPSHOT" ]; then
    echo "Found snapshot: $(basename $LATEST_SNAPSHOT)"
    cp "$LATEST_SNAPSHOT" data/validator-2/
    echo "Snapshot copied to data/validator-2/"
else
    echo "ERROR: No snapshot found. Bootstrap must produce snapshots first."
    echo "Wait for bootstrap to reach slot 400+ and check:"
    echo "  ls -la data/bootstrap/snapshot-*.tar.zst"
    exit 1
fi
```

### Step 6: Start the Validator

Use the automated script (recommended):

```bash
# Start validator-2
make start-validator NODE=validator-2
```

**Or manually:**

```bash
./scripts/start-validator.sh validator-2
```

**What the script does:**
1. Validates prerequisites
2. Checks keypairs exist
3. Verifies bootstrap is reachable
4. Copies genesis (if needed)
5. Cleans old data (snapshots, blockstore, accounts)
6. Copies latest snapshot
7. Starts validator with correct flags:
   - `--entrypoint` (bootstrap gossip address)
   - `--known-validator` (bootstrap identity)
   - `--allow-private-addr` (for local clusters)

### Step 7: Verify Validator Joined

```bash
# Check cluster nodes (should include validator-2)
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq

# Check validator-2 RPC is responding
curl http://localhost:8902 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq

# Check validator-2 is syncing
curl http://localhost:8902 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq -r '.result'
```

**Expected:** Validator-2 should appear in `getClusterNodes` and its slot should be catching up to bootstrap.

### Step 8: Monitor Validator

```bash
# View validator logs
tail -f logs/validator-2.log

# Monitor validator status
make monitor NODE=validator-2

# Check if validator is voting
VALIDATOR2_VOTE=$(solana-keygen pubkey keys/vote/validator-2-vote.json)
solana vote-account $VALIDATOR2_VOTE --url http://localhost:8899
```

---

## Adding Multiple Validators

To add multiple validators, repeat the process for each:

```bash
# Validator-2
make start-validator NODE=validator-2

# Wait a bit for validator-2 to sync
sleep 30

# Validator-3
make start-validator NODE=validator-3

# Validator-4
make start-validator NODE=validator-4
```

**Important:** Ensure each validator has:
- Unique ports (no overlaps)
- Unique configuration file (`configs/validator-N.conf`)
- Unique keypairs
- Vote account created

---

## Automated Multi-Validator Setup

You can configure multiple validators in `configs/cluster.conf`:

```bash
# In configs/cluster.conf or start-cluster.sh
VALIDATORS_TO_START="validator-1 validator-2 validator-3"
```

Then use:

```bash
make start-cluster
```

This will:
1. Start bootstrap
2. Wait for snapshots
3. Start all configured validators sequentially

---

## Troubleshooting

### Validator Not Joining

**Check:**
1. Vote account exists:
   ```bash
   solana vote-account <VOTE_PUBKEY> --url http://localhost:8899
   ```

2. Bootstrap is reachable:
   ```bash
   curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
   ```

3. Snapshot exists:
   ```bash
   ls -la data/bootstrap/snapshot-*.tar.zst
   ```

4. Genesis matches:
   ```bash
   sha256sum data/bootstrap/genesis.bin data/validator-2/genesis.bin
   # Should match
   ```

### Port Conflicts

**Error:** `Port XXXX is already in use`

**Solution:** Update `configs/validator-N.conf` with different ports.

### Genesis Mismatch

**Error:** `Bank snapshot genesis creation time does not match genesis.bin`

**Solution:**
```bash
# Clean validator data
rm -rf data/validator-2/*

# Copy fresh genesis
cp data/bootstrap/genesis.bin data/validator-2/

# Copy latest snapshot
LATEST_SNAPSHOT=$(find data/bootstrap -maxdepth 1 -name "snapshot-*.tar.zst" -type f | sort -r | head -1)
cp "$LATEST_SNAPSHOT" data/validator-2/

# Restart validator
make start-validator NODE=validator-2
```

### Validator Stuck at Old Slot

**Symptoms:** Validator slot doesn't advance

**Solution:**
```bash
# Stop validator
./scripts/stop-validator.sh validator-2

# Clean blockstore
rm -rf data/validator-2/rocksdb

# Restart
make start-validator NODE=validator-2
```

---

## Best Practices

1. **Port Planning:** Plan ports in advance to avoid conflicts
2. **Vote Accounts:** Create vote accounts before starting validators
3. **Snapshots:** Always wait for bootstrap to produce snapshots
4. **Genesis Sync:** Ensure all validators use the same genesis
5. **Monitoring:** Monitor validators after adding to ensure they sync
6. **Staggered Addition:** Add validators one at a time, wait for sync before adding next

---

## Quick Reference

```bash
# Add validator-2
make start-validator NODE=validator-2

# Check cluster
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq

# Monitor
make monitor NODE=validator-2

# Stop validator
./scripts/stop-validator.sh validator-2
```
