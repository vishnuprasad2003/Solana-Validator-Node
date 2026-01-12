# Troubleshooting Guide

Common issues and solutions for the Solana private cluster setup.

## Table of Contents

1. [Validator Startup Issues](#validator-startup-issues)
2. [Genesis & Snapshot Issues](#genesis--snapshot-issues)
3. [Cluster Consensus Issues](#cluster-consensus-issues)
4. [Token Program Issues](#token-program-issues)
5. [Network & Connectivity Issues](#network--connectivity-issues)
6. [Performance Issues](#performance-issues)

---

## Validator Startup Issues

### Validator Process Dies Immediately

**Symptoms:**
- Validator starts but exits immediately
- No error messages in logs
- PID file created but process not running

**Solutions:**

1. **Check system limits:**
   ```bash
   ulimit -Hn  # Should be 1000000
   ulimit -Sn  # Should be 1000000
   ```
   If not, run `sudo make setup-limits` and logout/login.

2. **Check logs:**
   ```bash
   tail -50 logs/bootstrap.log | grep -E "ERROR|panic|fatal"
   ```

3. **Check ports:**
   ```bash
   ss -tuln | grep -E "8899|8001|8901"
   ```
   Ensure ports are not already in use.

4. **Verify genesis exists:**
   ```bash
   ls -la data/bootstrap/genesis.bin
   ```

### Port Already in Use

**Error:** `Port XXXX is already in use`

**Solution:**
```bash
# Find process using port
sudo lsof -i :8899

# Kill process or use different port
# Update configs/cluster.conf or configs/validator-N.conf
```

### Insufficient File Descriptors

**Error:** `Too many open files` or validator crashes

**Solution:**
```bash
# Check current limits
ulimit -Hn
ulimit -Sn

# Configure limits
sudo make setup-limits

# Logout and login again
# Or restart shell session
```

---

## Genesis & Snapshot Issues

### Genesis Hash Mismatch

**Error:** `Bank snapshot genesis creation time does not match genesis.bin creation time`

**Cause:** Validator has old genesis/snapshot from previous cluster

**Solution:**
```bash
# Stop validator
./scripts/stop-validator.sh validator-1

# Clean validator data completely
rm -rf data/validator-1/*

# Copy fresh genesis from bootstrap
cp data/bootstrap/genesis.bin data/validator-1/

# Copy latest snapshot
LATEST_SNAPSHOT=$(find data/bootstrap -maxdepth 1 -name "snapshot-*.tar.zst" -type f | sort -r | head -1)
if [ -n "$LATEST_SNAPSHOT" ]; then
    cp "$LATEST_SNAPSHOT" data/validator-1/
fi

# Restart validator
make start-validator NODE=validator-1
```

### Failed to Replay Bank 0

**Error:** `failed to replay bank 0, did you forget to provide a snapshot`

**Cause:** Validator needs a snapshot to start, but doesn't have one

**Solution:**
```bash
# Ensure bootstrap has produced snapshots
ls -la data/bootstrap/snapshot-*.tar.zst

# If no snapshots, wait for bootstrap to reach slot 400+
# Check bootstrap slot:
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq

# Copy snapshot to validator
LATEST_SNAPSHOT=$(find data/bootstrap -maxdepth 1 -name "snapshot-*.tar.zst" -type f | sort -r | head -1)
cp "$LATEST_SNAPSHOT" data/validator-1/

# Clean blockstore
rm -rf data/validator-1/rocksdb

# Restart validator
make start-validator NODE=validator-1
```

### Snapshot Not Found

**Error:** Script waits for snapshot but times out

**Solution:**
```bash
# Check if bootstrap is producing blocks
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq

# Check bootstrap logs
tail -f logs/bootstrap.log | grep -E "slot|snapshot|ERROR"

# Manually check for snapshots
find data/bootstrap -name "snapshot-*.tar.zst" -type f

# If bootstrap is stuck, restart it
make stop
make start-bootstrap
```

---

## Cluster Consensus Issues

### Validator Not Joining Cluster

**Symptoms:**
- Only 1 node detected in `getClusterNodes`
- Validator-1 not visible
- Validator logs show connection issues

**Solutions:**

1. **Check vote account exists:**
   ```bash
   VALIDATOR1_VOTE=$(solana-keygen pubkey keys/vote/validator-1-vote.json)
   solana vote-account $VALIDATOR1_VOTE --url http://localhost:8899
   ```

2. **Create vote account if missing:**
   ```bash
   # Fund validator identity first
   VALIDATOR1_IDENTITY=$(solana-keygen pubkey keys/identity/validator-1-identity.json)
   solana transfer $VALIDATOR1_IDENTITY 10 \
     --allow-unfunded-recipient \
     --keypair keys/identity/faucet.json \
     --url http://localhost:8899
   
   # Create vote account
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
   
   # Check gossip port
   nc -zv localhost 8001
   ```

4. **Check validator logs:**
   ```bash
   tail -50 logs/validator-1.log | grep -E "entrypoint|gossip|ERROR|WARN"
   ```

### Slot Stuck / Not Producing Blocks

**Symptoms:**
- Slot number doesn't advance
- RPC reports same slot repeatedly
- Validators stuck at old slots

**Solutions:**

1. **Check bootstrap logs:**
   ```bash
   tail -100 logs/bootstrap.log | grep -E "vote|leader|slot|ERROR"
   ```

2. **Check if vote account is voting:**
   ```bash
   solana vote-account <VOTE_ACCOUNT> --url http://localhost:8899
   ```

3. **Restart bootstrap:**
   ```bash
   make stop
   make start-bootstrap
   ```

4. **Check for fork:**
   ```bash
   # Compare slots from different validators
   curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq
   curl http://localhost:8901 -X POST -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq
   ```

### FailedSwitchThreshold Error

**Error:** `FailedSwitchThreshold` in logs

**Cause:** Validator can't reach stake threshold to vote

**Solution:**
- Ensure vote account exists and is funded
- Ensure validator has stake delegated
- Wait for cluster to stabilize

---

## Token Program Issues

### Program Not Found

**Error:** `spl-token create-token` fails with "Program not found"

**Solutions:**

1. **Verify programs are deployed:**
   ```bash
   solana program show TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
     --url http://localhost:8899
   ```

2. **Check if programs are in genesis:**
   ```bash
   # Programs should be included automatically during genesis creation
   # If missing, recreate genesis:
   make stop
   rm -rf data/bootstrap/*
   make init-genesis
   make start-cluster
   ```

3. **Deploy programs manually:**
   ```bash
   make deploy-programs
   ```

### Token Creation Fails - Account Not Found

**Error:** `Attempt to debit an account but found no record of a prior credit`

**Cause:** Your wallet doesn't have SOL

**Solution:**
```bash
# Fund your wallet
YOUR_WALLET=$(solana address)
solana transfer $YOUR_WALLET 10 \
  --allow-unfunded-recipient \
  --keypair keys/identity/faucet.json \
  --url http://localhost:8899

# Verify balance
solana balance $YOUR_WALLET --url http://localhost:8899
```

### Token Operations Not Working

**Symptoms:** Token commands fail even with funded wallet

**Solutions:**

1. **Verify Token program exists:**
   ```bash
   curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
     -d '{
       "jsonrpc": "2.0",
       "id": 1,
       "method": "getAccountInfo",
       "params": [
         "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
         {"encoding": "base64"}
       ]
     }' | jq -r '.result.value.owner // "Not found"'
   ```

2. **Check cluster is producing blocks:**
   ```bash
   # Slots should be advancing
   curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq
   ```

3. **Recreate genesis with programs:**
   ```bash
   make stop
   rm -rf data/bootstrap/*
   make init-genesis  # Will include programs
   make start-cluster
   ```

---

## Network & Connectivity Issues

### External Access Not Working

**Symptoms:** Cannot connect from outside the VM/server

**Solutions:**

1. **Verify RPC bind address:**
   ```bash
   grep RPC_BIND_ADDRESS configs/cluster.conf
   # Should be: RPC_BIND_ADDRESS="0.0.0.0"
   ```

2. **Check firewall rules:**
   ```bash
   # Azure Network Security Group
   # AWS Security Groups
   # Local firewall (ufw/iptables)
   
   # Test locally first
   curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
   
   # Test from external
   curl http://YOUR_PUBLIC_IP:8899 -X POST -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
   ```

3. **Configure external access:**
   ```bash
   export PUBLIC_IP="your.public.ip"
   ./scripts/setup-external-access.sh
   ```

4. **Check validator is listening on 0.0.0.0:**
   ```bash
   ss -tuln | grep 8899
   # Should show: 0.0.0.0:8899
   ```

### Validators Not Discovering Each Other

**Symptoms:** Each validator only sees itself in cluster

**Solutions:**

1. **Check entrypoint:**
   ```bash
   # Validator should have --entrypoint flag
   ps aux | grep agave-validator | grep entrypoint
   ```

2. **Verify bootstrap gossip port:**
   ```bash
   nc -zv localhost 8001
   ```

3. **Check known-validator flag:**
   ```bash
   ps aux | grep agave-validator | grep known-validator
   ```

4. **Verify allow-private-addr flag:**
   ```bash
   ps aux | grep agave-validator | grep allow-private-addr
   ```

### Invalid Entrypoint Address

**Error:** `invalid entrypoint address`

**Solution:**
```bash
# Ensure entrypoint is correct in config
grep ENTRYPOINT configs/validator-1.conf

# Should be bootstrap's gossip address
# For local: localhost:8001
# For external: PUBLIC_IP:8001
```

---

## Performance Issues

### High CPU Usage

**Symptoms:** Validator using 100% CPU

**Solutions:**

1. **Check if validator is syncing:**
   ```bash
   # Validator catching up uses more CPU
   # Wait for it to sync
   ```

2. **Reduce account index:**
   ```bash
   # In configs/cluster.conf
   ACCOUNT_INDEX_INCLUDE_KEY=false
   ACCOUNT_INDEX_INCLUDE_OWNER=false
   ```

3. **Adjust cache size:**
   ```bash
   # Reduce if low memory
   ACCOUNTS_DB_CACHE_SIZE_MB=1024
   ```

### High Memory Usage

**Symptoms:** Validator using excessive RAM

**Solutions:**

1. **Reduce cache size:**
   ```bash
   # In configs/cluster.conf
   ACCOUNTS_DB_CACHE_SIZE_MB=1024  # Default: 2048
   ```

2. **Limit ledger size:**
   ```bash
   # Already configured in start scripts
   --limit-ledger-size 50000000
   ```

3. **Check for memory leaks:**
   ```bash
   # Monitor memory over time
   watch -n 5 'ps aux | grep agave-validator | awk "{print \$6/1024\" MB\"}"'
   ```

### Slow Block Production

**Symptoms:** Slots advancing slowly

**Solutions:**

1. **Check system resources:**
   ```bash
   htop  # Check CPU, RAM, I/O
   ```

2. **Verify validator is leader:**
   ```bash
   # Bootstrap should be producing blocks
   tail -f logs/bootstrap.log | grep "leader"
   ```

3. **Check network:**
   ```bash
   # Ensure validators can communicate
   ping <validator-ip>
   ```

---

## Quick Diagnostic Commands

```bash
# Check cluster health
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'

# Check slots
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | jq

# Check cluster nodes
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq

# Check running validators
ps aux | grep agave-validator | grep -v grep

# Check ports
ss -tuln | grep -E "8899|8001|8901"

# Check logs
tail -50 logs/bootstrap.log | grep -E "ERROR|WARN|panic"

# Check system limits
ulimit -Hn
ulimit -Sn

# Check disk space
df -h

# Check memory
free -h
```

---

## Still Having Issues?

1. **Check logs:** `tail -f logs/bootstrap.log`
2. **Review documentation:** [Complete Setup Guide](COMPLETE-SETUP-GUIDE.md)
3. **Verify configuration:** `cat configs/cluster.conf`
4. **Check system resources:** `htop`, `df -h`, `free -h`

---

## Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `Port XXXX is already in use` | Port conflict | Use different port in config |
| `failed to replay bank 0` | Missing snapshot | Copy snapshot from bootstrap |
| `Genesis hash mismatch` | Old genesis | Copy fresh genesis |
| `Vote account does not exist` | Vote account not created | Create vote account |
| `Program not found` | Programs not deployed | Run `make deploy-programs` |
| `Account not found` | Wallet not funded | Transfer SOL from faucet |
| `Too many open files` | Low file descriptor limit | Run `sudo make setup-limits` |
