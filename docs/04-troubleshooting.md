# Troubleshooting Guide

This guide covers common issues and their solutions for the Solana production cluster.

## Quick Diagnostics

Run these commands to gather information:

```bash
# Overall health check
./scripts/monitor.sh

# Detailed verification
./scripts/verify-setup.sh

# Check logs
tail -100 logs/validator.log

# Check systemd status
sudo systemctl status solana-validator
```

## Common Issues

### Validator Won't Start

**Symptoms:**
- Process doesn't start
- Immediate exit after start
- Error messages in logs

**Diagnosis:**

```bash
# Check if process is running
pgrep -f solana-test-validator

# Check logs
tail -50 logs/validator.log

# Check systemd logs
sudo journalctl -u solana-validator -n 50
```

**Common Causes & Solutions:**

1. **Port already in use:**
   ```bash
   # Check what's using the port
   sudo netstat -tulpn | grep 8899
   
   # Kill the process or change port in config.env
   ```

2. **Insufficient permissions:**
   ```bash
   # Check directory permissions
   ls -la ~/solana-ledger
   ls -la ~/.config/solana
   
   # Fix permissions if needed
   chmod 755 ~/solana-ledger
   chmod 755 ~/.config/solana
   ```

3. **Missing keypair:**
   ```bash
   # Check if keypair exists
   ls -la ~/.config/solana/validator-keypair.json
   
   # Re-run setup if missing
   ./scripts/setup-cluster.sh
   ```

4. **Corrupted ledger:**
   ```bash
   # Run recovery script
   ./scripts/recovery.sh
   ```

### RPC Endpoint Not Accessible

**Symptoms:**
- Can't connect to RPC from external clients
- Connection timeout
- Connection refused errors

**Diagnosis:**

```bash
# Test local RPC
curl http://localhost:8899 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'

# Test external RPC (from another machine)
curl http://<PUBLIC_IP>:8899 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'

# Check if validator is listening
sudo netstat -tulpn | grep 8899
```

**Common Causes & Solutions:**

1. **Firewall blocking:**
   ```bash
   # Check UFW status
   sudo ufw status
   
   # Allow RPC port
   sudo ufw allow 8899/tcp
   ```

2. **Wrong bind address:**
   ```bash
   # Check config
   grep RPC_BIND_ADDRESS configs/config.env
   
   # Should be "0.0.0.0" for public access
   # Edit config.env and restart validator
   ```

3. **Azure NSG blocking:**
   - Check Azure Network Security Group rules
   - Ensure port 8899 is allowed
   - See `docs/05-azure-configuration.md`

4. **Validator not running:**
   ```bash
   # Start validator
   sudo systemctl start solana-validator
   ```

### High CPU/Memory Usage

**Symptoms:**
- System becomes slow
- High resource usage reported

**Diagnosis:**

```bash
# Check resource usage
top -p $(pgrep -f solana-test-validator)

# Check memory
free -h

# Check CPU
htop
```

**Solutions:**

1. **Increase VM resources** (Azure):
   - Upgrade VM size
   - Add more RAM/CPU

2. **Optimize configuration:**
   - Reduce RPC threads if not needed
   - Limit ledger size
   - Review log level

3. **Check for issues:**
   - Review logs for errors
   - Check for stuck processes
   - Monitor network activity

### Disk Space Issues

**Symptoms:**
- Disk full errors
- Validator stops working
- Can't write to ledger

**Diagnosis:**

```bash
# Check disk usage
df -h

# Check ledger size
du -sh ~/solana-ledger

# Find large files
du -h --max-depth=1 ~/solana-ledger | sort -h
```

**Solutions:**

1. **Clean up backups:**
   ```bash
   # Remove old backups
   find ~/solana-backups -type f -mtime +30 -delete
   ```

2. **Increase ledger size limit:**
   ```bash
   # Edit config.env
   nano configs/config.env
   # Increase MAX_LEDGER_SIZE_GB
   ```

3. **Resize Azure disk:**
   - Resize in Azure portal
   - Resize filesystem: `sudo resize2fs /dev/sda1`

4. **Archive old ledger data:**
   ```bash
   # Stop validator first
   sudo systemctl stop solana-validator
   
   # Archive old data (if safe to do so)
   tar -czf ~/solana-backups/ledger-archive-$(date +%Y%m%d).tar.gz \
     ~/solana-ledger/old-data/
   ```

### Validator Crashes/Stops Unexpectedly

**Symptoms:**
- Validator stops running
- Systemd shows failed status
- No error messages

**Diagnosis:**

```bash
# Check systemd status
sudo systemctl status solana-validator

# Check logs
sudo journalctl -u solana-validator -n 100

# Check system logs
sudo dmesg | tail -50
```

**Common Causes:**

