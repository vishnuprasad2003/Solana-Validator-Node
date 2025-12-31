# Upgrade Guide

This guide covers the safe upgrade process for the Solana production cluster.

## Overview

Upgrades should be performed carefully to minimize downtime and ensure data integrity. The upgrade script includes:

- Automatic backups
- Version verification
- Rollback capability
- Configuration updates

## Pre-Upgrade Checklist

Before starting an upgrade:

- [ ] Review release notes for the target Solana version
- [ ] Check compatibility with your programs/applications
- [ ] Ensure sufficient disk space for backups
- [ ] Notify stakeholders of planned downtime
- [ ] Have rollback plan ready
- [ ] Test upgrade in staging environment (if available)

## Upgrade Process

### Step 1: Check Current Version

```bash
solana --version
```

Note the current version for reference.

### Step 2: Review Target Version

Check available versions:

- **Stable**: Latest stable release
- **Beta**: Latest beta release
- **Specific**: e.g., "1.19.0"

Review Solana release notes:
- https://github.com/solana-labs/solana/releases

### Step 3: Backup Current Installation

The upgrade script automatically creates backups, but you can create a manual backup:

```bash
# Backup Solana installation
tar -czf ~/solana-backups/manual-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  ~/.local/share/solana

# Backup configuration
tar -czf ~/solana-backups/config-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  ~/.config/solana \
  Solana-Validator-Node/configs/
```

### Step 4: Run Upgrade Script

```bash
./scripts/upgrade.sh
```

The script will:
1. Stop the validator
2. Create automatic backups
3. Update configuration
4. Install new Solana version
5. Verify installation
6. Document the upgrade

**Follow the prompts:**
- Enter target version (stable, beta, or specific version)
- Confirm upgrade

### Step 5: Verify Upgrade

```bash
# Check version
solana --version

# Verify installation
./scripts/verify-setup.sh

# Start validator
sudo systemctl start solana-validator

# Check status
sudo systemctl status solana-validator

# Test RPC
curl http://localhost:8899 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
```

### Step 6: Monitor After Upgrade

Monitor the validator closely after upgrade:

```bash
# Watch logs
sudo journalctl -u solana-validator -f

# Run health checks
./scripts/monitor.sh

# Check RPC responsiveness
solana slot --url http://localhost:8899
```

## Rollback Procedure

If issues occur after upgrade, rollback to previous version:

### Step 1: Stop Validator

```bash
sudo systemctl stop solana-validator
```

### Step 2: Restore Backup

```bash
# Find backup from upgrade
ls -lh ~/solana-backups/solana-backup-*

# Restore Solana installation
tar -xzf ~/solana-backups/solana-backup-YYYYMMDD-HHMMSS.tar.gz -C ~/.local/share/

# Restore configuration (if needed)
tar -xzf ~/solana-backups/config-backup-YYYYMMDD-HHMMSS.tar.gz -C ~/
```

### Step 3: Update Configuration

Edit `configs/config.env` to restore previous version:

```bash
nano configs/config.env
# Change SOLANA_VERSION back to previous version
```

### Step 4: Restart Validator

```bash
sudo systemctl start solana-validator
sudo systemctl status solana-validator
```

### Step 5: Verify Rollback

```bash
solana --version
./scripts/verify-setup.sh
```

## Upgrade Types

### Minor Version Upgrade

Example: 1.18.0 → 1.18.1

**Risk Level:** Low
**Downtime:** Minimal (5-10 minutes)

**Process:**
1. Follow standard upgrade process
2. Usually backward compatible
3. Minimal testing required

### Major Version Upgrade

Example: 1.18.x → 1.19.0

**Risk Level:** Medium-High
**Downtime:** 10-30 minutes

**Process:**
1. Review breaking changes in release notes
2. Test in staging environment first
3. Plan for potential compatibility issues
4. Have rollback plan ready
5. Monitor closely after upgrade

