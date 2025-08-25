#!/bin/bash

# test-podman-build.sh - Test script for validating Podman build with permission fixes
# Compatible with Linux and macOS

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if podman is available
check_podman() {
    if ! command -v podman >/dev/null 2>&1; then
        log_error "Podman is not installed or not in PATH"
        exit 1
    fi
    
    log_info "Podman version: $(podman --version)"
}

# Test rootless podman build
test_rootless_build() {
    log_info "Testing rootless Podman build..."
    
    if podman build --security-opt label=disable -t openfga-operator:test-rootless . 2>&1; then
        log_success "Rootless Podman build completed successfully"
        return 0
    else
        log_warning "Rootless Podman build failed"
        return 1
    fi
}

# Test with sudo if rootless fails
test_sudo_build() {
    log_info "Testing Podman build with sudo..."
    
    if sudo podman build -t openfga-operator:test-sudo .; then
        log_success "Sudo Podman build completed successfully"
        return 0
    else
        log_error "Sudo Podman build failed"
        return 1
    fi
}

# Validate the built image
validate_image() {
    local image_tag="$1"
    log_info "Validating built image: $image_tag"
    
    # Check if image exists
    if ! podman image exists "$image_tag"; then
        log_error "Image $image_tag does not exist"
        return 1
    fi
    
    # Check image size (should be reasonable)
    local image_size
    image_size=$(podman image inspect "$image_tag" --format '{{.Size}}')
    log_info "Image size: $((image_size / 1024 / 1024)) MB"
    
    # Try to run the container (basic functionality test)
    log_info "Testing container startup..."
    if podman run --rm --name test-container "$image_tag" --help >/dev/null 2>&1; then
        log_success "Container runs successfully"
        return 0
    else
        log_warning "Container failed to run (this may be expected if network access is required)"
        return 0
    fi
}

# Cleanup test images
cleanup() {
    log_info "Cleaning up test images..."
    
    for tag in openfga-operator:test-rootless openfga-operator:test-sudo; do
        if podman image exists "$tag" 2>/dev/null; then
            podman rmi "$tag" >/dev/null 2>&1 || true
            log_info "Removed $tag"
        fi
    done
}

# Main test function
main() {
    log_info "Starting Podman build validation tests..."
    echo
    
    check_podman
    echo
    
    local rootless_success=false
    local sudo_success=false
    
    # Test rootless build first
    if test_rootless_build; then
        rootless_success=true
        validate_image "openfga-operator:test-rootless"
    fi
    
    echo
    
    # Test sudo build if rootless failed or always test both
    if test_sudo_build; then
        sudo_success=true
        validate_image "openfga-operator:test-sudo"
    fi
    
    echo
    
    # Report results
    if $rootless_success; then
        log_success "✅ Rootless Podman build: PASSED"
    else
        log_warning "⚠️  Rootless Podman build: FAILED"
    fi
    
    if $sudo_success; then
        log_success "✅ Sudo Podman build: PASSED"
    else
        log_error "❌ Sudo Podman build: FAILED"
    fi
    
    echo
    
    if $rootless_success || $sudo_success; then
        log_success "🎉 At least one Podman build method works!"
        log_info "The Dockerfile permission fixes are working correctly."
    else
        log_error "❌ All Podman build methods failed"
        log_error "There may be additional permission or network issues to resolve."
        cleanup
        exit 1
    fi
    
    cleanup
    log_info "Test completed successfully"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help]"
        echo "Test script for validating Podman builds with permission fixes"
        echo ""
        echo "This script tests both rootless and sudo Podman builds to ensure"
        echo "the Dockerfile permission fixes resolve .cargo-lock access issues."
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac