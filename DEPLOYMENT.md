# Production Deployment Guide

Complete guide for deploying the Solana private cluster in production environments:
- **Azure VM**: Direct deployment on Azure Virtual Machines
- **Docker**: Containerized deployment with Docker Compose
- **Kubernetes**: Orchestrated deployment on Kubernetes clusters

## 🎯 Quick Deployment

### Azure VM (Recommended for Production)

```bash
# Complete automated setup
PUBLIC_IP=<your-azure-vm-ip> NUM_VALIDATORS=2 ./scripts/azure-setup.sh

# Then log out/in and start:
make start-bootstrap
make start-validator NODE=validator-1
make start-validator NODE=validator-2
```

### Docker

```bash
# Build and start
make build-docker
PUBLIC_IP=<your-ip> make docker-up
```

### Kubernetes

```bash
# Build, push, and deploy
REGISTRY=<your-registry> ./scripts/build-and-push.sh
make deploy-k8s
```

## Table of Contents

1. [Azure VM Deployment](#azure-vm-deployment)
2. [Docker Deployment](#docker-deployment)
3. [Kubernetes Deployment](#kubernetes-deployment)
4. [External Access Configuration](#external-access-configuration)
5. [SPL Token Programs](#spl-token-programs)
6. [Multi-Validator Setup](#multi-validator-setup)

## Azure VM Deployment

### Prerequisites

- Azure VM with:
  - Ubuntu 22.04 LTS
  - Minimum 16GB RAM (32GB+ recommended)
  - Minimum 500GB SSD storage
  - Static public IP address
  - Network Security Group configured

### Step 1: VM Setup

```bash
# SSH into your Azure VM
ssh azureuser@<your-public-ip>

# Clone or copy the repository
git clone <your-repo> solana-cluster
cd solana-cluster
```

### Step 2: Configure System Limits

```bash
# Configure file descriptor and memory lock limits
sudo ./scripts/configure-limits.sh

# Log out and log back in for limits to take effect
exit
# SSH back in
```

### Step 3: Configure External Access

```bash
# Set your public IP
export PUBLIC_IP=<your-azure-vm-public-ip>

# Configure cluster for external access
./scripts/setup-external-access.sh
```

### Step 4: Initialize and Start Cluster

```bash
# Install Agave validator
./scripts/install.sh

# Initialize genesis
./scripts/init-genesis.sh

# For multi-node cluster
./scripts/init-multi-node.sh 2  # Creates 2 additional validators

# Start bootstrap validator
./scripts/start-bootstrap.sh

# Start additional validators (in separate terminals or via systemd)
./scripts/start-validator.sh validator-1
./scripts/start-validator.sh validator-2
```

### Step 5: Configure Azure Network Security Group

Add the following inbound rules:

| Name | Priority | Source | Protocol | Port Range | Action |
|------|----------|--------|----------|------------|--------|
| Solana-Gossip-UDP | 100 | Any | UDP | 8001 | Allow |
| Solana-Gossip-TCP | 101 | Any | TCP | 8001 | Allow |
| Solana-RPC | 102 | Any | TCP | 8899 | Allow |
| Solana-RPC-WS | 103 | Any | TCP | 8900 | Allow |
| Solana-Dynamic-Ports | 104 | Any | UDP | 8000-8025 | Allow |

For additional validators, add rules for their ports (8002, 8003, etc.)

### Step 6: Verify External Access

From your local machine:

```bash
# Set cluster URL
export SOLANA_URL=http://<your-public-ip>:8899
solana config set --url $SOLANA_URL

# Check cluster status
solana cluster-version
solana balance
```

## Docker Deployment

### Quick Start

```bash
# Build the image
docker build -f docker/Dockerfile.production -t solana-validator:latest .

# Or use docker-compose
docker-compose -f docker/docker-compose.production.yml up -d
```

### Environment Variables

Create a `.env` file:

```bash
PUBLIC_IP=<your-public-ip>
BOOTSTRAP_GOSSIP_PORT=8001
BOOTSTRAP_RPC_PORT=8899
VALIDATOR_1_GOSSIP_PORT=8002
VALIDATOR_1_RPC_PORT=8901
VALIDATOR_2_GOSSIP_PORT=8003
VALIDATOR_2_RPC_PORT=8903
```

### Start Services

```bash
# Start all services
docker-compose -f docker/docker-compose.production.yml up -d

# View logs
docker-compose -f docker/docker-compose.production.yml logs -f

# Stop services
docker-compose -f docker/docker-compose.production.yml down
```

### Persistent Storage

Data is stored in Docker volumes:
- `bootstrap-ledger`: Bootstrap validator ledger
- `validator-1-ledger`: Validator 1 ledger
- `validator-2-ledger`: Validator 2 ledger
- `validator-keys`: Shared key storage

To backup:
```bash
docker run --rm -v solana-cluster_bootstrap-ledger:/data -v $(pwd):/backup ubuntu tar czf /backup/bootstrap-ledger-backup.tar.gz /data
```

## Kubernetes Deployment

### Prerequisites

- Kubernetes cluster (Azure AKS, EKS, GKE, or self-hosted)
- kubectl configured
- Storage class configured for persistent volumes

### Step 1: Build and Push Docker Image

```bash
# Build image
docker build -f docker/Dockerfile.production -t solana-validator:latest .

# Tag for your registry
docker tag solana-validator:latest <your-registry>/solana-validator:latest

# Push to registry
docker push <your-registry>/solana-validator:latest

# Update kubernetes manifests with your image
sed -i 's|solana-validator:latest|<your-registry>/solana-validator:latest|g' kubernetes/*.yaml
```

### Step 2: Deploy to Kubernetes

```bash
# Create namespace
kubectl apply -f kubernetes/namespace.yaml

# Create configmap
kubectl apply -f kubernetes/configmap.yaml

# Deploy bootstrap validator
kubectl apply -f kubernetes/bootstrap-validator.yaml

# Wait for bootstrap to be ready
kubectl wait --for=condition=ready pod -l app=solana-bootstrap -n solana-cluster --timeout=300s

# Deploy additional validators
kubectl apply -f kubernetes/validator.yaml

# Check status
kubectl get pods -n solana-cluster
kubectl get svc -n solana-cluster
```

### Step 3: Access RPC Endpoint

For Azure AKS with LoadBalancer:
```bash
# Get external IP
kubectl get svc solana-bootstrap -n solana-cluster

# Use the EXTERNAL-IP for RPC access
export SOLANA_URL=http://<EXTERNAL-IP>:8899
```

For NodePort (Azure VM with Kubernetes):
```bash
# Get node IP and port
kubectl get svc solana-bootstrap -n solana-cluster
# Access via <node-ip>:<nodeport>
```

### Step 4: Scale Validators

```bash
# Scale to 5 validators
kubectl scale statefulset solana-validator -n solana-cluster --replicas=5
```

## External Access Configuration

### For Azure VM

1. **Set Public IP in Configuration**:
   ```bash
   export PUBLIC_IP=<your-static-public-ip>
   ./scripts/setup-external-access.sh
   ```

2. **Update Bootstrap Validator**:
   The script updates `configs/cluster.conf` with the public IP.

3. **Restart Validators**:
   ```bash
   ./scripts/stop-validator.sh bootstrap
   ./scripts/start-bootstrap.sh
   ```

### For Docker

Set environment variable:
```bash
export PUBLIC_IP=<your-public-ip>
docker-compose -f docker/docker-compose.production.yml up -d
```

### For Kubernetes

Update the service to use LoadBalancer or NodePort, and set the public IP in the bootstrap validator's environment variables.

### Connect from External Clients

```bash
# Set cluster URL
export SOLANA_URL=http://<public-ip>:8899
solana config set --url $SOLANA_URL

# Verify connection
solana cluster-version
solana balance

# Get airdrop from faucet (if configured)
solana airdrop 100
```

## SPL Token Programs

### Default Programs in Genesis

**✅ INCLUDED BY DEFAULT** in development cluster type:
- **Token Program**: `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA` ✅
- **Token-2022 Program**: `TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb` ✅
- **Associated Token Program**: `ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL` ✅

**❌ NOT INCLUDED** (must be deployed separately):
- **Metaplex Token Metadata**: Must be deployed manually
- **Other Metaplex programs**: Must be deployed manually
- **Custom programs**: Deploy as needed

### Verify Programs

```bash
# Check if Token program exists
solana program show TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA --url $SOLANA_URL

# Check Token-2022
solana program show TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb --url $SOLANA_URL

# Check Associated Token
solana program show ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL --url $SOLANA_URL
```

### Deploy Additional Programs

If programs are missing, deploy them:

```bash
# Use the deployment script
./scripts/deploy-spl-programs.sh

# Or manually deploy Token program
git clone https://github.com/solana-labs/solana-program-library.git
cd solana-program-library/token/program
cargo build-sbf
solana program deploy target/deploy/spl_token.so --url $SOLANA_URL
```

### Metaplex Programs

Metaplex programs are NOT included by default. Deploy them separately:

```bash
# Clone Metaplex program library
git clone https://github.com/metaplex-foundation/metaplex-program-library.git

# Build and deploy Token Metadata program
cd metaplex-program-library/token-metadata/program
cargo build-sbf
solana program deploy target/deploy/mpl_token_metadata.so --url $SOLANA_URL
```

## Multi-Validator Setup

### Initialize Multi-Node Cluster

```bash
# Initialize cluster with 3 additional validators
./scripts/init-multi-node.sh 3
```

This creates:
- Keys for validator-1, validator-2, validator-3
- Node-specific configurations
- Unique ports for each validator

### Start Multi-Node Cluster

**Option 1: Manual Start**
```bash
# Terminal 1: Bootstrap
./scripts/start-bootstrap.sh

# Terminal 2: Validator 1
./scripts/start-validator.sh validator-1

# Terminal 3: Validator 2
./scripts/start-validator.sh validator-2

# Terminal 4: Validator 3
./scripts/start-validator.sh validator-3
```

**Option 2: Docker Compose**
```bash
docker-compose -f docker/docker-compose.production.yml up -d
```

**Option 3: Kubernetes**
```bash
kubectl apply -f kubernetes/bootstrap-validator.yaml
kubectl apply -f kubernetes/validator.yaml
# Scale as needed
kubectl scale statefulset solana-validator -n solana-cluster --replicas=3
```

### Verify Multi-Node Cluster

```bash
# List all validators
./scripts/list-validators.sh

# Monitor cluster
./scripts/monitor.sh all

# Check cluster info via RPC
curl -X POST http://localhost:8899 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getClusterNodes"}'
```

## Common Operations

All operations work the same as on Solana devnet/mainnet:

### Set Cluster URL

```bash
export SOLANA_URL=http://<public-ip>:8899
solana config set --url $SOLANA_URL
```

### Create Token Mint

```bash
# Create SPL Token mint
spl-token create-token

# Create Token-2022 mint
spl-token create-token --program-id TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb

# Create token account
spl-token create-account <token-mint-address>

# Mint tokens
spl-token mint <token-mint-address> 1000
```

### Deploy Custom Program

```bash
# Build your program
cargo build-sbf

# Deploy
solana program deploy target/deploy/your_program.so --url $SOLANA_URL

# Or with keypair
solana program deploy target/deploy/your_program.so \
  --url $SOLANA_URL \
  --keypair keys/identity/faucet.json
```

### Transfer SOL

```bash
# Get faucet address
FAUCET=$(solana-keygen pubkey keys/identity/faucet.json)

# Transfer SOL
solana transfer <recipient-address> 10 \
  --url $SOLANA_URL \
  --keypair keys/identity/faucet.json

# Check balance
solana balance $FAUCET
```

### Create Accounts

```bash
# Create new keypair
solana-keygen new --outfile my-keypair.json

# Airdrop SOL (if faucet is configured)
solana airdrop 100 $(solana-keygen pubkey my-keypair.json) --url $SOLANA_URL
```

### Deploy Metaplex Programs

```bash
# Clone Metaplex
git clone https://github.com/metaplex-foundation/metaplex-program-library.git
cd metaplex-program-library/token-metadata/program

# Build
cargo build-sbf

# Deploy
solana program deploy target/deploy/mpl_token_metadata.so \
  --url $SOLANA_URL \
  --keypair keys/identity/faucet.json
```

## Troubleshooting

### Validator Not Accessible Externally

1. Check firewall rules (Azure NSG)
2. Verify RPC_BIND_ADDRESS is 0.0.0.0 (not 127.0.0.1)
3. Check if ports are correctly mapped in Docker/Kubernetes
4. Verify public IP is set correctly

### Validators Not Connecting

1. Ensure bootstrap validator is running first
2. Check ENTRYPOINT_HOST and ENTRYPOINT_PORT in validator configs
3. Verify network connectivity between nodes
4. Check firewall allows gossip ports (UDP)

### Programs Not Found

1. Check if programs are in genesis (development clusters usually include them)
2. Deploy missing programs using deploy-spl-programs.sh
3. Verify program IDs match Solana mainnet/devnet IDs

## Production Checklist

- [ ] System limits configured (nofile: 1M, memlock: unlimited)
- [ ] Public IP configured in cluster.conf
- [ ] Firewall rules configured (Azure NSG)
- [ ] Persistent storage configured (Docker volumes or K8s PVCs)
- [ ] Monitoring and logging set up
- [ ] Backup strategy implemented
- [ ] SPL programs verified/deployed
- [ ] Multi-validator cluster tested
- [ ] External access verified
- [ ] Documentation updated for your environment
