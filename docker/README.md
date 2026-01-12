# Docker Deployment Guide

This directory contains Docker files for containerized deployment.

## Files

- `Dockerfile.production`: Production Docker image
- `docker-compose.production.yml`: Multi-validator Docker Compose setup

## Quick Start

### Build Image

```bash
docker build -f docker/Dockerfile.production -t solana-validator:latest .
```

### Run with Docker Compose

```bash
# Set public IP (optional, for external access)
export PUBLIC_IP=<your-public-ip>

# Start cluster
docker-compose -f docker/docker-compose.production.yml up -d

# View logs
docker-compose -f docker/docker-compose.production.yml logs -f

# Stop cluster
docker-compose -f docker/docker-compose.production.yml down
```

### Run Single Container

```bash
# Bootstrap validator
docker run -d \
  --name solana-bootstrap \
  --ulimit nofile=1000000:1000000 \
  --ulimit memlock=-1:-1 \
  -p 8001:8001/udp -p 8001:8001/tcp \
  -p 8899:8899 -p 8900:8900 \
  -v $(pwd)/data/bootstrap:/app/data/bootstrap \
  -v $(pwd)/keys:/app/keys \
  -v $(pwd)/logs:/app/logs \
  -e NODE_NAME=bootstrap \
  -e NODE_ROLE=bootstrap \
  solana-validator:latest \
  /app/scripts/start-bootstrap.sh
```

## Volumes

- `bootstrap-ledger`: Bootstrap validator ledger (persistent)
- `validator-*-ledger`: Validator ledgers (persistent)
- `validator-keys`: Shared key storage (persistent)
- `*-logs`: Log files (can be ephemeral)

## Environment Variables

- `NODE_NAME`: Node identifier
- `NODE_ROLE`: bootstrap or validator
- `ENTRYPOINT_HOST`: Bootstrap hostname/IP
- `ENTRYPOINT_PORT`: Bootstrap gossip port
- `PUBLIC_IP`: Public IP for external access
- `RPC_BIND_ADDRESS`: RPC bind address (0.0.0.0 for external)

## Networking

The Docker Compose setup creates a bridge network `solana-cluster` where:
- Bootstrap is accessible as `bootstrap`
- Validators can reach bootstrap via `bootstrap:8001`

## External Access

To expose RPC externally:

```bash
# In docker-compose.production.yml, ensure ports are mapped:
ports:
  - "8899:8899"  # RPC
  - "8900:8900"  # WebSocket
```

Then access via: `http://<host-ip>:8899`

## Troubleshooting

### Container Exits Immediately

```bash
# Check logs
docker logs solana-bootstrap

# Check if limits are set
docker inspect solana-bootstrap | grep -A 10 Ulimits
```

### Cannot Connect to Bootstrap

```bash
# Check network
docker network inspect solana-cluster

# Test connectivity
docker exec solana-validator-1 ping -c 3 bootstrap
```
