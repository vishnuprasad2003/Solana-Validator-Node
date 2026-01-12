#!/bin/bash
#
# Build and Push Docker Image
# Helper script for building and pushing to container registry
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

REGISTRY="${REGISTRY:-}"
IMAGE_NAME="${IMAGE_NAME:-solana-validator}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
DOCKERFILE="${DOCKERFILE:-docker/Dockerfile.production}"

log_info "Building Docker Image"
log_info "Registry: ${REGISTRY:-<local>}"
log_info "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
log_info "Dockerfile: ${DOCKERFILE}"

# Build image
log_info "Building image..."
docker build -f "$DOCKERFILE" -t "${IMAGE_NAME}:${IMAGE_TAG}" "$WORKSPACE_ROOT" || {
    log_error "Failed to build Docker image"
    exit 1
}

log_success "Image built successfully"

# Push to registry if specified
if [[ -n "$REGISTRY" ]]; then
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    log_info "Tagging image as: $FULL_IMAGE_NAME"
    docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "$FULL_IMAGE_NAME" || {
        log_error "Failed to tag image"
        exit 1
    }
    
    log_info "Pushing to registry..."
    docker push "$FULL_IMAGE_NAME" || {
        log_error "Failed to push image"
        exit 1
    }
    
    log_success "Image pushed successfully: $FULL_IMAGE_NAME"
    log_info ""
    log_info "Update Kubernetes manifests with:"
    log_info "  sed -i 's|solana-validator:latest|${FULL_IMAGE_NAME}|g' kubernetes/*.yaml"
else
    log_info "No registry specified, skipping push"
    log_info "To push to registry, set REGISTRY environment variable:"
    log_info "  REGISTRY=<your-registry> ./scripts/build-and-push.sh"
fi
