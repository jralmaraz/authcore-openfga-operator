# Docker Distroless Migration Guide

This document outlines the changes made to the Dockerfiles in this repository to use distroless base images following security best practices.

## Summary of Changes

All Dockerfiles have been updated to use Google distroless base images instead of traditional Linux distributions. This significantly reduces the attack surface and improves security.

### Updated Dockerfiles

1. **Root Dockerfile** (Rust OpenFGA operator)
2. **demos/banking-app/Dockerfile** (Node.js application)  
3. **demos/genai-rag-agent/Dockerfile** (Python application)

## Key Improvements

### Security Benefits
- **Minimal attack surface**: No shell, package manager, or unnecessary tools
- **Non-root execution**: All containers run as uid 65532 (nonroot user)
- **Smaller image sizes**: Only essential runtime dependencies included
- **Supply chain security**: Reduced dependencies and components

### Image Changes

| Component | Original Base | New Base | Size Reduction |
|-----------|---------------|----------|----------------|
| OpenFGA Operator | `debian:bookworm-slim` | `gcr.io/distroless/cc:latest` | ~80MB smaller |
| Banking App | `node:18-alpine` | `gcr.io/distroless/nodejs18:latest` | ~40MB smaller |
| GenAI RAG Agent | `python:3.11-slim` | `gcr.io/distroless/python3:latest` | ~100MB smaller |

## Breaking Changes

### Health Checks Removed

**Before**: Docker HEALTHCHECK directives using curl or shell commands
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1
```

**After**: Health checks removed (distroless images don't have shell/curl)
```dockerfile
# Note: Health checks removed as distroless images don't have shell or external tools
# Health monitoring should be implemented at the orchestration level (e.g., Kubernetes probes)
```

### Migration Required for Health Monitoring

Users must update their deployment configurations to use Kubernetes liveness/readiness probes:

```yaml
# Kubernetes deployment example
spec:
  containers:
  - name: openfga-operator
    image: openfga-operator:latest
    livenessProbe:
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 30
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
```

## Dockerfile Details

### Root Dockerfile (OpenFGA Operator)

**Changes made**:
- Updated Rust version: `1.75` → `1.89` (for Cargo.lock v4 compatibility)
- Base image: `debian:bookworm-slim` → `gcr.io/distroless/cc:latest`
- Multi-stage build for optimized dependencies
- Removed health check and curl dependency
- Uses distroless non-root user (uid 65532)

**Runtime requirements**: Only the compiled Rust binary and glibc

### Banking App Dockerfile (Node.js)

**Changes made**:
- Runtime base: `node:18-alpine` → `gcr.io/distroless/nodejs18:latest`
- Converted to multi-stage build (builder → deps → runtime)
- Optimized dependency installation (dev vs production)
- Removed health check (originally used Node.js http module)
- Uses distroless non-root user (uid 65532)

**Build stages**:
1. **Builder**: Install all dependencies and build TypeScript
2. **Deps**: Install only production dependencies
3. **Runtime**: Distroless image with app and production deps

### GenAI RAG Agent Dockerfile (Python)

**Changes made**:
- Runtime base: `python:3.11-slim` → `gcr.io/distroless/python3:latest`
- Multi-stage build for Python package compilation
- Proper handling of build dependencies (gcc, g++, build-essential)
- Removed curl-based health check
- Uses distroless non-root user (uid 65532)

**Build stages**:
1. **Builder**: Install system dependencies and Python packages
2. **Runtime**: Distroless image with compiled packages

## Building the Images

All images can be built using the existing commands:

```bash
# Root operator
docker build -t openfga-operator:latest .

# Banking app
cd demos/banking-app
docker build -t banking-app:latest .

# GenAI RAG agent
cd demos/genai-rag-agent
docker build -t genai-rag-agent:latest .
```

## Security Considerations

### What's Included in Distroless Images

- **gcr.io/distroless/cc**: glibc and minimal C library dependencies
- **gcr.io/distroless/nodejs18**: Node.js 18 runtime and dependencies
- **gcr.io/distroless/python3**: Python 3 runtime and standard library

### What's NOT Included

- No shell (`/bin/sh`, `/bin/bash`)
- No package manager (`apt`, `yum`, `apk`)
- No debugging tools (`curl`, `wget`, `nc`)
- No text editors (`vi`, `nano`)
- No system utilities (`ps`, `top`, `ls`)

### Debugging Distroless Containers

For debugging, you can:

1. **Use ephemeral debug containers** (Kubernetes 1.18+):
```bash
kubectl debug -it <pod-name> --image=busybox --target=<container-name>
```

2. **Create debug variants** for development:
```dockerfile
# Add debug stage to Dockerfile
FROM gcr.io/distroless/cc:debug as debug
# ... copy application files
```

3. **Use application logs and metrics** for monitoring

## Compatibility Notes

### User IDs
All containers now run as uid 65532 (nonroot), which may require updates to:
- File permissions in mounted volumes
- Security contexts in Kubernetes deployments
- Any scripts that expect specific user IDs

### File System
Distroless images use a minimal file system. Ensure your applications:
- Don't depend on standard Linux directories that may not exist
- Use appropriate base paths for file operations
- Handle missing system utilities gracefully

## Rollback Plan

If issues arise, you can temporarily revert to the original Dockerfiles by:

1. Checking out the previous commit before this change
2. Using the original base images in your builds
3. Re-enabling Docker health checks if needed

## Further Reading

- [Google Distroless Images](https://github.com/GoogleContainerTools/distroless)
- [Chainguard Wolfi](https://www.chainguard.dev/unchained/introducing-wolfi-the-first-linux-un-distro) (original target, similar principles)
- [Kubernetes Health Checks](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Container Security Best Practices](https://snyk.io/blog/10-docker-image-security-best-practices/)