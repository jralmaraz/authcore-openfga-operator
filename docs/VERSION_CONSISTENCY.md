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
   CARGO_VERSION=$(grep '^version\s*=\s*"' Cargo.toml | sed 's/.*"\([^"]*\)".*/\1/')
   ```

2. **Version Check (Warning Mode)**:
   ```bash
   TAG_VERSION=${GITHUB_REF#refs/tags/v}
   if [ "$TAG_VERSION" != "$CARGO_VERSION" ]; then
     echo "⚠️  Version mismatch detected!"
     echo "The workflow will automatically sync Cargo.toml to match the Git tag version."
     # Continue without failing
   fi
   ```

3. **Automatic Version Sync** (when mismatch detected):
   ```bash
   # Update Cargo.toml version to match Git tag
   sed -i "s/^version = \".*\"/version = \"$TAG_VERSION\"/" Cargo.toml
   
   # Commit and push to main branch
   git add Cargo.toml
   git commit -m "chore: sync Cargo.toml version to $TAG_VERSION for release"
   git push origin main
   ```

4. **Docker Build with Synchronized Version**:
   ```yaml
   build-args:
     - BUILDKIT_INLINE_CACHE=1
     - VERSION=${{ steps.final_version.outputs.version }}
   ```

### Build Process

1. **Trigger**: Push of tag prefixed with `v` (e.g., `v0.1.0`)
2. **Extract**: Version from `Cargo.toml`
3. **Check**: Git tag version against package version
4. **Auto-sync**: Update `Cargo.toml` if mismatch detected (with commit to main)
5. **Build**: Container with synchronized version information
6. **Publish**: Using the correct version tags

## Usage

### Creating a Release

**New Simplified Process (Automated):**

1. Create and push git tag:
   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```

2. GitHub Actions will automatically:
   - Extract version from current `Cargo.toml`
   - Check if tag `v0.2.0` matches package version
   - **If mismatch**: Automatically sync `Cargo.toml` to version `0.2.0` and commit to main
   - **If match**: Continue with existing version
   - Build container with correct `VERSION=0.2.0`
   - Publish with appropriate tags

**Traditional Process (Still Supported):**

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

**New Automated Behavior:**

If versions don't match, the workflow will emit a warning and automatically sync:

```
⚠️  Version mismatch detected!
Git tag version (0.2.0) does not match Cargo.toml version (0.1.0)
The workflow will automatically sync Cargo.toml to match the Git tag version.
🔄 Syncing Cargo.toml version to match Git tag: 0.2.0
✅ Successfully synced and committed Cargo.toml version update
```

The workflow will:
1. Detect the version mismatch
2. Emit a warning (not fail)
3. Update `Cargo.toml` to match the Git tag version
4. Commit the change to the main branch
5. Continue with the build using the synchronized version

**Legacy Behavior (Preserved for Reference):**

Previously, version mismatches would cause build failures with:

```
❌ Version mismatch detected!
Git tag version (0.2.0) does not match Cargo.toml version (0.1.0)
Please ensure the git tag version matches the version in Cargo.toml
```

## Benefits

1. **Consistency**: Ensures package and container versions always match
2. **Full Automation**: Zero manual intervention required for version synchronization
3. **Simplified Release Process**: Create tag and let automation handle the rest
4. **Traceability**: Container images include version metadata
5. **Error Prevention**: Prevents release of incorrectly versioned containers
6. **Developer Experience**: Automated sync with clear progress messages
7. **Backward Compatibility**: Traditional manual process still works seamlessly

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