1. **Out of memory:**
   ```bash
   # Check memory
   free -h
   
   # Check OOM killer
   sudo dmesg | grep -i "out of memory"
   ```

2. **Disk full:**
   ```bash
   df -h
   ```

3. **Corrupted ledger:**
   ```bash
   # Run recovery
   ./scripts/recovery.sh
   ```

4. **System issues:**
   ```bash
   # Check system logs
   sudo journalctl -p err -n 50
   ```

### Upgrade Issues

**Symptoms:**
- Upgrade fails
- Validator won't start after upgrade
- Version mismatch errors

**Solutions:**

1. **Rollback to previous version:**
   ```bash
   # See docs/03-upgrades.md for rollback procedure
   ```

2. **Check compatibility:**
   - Review Solana release notes
   - Check program compatibility
   - Verify client compatibility

3. **Clean installation:**
   ```bash
   # Backup first
   tar -czf ~/backup-before-clean.tar.gz ~/.local/share/solana
   
   # Remove old installation
   rm -rf ~/.local/share/solana
   
   # Reinstall
   ./scripts/install.sh
   ```

### Network Issues

**Symptoms:**
- Can't connect to other nodes
- Gossip not working
- Network timeouts

**Diagnosis:**

```bash
# Check network connectivity
ping <other-node-ip>

# Check firewall
sudo ufw status

# Check ports
sudo netstat -tulpn | grep solana
```

**Solutions:**

1. **Check firewall rules:**
   ```bash
   # Allow gossip port
   sudo ufw allow 8001/udp
   ```

2. **Check Azure NSG:**
   - Verify rules for gossip port
   - Check network security groups

3. **Verify network configuration:**
   ```bash
   # Check IP addresses
   ip addr show
   
   # Check routing
   ip route show
   ```

## Recovery Procedures

### Complete System Recovery

If the validator is completely broken:

```bash
# Run recovery script
./scripts/recovery.sh

# If that fails, manual recovery:
# 1. Stop validator
sudo systemctl stop solana-validator

# 2. Restore from backup
tar -xzf ~/solana-backups/latest-backup.tar.gz -C ~/

# 3. Verify configuration
./scripts/verify-setup.sh

# 4. Start validator
sudo systemctl start solana-validator
```

### Ledger Corruption

If ledger is corrupted:

```bash
# Stop validator
sudo systemctl stop solana-validator

# Backup corrupted ledger
mv ~/solana-ledger ~/solana-ledger.corrupt-$(date +%Y%m%d)

# Restore from backup or start fresh
# Option 1: Restore from backup
tar -xzf ~/solana-backups/ledger-backup.tar.gz -C ~/

# Option 2: Start fresh (WARNING: Loses all data)
mkdir -p ~/solana-ledger

# Start validator
sudo systemctl start solana-validator
```

### Configuration Issues

If configuration is wrong:

```bash
# Backup current config
cp configs/config.env configs/config.env.backup

# Restore from backup
tar -xzf ~/solana-backups/config-backup.tar.gz -C ~/

# Or edit manually
nano configs/config.env

# Restart validator
sudo systemctl restart solana-validator
```

## Getting Help

### Information to Collect

Before seeking help, collect:

1. **System information:**
   ```bash
   uname -a
   free -h
   df -h
   ```

2. **Solana version:**
   ```bash
   solana --version
   ```

3. **Configuration:**
   ```bash
   cat configs/config.env
   ```

4. **Logs:**
   ```bash
   tail -100 logs/validator.log
   sudo journalctl -u solana-validator -n 100
   ```

5. **Status:**
   ```bash
   ./scripts/monitor.sh
   ./scripts/verify-setup.sh
   ```

### Log Locations

- **Validator logs:** `logs/validator.log`
- **Systemd logs:** `sudo journalctl -u solana-validator`
- **Upgrade logs:** `logs/upgrades.log`
- **Health check logs:** `logs/health.log` (if configured)

### Useful Commands

```bash
# Check all Solana processes
ps aux | grep solana

# Check network connections
sudo netstat -tulpn | grep solana

# Check disk I/O
sudo iotop

# Check system resources
htop

# Check recent errors
sudo journalctl -p err -n 50

# Check Solana CLI config
solana config get
```

## Prevention

To avoid common issues:

1. **Regular monitoring:** Set up automated health checks
2. **Regular backups:** Automate backup creation
3. **Resource monitoring:** Watch CPU, memory, disk
4. **Stay updated:** Keep system packages updated
5. **Test changes:** Test in staging before production
6. **Document changes:** Keep notes of all changes
7. **Review logs:** Regularly review logs for issues
8. **Plan upgrades:** Plan and test upgrades carefully

## Emergency Contacts

- **Documentation:** `docs/` directory
- **Recovery script:** `./scripts/recovery.sh`
- **Monitor script:** `./scripts/monitor.sh`
- **Verify script:** `./scripts/verify-setup.sh`

