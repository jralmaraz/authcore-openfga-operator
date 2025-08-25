# Improved Minikube Image Loading

## Overview

The authcore-openfga-operator deployment scripts have been enhanced to provide more reliable image loading into Minikube clusters. This document explains the improvements and troubleshooting steps.

## New Features

### 1. Minikube Docker Environment Integration

The deployment script now uses Minikube's docker environment when possible, ensuring images are built directly in Minikube's context:

```bash
# Configure shell to use Minikube's Docker daemon
eval $(minikube docker-env)

# Build image directly in Minikube
docker build -t openfga-operator:latest .

# Reset environment when done
eval $(minikube docker-env -u)
```

### 2. Automatic Runtime Detection

The script automatically detects and configures the best approach based on:
- Minikube's driver (Docker vs other)
- Available container runtime (Docker vs Podman)
- Runtime compatibility

### 3. Image Verification

All image loading operations now include verification to ensure images are available:

```bash
# Verify image is loaded
minikube image ls | grep openfga-operator
```

## Build Strategies

### Strategy 1: Minikube Docker Environment (Recommended)

Used when:
- Minikube is using Docker driver
- Docker is available on the host

Benefits:
- Images built directly in Minikube's context
- No additional image loading required
- Faster deployment
- More reliable

### Strategy 2: Build and Load (Fallback)

Used when:
- Minikube uses non-Docker driver (e.g., VirtualBox, KVM)
- Only Podman is available
- Docker environment configuration fails

Process:
1. Build image locally with available runtime
2. Load image into Minikube using `minikube image load`
3. Verify image availability

## Using the Makefile

New Makefile targets are available:

```bash
# Build using Minikube's Docker environment (recommended)
make minikube-build

# Traditional build and load
make container-build minikube-load

# Complete deployment with improved build
make minikube-deploy
```

## Troubleshooting

### Image Not Available in Cluster

If pods fail with ImagePullBackOff:

```bash
# Check if image exists in Minikube
minikube image ls | grep openfga-operator

# If not found, try improved build
make minikube-build

# Or manually using Minikube's Docker environment
eval $(minikube docker-env)
docker build -t openfga-operator:latest .
eval $(minikube docker-env -u)
```

### Podman with Minikube

When using Podman:

```bash
# Podman requires image loading approach
CONTAINER_RUNTIME=podman make container-build minikube-load
```

### Driver Compatibility

Check Minikube driver:

```bash
# Check current driver
minikube config get driver

# For Docker driver (recommended for improved builds)
minikube start --driver=docker

# For other drivers, fallback approach is used
minikube start --driver=virtualbox
```

## Error Handling

The improved scripts include better error handling:

- Verification of Minikube status before operations
- Confirmation that images are loaded successfully
- Fallback to alternative approaches on failure
- Clear error messages and recovery suggestions

## Performance Benefits

The improved approach provides:

- **Faster builds**: No image transfer between Docker contexts
- **Reduced disk usage**: Single copy of image in Minikube
- **Better reliability**: Direct build in target environment
- **Automatic verification**: Confirms successful image loading

## Migration from Previous Versions

No changes required for existing workflows. The scripts automatically:

1. Detect optimal build strategy
2. Fall back to previous approach if needed
3. Maintain compatibility with all container runtimes
4. Provide the same interface and outputs

Existing commands continue to work:

```bash
# These commands use improved logic automatically
./scripts/minikube/deploy-operator.sh
make minikube-deploy
```