### Stable to Beta Upgrade

**Risk Level:** High
**Downtime:** Variable

**Not Recommended for Production**

Only upgrade to beta if:
- Testing new features
- Staging environment
- You understand the risks

## Version Compatibility

### Checking Compatibility

Before upgrading, check:

1. **Program Compatibility:**
   - Ensure your Solana programs compile with new version
   - Test program deployment
   - Verify program execution

2. **Client Compatibility:**
   - Update Solana web3.js/rust clients if needed
   - Test RPC API compatibility
   - Verify transaction formats

3. **Tool Compatibility:**
   - Anchor framework version
   - Other development tools

### Compatibility Matrix

| Solana Version | Anchor Version | Notes |
|---------------|----------------|-------|
| 1.18.x | 0.28.x | Stable |
| 1.19.x | 0.29.x | Check release notes |

*Note: Always check official documentation for latest compatibility*

## Automated Upgrade Checks

Set up automated version checking:

```bash
# Add to crontab (weekly check)
0 0 * * 0 /home/user/Solana-Validator-Node/scripts/check-updates.sh
```

Create `scripts/check-updates.sh`:

```bash
#!/bin/bash
CURRENT=$(solana --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
LATEST=$(curl -s https://api.github.com/repos/solana-labs/solana/releases/latest | jq -r .tag_name | sed 's/v//')

if [ "$CURRENT" != "$LATEST" ]; then
    echo "New version available: $LATEST (current: $CURRENT)"
    # Send notification (email, Slack, etc.)
fi
```

## Post-Upgrade Tasks

After successful upgrade:

1. **Update Documentation:**
   - Note version in upgrade log
   - Document any issues encountered
   - Update compatibility matrix

2. **Test Functionality:**
   - Deploy test program
   - Execute test transactions
   - Verify RPC endpoints
   - Test client connections

3. **Monitor Performance:**
   - Watch for performance regressions
   - Monitor resource usage
   - Check error rates

4. **Clean Up:**
   - Remove old backups (after verification period)
   - Archive upgrade logs
   - Update monitoring dashboards

## Troubleshooting Upgrades

### Upgrade Fails During Installation

1. Check validator status:
   ```bash
   ./scripts/monitor.sh
   ```

2. Verify disk space:
   ```bash
   df -h
   ```

3. Check network connectivity:
   ```bash
   curl -I https://release.solana.com/stable/install
   ```

4. Retry upgrade or restore from backup

### Validator Won't Start After Upgrade

1. Check logs:
   ```bash
   sudo journalctl -u solana-validator -n 100
   ```

2. Verify configuration:
   ```bash
   ./scripts/verify-setup.sh
   ```

3. Check ledger compatibility:
   ```bash
   # May need to reset ledger if incompatible
   # WARNING: This will lose data
   ```

4. Rollback if necessary

### RPC Not Working After Upgrade

1. Check if validator is running:
   ```bash
   pgrep -f solana-test-validator
   ```

2. Verify RPC port:
   ```bash
   sudo netstat -tulpn | grep 8899
   ```

3. Check firewall:
   ```bash
   sudo ufw status
   ```

4. Review configuration:
   ```bash
   grep RPC configs/config.env
   ```

## Best Practices

1. **Always backup before upgrading**
2. **Test in staging first** (if available)
3. **Upgrade during maintenance windows**
4. **Monitor closely after upgrade**
5. **Keep rollback plan ready**
6. **Document all upgrades**
7. **Review release notes before upgrading**
8. **Don't skip versions** - upgrade incrementally
9. **Keep old backups** until new version is stable
10. **Communicate upgrades** to stakeholders

## Support

If you encounter issues during upgrade:

1. Check `docs/04-troubleshooting.md`
2. Verify installation: `./scripts/verify-setup.sh`
3. Check Solana release notes for known issues
4. Consider rolling back if critical issues occur

