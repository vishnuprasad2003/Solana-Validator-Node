# Documentation Index

Complete guide to all documentation for the Production Solana Private Cluster.

## 🚀 Getting Started

### New Users - Start Here

1. **[Quick Start Guide](../QUICKSTART.md)** - Get running in 5 minutes
2. **[Complete Setup Guide](COMPLETE-SETUP-GUIDE.md)** - Detailed step-by-step setup from scratch
3. **[Adding Validators](ADDING-VALIDATORS.md)** - How to add new validator nodes

## 📚 Core Documentation

### Setup & Configuration

- **[Complete Setup Guide](COMPLETE-SETUP-GUIDE.md)**
  - Prerequisites and system requirements
  - Initial setup on new system
  - Genesis creation with programs
  - Starting the cluster
  - Token operations
  - External access configuration
  - Monitoring & maintenance

- **[Adding Validators](ADDING-VALIDATORS.md)**
  - Step-by-step guide to add validator nodes
  - Port planning
  - Vote account creation
  - Configuration examples
  - Troubleshooting validator addition

- **[Production Setup](PRODUCTION-SETUP.md)**
  - Production-grade architecture
  - Single-bootstrap pattern explanation
  - Best practices
  - Deployment considerations

### Programs & Features

- **[Programs Setup](PROGRAMS-SETUP.md)**
  - SPL Token programs
  - Metaplex programs
  - Program deployment
  - Verification methods

### Troubleshooting

- **[Troubleshooting Guide](TROUBLESHOOTING.md)**
  - Validator startup issues
  - Genesis & snapshot issues
  - Cluster consensus issues
  - Token program issues
  - Network & connectivity issues
  - Performance issues

### Advanced Topics

- **[Multi-Bootstrap](MULTI-BOOTSTRAP.md)**
  - Multi-bootstrap approach (not recommended)
  - Limitations and alternatives

## 📖 Quick Reference

### Essential Commands

```bash
# Setup
make setup-limits          # Configure system limits
make install              # Install Agave validator
make init-genesis         # Create genesis with programs

# Cluster Management
make start-cluster        # Start entire cluster
make start-bootstrap      # Start bootstrap only
make start-validator NODE=validator-1  # Start validator
make stop                 # Stop all validators

# Monitoring
make list                 # List running validators
make monitor              # Monitor cluster
tail -f logs/bootstrap.log  # View logs

# Programs
make setup-programs       # Download programs
make deploy-programs      # Deploy programs
```

### Key File Locations

```
keys/identity/           # Identity keypairs
keys/vote/               # Vote account keypairs
keys/stake/              # Stake account keypairs
data/bootstrap/          # Bootstrap ledger
data/validator-*/        # Validator ledgers
logs/                    # Log files
programs/                # Program binaries
configs/cluster.conf     # Cluster configuration
configs/validator-*.conf # Validator configurations
```

### Important Addresses

- **Bootstrap RPC:** `http://localhost:8899`
- **Bootstrap Gossip:** `127.0.0.1:8001`
- **Token Program:** `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA`
- **Token-2022:** `TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb`
- **Associated Token:** `ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL`
- **Metaplex Metadata:** `metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s`

## 🎯 Common Tasks

### Setting Up on New System

1. Read [Complete Setup Guide](COMPLETE-SETUP-GUIDE.md)
2. Follow steps 1-4 in Quick Start
3. Verify cluster is running
4. Test token operations

### Adding a New Validator

1. Read [Adding Validators Guide](ADDING-VALIDATORS.md)
2. Create configuration file
3. Generate keypairs
4. Fund identity account
5. Create vote account
6. Start validator

### Troubleshooting Issues

1. Check [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review relevant error section
3. Follow solution steps
4. Check logs if needed

## 📋 Documentation by Use Case

### For New Users
- Start with [Quick Start Guide](../QUICKSTART.md)
- Then read [Complete Setup Guide](COMPLETE-SETUP-GUIDE.md)

### For Adding Validators
- Read [Adding Validators Guide](ADDING-VALIDATORS.md)

### For Production Deployment
- Read [Production Setup Guide](PRODUCTION-SETUP.md)
- Review [Complete Setup Guide](COMPLETE-SETUP-GUIDE.md) sections on external access

### For Troubleshooting
- Check [Troubleshooting Guide](TROUBLESHOOTING.md)
- Review specific error in guide

### For Program Operations
- Read [Programs Setup Guide](PROGRAMS-SETUP.md)
- See token operations in [Complete Setup Guide](COMPLETE-SETUP-GUIDE.md)

## 🔗 External Resources

- [Solana Documentation](https://docs.solana.com/)
- [SPL Token Program](https://spl.solana.com/token)
- [Metaplex Programs](https://github.com/metaplex-foundation/metaplex-program-library)
- [Agave Validator](https://github.com/anza-xyz/agave)
