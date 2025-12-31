# Operations Manual

This guide covers day-to-day operations for maintaining the Solana production cluster.

## Daily Operations

### Checking Cluster Status

**Quick health check:**

```bash
./scripts/monitor.sh
```

This checks:
- Validator process status
- RPC endpoint responsiveness
- Disk usage
- Ledger size
- Current slot

**Detailed status:**

```bash
# Check validator process
pgrep -f solana-test-validator

# Check RPC
curl http://localhost:8899 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'

# Get current slot
solana slot --url http://localhost:8899

# Check validator status
./scripts/monitor.sh
```

### Starting the Validator

**If using systemd (recommended):**

```bash
sudo systemctl start solana-validator
sudo systemctl status solana-validator
```

**If running manually:**

```bash
./scripts/start-validator.sh
```

### Stopping the Validator

**If using systemd:**

```bash
sudo systemctl stop solana-validator
```

**If running manually:**

```bash
./scripts/stop-validator.sh
```

**Important:** Always use the stop script - never kill the process directly, as it may corrupt the ledger.


## Monitoring

### Health Monitoring

Run periodic health checks:

```bash
# Manual check
./scripts/monitor.sh

# Add to crontab for automated checks (every 5 minutes)
*/5 * * * * /home/user/Solana-Validator-Node/scripts/monitor.sh
```

### Resource Monitoring

**CPU and Memory:**

```bash
top -p $(pgrep -f solana-test-validator)
```

**Disk Usage:**

```bash
# Overall disk usage
df -h

# Ledger directory size
du -sh ~/solana-ledger

# Detailed breakdown
du -h --max-depth=1 ~/solana-ledger | sort -h
```

**Network:**

```bash
# Network connections
sudo netstat -tulpn | grep solana

# Network traffic
sudo iftop -i eth0
```

### RPC Monitoring

**Test RPC endpoint:**

```bash
# Health check
curl http://localhost:8899 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'

# Get version
curl http://localhost:8899 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getVersion"}'

# Get slot
solana slot --url http://localhost:8899
```

## Backup Procedures

### Automated Backups

Backups are automatically created during upgrades. Manual backup:

```bash
# Create backup directory
mkdir -p ~/solana-backups

# Backup ledger
tar -czf ~/solana-backups/ledger-$(date +%Y%m%d-%H%M%S).tar.gz ~/solana-ledger

# Backup configuration
tar -czf ~/solana-backups/config-$(date +%Y%m%d-%H%M%S).tar.gz \
  ~/.config/solana \
  Solana-Validator-Node/configs/
```

### Backup Strategy

**Recommended schedule:**

- **Daily**: Configuration backups
- **Weekly**: Full ledger backup (if space allows)
- **Before upgrades**: Always backup

**Backup retention:**

Configured in `config.env`:
```bash
BACKUP_RETENTION_DAYS=30
```

Clean up old backups:

```bash
find ~/solana-backups -type f -mtime +30 -delete
```

### Restoring from Backup

```bash
# Stop validator
./scripts/stop-validator.sh

# Restore ledger
tar -xzf ~/solana-backups/ledger-YYYYMMDD-HHMMSS.tar.gz -C ~/

# Restore configuration
tar -xzf ~/solana-backups/config-YYYYMMDD-HHMMSS.tar.gz -C ~/

# Start validator
./scripts/start-validator.sh
```

## Maintenance Tasks

### Weekly Maintenance

1. **Check disk space:**
   ```bash
   df -h
   du -sh ~/solana-ledger
   ```

2. **Review logs for errors:**
   ```bash
   ./scripts/monitor.sh
   ```

3. **Verify RPC accessibility:**
   ```bash
   ./scripts/verify-setup.sh
   ```

4. **Check system resources:**
   ```bash
   ./scripts/monitor.sh
   ```

### Monthly Maintenance

1. **Update system packages:**
   ```bash
   sudo apt-get update
   sudo apt-get upgrade -y
   ```

2. **Review and clean backups:**
   ```bash
   ls -lh ~/solana-backups/
   find ~/solana-backups -type f -mtime +30 -delete
   ```

