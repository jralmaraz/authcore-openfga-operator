# Manual Podman Image Upload Enhancement

## Overview

The `deploy-operator.sh` script has been enhanced to handle manual Podman image upload cases more effectively, particularly when Podman is used as the container runtime and standard image loading fails.

## New Features

### 1. Manual Podman Image Save as Tarball
- **Function**: `save_podman_image_as_tarball()`
- **Purpose**: Saves a Podman image as a tarball file for manual transfer
- **Features**:
  - Saves image using `podman save`
  - Verifies tarball creation and size
  - Provides size information in MB
  - Proper error handling and logging

### 2. Tarball Transfer to Minikube
- **Function**: `transfer_and_import_tarball()`
- **Purpose**: Transfers tarball to Minikube and imports it into containerd
- **Features**:
  - Primary method: Direct `minikube image load` with tarball
  - Fallback method: Copy to Minikube + `ctr` import
  - Automatic cleanup of temporary files
  - Integration with Minikube's containerd runtime

### 3. SHA Hash Verification
- **Function**: `verify_image_sha_in_minikube()`
- **Purpose**: Verifies image integrity by checking SHA hashes
- **Features**:
  - Extracts SHA from Minikube using `ctr` or `crictl`
  - Compares with local image SHA
  - Multiple verification methods for compatibility
  - Detailed logging of verification results

### 4. Local Image SHA Extraction
- **Function**: `get_local_image_sha()`
- **Purpose**: Extracts SHA hash from local images
- **Features**:
  - Supports both Podman and Docker
  - Returns truncated SHA (12 characters) for comparison
  - Proper error handling for missing images

### 5. Enhanced Build Process
- **Function**: `manual_podman_image_upload()`
- **Purpose**: Orchestrates the complete manual upload process
- **Features**:
  - Temporary directory management with cleanup
  - Retry logic (3 attempts by default)
  - Comprehensive error handling
  - Step-by-step progress logging
  - Automatic cleanup on exit

## Integration

The enhanced functionality is integrated into the existing `build_container_image()` function:

1. **Standard Approach First**: Attempts standard `minikube image load`
2. **Automatic Fallback**: Falls back to manual tarball upload on failure
3. **Podman-Specific Logic**: Only activates for Podman runtime
4. **Docker Compatibility**: Preserves existing Docker behavior

## Logging and Error Handling

### Comprehensive Logging
- **Info**: Process steps and progress updates
- **Success**: Successful completion of steps
- **Warning**: Non-fatal issues and fallback scenarios
- **Error**: Fatal errors with detailed context

### Error Scenarios Handled
- Image not found locally
- Tarball creation failures
- Transfer failures to Minikube
- Import failures in containerd
- SHA verification mismatches
- Temporary directory creation issues

### Retry Logic
- **Standard Load**: 2 attempts with 2-second delays
- **Manual Upload**: 3 attempts with 5-second delays
- **Individual Steps**: Specific retry counts per operation

## Usage

The enhancement is transparent to existing users:

```bash
# Existing command continues to work
./scripts/minikube/deploy-operator.sh

# With Podman runtime
CONTAINER_RUNTIME=podman ./scripts/minikube/deploy-operator.sh
```

### Manual Function Usage
```bash
# For testing or manual operations
source scripts/minikube/deploy-operator.sh

# Save image as tarball
save_podman_image_as_tarball "myimage:latest" "/tmp/myimage.tar"

# Transfer and import
transfer_and_import_tarball "/tmp/myimage.tar" "myimage:latest"

# Verify SHA
verify_image_sha_in_minikube "myimage:latest" "abc123def456"
```

## Benefits

1. **Resilience**: Handles cases where standard image loading fails
2. **Reliability**: Multiple fallback mechanisms ensure successful deployment
3. **Transparency**: Enhanced logging provides clear feedback
4. **Compatibility**: Maintains backward compatibility with existing workflows
5. **Verification**: SHA checking ensures image integrity
6. **Cleanup**: Automatic cleanup prevents disk space issues

## Technical Details

### Temporary File Management
- Uses process-specific temporary directories (`/tmp/minikube-image-upload-$$`)
- Implements cleanup traps to ensure file removal
- Provides size information for debugging

### Minikube Integration
- Direct integration with Minikube's containerd runtime
- Uses `ctr -n k8s.io` for image operations
- Fallback to `crictl` for compatibility
- Automatic cleanup of transferred files

### Security Considerations
- Uses `sudo` only when necessary for containerd operations
- Implements proper file permissions
- Cleans up temporary files automatically
- Validates file existence and content before operations

## Testing

The enhancement includes comprehensive test coverage:
- Unit tests for individual functions
- Integration tests for the complete workflow
- Error condition testing
- Backward compatibility validation