## Current Status

The multi-bootstrap setup is experiencing issues with Agave validator 3.1.5. The recommended approach is to use a single bootstrap validator with additional validators joining as regular validators.

### Working Setup:
1. Bootstrap validator starts first (produces blocks)
2. Wait for bootstrap to produce snapshots
3. Additional validators join as regular validators (not bootstrap)

### Test Commands:
```bash
# Start bootstrap
make start-bootstrap

# Wait for snapshots (check data/bootstrap/snapshots/)
# Then start validator-1 as regular validator
make start-validator NODE=validator-1
```

## Summary

The multi-bootstrap genesis setup has been tested but is currently not working with Agave validator 3.1.5 due to a limitation where a second bootstrap validator cannot start from the same genesis file.

### Current Status:
- ✅ Bootstrap validator starts successfully
- ❌ Validator-1 fails with 'failed to replay bank 0' error
- ✅ All scripts and configurations are in place
- ✅ Documentation updated with limitations

### Recommended Approach:
Use the traditional single-bootstrap setup where validators join as regular validators after the bootstrap produces snapshots.

See STATUS.md and docs/TROUBLESHOOTING.md for more details.

