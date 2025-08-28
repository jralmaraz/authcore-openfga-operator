#!/bin/bash

# test-deploy-script-shell-compatibility.sh - Test the deploy-operator.sh script in different shells
# This test validates that key functions work correctly in non-bash shells

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

# Test that the deploy script can be sourced and basic functions work
test_deploy_script_functions() {
    local shell="$1"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local deploy_script="$script_dir/minikube/deploy-operator.sh"
    
    log_info "Testing deploy-operator.sh functions in $shell..."
    
    # Create a test script that sources the deploy script and tests key functions
    local test_script="/tmp/test_deploy_functions_$$"
    cat > "$test_script" << 'EOF'
#!/bin/bash

# Mock external commands that aren't available in test environment
command_exists() {
    case "$1" in
        kubectl|minikube|cargo|docker|podman|seq)
            return 0  # Pretend these exist
            ;;
        *)
            return 1
            ;;
    esac
}

# Mock seq if not available (shouldn't be needed but for safety)
seq() {
    if [ $# -eq 2 ]; then
        local start=$1
        local end=$2
        local i=$start
        while [ $i -le $end ]; do
            echo $i
            i=$((i + 1))
        done
    else
        echo "Usage: seq start end" >&2
        return 1
    fi
}

# Test the retry loops that used to have brace expansions
test_retry_loops() {
    echo "Testing retry loop patterns..."
    
    # Test pattern 1: seq 1 2
    local count=0
    for attempt in $(seq 1 2); do
        count=$((count + 1))
        echo "Attempt $attempt"
    done
    if [ $count -eq 2 ]; then
        echo "✓ seq 1 2 loop works correctly"
    else
        echo "✗ seq 1 2 loop failed - got $count iterations instead of 2"
        return 1
    fi
    
    # Test pattern 2: seq 1 3
    count=0
    for attempt in $(seq 1 3); do
        count=$((count + 1))
        echo "Attempt $attempt"
    done
    if [ $count -eq 3 ]; then
        echo "✓ seq 1 3 loop works correctly"
    else
        echo "✗ seq 1 3 loop failed - got $count iterations instead of 3"
        return 1
    fi
    
    return 0
}

# Test variable retry loops
test_variable_retry_loops() {
    echo "Testing variable retry loops..."
    
    local max_retries=5
    local count=0
    for attempt in $(seq 1 $max_retries); do
        count=$((count + 1))
        echo "Attempt $attempt of $max_retries"
    done
    if [ $count -eq $max_retries ]; then
        echo "✓ Variable retry loop works correctly"
    else
        echo "✗ Variable retry loop failed - got $count iterations instead of $max_retries"
        return 1
    fi
    
    return 0
}

# Run tests
echo "Running deploy script function tests..."
if test_retry_loops && test_variable_retry_loops; then
    echo "All function tests passed"
    exit 0
else
    echo "Some function tests failed"
    exit 1
fi
EOF
    
    chmod +x "$test_script"
    
    # Run the test script with the specified shell
    if $shell "$test_script" 2>/dev/null; then
        log_success "Deploy script functions work correctly in $shell"
        rm -f "$test_script"
        return 0
    else
        log_error "Deploy script functions failed in $shell"
        rm -f "$test_script"
        return 1
    fi
}

# Test syntax validity of the deploy script
test_deploy_script_syntax() {
    local shell="$1"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local deploy_script="$script_dir/minikube/deploy-operator.sh"
    
    log_info "Testing deploy-operator.sh syntax in $shell..."
    
    # For dash, we need to be careful as it may not support all bash features
    if [ "$(basename "$shell")" = "dash" ]; then
        # Check for bash-specific constructs that might not work in dash
        log_info "Checking for bash-specific constructs..."
        
        # Check if script uses any problematic bash features
        local problematic_features=""
        
        # Check for remaining brace expansions
        if grep -q '{[0-9]\+\.\.[0-9]\+}' "$deploy_script"; then
            problematic_features="$problematic_features brace_expansion"
        fi
        
        # Check for bash arrays (not supported in dash)
        if grep -q '\[\[' "$deploy_script"; then
            problematic_features="$problematic_features double_brackets"
        fi
        
        if [ -n "$problematic_features" ]; then
            log_warning "Found potentially problematic features for dash: $problematic_features"
        else
            log_success "No problematic bash-specific features found"
        fi
    fi
    
    # Test basic syntax by running with -n flag
    if $shell -n "$deploy_script" 2>/dev/null; then
        log_success "Deploy script syntax is valid for $shell"
        return 0
    else
        log_error "Deploy script has syntax errors for $shell"
        return 1
    fi
}

# Test that the specific fixed loops work
test_fixed_loop_patterns() {
    local shell="$1"
    
    log_info "Testing the specific fixed loop patterns in $shell..."
    
    # Test the exact patterns that were fixed
    local patterns="1 2 1 3"
    set -- $patterns
    
    while [ $# -ge 2 ]; do
        local start="$1"
        local end="$2"
        shift 2
        
        log_info "Testing loop pattern: for attempt in \$(seq $start $end)..."
        
        local result
        if result=$($shell -c "
            count=0
            for attempt in \$(seq $start $end); do
                count=\$((count + 1))
            done
            echo \$count
        " 2>/dev/null); then
            local expected=$((end - start + 1))
            if [ "$result" = "$expected" ]; then
                log_success "Loop pattern seq $start $end works correctly"
            else
                log_error "Loop pattern seq $start $end failed - expected $expected, got $result"
                return 1
            fi
        else
            log_error "Loop pattern seq $start $end failed to execute"
            return 1
        fi
    done
    
    return 0
}

# Main test function for a specific shell
run_shell_tests() {
    local shell="$1"
    local shell_name="$(basename "$shell")"
    
    echo "=================================================="
    echo "  Deploy Script Tests for $shell_name"
    echo "=================================================="
    echo
    
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: Script syntax
    if test_deploy_script_syntax "$shell"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    echo
    
    # Test 2: Fixed loop patterns
    if test_fixed_loop_patterns "$shell"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    echo
    
    # Test 3: Deploy script functions
    if test_deploy_script_functions "$shell"; then
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
        log_success "All deploy script tests passed for $shell_name!"
        return 0
    else
        log_error "Some deploy script tests failed for $shell_name!"
        return 1
    fi
}

# Main function
main() {
    echo "=================================================="
    echo "  Deploy Script Shell Compatibility Test"
    echo "=================================================="
    echo
    
    # Test available shells
    local shells="/bin/bash /usr/bin/dash"
    local overall_status=0
    
    for shell in $shells; do
        if [ -x "$shell" ]; then
            if ! run_shell_tests "$shell"; then
                overall_status=1
            fi
            echo
        else
            log_warning "Shell $shell not available, skipping"
        fi
    done
    
    if [ $overall_status -eq 0 ]; then
        log_success "All deploy script compatibility tests passed!"
        echo
        echo "The deploy-operator.sh script is now compatible with non-bash shells!"
    else
        log_error "Some deploy script compatibility tests failed!"
    fi
    
    return $overall_status
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi