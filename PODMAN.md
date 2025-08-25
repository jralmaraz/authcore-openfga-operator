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

The Dockerfile has been comprehensively updated to handle permissions properly for rootless Podman builds:
- **Multi-stage permission handling**: Ownership is fixed after each `COPY` operation since rootless Podman copies files with container-specific ownership
- **Cargo cache directory setup**: `CARGO_HOME` environment variable and directory are created with proper permissions
- **Target directory preparation**: Build target directory is created with proper permissions before any cargo operations
- **Incremental permission fixes**: Permissions are fixed after dependency build when .cargo-lock is first created
- **HOME environment variable set explicitly** for Cargo (fixes "Cargo couldn't find your home directory" error)
- **Comprehensive final permission fix** including specific .cargo-lock file handling using find command
- **Strategic user switching**: Uses `USER root` for permission operations, then switches back to `USER 1000` for security

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

### Cargo Lock File Permission Issues
If you encounter "Permission denied (os error 13)" when accessing `/app/target/release/.cargo-lock`:
1. **Comprehensive fix implemented**: The Dockerfile now handles permissions at multiple critical stages:
   - Sets proper ownership after each `COPY` operation (rootless Podman copies files with different ownership)
   - Creates target directory with proper permissions before cargo operations
   - Fixes permissions after dependency build (when .cargo-lock is first created)
   - Applies final permission fix with specific .cargo-lock file handling
2. **Multi-stage permission handling**: Uses `USER root` to fix ownership, then switches back to `USER 1000`
3. **Specific .cargo-lock handling**: Uses `find` command to locate and fix permissions on .cargo-lock files specifically
4. This comprehensive approach resolves all known rootless Podman permission issues with cargo build artifacts

### Permission Denied Errors
If you encounter permission errors:
1. The build will automatically retry with sudo
2. Ensure your user has sudo privileges
3. Check SELinux configuration if applicable

### Debugging Permission Issues
For troubleshooting remaining permission issues:
1. **Enable verbose logging**: Add `--log-level=debug` to podman build command
2. **Check file ownership in container**: 
   ```bash
   # Inspect intermediate container layers
   podman build --layers -t openfga-operator:debug .
   podman run --rm -it openfga-operator:debug ls -la /app/target/release/
   ```
3. **Verify user namespaces**: 
   ```bash
   podman unshare cat /proc/self/uid_map
   ```
4. **Alternative workaround**: If issues persist, you can force privileged build:
   ```bash
   sudo podman build --privileged -t openfga-operator:latest .
   ```

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
5. **Test your builds** using the provided test script

## Testing Podman Builds

A comprehensive test script is provided to validate Podman builds:

```bash
# Test both rootless and sudo Podman builds
make test-podman-build

# Or run directly
./scripts/test-podman-build.sh
```

The test script will:
- Test rootless Podman build first
- Fall back to sudo build if needed
- Validate the built container image
- Report which build methods work
- Clean up test artifacts

## Related Documentation

- [CHAINGUARD-MIGRATION.md](CHAINGUARD-MIGRATION.md) - Information about the secure base images
- [README.md](README.md) - General project documentation