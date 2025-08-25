# Docker Chainguard Secure Images Migration Guide

This document outlines the changes made to the Dockerfiles in this repository to use Chainguard secure base images following security best practices.

## Summary of Changes

All Dockerfiles have been updated to use Chainguard secure base images instead of traditional Linux distributions. This significantly reduces the attack surface and improves security while maintaining necessary functionality.

### Updated Dockerfiles

1. **Root Dockerfile** (Rust OpenFGA operator)
2. **demos/banking-app/Dockerfile** (Node.js application)  
3. **demos/genai-rag-agent/Dockerfile** (Python application)

## Key Improvements

### Security Benefits
- **Minimal attack surface**: Only essential runtime components included
- **Non-root execution**: All containers run as uid 65532 (nonroot user)
- **Smaller image sizes**: Optimized runtime dependencies
- **Supply chain security**: Chainguard's trusted build process and vulnerability scanning
- **Regular updates**: Automated security patches and CVE remediation

### Image Changes

| Component | Original Base | New Base | Security Benefits |
|-----------|---------------|----------|-------------------|
| OpenFGA Operator | `debian:bookworm-slim` | `cgr.dev/chainguard/gcc-glibc:latest-dev` | Minimal glibc runtime with dev tools |
| Banking App | `node:18-alpine` | `cgr.dev/chainguard/node:latest-dev` | Hardened Node.js runtime with curl |
| GenAI RAG Agent | `python:3.11-slim` | `cgr.dev/chainguard/python:latest-dev` | Minimal Python runtime with dev tools |

## Health Checks Maintained

### Development Variants for Operational Support

All images use Chainguard's `-dev` variants which include essential operational tools like curl while maintaining security:

```dockerfile
# Health check using curl (available in -dev variant)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1
```

### No Breaking Changes

Unlike distroless images, health checks are preserved, eliminating the need for users to migrate their monitoring setup.

```yaml
# Kubernetes deployment example
## Dockerfile Details

### Root Dockerfile (OpenFGA Operator)

**Changes made**:
- Base image: `debian:bookworm-slim` → `cgr.dev/chainguard/gcc-glibc:latest-dev`
- Multi-stage build for optimized dependencies
- Maintained health check using curl (included in -dev variant)
- Uses Chainguard non-root user (uid 65532)

**Runtime requirements**: Compiled Rust binary, glibc, and minimal dev tools for health checks

### Banking App Dockerfile (Node.js)

**Changes made**:
- Runtime base: `node:18-alpine` → `cgr.dev/chainguard/node:latest-dev`
- Converted to multi-stage build (builder → deps → runtime)
- Optimized dependency installation (dev vs production)
- Maintained health check using Node.js http module
- Uses Chainguard non-root user (uid 65532)

**Build stages**:
1. **Builder**: Install all dependencies and build TypeScript
2. **Deps**: Install only production dependencies
3. **Runtime**: Chainguard image with app and production deps

### GenAI RAG Agent Dockerfile (Python)

**Changes made**:
- Runtime base: `python:3.11-slim` → `cgr.dev/chainguard/python:latest-dev`
- Multi-stage build for Python package compilation
- Maintained curl-based health check (included in -dev variant)
- Uses Chainguard non-root user (uid 65532)

**Build stages**:
1. **Builder**: Install system dependencies and Python packages
2. **Runtime**: Chainguard image with compiled packages

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

### What's Included in Chainguard Dev Images

- **cgr.dev/chainguard/gcc-glibc:latest-dev**: glibc, minimal C library dependencies, and dev tools
- **cgr.dev/chainguard/node:latest-dev**: Node.js runtime, dependencies, and curl for health checks
- **cgr.dev/chainguard/python:latest-dev**: Python 3 runtime, standard library, and dev tools

### What's NOT Included

- No unnecessary binaries or libraries
- Minimal package manager footprint
- No text editors (`vi`, `nano`)
- Reduced system utilities
- Hardened against common attack vectors

### Debugging Chainguard Containers

The `-dev` variants include essential debugging tools while maintaining security:

1. **Health check tools**: curl and basic networking utilities
2. **Runtime debugging**: Basic shell access for troubleshooting
3. **Development tools**: Minimal set for operational needs
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