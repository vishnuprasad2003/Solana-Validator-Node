# Production-Grade Private Solana Cluster

A production-ready, containerized setup for running a private Solana test cluster using the Agave validator. Designed for deployment on Azure VMs, Docker, and Kubernetes.

## 🚀 Quick Start

### Complete Setup from Scratch

**For detailed step-by-step instructions, see [Complete Setup Guide](docs/COMPLETE-SETUP-GUIDE.md)**

```bash
# 1. Configure system limits (requires sudo, then logout/login)
sudo make setup-limits

# 2. Install Agave validator and Solana CLI tools
make install

# 3. Initialize genesis (automatically includes SPL & Metaplex programs)
make init-genesis

# 4. Start entire cluster (bootstrap + validators)
make start-cluster

# 5. Verify cluster
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}' | jq

# 6. Test token operations
spl-token create-token --url http://localhost:8899
```

### Adding New Validators

**See [Adding Validators Guide](docs/ADDING-VALIDATORS.md) for detailed instructions**

```bash
# Create validator configuration
cp configs/node.conf.template configs/validator-2.conf
# Edit configs/validator-2.conf with unique ports

# Fund validator identity
VALIDATOR2_IDENTITY=$(solana-keygen pubkey keys/identity/validator-2-identity.json)
solana transfer $VALIDATOR2_IDENTITY 10 --allow-unfunded-recipient \
  --keypair keys/identity/faucet.json --url http://localhost:8899

# Create vote account
solana create-vote-account keys/vote/validator-2-vote.json \
  keys/identity/validator-2-identity.json keys/stake/validator-2-stake.json \
  --fee-payer keys/identity/validator-2-identity.json --url http://localhost:8899

# Start validator
make start-validator NODE=validator-2
```

### Docker Deployment

```bash
# Build image
make build-docker

# Start cluster
make docker-up

# View logs
make docker-logs SERVICE=bootstrap
```

### Kubernetes Deployment

```bash
# Deploy to Kubernetes
make deploy-k8s

# Check status
make k8s-status
```

## 📋 Features

- ✅ **Production-Ready**: Optimized for production workloads
- ✅ **Multi-Validator Support**: Scale from 1 to N validators
- ✅ **Docker & Kubernetes**: Full containerization support
- ✅ **External Access**: Configured for Azure VM with public IP
- ✅ **SPL Token Support**: Token, Token-2022, Associated Token programs
- ✅ **Monitoring & Logging**: Built-in health checks and log rotation
- ✅ **High Availability**: Supports multi-node clusters

## 📁 Directory Structure

```
Solana-Validator-Node/
├── configs/              # Configuration files
│   ├── cluster.conf      # Cluster-wide settings
│   └── node.conf.template # Node configuration template
├── scripts/               # Management scripts
│   ├── common.sh         # Shared utilities
│   ├── install.sh        # Install Agave validator
│   ├── init-genesis.sh   # Initialize genesis
│   ├── init-multi-node.sh # Multi-node setup
│   ├── start-bootstrap.sh # Start bootstrap
│   ├── start-validator.sh # Start validator
│   ├── stop-validator.sh  # Stop validator
│   ├── monitor.sh        # Monitor status
│   ├── setup-external-access.sh # External access config
│   └── deploy-spl-programs.sh # SPL program deployment
├── docker/                # Docker files
│   ├── Dockerfile.production
│   └── docker-compose.production.yml
├── kubernetes/            # Kubernetes manifests
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── bootstrap-validator.yaml
│   └── validator.yaml
├── keys/                  # Keypair storage (gitignored)
├── data/                  # Ledger data (gitignored)
├── logs/                  # Log files (gitignored)
├── Makefile              # Common operations
├── README.md             # This file
├── DEPLOYMENT.md         # Detailed deployment guide
└── QUICKSTART.md         # Quick start guide
```

## 🏗️ Deployment Options

### 1. Azure VM Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md#azure-vm-deployment) for detailed instructions.

**Quick Steps:**
```bash
# On Azure VM
sudo make setup-limits
make install
make init-genesis
PUBLIC_IP=<your-public-ip> make setup-external
make start-bootstrap
```

### 2. Docker Deployment

```bash
# Build and start
make build-docker
make docker-up

# Or with custom public IP
PUBLIC_IP=<your-ip> docker-compose -f docker/docker-compose.production.yml up -d
```

### 3. Kubernetes Deployment

```bash
# Build and push image to your registry
docker build -f docker/Dockerfile.production -t <registry>/solana-validator:latest .
docker push <registry>/solana-validator:latest

# Update image in manifests, then deploy
make deploy-k8s
```

## 🌐 External Access

### Configure External Access

```bash
# Set your public IP
export PUBLIC_IP=<your-azure-vm-public-ip>

# Configure cluster
make setup-external

# Restart bootstrap
make stop
make start-bootstrap
```

### Connect from External Client

```bash
# Set cluster URL
export SOLANA_URL=http://<public-ip>:8899
solana config set --url $SOLANA_URL

# Verify connection
solana cluster-version
solana balance
```

### Azure Network Security Group Rules

Add these inbound rules:

| Protocol | Port Range | Source | Description |
|----------|------------|--------|-------------|
| UDP | 8001 | Any | Gossip (Bootstrap) |
| TCP | 8001 | Any | Gossip (Bootstrap) |
| TCP | 8899 | Any | RPC (Bootstrap) |
| TCP | 8900 | Any | RPC WebSocket |
| UDP | 8000-8025 | Any | Dynamic ports |

## 🔧 Multi-Validator Setup

### Initialize Multi-Node Cluster

