#!/bin/bash

# test-deployment-functions.sh - Test the improved deployment functions
# This script tests individual functions from the deployment script

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

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the deployment script to get the functions
source "$SCRIPT_DIR/minikube/deploy-operator.sh"

# Test functions
test_verify_image_function() {
    log_info "Testing verify_image_in_minikube function..."
    
    # Test with existing image
    if verify_image_in_minikube "openfga-operator:latest" 2 2; then
        log_success "verify_image_in_minikube works correctly with existing image"
    else
        log_error "verify_image_in_minikube failed with existing image"
        return 1
    fi
    
    # Test with non-existing image
    if verify_image_in_minikube "non-existent-image:latest" 2 1; then
        log_error "verify_image_in_minikube should have failed with non-existent image"
        return 1
    else
        log_success "verify_image_in_minikube correctly failed with non-existent image"
    fi
    
    return 0
}

test_minikube_environment() {
    log_info "Testing Minikube environment detection..."
    
    if configure_minikube_env; then
        log_success "configure_minikube_env returned success"
    else
        log_info "configure_minikube_env returned failure (expected for non-docker drivers)"
    fi
    
    return 0
}

test_container_runtime_detection() {
    log_info "Testing container runtime detection..."
    
    local runtime
    runtime=$(detect_container_runtime)
    
    if [ -n "$runtime" ]; then
        log_success "Detected container runtime: $runtime"
    else
        log_error "Failed to detect container runtime"
        return 1
    fi
    
    return 0
}

# Main test function
main() {
    echo "=================================================="
    echo "  Testing Deployment Script Functions"
    echo "=================================================="
    echo
    
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: Container runtime detection
    if test_container_runtime_detection; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # Test 2: Minikube environment
    if test_minikube_environment; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # Test 3: Image verification
    if test_verify_image_function; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    echo
    echo "=================================================="
    echo "  Test Results"
    echo "=================================================="
    echo "Tests passed: $tests_passed"
    echo "Tests failed: $tests_failed"
    
    if [ "$tests_failed" -eq 0 ]; then
        log_success "All function tests passed!"
        return 0
    else
        log_error "Some function tests failed!"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi