# Production Deployment Guide

This guide covers production-grade deployment practices for the Solana Validator Node.

## Prerequisites

- Ubuntu 22.04 LTS (or compatible Linux distribution)
- Minimum 8GB RAM (16GB+ recommended for production)
- 100GB+ disk space (SSD recommended)
- Static IP address
- Firewall configured
- SSL/TLS certificates (if exposing RPC publicly)

## Pre-Deployment Checklist

- [ ] System updated: `sudo apt update && sudo apt upgrade -y`
- [ ] Firewall configured: `sudo ./firewall-setup.sh`
- [ ] Security setup: `sudo ./security-setup.sh`
- [ ] IP whitelist configured (if exposing RPC)
- [ ] Systemd service installed: `sudo systemd/install-service.sh`
- [ ] Auto-start enabled: `sudo systemctl enable solana-validator`
- [ ] Monitoring configured
- [ ] Backup strategy in place

## Installation

### 1. Clone and Install

```bash
git clone <your-repo-url>
cd Solana-Validator-Node
chmod +x *.sh systemd/*.sh
./install.sh
source ~/.bashrc
```

### 2. Configure Validator

```bash
# Single node
./setup-validator.sh

# Or multi-node cluster
./setup-cluster.sh  # First node
./setup-validator.sh
```

### 3. Security Configuration

```bash
# Configure firewall
sudo ./firewall-setup.sh

# Configure IP whitelist
sudo ./security-setup.sh
# Edit ~/solana-security-config/allowed-ips.txt
# Add trusted IPs, one per line
sudo ./security-setup.sh  # Apply changes
```

### 4. Install Systemd Service

```bash
sudo systemd/install-service.sh
sudo systemctl start solana-validator
sudo systemctl enable solana-validator
```

### 5. Verify Installation

```bash
./verify-setup.sh
```

## Network Configuration

### Firewall Rules

**Required Ports**:
- `8899/tcp` - RPC/HTTP API
- `9900/tcp` - Faucet (for local development)
- `8001/udp` - Gossip (for multi-node)

**Security Best Practices**:
- Restrict RPC port (8899) to trusted IPs only
- Use VPN for remote access
- Enable SSH key-based authentication
- Disable password authentication for SSH

### IP Whitelist

Edit `~/solana-security-config/allowed-ips.txt`:
```
192.168.1.100
10.0.0.50
```

Apply: `sudo ./security-setup.sh`

## Monitoring

### Health Checks

```bash
# Check process
pgrep -f solana-test-validator

# Check RPC
curl http://127.0.0.1:8899

# Check cluster version
solana cluster-version --url http://127.0.0.1:8899

# Check slot
solana slot --url http://127.0.0.1:8899
```

### Log Monitoring

**Systemd**:
```bash
sudo journalctl -u solana-validator -f
sudo journalctl -u solana-validator --since today
```

**Direct Logs**:
```bash
# Solana test validator logs to stdout/stderr
# Check systemd journal or tmux session
```

### Automated Monitoring

```bash
# Continuous monitoring
./monitor.sh

# Or use maintenance script
./maintenance.sh
```

## Backup Strategy

### Data Backup

```bash
# Stop validator
sudo systemctl stop solana-validator

# Create backup
tar -czf solana-backup-$(date +%Y%m%d).tar.gz ~/solana-local-ledger

# Restart validator
sudo systemctl start solana-validator
```

### Automated Backups

Create a cron job:
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/backup-script.sh
```

### Backup Script Example

```bash
#!/bin/bash
BACKUP_DIR="$HOME/solana-backups"
mkdir -p "$BACKUP_DIR"
sudo systemctl stop solana-validator
tar -czf "$BACKUP_DIR/solana-backup-$(date +%Y%m%d).tar.gz" ~/solana-local-ledger
sudo systemctl start solana-validator
# Keep only last 30 days
find "$BACKUP_DIR" -name "solana-backup-*.tar.gz" -mtime +30 -delete
```

## Upgrades

### Upgrade Process

```bash
# 1. Backup current installation
sudo systemctl stop solana-validator
tar -czf backup-$(date +%Y%m%d).tar.gz ~/solana-local-ledger

