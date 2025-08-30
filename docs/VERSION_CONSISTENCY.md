# Version Consistency Implementation

This document describes the version consistency mechanism implemented to ensure that the Rust package version in `Cargo.toml` matches the container image version.

## Problem Statement

Previously, there was no validation to ensure that the version in `Cargo.toml` matched the version used for tagging container images. This could lead to:

- Container images with incorrect version tags
- Confusion about which package version corresponds to which container
- Inconsistent versioning across the build pipeline

## Solution

The implementation introduces automated version consistency validation that:

1. **Extracts version from `Cargo.toml`** during the Docker build process
2. **Validates version consistency** between git tags and package version
3. **Embeds version information** in container images
4. **Only builds for valid version tags** prefixed with `v`

## Implementation Details

### Docker Build Changes

The `Dockerfile` now accepts a `VERSION` build argument:

```dockerfile
# Accept version as build argument
ARG VERSION
ENV VERSION=${VERSION}

# Add version information as labels for better traceability
LABEL org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.title="OpenFGA Operator" \
      org.opencontainers.image.description="Kubernetes operator for OpenFGA"
```

### GitHub Actions Workflow

The workflow now includes:

1. **Version Extraction**:
   ```bash
   CARGO_VERSION=$(grep '^version = ' Cargo.toml | cut -d '"' -f 2)
   ```

2. **Version Validation**:
   ```bash
   TAG_VERSION=${GITHUB_REF#refs/tags/v}
   if [ "$TAG_VERSION" != "$CARGO_VERSION" ]; then
     echo "❌ Version mismatch detected!"
     exit 1
   fi
   ```

3. **Docker Build with Version**:
   ```yaml
   build-args: |
     BUILDKIT_INLINE_CACHE=1
     VERSION=${{ steps.extract_version.outputs.cargo_version }}
   ```

### Build Process

1. **Trigger**: Push of tag prefixed with `v` (e.g., `v0.1.0`)
2. **Extract**: Version from `Cargo.toml`
3. **Validate**: Git tag version matches package version
4. **Build**: Container with embedded version information
5. **Publish**: Only if validation passes

## Usage

### Creating a Release

1. Update version in `Cargo.toml`:
   ```toml
   [package]
   version = "0.2.0"
   ```

2. Create and push git tag:
   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```

3. GitHub Actions will:
   - Extract version `0.2.0` from `Cargo.toml`
   - Validate tag `v0.2.0` matches package version `0.2.0`
   - Build container with `VERSION=0.2.0`
   - Publish with appropriate tags

### Version Mismatch Handling

If versions don't match, the build will fail with:

```
❌ Version mismatch detected!
Git tag version (0.2.0) does not match Cargo.toml version (0.1.0)
Please ensure the git tag version matches the version in Cargo.toml
```

## Benefits

1. **Consistency**: Ensures package and container versions always match
2. **Automation**: No manual intervention required for version synchronization
3. **Traceability**: Container images include version metadata
4. **Error Prevention**: Prevents release of incorrectly versioned containers
5. **Developer Experience**: Clear error messages when versions mismatch

## Verification

Check container version information:

```bash
# Check image labels
docker inspect ghcr.io/jralmaraz/authcore-openfga-operator:v0.1.0 \
  --format '{{.Config.Labels}}'

# Check environment variables
docker run --rm ghcr.io/jralmaraz/authcore-openfga-operator:v0.1.0 \
  env | grep VERSION
```

## Compatibility

- **Existing tags**: All existing workflows remain unchanged
- **Local builds**: Local builds work without VERSION argument (defaults to empty)
- **CI/CD**: Only affects tagged releases, not development builds