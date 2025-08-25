# Container Runtime Support - Quick Reference

The authcore-openfga-operator now supports both Docker and Podman as container runtimes. This provides flexibility for users who prefer different container technologies or have licensing considerations.

## Runtime Selection Methods

### 1. Environment Variable (Recommended)
```bash
# Set globally for session
export CONTAINER_RUNTIME=podman

# Set for specific command
CONTAINER_RUNTIME=podman make container-build
```

### 2. Command Line Options
```bash
# Shell scripts
./scripts/minikube/setup-minikube.sh --runtime podman

# PowerShell scripts  
.\scripts\minikube\setup-minikube.ps1 -Runtime podman
```

### 3. Automatic Detection
If no preference is specified, the system automatically detects available runtimes:
1. Docker (if available)
2. Podman (if Docker not available)
3. Error if neither is available

## Common Usage Patterns

### Development Workflow
```bash
# Setup with preferred runtime
export CONTAINER_RUNTIME=podman
./scripts/minikube/setup-minikube.sh
./scripts/minikube/deploy-operator.sh

# Build with specific runtime
CONTAINER_RUNTIME=docker make container-build
```

### CI/CD Integration
```bash
# In your CI/CD scripts
if command -v podman >/dev/null 2>&1; then
    export CONTAINER_RUNTIME=podman
fi

make container-build
```

## Backward Compatibility

All existing Docker commands continue to work:
- `make docker-build` → uses detected runtime
- Scripts without runtime flags → use Docker if available
- Existing documentation examples → work unchanged

## Runtime-Specific Features

### Docker
- Mature ecosystem and tooling
- Broad compatibility
- Default choice for most users

### Podman
- Rootless execution by default
- No daemon required
- Enhanced security model
- Red Hat/RHEL integration

## Troubleshooting

### Check which runtime will be used:
```bash
make detect-runtime
```

### Verify runtime installation:
```bash
docker --version  # or podman --version
```

### Force specific runtime:
```bash
export CONTAINER_RUNTIME=podman
```

### Reset to auto-detection:
```bash
unset CONTAINER_RUNTIME
```