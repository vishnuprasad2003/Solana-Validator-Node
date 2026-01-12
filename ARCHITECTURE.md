# Architecture Overview

This document explains the architecture and design decisions of the production-grade Solana validator cluster setup.

## Design Principles

1. **Modularity**: Clear separation of concerns (configs, scripts, data, keys)
2. **Scalability**: Easy to add nodes, works on single machine or across VMs
3. **Production-Ready**: Best practices for logging, monitoring, and resource management
4. **Environment-Driven**: Configuration adapts to deployment environment
5. **Maintainability**: Well-documented, standardized structure

## Directory Structure

```
Solana-Validator-Node/
├── configs/              # Configuration layer
│   ├── cluster.conf      # Cluster-wide settings (single source of truth)
│   ├── node.conf.template # Template for node-specific overrides
│   └── logrotate.conf    # Log rotation configuration
│
├── scripts/              # Automation layer
│   ├── common.sh         # Shared utilities and functions
│   ├── install.sh        # Installation/upgrade automation
│   ├── init-genesis.sh   # Genesis initialization
│   ├── start-*.sh        # Validator lifecycle management
│   ├── stop-validator.sh # Graceful shutdown
│   ├── list-validators.sh # Status monitoring
│   ├── gen-keys.sh       # Key management
│   ├── monitor.sh        # Health monitoring
│   └── verify-setup.sh   # Setup validation
│
├── keys/                 # Security layer (gitignored)
│   ├── identity/         # Validator identity keys
│   ├── vote/             # Vote account keys
│   └── stake/            # Stake account keys
│
├── data/                 # Runtime data (gitignored)
│   ├── bootstrap/        # Bootstrap validator ledger
│   └── validator/       # Additional validator ledgers
│
├── logs/                 # Logging (gitignored)
│   └── *.log            # Rotated log files
│
└── systemd/             # Service integration
    └── *.service.template # Systemd service templates
```

## Configuration Hierarchy

```
cluster.conf (base)
    ↓
node.conf (overrides for specific node)
    ↓
Environment variables (runtime overrides)
    ↓
Final validator configuration
```

## Component Architecture

### Bootstrap Validator

```
┌─────────────────────────────────────┐
│   Bootstrap Validator               │
│                                     │
│  ┌──────────┐  ┌──────────┐       │
│  │ Identity │  │   Vote   │       │
│  │   Key    │  │   Key    │       │
│  └──────────┘  └──────────┘       │
│                                     │
│  Ports:                             │
│  • Gossip: 8001 (UDP/TCP)          │
│  • RPC: 8899 (HTTP)                 │
│  • TPU: 8003 (UDP)                  │
│  • Metrics: 9090 (HTTP)             │
│                                     │
│  Ledger: data/bootstrap/            │
└─────────────────────────────────────┘
            │
            │ Entrypoint
            │
            ▼
```

### Additional Validators

```
┌─────────────────────────────────────┐
│   Validator N                      │
│                                     │
│  ┌──────────┐  ┌──────────┐       │
│  │ Identity │  │   Vote   │       │
│  │   Key    │  │   Key    │       │
│  └──────────┘  └──────────┘       │
│                                     │
│  Entrypoint: bootstrap:8001        │
│                                     │
│  Ports:                             │
│  • Gossip: 800N (unique)           │
│  • RPC: 889N (unique)              │
│  • TPU: 800N+2 (unique)            │
│                                     │
│  Ledger: data/validator/N/         │
└─────────────────────────────────────┘
```

## Network Topology

### Single Machine (Multiple Validators)

```
┌─────────────────────────────────────────────┐
│           Single Machine                    │
│                                             │
│  Bootstrap (8001) ──┐                       │
│                     │                       │
│  Validator-1 (8002) ┼── Gossip Network      │
│                     │                       │
│  Validator-2 (8003) ┘                       │
│                                             │
└─────────────────────────────────────────────┘
```

### Multi-Machine (VM Deployment)

```
┌──────────────┐      ┌──────────────┐
│   Machine 1  │      │   Machine 2  │
│              │      │              │
│  Bootstrap   │◄─────┤ Validator-1  │
│  (10.0.1.10) │      │ (10.0.1.11)  │
│              │      │              │
└──────────────┘      └──────────────┘
       │                     │
       │                     │
       └──────────┬──────────┘
                  │
         ┌────────▼────────┐
         │  Gossip Network │
         │  (UDP/TCP)      │
         └─────────────────┘
```

## Data Flow

### Genesis Initialization

