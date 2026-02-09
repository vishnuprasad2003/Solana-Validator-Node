# Solana Private Validator Cluster

A private Solana blockchain cluster with bootstrap validator, additional validators, and centralized configuration.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                  Solana Private Cluster                │
│                                                        │
│  ┌──────────────┐       ┌──────────────┐              │
│  │  Bootstrap    │◄─────►│  Validator-1  │              │
│  │  (Port 8899)  │ gossip│  (Port 8901)  │              │
│  └──────────────┘       └──────────────┘              │
│                                                        │
│  Genesis → Block Production → Gossip → Consensus       │
└──────────────────────────────────────────────────────┘
```

- **Bootstrap** — Creates genesis, produces initial blocks, serves as gossip entry point
- **Validator-1** — Joins cluster via bootstrap, syncs ledger, votes on blocks
- Both expose full RPC API for querying and submitting transactions

## Directory Layout

```
Solana-Validator-Node/              ← this repo (scripts + config, small)
├── configs/
│   ├── bootstrap.conf              ← bootstrap validator config
│   └── validator-1.conf            ← additional validator config
├── programs/                       ← SPL program .so files (for genesis)
│   ├── spl_token.so
│   ├── spl_token_2022.so
│   ├── spl_associated_token_account.so
│   └── mpl_token_metadata.so
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── systemd/
│   └── solana-validator@.service
├── scripts/
│   ├── common.sh
│   ├── install.sh
│   ├── gen-keys.sh
│   ├── init-genesis.sh
│   ├── setup-genesis-programs.sh
│   ├── create-vote-account.sh
│   ├── start-validator.sh
│   ├── stop-validator.sh
│   ├── get-faucet-private-key.sh
│   ├── upgrade.sh
│   └── docker-entrypoint.sh
├── Makefile
└── README.md

/solana/                            ← runtime storage (BASE_DIR)
├── data/
│   ├── bootstrap/                  ← bootstrap ledger (large)
│   └── validator-1/                ← validator-1 ledger (large)
├── logs/
│   ├── bootstrap.log
│   └── validator-1.log
├── keys/
│   ├── bootstrap-identity.json
│   ├── bootstrap-vote.json
│   ├── bootstrap-stake.json
│   ├── faucet.json
│   ├── faucet.txt                  ← faucet pubkey + genesis hash
│   ├── validator-1-identity.json
│   ├── validator-1-vote.json
│   └── validator-1-stake.json
├── pids/
│   ├── bootstrap.pid
│   └── validator-1.pid
├── programs/                       ← copied SPL programs
└── backups/
```

All runtime data lives under `BASE_DIR` (`/solana` by default). Change `BASE_DIR` in each config to relocate.

## Prerequisites

| Tool | Purpose |
|------|---------|
| Solana CLI | `solana`, `solana-keygen`, `solana-genesis` |
| Agave Validator | `agave-validator` (block production + consensus) |
| jq | JSON processing |
| curl | RPC health checks |

**System requirements:**
```bash
# File descriptor + memory lock limits (required)
sudo bash -c 'cat >> /etc/security/limits.conf <<EOF
* soft nofile 1000000
* hard nofile 1000000
* soft memlock unlimited
* hard memlock unlimited
EOF'
# Logout and login for limits to take effect
```

## Complete Setup Guide

### Step 1 — Install Solana & Agave

```bash
make install
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
# Add the above line to ~/.bashrc

solana --version
agave-validator --version
```

### Step 2 — Initialise Storage

```bash
make init
```

### Step 3 — Generate Keys & Create Genesis (Bootstrap)

```bash
make gen-keys-bootstrap
make init-genesis
# Note the genesis hash and bootstrap identity from the output
```

### Step 4 — Start Bootstrap Validator

```bash
make start-bootstrap
# Wait for RPC to be ready
```

### Step 5 — Configure Solana CLI

```bash
solana config set --keypair /solana/keys/faucet.json --url http://localhost:8899
solana balance    # Should show ~1 billion SOL
cat /solana/keys/faucet.txt    # Genesis hash + bootstrap identity
```

### Step 6 — Add Validator-1

Update `configs/validator-1.conf` with values from Step 3:
- `KNOWN_VALIDATOR` → bootstrap identity pubkey
- `EXPECTED_GENESIS_HASH` → genesis hash

```bash
# Generate keys
make gen-keys-validator-1

