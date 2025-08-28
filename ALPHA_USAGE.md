# Alpha Release (v0.1.0-alpha) - Usage Examples

## Quick Start Commands

### Deploy from Registry (Recommended)
```bash
# Deploy the alpha release directly from GHCR
IMAGE_TAG=v0.1.0-alpha make minikube-deploy-registry
```

### Pull Docker Image
```bash
# Pull the alpha image
docker pull ghcr.io/jralmaraz/authcore-openfga-operator:v0.1.0-alpha

# Or using Podman
podman pull ghcr.io/jralmaraz/authcore-openfga-operator:v0.1.0-alpha
```

### Build and Release (For Maintainers)
```bash
# Build alpha release
make alpha-build

# Push to registry (requires authentication)
make alpha-push

# Complete alpha release process
make alpha-release
```

## Available Make Targets

```bash
# Build targets
make build                  # Build Rust binary
make container-build        # Build container image
make alpha-build           # Build alpha release image

# Testing targets
make test                  # Run all tests
make clippy                # Run linting

# Deployment targets
make install-crds          # Install CRDs
make minikube-deploy-registry  # Deploy from registry
make minikube-deploy-local     # Deploy local build

# Alpha release targets
make alpha-build           # Build alpha release image
make alpha-push            # Push alpha release to registry
make alpha-tag             # Create git tag
make alpha-release         # Complete alpha release process
```

## Configuration Variables

```bash
# Container runtime
CONTAINER_RUNTIME=docker    # or podman

# Image configuration
IMAGE_REGISTRY=ghcr.io/jralmaraz/authcore-openfga-operator
IMAGE_TAG=v0.1.0-alpha     # or latest
ALPHA_VERSION=v0.1.0-alpha

# Example usage
CONTAINER_RUNTIME=podman IMAGE_TAG=v0.1.0-alpha make minikube-deploy-registry
```

## Verification

```bash
# Check deployment
kubectl get pods -n openfga-system
kubectl get crd openfgas.authorization.openfga.dev

# Run validation
./scripts/minikube/validate-deployment.sh
```

## Alpha Release Features

✅ **Core Functionality**
- Kubernetes operator for OpenFGA
- Custom Resource Definitions (CRDs)
- Automated deployment and management

✅ **Security Features**
- Security-first design
- Admission controller framework
- Git commit verification
- Container image scanning

✅ **Deployment Features**
- Docker and Podman support
- Minikube integration
- Shell compatibility (bash, dash, etc.)
- Registry-based deployment

✅ **Quality Assurance**
- 40 passing tests
- Comprehensive linting
- Shell compatibility testing
- Deployment validation scripts