# 2. Run upgrade script
./upgrade-solana.sh

# 3. Check VERSION_COMPATIBILITY.md for program compatibility
cat VERSION_COMPATIBILITY.md

# 4. Restart validator
sudo systemctl start solana-validator

# 5. Verify
./verify-setup.sh
```

### Post-Upgrade Checklist

- [ ] Validator starts successfully
- [ ] RPC endpoint responding
- [ ] Programs compile and deploy correctly
- [ ] Check VERSION_COMPATIBILITY.md for updated program versions
- [ ] Update Solana Interactor dependencies if needed
- [ ] Test API interactions

## Multi-Node Production Setup

### Bootstrap Node (First Node)

```bash
./setup-cluster.sh
./setup-validator.sh
sudo ./security-setup.sh
sudo systemd/install-service.sh
sudo systemctl start solana-validator
sudo systemctl enable solana-validator
```

### Additional Validators

```bash
# On each additional node
./add-validator.sh  # Enter bootstrap node IP and identity
./setup-validator.sh
sudo ./security-setup.sh
sudo systemd/install-service.sh
sudo systemctl start solana-validator
sudo systemctl enable solana-validator
```

### Network Requirements

- All nodes must be able to reach each other on gossip port (8001/udp)
- Firewall rules must allow P2P communication
- Bootstrap node IP must be accessible from all validators

## Maintenance

### Regular Tasks

**Daily**:
- Monitor logs for errors
- Check disk space: `df -h ~/solana-local-ledger`
- Verify validator is running: `pgrep -f solana-test-validator`

**Weekly**:
- Review disk usage
- Check performance metrics
- Verify backups

**Monthly**:
- Full data backup
- Security audit
- Update system packages
- Review and rotate logs

### Maintenance Script

```bash
./maintenance.sh
```

Interactive menu for:
- Health checks
- Log viewing
- Disk usage
- Network status
- Backup creation
- Validator restart

## Troubleshooting

### Validator Won't Start

1. Check logs: `sudo journalctl -u solana-validator -n 50`
2. Check port availability: `sudo lsof -i :8899`
3. Check disk space: `df -h`
4. Verify Rust/Solana installation: `solana --version`

### RPC Not Responding

1. Wait 10-30 seconds after start
2. Check validator is running: `pgrep -f solana-test-validator`
3. Test RPC: `curl http://127.0.0.1:8899`
4. Check firewall: `sudo ufw status`

### High Disk Usage

1. Check size: `du -sh ~/solana-local-ledger`
2. Review ledger size limits
3. Consider increasing disk space
4. Use `--limit-ledger-size` flag

### Program Deployment Issues

1. Check Solana version: `solana --version`
2. Check Anchor version: `anchor --version`
3. Verify program compatibility: `cat VERSION_COMPATIBILITY.md`
4. Rebuild programs: `anchor build`
5. Check program logs

## Security Best Practices

1. **Firewall**: Restrict RPC access to trusted IPs only
2. **SSH**: Use key-based authentication, disable passwords
3. **Updates**: Keep system and Solana CLI updated
4. **Monitoring**: Monitor logs and access patterns
5. **Backups**: Regular encrypted backups
6. **Access Control**: Use VPN for remote access
7. **Secrets**: Never commit private keys or wallet files

## Scaling

### Horizontal Scaling

Add more validator nodes using the multi-node setup process.

### Vertical Scaling

- Increase RAM for better performance
- Use SSD for faster I/O
- Optimize ledger size limits
- Tune validator parameters

## Support

For issues:
1. Check logs: `journalctl -u solana-validator` or `tmux attach -t solana-validator`
2. Review health: `./verify-setup.sh`
3. Check configuration: `config.env` and validator config
4. Review documentation: `README.md` and troubleshooting sections

