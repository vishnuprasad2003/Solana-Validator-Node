# Kubernetes Deployment Guide

This directory contains Kubernetes manifests for deploying the Solana private cluster.

## Prerequisites

- Kubernetes cluster (1.20+)
- kubectl configured
- Storage class for persistent volumes
- Docker registry (for pushing images)

## Quick Start

### 1. Build and Push Image

```bash
# Build image
docker build -f docker/Dockerfile.production -t solana-validator:latest .

# Tag for your registry
docker tag solana-validator:latest <your-registry>/solana-validator:latest

# Push to registry
docker push <your-registry>/solana-validator:latest

# Update image in manifests
sed -i 's|solana-validator:latest|<your-registry>/solana-validator:latest|g' *.yaml
```

### 2. Deploy

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Create configmap
kubectl apply -f configmap.yaml

# Deploy bootstrap validator
kubectl apply -f bootstrap-validator.yaml

# Wait for bootstrap to be ready
kubectl wait --for=condition=ready pod -l app=solana-bootstrap -n solana-cluster --timeout=300s

# Deploy additional validators
kubectl apply -f validator.yaml
```

### 3. Access RPC

```bash
# Get service external IP (LoadBalancer)
kubectl get svc solana-bootstrap -n solana-cluster

# Or use port-forward for testing
kubectl port-forward svc/solana-bootstrap 8899:8899 -n solana-cluster
```

## Configuration

### Storage

Update PVC sizes in `bootstrap-validator.yaml` and `validator.yaml`:
- Bootstrap ledger: 500Gi (adjust based on needs)
- Validator ledger: 500Gi per validator

### Resources

Adjust resource requests/limits in manifests:
- Requests: memory: 4Gi, cpu: 2
- Limits: memory: 16Gi, cpu: 8

### Scaling

```bash
# Scale validators
kubectl scale statefulset solana-validator -n solana-cluster --replicas=5
```

## External Access

### LoadBalancer (Azure AKS, AWS EKS, GKE)

The bootstrap service uses `type: LoadBalancer` which automatically creates an external IP.

### NodePort (Self-hosted K8s)

Change service type to NodePort and access via `<node-ip>:<nodeport>`.

### Ingress (Optional)

For HTTP/HTTPS access, create an Ingress resource pointing to the RPC service.

## Monitoring

```bash
# View pods
kubectl get pods -n solana-cluster

# View logs
kubectl logs -f solana-bootstrap-0 -n solana-cluster

# Check resource usage
kubectl top pods -n solana-cluster
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n solana-cluster

# Check logs
kubectl logs <pod-name> -n solana-cluster
```

### Storage Issues

```bash
# Check PVC status
kubectl get pvc -n solana-cluster

# Check storage class
kubectl get storageclass
```

### Network Issues

```bash
# Check services
kubectl get svc -n solana-cluster

# Test connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- ping solana-bootstrap
```
