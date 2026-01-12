# Production-Grade Private Solana Cluster Setup

## Root Cause Analysis

### Why Multi-Bootstrap Fails

The error "failed to replay bank 0, did you forget to provide a snapshot" occurs because:

1. **Blockstore State Conflict**: When validator-1 starts, it may have a `rocksdb` directory from previous attempts. Even with a fresh genesis.bin, the validator tries to process existing blockstore data and fails.

2. **Agave Validator Limitation**: Agave validator 3.1.5 has a strict requirement that when processing a blockstore, it needs either:
   - A clean genesis (no existing blockstore)
   - A valid snapshot to bootstrap from
   - The validator cannot start as a second bootstrap from the same genesis if there's any blockstore state

3. **Genesis Processing**: The validator processes slot 0 (genesis bank) but fails during replay, likely because:
   - The blockstore has conflicting state
   - The validator expects a snapshot for non-bootstrap validators
   - Multi-bootstrap validators need to start simultaneously with clean state

### Why Companies Don't Use Multi-Bootstrap

**Production Reality**: Companies use the **single-bootstrap pattern** because:

1. **Reliability**: Single bootstrap ensures deterministic cluster initialization
2. **Snapshot-Based Joining**: Additional validators join using snapshots, which is the standard Solana pattern
3. **Scalability**: Easy to add/remove validators without regenerating genesis
4. **Proven Pattern**: This is how Solana mainnet, testnet, and devnet work
5. **Operational Simplicity**: One bootstrap validator is easier to manage and troubleshoot

## Production-Grade Solution

### Architecture Pattern

```
┌─────────────────────────────────────────────────────────┐
│                    Private Solana Cluster                │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐         ┌──────────────┐             │
│  │  Bootstrap   │◄────────│ Validator-1  │             │
│  │  Validator   │  Entry  │  (Regular)  │             │
│  │  (Primary)   │  Point  │              │             │
│  │              │         │              │             │
│  │  Port: 8001  │         │  Port: 8026  │             │
│  │  RPC: 8899   │         │  RPC: 8901   │             │
│  │              │         │              │             │
│  │  Programs:   │         │              │             │
│  │  • Token     │         │              │             │
│  │  • Token-2022│         │              │             │
│  │  • ATA       │         │              │             │
│  │  • Metaplex  │         │              │             │
│  └──────────────┘         └──────────────┘             │
│         │                         │                     │
│         └────── Gossip Protocol ──┘                     │
│                                                          │
│  ┌──────────────┐         ┌──────────────┐             │
│  │ Validator-2  │         │ Validator-N  │             │
│  │  (Regular)   │         │  (Regular)   │             │
│  └──────────────┘         └──────────────┘             │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Setup Steps

#### 1. Initialize Single-Bootstrap Genesis

```bash
# Create genesis with ONLY bootstrap validator
make init-genesis
# Or: ./scripts/init-genesis.sh
```

This creates a genesis with:
- One bootstrap validator (the primary)
- Faucet account
- **SPL Token Program** (automatically downloaded and included at standard address)
- **SPL Token-2022 Program** (automatically downloaded and included)
- **Associated Token Account Program** (automatically downloaded and included)
- **Metaplex Token Metadata Program** (automatically downloaded and included)

All programs are included at their standard mainnet addresses!

#### 2. Start Bootstrap Validator

```bash
make start-bootstrap
```

The bootstrap validator will:
- Start from genesis (slot 0)
- Produce blocks immediately (with `--no-wait-for-vote-to-start-leader`)
- Generate snapshots periodically (every 400 slots by default)

#### 3. Wait for Snapshots

```bash
# Check if snapshots are being created
ls -la data/bootstrap/snapshots/

# Wait until you see snapshot files (tar.zst format)
# Or check via RPC:
curl -X POST http://localhost:8899 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHighestSnapshotSlot"}'
```

**Important**: Wait until the bootstrap has produced at least one snapshot before starting additional validators.

#### 4. Start Additional Validators

```bash
# Generate keys for validator-1 (if not already done)
./scripts/gen-keys.sh validator-1 all

# Start validator-1 (it will automatically copy snapshot from bootstrap)
make start-validator NODE=validator-1
```

The validator startup script will:
1. Check if genesis exists in validator ledger
2. If not, copy genesis from bootstrap
3. Check if snapshot exists
4. If not, copy snapshot from bootstrap
5. Start validator with entrypoint pointing to bootstrap

### Key Configuration

#### Bootstrap Validator (`start-bootstrap.sh`)

```bash
agave-validator \
  --identity <bootstrap-identity> \
  --vote-account <bootstrap-vote> \
  --ledger <bootstrap-ledger> \
  --gossip-port 8001 \
  --rpc-port 8899 \
  --no-wait-for-vote-to-start-leader \  # Critical for single-node
  --allow-private-addr \                  # Allow private IPs
  --full-snapshot-interval-slots 400 \    # Generate snapshots frequently
  --known-validator <validator-1-pubkey>  # Help discovery
```

#### Additional Validator (`start-validator.sh`)

```bash
agave-validator \
  --identity <validator-1-identity> \
  --vote-account <validator-1-vote> \
  --ledger <validator-1-ledger> \
  --gossip-port 8026 \
  --rpc-port 8901 \
  --entrypoint localhost:8001 \           # Point to bootstrap
  --known-validator <bootstrap-pubkey> \ # Trust bootstrap
  --full-rpc-api
```

### Why This Works

1. **Clean State**: Bootstrap starts with clean genesis, no conflicts
2. **Snapshot-Based**: Additional validators use snapshots (standard Solana pattern)
3. **Entrypoint**: Validators connect to bootstrap via entrypoint (proven mechanism)
4. **Gossip Discovery**: Once connected, validators discover each other via gossip
5. **Scalable**: Easy to add more validators without changing genesis

### Production Best Practices

#### 1. Snapshot Management

```bash
# Configure snapshot interval (in cluster.conf)
FULL_SNAPSHOT_INTERVAL_SLOTS=400  # Generate snapshots every 400 slots

# For production, consider:
FULL_SNAPSHOT_INTERVAL_SLOTS=100  # More frequent snapshots for faster joining
```

#### 2. Validator Startup Sequence

```bash
# 1. Start bootstrap
make start-bootstrap

# 2. Wait for bootstrap to be ready (check RPC)
curl http://localhost:8899 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}'

# 3. Wait for snapshot (check snapshots directory)
while [ ! -f data/bootstrap/snapshots/*.tar.zst ]; do
  echo "Waiting for snapshot..."
  sleep 5
done

# 4. Start additional validators
make start-validator NODE=validator-1
make start-validator NODE=validator-2
```

#### 3. Health Checks

```bash
# Check all validators are running
make list

# Check cluster nodes
curl http://localhost:8899 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq

# Check slots are advancing
curl http://localhost:8899 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}'
```

#### 4. Network Configuration

For production (not localhost):

```bash
# In configs/cluster.conf
BOOTSTRAP_VALIDATOR_IP="<bootstrap-public-ip>"
BOOTSTRAP_VALIDATOR_GOSSIP_PORT=8001

# In configs/validator-1.conf
ENTRYPOINT_HOST="<bootstrap-public-ip>"
ENTRYPOINT_PORT=8001
```

#### 5. Firewall Rules

```bash
# Bootstrap validator needs:
# - Gossip port (UDP/TCP): 8001
# - RPC port (TCP): 8899
# - Dynamic port range (UDP): 8000-8025

# Additional validators need:
# - Gossip port (UDP/TCP): 8026, 8031, etc.
# - RPC port (TCP): 8901, 8902, etc.
# - Dynamic port range (UDP): 8030-8055, etc.
```

### Troubleshooting

#### Validator Fails to Start

1. **Check bootstrap is running**: `ps aux | grep agave-validator`
2. **Check snapshot exists**: `ls -la data/bootstrap/snapshots/`
3. **Check entrypoint connectivity**: `nc -zv <bootstrap-ip> 8001`
4. **Check logs**: `tail -f logs/validator-1.log`

#### Validators Not Connecting

1. **Verify entrypoint**: Check `ENTRYPOINT_HOST` and `ENTRYPOINT_PORT` in config
2. **Check firewall**: Ensure gossip ports are open
3. **Verify known-validator**: Check bootstrap pubkey is correct
4. **Check network**: Validators must be on same network or have network access

#### Slot Mismatch

- Small differences (< 10 slots) are normal
- Large differences indicate connectivity issues
- Check gossip connectivity between validators

### Comparison: Multi-Bootstrap vs Single-Bootstrap

| Aspect | Multi-Bootstrap | Single-Bootstrap (Production) |
|--------|----------------|-------------------------------|
| **Genesis** | Multiple bootstrap validators | Single bootstrap validator |
| **Startup** | All start simultaneously | Sequential (bootstrap first) |
| **Snapshots** | Not needed (theoretical) | Required for additional validators |
| **Entrypoint** | Not needed (theoretical) | Required for additional validators |
| **Reliability** | ❌ Fails with Agave 3.1.5 | ✅ Proven and stable |
| **Scalability** | Limited | ✅ Easy to add/remove validators |
| **Production Use** | ❌ Not recommended | ✅ Standard pattern |

### Conclusion

**Use the single-bootstrap pattern** for production:
- ✅ Proven and reliable
- ✅ Standard Solana pattern
- ✅ Easy to scale
- ✅ Works with current Agave validator
- ✅ Matches how companies deploy private clusters

The multi-bootstrap approach is theoretically elegant but has implementation limitations in current Agave validator versions.