```bash
# Create 3 additional validators
make init-multi-node NUM=3
```

### Start Multi-Node Cluster

**Docker:**
```bash
make docker-up  # Starts bootstrap + 2 validators
```

**Kubernetes:**
```bash
make deploy-k8s
kubectl scale statefulset solana-validator -n solana-cluster --replicas=3
```

**Manual:**
```bash
make start-bootstrap
make start-validator NODE=validator-1
make start-validator NODE=validator-2
make start-validator NODE=validator-3
```

## 💰 SPL Token Programs & Functionality

### ✅ Automatically Included in Genesis

These programs are **automatically downloaded and included** during genesis creation:
- **SPL Token Program**: `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA` ✅
- **SPL Token-2022 Program**: `TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb` ✅
- **Associated Token Account Program**: `ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL` ✅
- **Metaplex Token Metadata Program**: `metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s` ✅

**All programs are deployed at their standard mainnet addresses**, so standard Solana tools work without modification!

### Verify Programs

```bash
make deploy-spl  # Check program status
# Or: ./scripts/deploy-spl-programs.sh
```

### Full Devnet Functionality

**✅ All standard Solana operations work:**

```bash
# Set cluster URL
export SOLANA_URL=http://<public-ip>:8899
solana config set --url $SOLANA_URL

# Token Operations
spl-token create-token                    # Create token mint
spl-token create-account <mint>          # Create token account
spl-token mint <mint> 1000               # Mint tokens
spl-token transfer <mint> 100 <address>  # Transfer tokens

# Account Operations
solana-keygen new                        # Create keypair
solana airdrop 100 <address>            # Airdrop SOL (if faucet configured)
solana balance <address>                # Check balance
solana transfer <address> 10            # Transfer SOL

# Program Deployment
solana program deploy <program.so>       # Deploy custom program
solana program show <program-id>         # View program info

# Transaction Operations
solana confirm <signature>               # Confirm transaction
solana transaction-history <address>    # View transaction history
```

**All operations work exactly like devnet/mainnet!**

## 📊 Monitoring

```bash
# List all validators
make list

# Monitor specific validator
make monitor NODE=bootstrap

# Monitor all validators
make monitor NODE=all

# View logs
tail -f logs/bootstrap.log
```

## 🔐 Security Considerations

1. **Keys**: Never commit keys to git (already in `.gitignore`)
2. **Firewall**: Restrict RPC access to trusted IPs in production
3. **Backup**: Regularly backup `keys/` and `data/` directories
4. **Updates**: Keep Agave validator updated to latest stable version

## 📚 Documentation

- **[Complete Setup Guide](docs/COMPLETE-SETUP-GUIDE.md)**: Step-by-step setup from scratch
- **[Adding Validators](docs/ADDING-VALIDATORS.md)**: How to add new validator nodes
- **[Production Setup](docs/PRODUCTION-SETUP.md)**: Production-grade architecture and setup
- **[Programs Setup](docs/PROGRAMS-SETUP.md)**: SPL and Metaplex programs configuration
- **[Troubleshooting](docs/TROUBLESHOOTING.md)**: Common issues and solutions

## 🛠️ Common Commands

```bash
# Setup
make setup-limits          # Configure system limits
make install              # Install Agave validator
make init-genesis         # Initialize genesis
make init-multi-node NUM=3 # Setup multi-node cluster

# Operations
make start-bootstrap      # Start bootstrap validator
make start-validator NODE=validator-1 # Start validator
make stop                 # Stop all validators
make list                 # List running validators
make monitor              # Monitor status

# Docker
make build-docker         # Build Docker image
make docker-up            # Start with Docker Compose
make docker-down          # Stop Docker Compose
make docker-logs          # View logs

# Kubernetes
make deploy-k8s           # Deploy to Kubernetes
make k8s-status           # Check status

# Utilities
make setup-external IP=1.2.3.4 # Configure external access
make verify-setup         # Verify configuration
make deploy-spl           # Check SPL programs
```

## 🐛 Troubleshooting

### Validator Won't Start

1. Check system limits: `ulimit -Hn` (should be 1000000+)
2. Check logs: `tail -f logs/bootstrap.log`
3. Verify ports: `ss -tuln | grep 8899`
4. Check genesis: `ls -la data/bootstrap/genesis.bin`

### External Access Issues

1. Verify public IP is set: `grep BOOTSTRAP_VALIDATOR_IP configs/cluster.conf`
2. Check Azure NSG firewall rules
3. Verify RPC_BIND_ADDRESS is 0.0.0.0 (not 127.0.0.1)
4. Test connectivity: `curl http://<public-ip>:8899`

### Programs Not Found

1. Check if programs exist: `make deploy-spl`
2. Deploy missing programs manually (see DEPLOYMENT.md)
3. Verify program IDs match Solana standard IDs

## 📝 Production Checklist

- [ ] System limits configured (nofile: 1M, memlock: unlimited)
- [ ] Public IP configured in cluster.conf
- [ ] Firewall rules configured (Azure NSG)
- [ ] Persistent storage configured
- [ ] Monitoring and logging set up
- [ ] Backup strategy implemented
- [ ] SPL programs verified
- [ ] Multi-validator cluster tested
- [ ] External access verified
- [ ] Documentation reviewed

## 🔗 Useful Links

- [Agave Validator](https://github.com/anza-xyz/agave)
- [Solana Documentation](https://docs.solana.com/)
- [SPL Token Program](https://spl.solana.com/token)
- [Metaplex Programs](https://github.com/metaplex-foundation/metaplex-program-library)

## 📄 License

This setup is provided as-is for private cluster deployments.
