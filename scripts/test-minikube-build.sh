#!/bin/bash

# test-minikube-build.sh - Test script for Minikube image building functionality
# This script tests the new Minikube docker environment integration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Test Minikube docker environment configuration
test_minikube_env() {
    log_info "Testing Minikube docker environment configuration..."
    
    # Check if Minikube is running
    if ! minikube status >/dev/null 2>&1; then
        log_error "Minikube is not running. Please start Minikube first."
        return 1
    fi
    
    # Check if docker-env works
    if ! minikube docker-env >/dev/null 2>&1; then
        log_error "Minikube docker-env command failed"
        return 1
    fi
    
    log_success "Minikube docker environment is accessible"
    return 0
}

# Test image building with Minikube environment
test_image_build() {
    log_info "Testing image building with Minikube environment..."
    
    cd "$PROJECT_ROOT"
    
    # Test the new minikube-build target
    if make minikube-build; then
        log_success "Image building with Minikube environment succeeded"
        return 0
    else
        log_error "Image building with Minikube environment failed"
        return 1
    fi
}

# Test image verification
test_image_verification() {
    log_info "Testing image verification in Minikube..."
    
    # Check if image is listed in Minikube
    if minikube image ls | grep -q openfga-operator; then
        log_success "Image is available in Minikube"
        return 0
    else
        log_error "Image is not available in Minikube"
        return 1
    fi
}

# Test the deployment script functions
test_deployment_script() {
    log_info "Testing deployment script functions..."
    
    cd "$PROJECT_ROOT"
    
    # Source the deployment script to test functions
    source scripts/minikube/deploy-operator.sh
    
    # Test configure_minikube_env function
    if configure_minikube_env; then
        log_success "configure_minikube_env function works"
    else
        log_warning "configure_minikube_env function returned non-zero (may be expected for non-Docker drivers)"
    fi
    
    # Test verify_image_in_minikube function
    if verify_image_in_minikube "openfga-operator:latest"; then
        log_success "verify_image_in_minikube function works"
        return 0
    else
        log_warning "verify_image_in_minikube function failed (image may not exist yet)"
        return 1
    fi
}

# Main test function
main() {
    echo "=============================================="
    echo "  Minikube Build Integration Test"
    echo "=============================================="
    echo
    
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: Minikube environment
    if test_minikube_env; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # Test 2: Image building
    if test_image_build; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # Test 3: Image verification
    if test_image_verification; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # Test 4: Deployment script functions
    if test_deployment_script; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    echo
    echo "=============================================="
    echo "  Test Results"
    echo "=============================================="
    echo "Tests passed: $tests_passed"
    echo "Tests failed: $tests_failed"
    
    if [ "$tests_failed" -eq 0 ]; then
        log_success "All tests passed!"
        return 0
    else
        log_error "Some tests failed!"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi