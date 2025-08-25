# GitHub Container Registry Integration for Minikube Deployments

This document explains the new GitHub Container Registry (GHCR) integration that resolves Minikube image loading issues and provides a more reliable deployment experience.

## Problem Statement

The original Minikube deployment approach had several limitations:
- Local-only image builds that couldn't be cached properly by Minikube
- Frequent "image is not known and cannot be cached" errors
- No fallback when local image loading failed
- Difficulty in sharing consistent images across environments

## Solution: GitHub Container Registry Integration

The new approach uses GitHub Container Registry (GHCR) to store and distribute pre-built container images, providing:

### ✅ Benefits

1. **Reliability**: No more local image loading failures
2. **Speed**: Skip local builds, use pre-built images
3. **Consistency**: Same image across all environments
4. **Automation**: Images built and published via GitHub Actions
5. **Fallback**: Automatic retry with different strategies

### 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub        │    │   GitHub        │    │   Minikube      │
│   Repository    │───▶│   Container     │───▶│   Kubernetes    │
│   (Source)      │    │   Registry      │    │   Cluster       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                        │                        │
        │                        │                        │
    Code Push              Image Build                Image Pull
   (main/develop)         & Publish                 & Deploy
```

## Usage

### Quick Start (Recommended)

Use the enhanced deployment script for an interactive experience:

```bash
./scripts/minikube/deploy-operator-enhanced.sh
```

### Registry-Based Deployment (Recommended)

Deploy using pre-built images from GHCR:

```bash
# Default deployment using latest image
make minikube-deploy-registry

# Or complete setup with validation
make minikube-setup-and-deploy-registry

# Custom image tag
IMAGE_TAG=v1.0.0 make minikube-deploy-registry

# Custom registry
IMAGE_REGISTRY=my-registry.com/my-org/openfga-operator make minikube-deploy-registry
```

### Local Build Deployment (Development)

For development when you need to test local changes:

```bash
# Build locally and deploy
make minikube-deploy-local

# Or complete setup with validation
make minikube-setup-and-deploy-local
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `IMAGE_REGISTRY` | `ghcr.io/jralmaraz/authcore-openfga-operator` | Container registry URL |
| `IMAGE_TAG` | `latest` | Image tag to deploy |
| `LOCAL_IMAGE_NAME` | `openfga-operator:latest` | Local image name for builds |

### Example Configurations

#### Production Deployment
```bash
export IMAGE_REGISTRY=ghcr.io/jralmaraz/authcore-openfga-operator
export IMAGE_TAG=v1.0.0
make minikube-deploy-registry
```

#### Development with Custom Registry
```bash
export IMAGE_REGISTRY=my-company.azurecr.io/openfga-operator
export IMAGE_TAG=dev-latest
make minikube-deploy-registry
```

## GitHub Actions Integration

### Automated Image Building

The `.github/workflows/build-and-publish.yml` workflow automatically:

1. **Builds** multi-platform images (linux/amd64, linux/arm64)
2. **Tests** image functionality
3. **Publishes** to GitHub Container Registry
4. **Tags** images appropriately based on:
   - Branch names (e.g., `main`, `develop`)
   - Pull request numbers (e.g., `pr-123`)
   - Git tags (e.g., `v1.0.0`)
   - Commit SHAs (e.g., `main-abc1234`)

### Image Tags

| Trigger | Tag Format | Example |
|---------|------------|---------|
| Push to main | `latest` | `ghcr.io/jralmaraz/authcore-openfga-operator:latest` |
| Push to develop | `develop` | `ghcr.io/jralmaraz/authcore-openfga-operator:develop` |
| Git tag | `v1.0.0`, `v1.0`, `v1` | `ghcr.io/jralmaraz/authcore-openfga-operator:v1.0.0` |
| Pull request | `pr-123` | `ghcr.io/jralmaraz/authcore-openfga-operator:pr-123` |

## Troubleshooting

### Common Issues and Solutions

#### 1. Image Pull Failures

**Problem**: `ImagePullBackOff` or `ErrImagePull`

**Solutions**:
```bash
# Check if image exists
docker pull ghcr.io/jralmaraz/authcore-openfga-operator:latest

# Verify image tag
docker image ls | grep openfga-operator

# Check Minikube's ability to pull
minikube ssh -- docker pull ghcr.io/jralmaraz/authcore-openfga-operator:latest
```

#### 2. Permission Issues

**Problem**: Access denied to GHCR

**Solutions**:
```bash
# For private repositories, login to GHCR
docker login ghcr.io -u YOUR_USERNAME

# Check if repository is public
curl -s https://ghcr.io/v2/jralmaraz/authcore-openfga-operator/tags/list
```

#### 3. Network Issues

**Problem**: Cannot reach GitHub Container Registry

**Solutions**:
```bash
# Test connectivity
curl -I https://ghcr.io

# Use local build as fallback
make minikube-deploy-local

# Check proxy settings
echo $HTTP_PROXY $HTTPS_PROXY
```

### Debug Commands

```bash
# Check deployment status
kubectl get pods -n openfga-system
kubectl describe pod -n openfga-system -l app=openfga-operator

# View operator logs
kubectl logs -n openfga-system -l app=openfga-operator

# Check image details
kubectl get deployment openfga-operator -n openfga-system -o yaml | grep image:

# Validate image in Minikube
minikube ssh -- docker images | grep openfga-operator
```

## Migration Guide

### From Local-Only to Registry-Based

1. **Update existing deployments**:
   ```bash
   # Clean up old deployment
   kubectl delete deployment openfga-operator -n openfga-system
   
   # Deploy with registry image
   make minikube-deploy-registry
   ```

2. **Update CI/CD pipelines**:
   ```bash
   # Old approach
   make minikube-build
   make minikube-deploy
   
   # New approach
   make minikube-deploy-registry
   ```

3. **Update documentation and scripts**:
   - Replace `minikube-deploy` with `minikube-deploy-registry`
   - Add `IMAGE_REGISTRY` and `IMAGE_TAG` environment variables
   - Update deployment instructions

## Best Practices

### For Development

1. **Use registry images** for most testing
2. **Use local builds** only when testing code changes
3. **Tag images properly** when publishing custom versions
4. **Clean up local images** regularly to save space

### For Production

1. **Always use specific tags** (not `latest`)
2. **Verify image signatures** if security is critical
3. **Use private registries** for proprietary code
4. **Implement image scanning** in CI/CD pipeline

### For CI/CD

1. **Cache layers** for faster builds
2. **Build multi-platform images** for compatibility
3. **Tag images consistently** across environments
4. **Automate security scanning** and vulnerability checks

## Security Considerations

### Image Security

- **Distroless base images**: Uses Chainguard images for minimal attack surface
- **Non-root execution**: Runs as non-privileged user (uid 65532)
- **Read-only filesystem**: Container filesystem is read-only
- **Security scanning**: Automated vulnerability scanning in CI

### Registry Security

- **Private repositories**: Control access to container images
- **Token authentication**: Use GitHub tokens for CI/CD access
- **Image signing**: Consider signing images for supply chain security
- **Audit logs**: Monitor image pulls and registry access

## Performance Optimization

### Build Performance

- **Layer caching**: Optimize Dockerfile for better layer reuse
- **Multi-stage builds**: Separate build and runtime environments
- **Dependency caching**: Cache Cargo dependencies between builds
- **Parallel builds**: Build multiple platforms simultaneously

### Deployment Performance

- **Image locality**: Use registry close to deployment region
- **Pre-pulling**: Pre-pull images during cluster setup
- **Image compression**: Optimize image size for faster pulls
- **Local caching**: Leverage Docker layer caching in CI

## Conclusion

The GitHub Container Registry integration significantly improves the reliability and user experience of Minikube deployments by:

- ✅ Eliminating local image loading failures
- ✅ Providing consistent, tested images
- ✅ Enabling automated deployment workflows
- ✅ Supporting both development and production use cases

This approach follows container industry best practices and provides a solid foundation for scaling the OpenFGA operator deployment across different environments.