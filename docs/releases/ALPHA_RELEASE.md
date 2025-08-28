# OpenFGA Operator Alpha Release (v0.1.0-alpha)

## Overview

This document provides comprehensive instructions for deploying and using the OpenFGA Operator v0.1.0-alpha release.

## Features Included

- ✅ Core operator functionality with security-first design
- ✅ Advanced admission controller framework
- ✅ Git commit verification and developer authentication
- ✅ Malicious code injection analysis
- ✅ Container image scanning and vulnerability assessment
- ✅ Support for both Docker and Podman container runtimes
- ✅ Comprehensive shell compatibility (bash, dash, etc.)
- ✅ Minikube deployment scripts and validation

## Prerequisites

- Kubernetes cluster (v1.20+)
- kubectl configured for your cluster
- Docker or Podman (for local builds)
- Minikube (for local development)

## Quick Start

### Option 1: Deploy from Container Registry (Recommended)

```bash
# Install CRDs
make install-crds

# Deploy the alpha release
IMAGE_TAG=v0.1.0-alpha make minikube-deploy-registry
```

### Option 2: Pull Docker Image Manually

```bash
# Pull the alpha image
docker pull ghcr.io/jralmaraz/authcore-openfga-operator:v0.1.0-alpha

# Tag for local use
docker tag ghcr.io/jralmaraz/authcore-openfga-operator:v0.1.0-alpha openfga-operator:latest

# Deploy using standard scripts
./scripts/minikube/deploy-operator.sh
```

### Option 3: Build from Source

```bash
# Clone the repository
git clone https://github.com/jralmaraz/authcore-openfga-operator
cd authcore-openfga-operator

# Checkout the alpha tag
git checkout v0.1.0-alpha

# Build and deploy
make alpha-build
make minikube-deploy-local
```

## Docker Registry Information

The OpenFGA Operator alpha release is available on GitHub Container Registry:

- **Registry**: `ghcr.io/jralmaraz/authcore-openfga-operator`
- **Alpha Tag**: `v0.1.0-alpha`
- **Latest Tag**: `latest` (also points to alpha)

### Pulling Images

```bash
# Pull specific alpha version
docker pull ghcr.io/jralmaraz/authcore-openfga-operator:v0.1.0-alpha

# Pull latest (alpha)
docker pull ghcr.io/jralmaraz/authcore-openfga-operator:latest

# Using Podman
podman pull ghcr.io/jralmaraz/authcore-openfga-operator:v0.1.0-alpha
```

## Deployment Options

### Minikube Deployment

```bash
# Complete setup and deployment
make minikube-setup-and-deploy-registry

# Or step by step
minikube start
make install-crds
IMAGE_TAG=v0.1.0-alpha make minikube-deploy-registry
```

### Production Kubernetes

```bash
# Install CRDs
kubectl apply -f crds/

# Create namespace
kubectl create namespace openfga-system

# Deploy operator
kubectl apply -f k8s/
```

## Validation

After deployment, validate the operator is working:

```bash
# Check operator pod
kubectl get pods -n openfga-system

# Check CRDs are installed
kubectl get crd openfgas.authorization.openfga.dev

# Run validation script
./scripts/minikube/validate-deployment.sh
```

## Known Issues and Limitations

### Alpha Release Limitations

- This is an alpha release intended for testing and evaluation
- Not recommended for production use
- APIs may change in future releases
- Limited error handling in some edge cases

### Workarounds

- If deployment fails, try cleaning up and redeploying:
  ```bash
  kubectl delete namespace openfga-system
  make minikube-deploy-registry
  ```

## Configuration

### Environment Variables

- `CONTAINER_RUNTIME`: Set to `docker` or `podman` to specify runtime
- `IMAGE_TAG`: Override the image tag (default: `latest`)
- `IMAGE_REGISTRY`: Override the registry (default: `ghcr.io/jralmaraz/authcore-openfga-operator`)

### Example Custom Deployment

```bash
# Use Podman with specific tag
CONTAINER_RUNTIME=podman IMAGE_TAG=v0.1.0-alpha make minikube-deploy-registry
```

## Troubleshooting

### Common Issues

1. **Image Pull Errors**
   ```bash
   # Verify image exists
   docker pull ghcr.io/jralmaraz/authcore-openfga-operator:v0.1.0-alpha
   ```

2. **CRD Installation Failures**
   ```bash
   # Manually install CRDs
   kubectl apply -f crds/openfga.authorization.openfga.dev_openfgas.yaml
   ```

3. **Operator Pod Not Starting**
   ```bash
   # Check logs
   kubectl logs -n openfga-system -l app=openfga-operator
   ```

### Getting Help

- **Issues**: [GitHub Issues](https://github.com/jralmaraz/authcore-openfga-operator/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jralmaraz/authcore-openfga-operator/discussions)
- **Security**: security@openfga.dev

## Next Steps

After successful deployment:

1. Deploy demo applications: `./scripts/deploy-demos.sh`
2. Explore examples in the `examples/` directory
3. Read the comprehensive documentation in `docs/`
4. Provide feedback through GitHub issues

## Upgrade Path

When v0.2.0 is released:

```bash
# Update to next version
IMAGE_TAG=v0.2.0 make minikube-deploy-registry
```

## Release Notes

### v0.1.0-alpha

- Initial alpha release
- Core operator functionality
- Security-first architecture
- Container runtime flexibility
- Comprehensive deployment scripts
- Shell compatibility improvements