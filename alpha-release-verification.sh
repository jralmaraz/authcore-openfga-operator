#!/bin/bash

# alpha-release-verification.sh - Verify alpha release readiness
# This script validates that all alpha release components are ready

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

# Check git tag
check_git_tag() {
    log_info "Checking git tag v0.1.0-alpha..."
    if git tag -l | grep -q "^v0.1.0-alpha$"; then
        log_success "Git tag v0.1.0-alpha exists"
        return 0
    else
        log_error "Git tag v0.1.0-alpha not found"
        return 1
    fi
}

# Check version in Cargo.toml
check_version() {
    log_info "Checking version in Cargo.toml..."
    local version=$(grep '^version = ' Cargo.toml | cut -d '"' -f 2)
    if [ "$version" = "0.1.0" ]; then
        log_success "Cargo.toml version is correct: $version"
        return 0
    else
        log_warning "Cargo.toml version is: $version (should be 0.1.0)"
        return 1
    fi
}

# Check README version references
check_readme_versions() {
    log_info "Checking README version references..."
    local issues=0
    
    if grep -q "v0.1.0-alpha" README.md; then
        log_success "README contains v0.1.0-alpha references"
    else
        log_error "README missing v0.1.0-alpha references"
        ((issues++))
    fi
    
    if ! grep -q "v1.0.0" README.md; then
        log_success "README no longer references v1.0.0 as current release"
    else
        log_warning "README still contains v1.0.0 references"
        ((issues++))
    fi
    
    return $issues
}

# Check alpha release documentation
check_alpha_docs() {
    log_info "Checking alpha release documentation..."
    local issues=0
    
    if [ -f "docs/releases/ALPHA_RELEASE.md" ]; then
        log_success "Alpha release documentation exists"
    else
        log_error "Alpha release documentation missing"
        ((issues++))
    fi
    
    if grep -q "v0.1.0-alpha" docs/releases/ALPHA_RELEASE.md 2>/dev/null; then
        log_success "Alpha documentation contains correct version"
    else
        log_error "Alpha documentation missing version references"
        ((issues++))
    fi
    
    return $issues
}

# Check Makefile alpha targets
check_makefile_targets() {
    log_info "Checking Makefile alpha targets..."
    local issues=0
    
    if grep -q "alpha-build:" Makefile; then
        log_success "alpha-build target exists"
    else
        log_error "alpha-build target missing"
        ((issues++))
    fi
    
    if grep -q "alpha-push:" Makefile; then
        log_success "alpha-push target exists"
    else
        log_error "alpha-push target missing"
        ((issues++))
    fi
    
    if grep -q "alpha-release:" Makefile; then
        log_success "alpha-release target exists"
    else
        log_error "alpha-release target missing"
        ((issues++))
    fi
    
    if grep -q "ALPHA_VERSION" Makefile; then
        log_success "ALPHA_VERSION variable defined"
    else
        log_error "ALPHA_VERSION variable missing"
        ((issues++))
    fi
    
    return $issues
}

# Check deployment scripts
check_deployment_scripts() {
    log_info "Checking deployment scripts..."
    local issues=0
    
    if [ -f "scripts/minikube/deploy-operator.sh" ]; then
        log_success "deploy-operator.sh exists"
    else
        log_error "deploy-operator.sh missing"
        ((issues++))
    fi
    
    # Test shell compatibility (no brace expansions)
    if ! grep -q '{[0-9].*\.\.[0-9]}' scripts/minikube/deploy-operator.sh; then
        log_success "deploy-operator.sh has no brace expansions (shell compatible)"
    else
        log_error "deploy-operator.sh contains brace expansions"
        ((issues++))
    fi
    
    return $issues
}

# Run tests
run_tests() {
    log_info "Running project tests..."
    if make test >/dev/null 2>&1; then
        log_success "All tests pass"
        return 0
    else
        log_error "Some tests are failing"
        return 1
    fi
}

# Check build capability
check_build() {
    log_info "Checking build capability..."
    if make build >/dev/null 2>&1; then
        log_success "Project builds successfully"
        return 0
    else
        log_error "Project build failed"
        return 1
    fi
}

# Main verification function
main() {
    echo "=================================================="
    echo "  Alpha Release Verification (v0.1.0-alpha)"
    echo "=================================================="
    echo
    
    local total_checks=0
    local passed_checks=0
    
    # Run all checks
    checks=(
        "check_git_tag"
        "check_version"
        "check_readme_versions"
        "check_alpha_docs"
        "check_makefile_targets"
        "check_deployment_scripts"
        "run_tests"
        "check_build"
    )
    
    for check in "${checks[@]}"; do
        echo
        if $check; then
            ((passed_checks++))
        fi
        ((total_checks++))
    done
    
    echo
    echo "=================================================="
    echo "  Verification Results"
    echo "=================================================="
    echo "Checks passed: $passed_checks/$total_checks"
    
    if [ $passed_checks -eq $total_checks ]; then
        log_success "✅ Alpha release is ready!"
        echo
        echo "Next steps:"
        echo "1. Build alpha image: make alpha-build"
        echo "2. Push to registry: make alpha-push"
        echo "3. Deploy: IMAGE_TAG=v0.1.0-alpha make minikube-deploy-registry"
        return 0
    else
        log_error "❌ Alpha release has issues that need to be addressed"
        return 1
    fi
}

# Run verification if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi