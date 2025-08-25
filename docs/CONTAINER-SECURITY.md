# Container Security Notes for Podman Permission Fixes

## Security Implications

The Dockerfile has been updated to address permission issues with rootless Podman builds while maintaining security best practices:

### User Switching Strategy

The Dockerfile uses a strategic approach to user switching:
- **USER root**: Only used temporarily for permission operations
- **USER 1000**: Used for all build operations to maintain non-root security
- **Final runtime**: Uses Chainguard's nonroot user (uid 65532) for maximum security

### Permission Model

The permission fixes follow these security principles:

1. **Minimal Privilege**: Root access is only used for `chown` operations
2. **Explicit Permissions**: All file permissions are explicitly set rather than relying on defaults
3. **Defense in Depth**: Multiple permission checks at different build stages
4. **No Persistent Root**: No operations run as root in the final container

### Rootless Container Compatibility

The changes specifically address rootless Podman issues:
- Files copied into containers have different ownership in rootless mode
- User namespace mapping requires explicit ownership management
- Cargo build artifacts need specific permission handling

### Security Validation

The container maintains security posture:
- ✅ No privileged containers required
- ✅ No persistent root processes
- ✅ Minimal attack surface with Chainguard base images
- ✅ Read-only filesystem compatible
- ✅ Non-root user in final runtime

### Alternative Security Approaches

If the permission fixes don't work in your environment, consider these alternatives:

1. **User Namespace Configuration**: Configure proper user namespace mapping
2. **SELinux Policies**: Create specific SELinux policies for container builds
3. **Podman Configuration**: Tune Podman settings for your environment
4. **Volume Mounts**: Use volume mounts with proper permissions for build artifacts

See [PODMAN.md](PODMAN.md) for detailed troubleshooting steps.