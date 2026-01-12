# Production Deployment Checklist

Complete checklist for production deployment on Azure VM, Docker, or Kubernetes.

## Pre-Deployment

### System Requirements

- [ ] **VM/Node Specs**:
  - CPU: 8+ cores (16+ recommended)
  - RAM: 16GB+ (32GB+ recommended)
  - Storage: 500GB+ SSD (1TB+ recommended)
  - Network: Low latency, high bandwidth

- [ ] **System Limits**:
  - File descriptors: 1,000,000+
  - Memory lock: unlimited
  - Configured via: `sudo ./scripts/configure-limits.sh`

- [ ] **Network**:
  - Static public IP (Azure VM)
  - Firewall rules configured (see below)
  - DNS (optional, for hostname resolution)

### Azure VM Specific

- [ ] VM created with sufficient resources
- [ ] Static public IP assigned
- [ ] Network Security Group configured
- [ ] SSH access configured
- [ ] Storage account for backups (optional)

### Kubernetes Specific

- [ ] Cluster created and accessible
- [ ] kubectl configured
- [ ] Storage class configured
- [ ] Container registry access
- [ ] Image pull secrets (if private registry)

## Deployment Steps

### 1. Initial Setup

- [ ] Clone/copy repository to deployment environment
- [ ] Configure system limits (`sudo make setup-limits`)
- [ ] Log out and log back in (for limits to take effect)
- [ ] Install Agave validator (`make install`)

### 2. Genesis & Keys

- [ ] Initialize genesis (`make init-genesis`)
- [ ] Backup genesis file (`data/bootstrap/genesis.bin`)
- [ ] Backup all keys (`keys/` directory)
- [ ] Store backups securely (encrypted, off-site)

### 3. Multi-Node Setup (if applicable)

- [ ] Initialize multi-node cluster (`make init-multi-node NUM=X`)
- [ ] Verify node configurations created
- [ ] Verify unique ports for each validator

### 4. External Access

- [ ] Set public IP (`export PUBLIC_IP=<ip>`)
- [ ] Configure external access (`make setup-external`)
- [ ] Verify `BOOTSTRAP_VALIDATOR_IP` in `configs/cluster.conf`
- [ ] Configure firewall rules (see below)

### 5. Start Cluster

**Option A: Direct VM**
- [ ] Start bootstrap validator (`make start-bootstrap`)
- [ ] Verify bootstrap is running (`make monitor`)
- [ ] Start additional validators (`make start-validator NODE=X`)

**Option B: Docker**
- [ ] Build image (`make build-docker`)
- [ ] Start cluster (`make docker-up`)
- [ ] Verify all containers running (`docker ps`)

**Option C: Kubernetes**
- [ ] Build and push image (`REGISTRY=X make build-docker`)
- [ ] Update image in manifests
- [ ] Deploy (`make deploy-k8s`)
- [ ] Verify pods running (`make k8s-status`)

## Firewall Configuration

### Azure Network Security Group Rules

| Name | Priority | Source | Protocol | Port Range | Action |
|------|----------|--------|----------|------------|--------|
| Solana-Gossip-UDP | 100 | Any | UDP | 8001 | Allow |
| Solana-Gossip-TCP | 101 | Any | TCP | 8001 | Allow |
| Solana-RPC | 102 | Any | TCP | 8899 | Allow |
| Solana-RPC-WS | 103 | Any | TCP | 8900 | Allow |
| Solana-Dynamic | 104 | Any | UDP | 8000-8025 | Allow |

**For Production**: Restrict RPC ports (8899, 8900) to trusted IPs only.

### Additional Validators

Add similar rules for each validator's ports:
- Validator-1: 8002 (UDP/TCP), 8901 (TCP)
- Validator-2: 8003 (UDP/TCP), 8903 (TCP)
- etc.

## Verification

### Cluster Health

- [ ] Bootstrap validator running (`make list`)
- [ ] RPC responding (`curl http://<ip>:8899 -X POST -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'`)
- [ ] Validators connected (check logs for gossip connections)
- [ ] Slots advancing (`solana slot --url $SOLANA_URL`)

### External Access

- [ ] Can connect from external client
- [ ] RPC calls work (`solana cluster-version`)
- [ ] Can query accounts (`solana balance <address>`)
- [ ] Can submit transactions

### SPL Programs

- [ ] Token program available (`make deploy-spl`)
- [ ] Token-2022 program available
- [ ] Associated Token program available
- [ ] Can create token mints
- [ ] Can mint and transfer tokens

### Functionality Tests

- [ ] Create token mint: `spl-token create-token`
- [ ] Create token account: `spl-token create-account <mint>`
- [ ] Mint tokens: `spl-token mint <mint> 1000`
- [ ] Transfer tokens: `spl-token transfer <mint> 100 <recipient>`
- [ ] Deploy custom program: `solana program deploy <program.so>`
- [ ] Transfer SOL: `solana transfer <address> 10`

## Monitoring & Maintenance

### Logging

- [ ] Log rotation configured (`configs/logrotate.conf`)
- [ ] Logs accessible (`logs/` directory)
- [ ] Log aggregation set up (optional: ELK, Loki, etc.)

### Monitoring

- [ ] Metrics endpoint accessible (`http://<ip>:9090/metrics`)
- [ ] Health checks configured (Docker/K8s)
- [ ] Alerting set up (optional: Prometheus + Alertmanager)

### Backups

- [ ] Backup strategy defined
- [ ] Keys backed up securely
- [ ] Genesis file backed up
- [ ] Regular ledger snapshots (automatic via validator config)

## Security

### Access Control

- [ ] SSH keys configured (no password auth)
- [ ] Firewall restricts RPC to trusted IPs (production)
- [ ] Keys stored securely (encrypted, access-controlled)
- [ ] No keys committed to git (verify `.gitignore`)

### Updates

- [ ] Update strategy defined
- [ ] Test updates in staging first
- [ ] Rollback plan prepared

## Post-Deployment

- [ ] Documentation updated with actual IPs/endpoints
- [ ] Team trained on operations
- [ ] Runbook created for common issues
- [ ] Monitoring dashboards configured
- [ ] Backup verification tested

## Troubleshooting

### Validator Not Starting

1. Check system limits: `ulimit -Hn` (should be 1000000+)
2. Check logs: `tail -f logs/bootstrap.log`
3. Verify ports: `ss -tuln | grep 8899`
4. Check disk space: `df -h`

### External Access Not Working

1. Verify public IP in config: `grep BOOTSTRAP_VALIDATOR_IP configs/cluster.conf`
2. Check firewall rules (Azure NSG)
3. Verify RPC_BIND_ADDRESS is 0.0.0.0
4. Test from VM: `curl http://localhost:8899`
5. Test from external: `curl http://<public-ip>:8899`

### Validators Not Connecting

1. Verify bootstrap is running first
2. Check ENTRYPOINT_HOST/PORT in validator configs
3. Verify network connectivity (ping, telnet)
4. Check firewall allows gossip ports (UDP)
5. Review validator logs for connection errors

## Support

For issues:
1. Check logs: `logs/bootstrap.log`, `logs/validator-*.log`
2. Run diagnostics: `make verify-setup`
3. Check monitoring: `make monitor`
4. Review [DEPLOYMENT.md](DEPLOYMENT.md) troubleshooting section
