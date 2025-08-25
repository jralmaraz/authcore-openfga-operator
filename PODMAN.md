# Podman Compatibility Guide

This document provides guidance on using Podman with the authcore-openfga-operator.

## Overview

The authcore-openfga-operator supports both Docker and Podman as container runtimes. However, Podman in rootless mode may encounter permission issues during the build process.

## Permission Issues

When using Podman in rootless mode, you may encounter permission errors such as:
- "Permission denied" when creating directories or files during container builds
- "Interactive authentication required" messages
- SELinux context-related errors

## Solutions

### Automatic Fallback

The Makefile has been configured to automatically handle Podman permission issues:

1. **First attempt**: Tries rootless Podman with security label disabled
2. **Fallback**: If the first attempt fails, automatically retries with `sudo`

### Manual Override

You can explicitly specify the container runtime:

```bash
# Use Docker (if available)
CONTAINER_RUNTIME=docker make container-build

# Use Podman with automatic permission handling
CONTAINER_RUNTIME=podman make container-build

# Force sudo usage (if you know rootless won't work)
sudo podman build -t openfga-operator:latest .
```

### Podman Configuration

For persistent rootless Podman usage, you may need to configure your system:

```bash
# Enable lingering for your user (may require root)
sudo loginctl enable-linger $(id -u)

# Check Podman configuration
podman info
```

## Build Process

The container build process includes:
1. Multi-stage build with Chainguard secure base images
2. Rust compilation in the builder stage
3. Minimal runtime image with proper user permissions

### Dockerfile Changes

The Dockerfile has been updated to handle permissions properly:
- Explicit permission setting for the build directory
- User switching to ensure proper ownership
- **HOME environment variable set explicitly** for Cargo (fixes "Cargo couldn't find your home directory" error)
- Graceful handling of directory creation

## Requirements

- Podman 3.0+ (rootless mode supported)
- For rootless mode: proper user namespace configuration
- For fallback: sudo access on the local machine

## Troubleshooting

### Cargo Home Directory Issues
If you encounter "Cargo couldn't find your home directory" error:
1. This has been fixed in the Dockerfile by explicitly setting `HOME=/tmp/cargo-home`
2. The directory is created with proper permissions for the build user
3. This fix ensures compatibility with rootless Podman builds

### Permission Denied Errors
If you encounter permission errors:
1. The build will automatically retry with sudo
2. Ensure your user has sudo privileges
3. Check SELinux configuration if applicable

### Network Issues
If you encounter network connectivity issues:
1. Check DNS resolution
2. Verify container registry access
3. Consider using a local registry mirror

### SELinux Issues
On SELinux-enabled systems:
1. The build uses `--security-opt label=disable` to bypass SELinux restrictions
2. Alternatively, configure SELinux policies for container builds

## Best Practices

1. **Use Docker when available** for simplest setup
2. **Configure rootless Podman properly** for security
3. **Keep sudo access available** as fallback for Podman
4. **Monitor build logs** for permission-related warnings

## Related Documentation

- [CHAINGUARD-MIGRATION.md](CHAINGUARD-MIGRATION.md) - Information about the secure base images
- [README.md](README.md) - General project documentation