# Fund validator identity
IDENTITY=$(solana-keygen pubkey /solana/keys/validator-1-identity.json)
solana transfer $IDENTITY 1000 --allow-unfunded-recipient

# Create vote account
make create-vote-account

# Start validator
make start-validator-1
```

### Step 7 — Verify

```bash
make status
make logs

# Check cluster nodes (should show 2)
curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq '.result | length'

# Check slot progression
solana get-slot
```

## Make Targets

```
Setup:
  make install                Install Solana CLI & Agave
  make init                   Create storage directories
  make gen-keys-bootstrap     Generate bootstrap keypairs
  make gen-keys-validator-1   Generate validator-1 keypairs
  make init-genesis           Create genesis block
  make create-vote-account    Create vote account for validator-1

Operations:
  make start-bootstrap / stop-bootstrap
  make start-validator-1 / stop-validator-1
  make start-all / stop-all

Logs:
  make logs                   Last 30 lines of all logs
  make logs-bootstrap / logs-validator-1   (tail -f)

Utilities:
  make faucet-private-key     Get faucet key in base58
  make status                 Versions + process status

Maintenance:
  make upgrade                Backup → update → verify
  make upgrade-check          Check versions
  make backup                 Create backup
  make clean                  Wipe data, logs, keys, pids

Docker:
  make build / docker-up / docker-down
```

## Configuration

Each config file has `BASE_DIR` at the top. All paths derive from it:

| Variable | Description |
|----------|-------------|
| `BASE_DIR` | Root storage directory (default `/solana`) |
| `NODE_NAME` | Node identifier |
| `NODE_TYPE` | `bootstrap` or `validator` |
| `GOSSIP_PORT` | Gossip protocol port |
| `RPC_PORT` | JSON-RPC port |
| `ENTRYPOINT` | Bootstrap gossip address (validators only) |
| `KNOWN_VALIDATOR` | Bootstrap identity pubkey (validators only) |
| `EXPECTED_GENESIS_HASH` | Genesis hash (validators only) |
| `LIMIT_LEDGER_SIZE` | Shreds to keep (50M ≈ 2-3 days) |

### Port Planning

| Node | Gossip | RPC | Dynamic Range |
|------|--------|-----|---------------|
| bootstrap | 8001 | 8899 | 8000-8025 |
| validator-1 | 8026 | 8901 | 8030-8055 |

## Storage & Disk Usage

| Location | Contents | Expected Size |
|----------|----------|---------------|
| `data/bootstrap/` | Ledger database (RocksDB) | 20-100+ GB |
| `data/validator-1/` | Ledger database | 20-100+ GB |
| `logs/` | Validator logs | Grows over time |
| `keys/` | Keypairs | < 1 KB each |

**Controlling disk growth:**
- Set `LIMIT_LEDGER_SIZE=50000000` (≈ 100-150 GB ≈ 2-3 days)
- Set to `"unlimited"` to keep all history (disk fills quickly)

## Systemd Services (Auto-Restart)

For production, use systemd to auto-restart validators on failure or reboot.

```bash
# Copy service file
sudo cp systemd/solana-validator@.service /etc/systemd/system/
sudo systemctl daemon-reload

# Enable and start bootstrap
sudo systemctl enable solana-validator@bootstrap.service
sudo systemctl start solana-validator@bootstrap.service

# Enable and start validator-1
sudo systemctl enable solana-validator@validator-1.service
sudo systemctl start solana-validator@validator-1.service

# Check status
sudo systemctl status solana-validator@bootstrap.service

# View logs
sudo journalctl -u solana-validator@bootstrap.service -f

# Restart
sudo systemctl restart solana-validator@bootstrap.service
```

> **Note:** When using systemd, use `systemctl` commands instead of `make start-*` / `make stop-*`.

## Upgrading

```bash
make upgrade-check     # check versions
make upgrade           # backup → stop → update → verify
./scripts/upgrade.sh rollback /solana/backups/<timestamp>   # rollback
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Validator won't start | Check keys exist: `ls /solana/keys/` |
| RPC not responding | `make logs-bootstrap` to check errors |
| Validator not joining | Verify `ENTRYPOINT`, `KNOWN_VALIDATOR`, `EXPECTED_GENESIS_HASH` |
| Disk space growing | Set `LIMIT_LEDGER_SIZE=50000000` and restart |
| `ulimit` errors | Set file descriptor limits (see Prerequisites) |
| Snapshot errors | Stop validator, `rm -rf /solana/data/<node>/snapshots`, restart |
