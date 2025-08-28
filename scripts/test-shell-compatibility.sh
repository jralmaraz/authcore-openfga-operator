#!/bin/bash

# test-shell-compatibility.sh - Test script for shell compatibility
# Tests that deployment scripts work in non-bash shells like dash

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

# Test brace expansion functionality
test_brace_expansion() {
    local shell="$1"
    local test_name="Brace expansion test"
    
    log_info "Testing brace expansion in $shell..."
    
    # Test brace expansion - this should fail in dash
    local result
    if result=$($shell -c 'for i in {1..3}; do echo $i; done' 2>/dev/null); then
        if [ "$result" = "1
2
3" ]; then
            log_success "$test_name passed in $shell"
            return 0
        else
            log_error "$test_name failed in $shell - got: $result"
            return 1
        fi
    else
        log_error "$test_name failed in $shell - command failed"
        return 1
    fi
}

# Test seq command functionality
test_seq_command() {
    local shell="$1"
    local test_name="Seq command test"
    
    log_info "Testing seq command in $shell..."
    
    # Test seq command - this should work in all shells
    local result
    if result=$($shell -c 'for i in $(seq 1 3); do echo $i; done' 2>/dev/null); then
        if [ "$result" = "1
2
3" ]; then
            log_success "$test_name passed in $shell"
            return 0
        else
            log_error "$test_name failed in $shell - got: $result"
            return 1
        fi
    else
        log_error "$test_name failed in $shell - command failed"
        return 1
    fi
}

# Test specific brace expansions from deploy-operator.sh
test_deploy_script_patterns() {
    local shell="$1"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local deploy_script="$script_dir/minikube/deploy-operator.sh"
    
    log_info "Testing deploy-operator.sh patterns in $shell..."
    
    # Extract the problematic patterns from the script
    local patterns
    patterns=$(grep -n '{[0-9]\+\.\.[0-9]\+}' "$deploy_script" || true)
    
    if [ -n "$patterns" ]; then
        log_warning "Found brace expansion patterns in deploy-operator.sh:"
        echo "$patterns"
        
        # Test each pattern
        local failed=0
        echo "$patterns" | while IFS=: read -r line_num pattern_line; do
            log_info "Testing pattern from line $line_num..."
            
            # Extract the brace expansion pattern
            local brace_pattern
            brace_pattern=$(echo "$pattern_line" | grep -o '{[0-9]\+\.\.[0-9]\+}' | head -1)
            
            if [ -n "$brace_pattern" ]; then
                # Test if this pattern works in the shell
                local test_cmd="for i in $brace_pattern; do echo \$i; done"
                if ! $shell -c "$test_cmd" >/dev/null 2>&1; then
                    log_error "Pattern $brace_pattern fails in $shell"
                    failed=$((failed + 1))
                fi
            fi
        done
        
        if [ $failed -gt 0 ]; then
            log_error "Some patterns failed in $shell"
            return 1
        fi
    else
        log_success "No brace expansion patterns found in deploy-operator.sh"
    fi
    
    return 0
}

# Test that seq equivalents work
test_seq_equivalents() {
    local shell="$1"
    
    log_info "Testing seq equivalents for deploy-operator.sh patterns in $shell..."
    
    # Test the specific ranges used in deploy-operator.sh
    local ranges="1 2 1 3"
    set -- $ranges
    
    while [ $# -ge 2 ]; do
        local start="$1"
        local end="$2"
        shift 2
        
        log_info "Testing seq $start $end in $shell..."
        
        local result
        if result=$($shell -c "for i in \$(seq $start $end); do echo \$i; done" 2>/dev/null); then
            local expected
            expected=$(seq $start $end)
            if [ "$result" = "$expected" ]; then
                log_success "seq $start $end works correctly in $shell"
            else
                log_error "seq $start $end failed in $shell - expected: $expected, got: $result"
                return 1
            fi
        else
            log_error "seq $start $end command failed in $shell"
            return 1
        fi
    done
    
    return 0
}

# Main test function
run_tests() {
    local shell="$1"
    local shell_name="$(basename "$shell")"
    
    echo "=================================================="
    echo "  Shell Compatibility Tests for $shell_name"
    echo "=================================================="
    echo
    
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: Brace expansion (expected to fail in dash)
    if test_brace_expansion "$shell"; then
        ((tests_passed++))
    else
        ((tests_failed++))
        if [ "$shell_name" = "dash" ]; then
            log_info "This failure is expected for dash shell"
        fi
    fi
    
    echo
    
    # Test 2: Seq command (should work in all shells)
    if test_seq_command "$shell"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    echo
    
    # Test 3: Deploy script patterns
    if test_deploy_script_patterns "$shell"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    echo
    
    # Test 4: Seq equivalents
    if test_seq_equivalents "$shell"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    echo
    echo "=================================================="
    echo "  Test Results for $shell_name"
    echo "=================================================="
    echo "Tests passed: $tests_passed"
    echo "Tests failed: $tests_failed"
    
    if [ "$tests_failed" -eq 0 ]; then
        log_success "All tests passed for $shell_name!"
        return 0
    else
        if [ "$shell_name" = "dash" ] && [ "$tests_failed" -eq 1 ]; then
            log_warning "Only brace expansion test failed for dash (expected)"
            log_info "The other tests show that seq-based alternatives work"
            return 0
        else
            log_error "Some tests failed for $shell_name!"
            return 1
        fi
    fi
}

# Main function
main() {
    echo "=================================================="
    echo "  Shell Compatibility Test Suite"
    echo "=================================================="
    echo
    
    # Test available shells
    local shells="/bin/bash /usr/bin/dash"
    local overall_status=0
    
    for shell in $shells; do
        if [ -x "$shell" ]; then
            if ! run_tests "$shell"; then
                overall_status=1
            fi
            echo
        else
            log_warning "Shell $shell not available, skipping"
        fi
    done
    
    if [ $overall_status -eq 0 ]; then
        log_success "All shell compatibility tests completed successfully!"
    else
        log_error "Some shell compatibility tests failed!"
    fi
    
    return $overall_status
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi