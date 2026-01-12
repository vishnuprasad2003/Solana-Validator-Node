# Multi-Bootstrap Cluster Setup

## ⚠️ IMPORTANT LIMITATION

**Agave validator 3.1.5 has a known issue**: A second bootstrap validator cannot start from the same genesis file, even with `--no-wait-for-vote-to-start-leader` and `--allow-private-addr` flags. The validator will fail with "failed to replay bank 0, did you forget to provide a snapshot".

**RECOMMENDED APPROACH**: Use the traditional single-bootstrap setup (see main README.md) where:
1. Bootstrap validator starts first and produces blocks
2. Additional validators join as regular validators after the bootstrap has produced snapshots

This document is kept for reference and future compatibility.

## Overview

In a multi-bootstrap setup, multiple validators are included as bootstrap validators in the genesis configuration. This approach would be ideal for:
- **Local testing** on the same machine
- **Private clusters** where all validators start together
- **Avoiding snapshot/entrypoint issues** for validators joining later

## How It Works

### Same Cluster Identity

Both validators belong to the **same private cluster** because:

1. **Same Genesis Hash**: Both validators use the exact same `genesis.bin` file
   - This gives them the same cluster ID
   - Same genesis hash = same cluster

2. **Same Cluster Configuration**: Both use `configs/cluster.conf`
   - Same network settings
   - Same cluster name and type

3. **Gossip Discovery**: Validators discover each other via gossip protocol
   - Bootstrap listens on port 8001 (gossip)
   - Validator-1 listens on port 8026 (gossip)
   - They exchange cluster information via gossip

4. **Known Validators**: Both validators know about each other
   - Bootstrap has validator-1 as `--known-validator`
   - Validator-1 has bootstrap as `--known-validator`
   - This speeds up initial connection

### Cluster Connectivity

```
┌─────────────────┐         ┌─────────────────┐
│  Bootstrap      │◄───────►│  Validator-1    │
│  Port: 8001     │ Gossip  │  Port: 8026     │
│  RPC: 8899      │         │  RPC: 8901      │
└─────────────────┘         └─────────────────┘
        │                            │
        └──────── Same Cluster ──────┘
        (Same genesis.bin)
```

## Setup Steps

### 1. Stop Current Bootstrap

```bash
make stop
```

### 2. Create Multi-Bootstrap Genesis

```bash
./scripts/init-genesis-multi-bootstrap.sh
```

This will:
- Generate validator-1 keys (if needed)
- Create genesis with **both** validators as bootstrap validators
- Set up validator-1's ledger directory

### 3. Start Bootstrap Validator

```bash
make start-bootstrap
```

### 4. Start Validator-1

```bash
make start-validator NODE=validator-1
```

## Verification

### Check Both Validators Are Running

```bash
make list
# Should show both bootstrap and validator-1
```

### Check Cluster Nodes

```bash
curl -X POST http://localhost:8899 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}'
```

Should show both validators in the cluster.

### Check Slots Are Advancing

```bash
# Bootstrap
curl -X POST http://localhost:8899 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}'

# Validator-1
curl -X POST http://localhost:8901 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}'
```

Both should show the same or very close slot numbers.

## Advantages

✅ **No Entrypoint Issues**: Both validators start independently  
✅ **No Snapshot Needed**: Both start from genesis  
✅ **Faster Startup**: No waiting for snapshots or downloads  
✅ **Same Cluster**: Guaranteed same cluster via shared genesis  
✅ **Automatic Discovery**: Gossip protocol connects them  

## How They Connect

1. **Gossip Protocol**: Both validators broadcast their presence on their gossip ports
2. **Known Validators**: `--known-validator` flags help initial discovery
3. **Cluster Info Exchange**: Validators exchange cluster information via gossip
4. **Consensus**: Both vote on the same chain (same genesis hash)

## Network Ports

| Validator | Gossip (UDP/TCP) | RPC (TCP) | Dynamic Range |
|-----------|------------------|-----------|---------------|
| Bootstrap | 8001 | 8899 | 8000-8025 |
| Validator-1 | 8026 | 8901 | 8030-8055 |

## Troubleshooting

### Validators Not Connecting

1. Check both are running: `make list`
2. Check gossip ports are open: `ss -tuln | grep -E "8001|8026"`
3. Check logs for connection errors: `tail -f logs/bootstrap.log` and `tail -f logs/validator-1.log`

### Different Slot Numbers

- Small differences (< 10 slots) are normal
- Large differences indicate connectivity issues
- Check network connectivity between validators

### Genesis Hash Mismatch

If validators have different genesis hashes, they're in different clusters:
- Verify both use the same `genesis.bin` file
- Regenerate genesis if needed: `./scripts/init-genesis-multi-bootstrap.sh`

## Production Considerations

For production deployments:
- Use actual IP addresses or hostnames (not localhost)
- Configure firewall rules for gossip ports
- Use `--known-validator` for all validators in the cluster
- Monitor cluster connectivity via `getClusterNodes` RPC call