```
init-genesis.sh
    │
    ├── Generate keys (identity, vote, stake, faucet)
    │
    ├── Create genesis.bin
    │   └── Bootstrap validator configuration
    │   └── Initial token distribution
    │   └── Faucet setup
    │
    └── Store in data/bootstrap/
```

### Validator Startup

```
start-bootstrap.sh / start-validator.sh
    │
    ├── Validate prerequisites
    │   ├── Check Agave installed
    │   ├── Check genesis exists
    │   ├── Check keys exist
    │   └── Check ports available
    │
    ├── Build validator command
    │   ├── Load configuration
    │   ├── Set network ports
    │   ├── Configure performance flags
    │   └── Enable logging/metrics
    │
    ├── Start validator process
    │   └── Background execution
    │   └── Save PID
    │
    └── Wait for readiness
        └── Health check via RPC
```

### Logging Flow

```
Validator Process
    │
    ├── stdout/stderr
    │   └── Redirected to log file
    │
    └── logs/<node-name>.log
        │
        ├── Real-time: tail -f
        ├── Rotation: logrotate (daily/size-based)
        └── Compression: gzip (old logs)
```

## Key Management

### Key Types

1. **Identity Key**: Validator's unique identifier
   - Used for signing blocks and transactions
   - Must be kept secure
   - Location: `keys/identity/<node>-identity.json`

2. **Vote Key**: Vote account keypair
   - Used for consensus voting
   - Can be different from identity key
   - Location: `keys/vote/<node>-vote.json`

3. **Stake Key**: Stake account keypair
   - Used for staking SOL
   - Delegates to vote account
   - Location: `keys/stake/<node>-stake.json`

### Key Generation Flow

```
gen-keys.sh <node-name> <type>
    │
    ├── Check if key exists
    │   └── Skip if exists (or force)
    │
    ├── Generate using solana-keygen
    │   └── No BIP39 passphrase (for automation)
    │
    └── Validate and display pubkey
```

## Scaling Strategy

### Horizontal Scaling (Add Nodes)

1. **Generate keys** for new node
2. **Create node config** (optional, for custom ports)
3. **Start validator** pointing to bootstrap entrypoint
4. **Validator syncs** ledger from cluster
5. **Validator joins** gossip network
6. **Validator participates** in consensus

### Vertical Scaling (Single Node)

1. **Increase resources** (CPU, RAM, disk)
2. **Tune configuration** in `cluster.conf`:
   - `ACCOUNTS_DB_CACHE_SIZE_MB`
   - `VALIDATOR_MEMORY_LIMIT_MB`
   - `SNAPSHOT_INTERVAL_SLOTS`
3. **Monitor performance** via metrics endpoint

## Security Considerations

1. **Key Protection**:
   - Keys are gitignored
   - Should be backed up securely
   - Use file permissions (600)

2. **Network Security**:
   - RPC can be bound to localhost
   - Use firewall rules for public deployments
   - Consider VPN for multi-machine clusters

3. **Process Isolation**:
   - Each validator runs as separate process
   - Can use systemd for additional isolation
   - Resource limits via systemd/cgroups

## Monitoring & Observability

### Metrics

- **Prometheus endpoint**: `http://localhost:9090/metrics`
- **RPC health**: `getHealth` JSON-RPC method
- **Slot tracking**: `getSlot` JSON-RPC method
- **Epoch info**: `getEpochInfo` JSON-RPC method

### Logging

- **Structured logs**: JSON format (via RUST_LOG)
- **Log levels**: error, warn, info, debug, trace
- **Rotation**: Automatic via logrotate
- **Retention**: Configurable (default 10 files)

### Health Checks

```bash
# Script-based
./scripts/monitor.sh [node-name]

# Direct RPC
curl -X POST http://localhost:8899 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
```

## Deployment Patterns

### Development (Local)

- Single bootstrap validator
- All components on one machine
- Default ports
- Full logging enabled

### Testing (Multi-Node Local)

- Bootstrap + 2-3 validators
- All on same machine
- Unique ports per validator
- Full monitoring

### Production (VM-Based)

- Bootstrap on dedicated VM
- Additional validators on separate VMs
- Firewall rules configured
- Systemd services
- Centralized logging (optional)

## Future Enhancements

Potential improvements:

1. **Orchestration**: Kubernetes/Docker Compose support
2. **Backup Automation**: Automated snapshot/backup scripts
3. **Alerting**: Integration with Prometheus Alertmanager
4. **Dashboard**: Grafana dashboards for visualization
5. **Multi-Region**: Support for geographically distributed clusters