3. **Check ledger size and cleanup if needed:**
   ```bash
   du -sh ~/solana-ledger
   ```

4. **Review firewall rules:**
   ```bash
   sudo ufw status verbose
   ```

## Common Operations

### Restarting the Validator

```bash
# Stop
sudo systemctl stop solana-validator

# Wait a few seconds
sleep 5

# Start
sudo systemctl start solana-validator

# Verify
sudo systemctl status solana-validator
```

### Changing Configuration

1. **Edit configuration:**
   ```bash
   nano configs/config.env
   ```

2. **Restart validator:**
   ```bash
   sudo systemctl restart solana-validator
   ```

3. **Verify changes:**
   ```bash
   ./scripts/verify-setup.sh
   ```

### Adding IP to Whitelist

1. **Edit whitelist file:**
   ```bash
   nano ~/solana-security-config/allowed-ips.txt
   ```

2. **Reconfigure networking:**
   ```bash
   ./scripts/configure-networking.sh
   ```

3. **Restart validator (if needed):**
   ```bash
   sudo systemctl restart solana-validator
   ```

## Performance Tuning

### Increasing RPC Threads

Edit `configs/config.env` and add to validator startup (if needed):

```bash
# In start-validator.sh, add:
--rpc-threads 8
```

### Adjusting Ledger Size Limit

Edit `configs/config.env`:

```bash
MAX_LEDGER_SIZE_GB=1000  # Increase if you have more disk space
```

### Network Optimization

For multi-node clusters, ensure:
- Low latency between nodes
- Sufficient bandwidth
- Proper firewall rules for gossip port

## Troubleshooting Common Issues

### Validator Not Responding

1. Check if process is running:
   ```bash
   pgrep -f solana-test-validator
   ```

2. Check logs:
   ```bash
   ./scripts/monitor.sh
   ```

3. Restart if needed:
   ```bash
   ./scripts/recovery.sh
   ```

### High Disk Usage

1. Check current usage:
   ```bash
   du -sh ~/solana-ledger
   ```

2. Review ledger size limit:
   ```bash
   grep MAX_LEDGER_SIZE_GB configs/config.env
   ```

3. Consider increasing limit or archiving old data

### RPC Timeout

1. Check network connectivity
2. Verify firewall rules
3. Check Azure NSG rules (if applicable)
4. Review validator logs for errors

## Emergency Procedures

### Complete System Failure

1. **Stop validator:**
   ```bash
   ./scripts/stop-validator.sh
   ```

2. **Run recovery:**
   ```bash
   ./scripts/recovery.sh
   ```

3. **If recovery fails, restore from backup:**
   ```bash
   # Restore latest backup
   # See backup restoration section above
   ```

### Disk Full

1. **Stop validator immediately:**
   ```bash
   sudo systemctl stop solana-validator
   ```

2. **Free up space:**
   ```bash
   # Clean old backups
   find ~/solana-backups -type f -mtime +7 -delete
   
   # Check what's using space
   du -h --max-depth=1 ~/solana-ledger | sort -h
   ```

3. **Increase disk size (Azure VM):**
   - Resize VM disk in Azure portal
   - Resize filesystem: `sudo resize2fs /dev/sda1`

4. **Restart validator:**
   ```bash
   sudo systemctl start solana-validator
   ```

## Best Practices

1. **Always use scripts** - Don't manually start/stop the validator
2. **Monitor regularly** - Set up automated health checks
3. **Backup before changes** - Especially before upgrades
4. **Test changes in staging** - Before applying to production
5. **Document changes** - Keep notes of configuration changes
6. **Monitor resources** - Watch CPU, memory, and disk usage
7. **Keep logs** - Review logs regularly for issues
8. **Stay updated** - Keep system packages updated

## Support Contacts

- **Documentation**: See `docs/` directory
- **Troubleshooting**: `docs/04-troubleshooting.md`
- **Status**: `./scripts/monitor.sh` or `sudo systemctl status solana-validator`

