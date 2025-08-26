#!/bin/bash

# validate-demos.sh - Validation script for OpenFGA Operator demo applications
# Compatible with Linux and macOS

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEMO_NAMESPACE="openfga-system"
TIMEOUT=60
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Test configuration
BANKING_APP_PORT=3000
GENAI_APP_PORT=8000
OPENFGA_PORT=8080

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

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if port is open
check_port() {
    local host="$1"
    local port="$2"
    local timeout="$3"
    
    if command_exists nc; then
        timeout "$timeout" nc -z "$host" "$port" 2>/dev/null
    elif command_exists telnet; then
        timeout "$timeout" bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null
    else
        # Fallback using curl
        timeout "$timeout" curl -s --connect-timeout 1 "http://$host:$port" >/dev/null 2>&1
    fi
}

# Make HTTP request with timeout
make_request() {
    local url="$1"
    local method="${2:-GET}"
    local headers="${3:-}"
    local data="${4:-}"
    local timeout="${5:-10}"
    
    local curl_args=("--max-time" "$timeout" "--silent" "--show-error")
    
    if [[ -n "$headers" ]]; then
        IFS=',' read -ra header_array <<< "$headers"
        for header in "${header_array[@]}"; do
            curl_args+=("-H" "$header")
        done
    fi
    
    if [[ "$method" != "GET" ]]; then
        curl_args+=("-X" "$method")
    fi
    
    if [[ -n "$data" ]]; then
        curl_args+=("-d" "$data")
        curl_args+=("-H" "Content-Type: application/json")
    fi
    
    curl "${curl_args[@]}" "$url"
}

# Start port-forward in background
start_port_forward() {
    local service="$1"
    local local_port="$2"
    local service_port="$3"
    local namespace="$4"
    
    log_info "Starting port-forward for $service ($local_port -> $service_port)..."
    
    # Kill any existing port-forward on this port
    pkill -f "kubectl port-forward.*:$local_port" 2>/dev/null || true
    sleep 1
    
    # Start new port-forward
    kubectl port-forward "service/$service" "$local_port:$service_port" -n "$namespace" >/dev/null 2>&1 &
    local pf_pid=$!
    
    # Give it time to establish
    sleep 3
    
    # Check if port-forward is working
    if ! check_port "localhost" "$local_port" 5; then
        log_warning "Port-forward for $service may not be ready yet"
        return 1
    fi
    
    echo "$pf_pid"
}

# Stop port-forward
stop_port_forward() {
    local pid="$1"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    fi
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    local issues=0
    
    if ! command_exists kubectl; then
        log_error "kubectl is not installed"
        ((issues++))
    fi
    
    if ! command_exists curl; then
        log_error "curl is not installed"
        ((issues++))
    fi
    
    # Check kubectl connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        log_success "Prerequisites validation passed"
        return 0
    else
        log_error "Prerequisites validation failed"
        return 1
    fi
}

# Validate demo application deployments
validate_deployments() {
    log_info "Validating demo application deployments..."
    
    local issues=0
    
    # Check banking app deployment
    if kubectl get deployment banking-demo-app -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
        if kubectl wait --for=condition=available --timeout=30s deployment/banking-demo-app -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
            log_success "Banking app deployment is ready"
        else
            log_warning "Banking app deployment exists but may not be ready"
            ((issues++))
        fi
    else
        log_warning "Banking app deployment not found"
        ((issues++))
    fi
    
    # Check GenAI app deployment
    if kubectl get deployment genai-rag-agent -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
        if kubectl wait --for=condition=available --timeout=30s deployment/genai-rag-agent -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
            log_success "GenAI RAG agent deployment is ready"
        else
            log_warning "GenAI RAG agent deployment exists but may not be ready"
            ((issues++))
        fi
    else
        log_warning "GenAI RAG agent deployment not found"
        ((issues++))
    fi
    
    # Check OpenFGA deployment
    if kubectl get deployment openfga-basic -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
        if kubectl wait --for=condition=available --timeout=30s deployment/openfga-basic -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
            log_success "OpenFGA instance deployment is ready"
        else
            log_warning "OpenFGA instance deployment exists but may not be ready"
            ((issues++))
        fi
    else
        log_error "OpenFGA instance deployment not found"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Test OpenFGA API connectivity
test_openfga_api() {
    log_test "Testing OpenFGA API connectivity..."
    
    local pf_pid
    pf_pid=$(start_port_forward "openfga-basic-http" "$OPENFGA_PORT" "8080" "$DEMO_NAMESPACE")
    
    if [[ -z "$pf_pid" ]]; then
        log_error "Failed to establish port-forward to OpenFGA"
        return 1
    fi
    
    # Test health endpoint
    local health_response
    if health_response=$(make_request "http://localhost:$OPENFGA_PORT/healthz" "GET" "" "" 10); then
        log_success "OpenFGA health check passed"
        log_info "Health response: $health_response"
    else
        log_error "OpenFGA health check failed"
        stop_port_forward "$pf_pid"
        return 1
    fi
    
    # Test stores endpoint
    local stores_response
    if stores_response=$(make_request "http://localhost:$OPENFGA_PORT/stores" "GET" "" "" 10); then
        log_success "OpenFGA stores endpoint accessible"
        local store_count
        store_count=$(echo "$stores_response" | grep -o '"stores":\[' | wc -l || echo "0")
        log_info "Found stores response (contains stores array: $store_count)"
    else
        log_warning "OpenFGA stores endpoint test failed"
    fi
    
    stop_port_forward "$pf_pid"
    return 0
}

# Test Banking Application API
test_banking_app_api() {
    log_test "Testing Banking Application API..."
    
    # Check if service exists
    if ! kubectl get service banking-demo-service -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
        log_warning "Banking app service not found - skipping API tests"
        return 1
    fi
    
    local pf_pid
    pf_pid=$(start_port_forward "banking-demo-service" "$BANKING_APP_PORT" "80" "$DEMO_NAMESPACE")
    
    if [[ -z "$pf_pid" ]]; then
        log_error "Failed to establish port-forward to Banking app"
        return 1
    fi
    
    # Test health endpoint
    log_info "Testing health endpoint..."
    local health_response
    if health_response=$(make_request "http://localhost:$BANKING_APP_PORT/health" "GET" "" "" 10); then
        log_success "Banking app health check passed"
        log_info "Health response: $health_response"
    else
        log_error "Banking app health check failed"
        stop_port_forward "$pf_pid"
        return 1
    fi
    
    # Test API endpoints with demo user
    log_info "Testing API endpoints..."
    local accounts_response
    if accounts_response=$(make_request "http://localhost:$BANKING_APP_PORT/api/accounts" "GET" "x-user-id: alice" "" 10); then
        log_success "Banking app accounts endpoint accessible"
        log_info "Accounts response: $accounts_response"
    else
        log_warning "Banking app accounts endpoint test failed (may be normal if demo data not setup)"
    fi
    
    # Test user info endpoint
    local user_response
    if user_response=$(make_request "http://localhost:$BANKING_APP_PORT/api/users/me" "GET" "x-user-id: alice" "" 10); then
        log_success "Banking app user info endpoint accessible"
        log_info "User response: $user_response"
    else
        log_warning "Banking app user info endpoint test failed"
    fi
    
    stop_port_forward "$pf_pid"
    return 0
}

# Test GenAI RAG Agent API
test_genai_app_api() {
    log_test "Testing GenAI RAG Agent API..."
    
    # Check if service exists
    if ! kubectl get service genai-rag-agent-service -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
        log_warning "GenAI RAG agent service not found - skipping API tests"
        return 1
    fi
    
    local pf_pid
    pf_pid=$(start_port_forward "genai-rag-agent-service" "$GENAI_APP_PORT" "80" "$DEMO_NAMESPACE")
    
    if [[ -z "$pf_pid" ]]; then
        log_error "Failed to establish port-forward to GenAI RAG agent"
        return 1
    fi
    
    # Test health endpoint
    log_info "Testing health endpoint..."
    local health_response
    if health_response=$(make_request "http://localhost:$GENAI_APP_PORT/health" "GET" "" "" 10); then
        log_success "GenAI RAG agent health check passed"
        log_info "Health response: $health_response"
    else
        log_error "GenAI RAG agent health check failed"
        stop_port_forward "$pf_pid"
        return 1
    fi
    
    # Test API endpoints
    log_info "Testing API endpoints..."
    
    # Test user info endpoint
    local user_response
    if user_response=$(make_request "http://localhost:$GENAI_APP_PORT/api/users/me" "GET" "x-user-id: alice" "" 10); then
        log_success "GenAI user info endpoint accessible"
        log_info "User response: $user_response"
    else
        log_warning "GenAI user info endpoint test failed"
    fi
    
    # Test knowledge bases endpoint
    local kb_response
    if kb_response=$(make_request "http://localhost:$GENAI_APP_PORT/api/knowledge-bases" "GET" "x-user-id: alice" "" 10); then
        log_success "GenAI knowledge bases endpoint accessible"
        log_info "Knowledge bases response: $kb_response"
    else
        log_warning "GenAI knowledge bases endpoint test failed (may be normal if demo data not setup)"
    fi
    
    stop_port_forward "$pf_pid"
    return 0
}

# Test authorization scenarios
test_authorization_scenarios() {
    log_test "Testing authorization scenarios..."
    
    local banking_pf_pid genai_pf_pid
    
    # Start port-forwards
    if kubectl get service banking-demo-service -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
        banking_pf_pid=$(start_port_forward "banking-demo-service" "$BANKING_APP_PORT" "80" "$DEMO_NAMESPACE")
    fi
    
    if kubectl get service genai-rag-agent-service -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
        genai_pf_pid=$(start_port_forward "genai-rag-agent-service" "$GENAI_APP_PORT" "80" "$DEMO_NAMESPACE")
    fi
    
    # Test banking app authorization
    if [[ -n "$banking_pf_pid" ]]; then
        log_info "Testing banking app authorization..."
        
        # Test authorized user
        local auth_response
        if auth_response=$(make_request "http://localhost:$BANKING_APP_PORT/api/accounts" "GET" "x-user-id: alice" "" 10 2>/dev/null); then
            log_success "Banking app authorized request worked"
        else
            log_warning "Banking app authorized request failed (may be normal during startup)"
        fi
        
        # Test unauthorized user
        if auth_response=$(make_request "http://localhost:$BANKING_APP_PORT/api/accounts" "GET" "x-user-id: unauthorized" "" 10 2>/dev/null); then
            log_warning "Banking app should have rejected unauthorized user"
        else
            log_success "Banking app correctly rejected unauthorized request"
        fi
    fi
    
    # Test GenAI app authorization
    if [[ -n "$genai_pf_pid" ]]; then
        log_info "Testing GenAI app authorization..."
        
        # Test authorized user
        local genai_auth_response
        if genai_auth_response=$(make_request "http://localhost:$GENAI_APP_PORT/api/knowledge-bases" "GET" "x-user-id: alice" "" 10 2>/dev/null); then
            log_success "GenAI app authorized request worked"
        else
            log_warning "GenAI app authorized request failed (may be normal during startup)"
        fi
    fi
    
    # Cleanup port-forwards
    [[ -n "$banking_pf_pid" ]] && stop_port_forward "$banking_pf_pid"
    [[ -n "$genai_pf_pid" ]] && stop_port_forward "$genai_pf_pid"
    
    return 0
}

# Generate validation report
generate_report() {
    local total_tests="$1"
    local passed_tests="$2"
    local failed_tests="$3"
    
    echo
    echo "=================================================="
    echo "            VALIDATION REPORT"
    echo "=================================================="
    echo
    echo "Total tests run: $total_tests"
    echo "Tests passed: $passed_tests"
    echo "Tests failed: $failed_tests"
    echo "Success rate: $(( (passed_tests * 100) / total_tests ))%"
    echo
    
    if [[ $failed_tests -eq 0 ]]; then
        log_success "All validation tests passed!"
        echo
        echo "🎉 Your demo applications are working correctly!"
        echo
    else
        log_warning "Some validation tests failed"
        echo
        echo "This may be normal if:"
        echo "- Demo applications are still starting up"
        echo "- Demo data hasn't been set up yet"
        echo "- OpenFGA store configuration is incomplete"
        echo
        echo "Try running the setup again:"
        echo "  ./scripts/minikube/deploy-demos.sh"
        echo
    fi
}

# Print usage instructions
print_usage_instructions() {
    echo "=================================================="
    echo "            USAGE INSTRUCTIONS"
    echo "=================================================="
    echo
    echo "To access the demo applications manually:"
    echo
    echo "1. Banking Application:"
    echo "   kubectl port-forward service/banking-demo-service 3000:80 &"
    echo "   curl http://localhost:3000/health"
    echo "   curl -H 'x-user-id: alice' http://localhost:3000/api/accounts"
    echo
    echo "2. GenAI RAG Agent:"
    echo "   kubectl port-forward service/genai-rag-agent-service 8000:80 &"
    echo "   curl http://localhost:8000/health"
    echo "   curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases"
    echo "   # Web UI: http://localhost:8000/docs"
    echo
    echo "3. OpenFGA API:"
    echo "   kubectl port-forward service/openfga-basic-http 8080:8080 &"
    echo "   curl http://localhost:8080/healthz"
    echo "   curl http://localhost:8080/stores"
    echo
    echo "To stop all port-forwards:"
    echo "   pkill -f 'kubectl port-forward'"
    echo
}

# Handle cleanup on script exit
cleanup() {
    # Kill any port-forwards we started
    pkill -f "kubectl port-forward.*:$BANKING_APP_PORT" 2>/dev/null || true
    pkill -f "kubectl port-forward.*:$GENAI_APP_PORT" 2>/dev/null || true
    pkill -f "kubectl port-forward.*:$OPENFGA_PORT" 2>/dev/null || true
}

# Set up cleanup trap
trap cleanup EXIT

# Main function
main() {
    local test_banking=true
    local test_genai=true
    local test_auth=true
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --banking-only)
                test_genai=false
                test_auth=false
                shift
                ;;
            --genai-only)
                test_banking=false
                test_auth=false
                shift
                ;;
            --no-auth)
                test_auth=false
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Validate OpenFGA Operator demo applications"
                echo
                echo "Options:"
                echo "  --banking-only  Test only the banking application"
                echo "  --genai-only    Test only the GenAI RAG agent"
                echo "  --no-auth       Skip authorization scenario tests"
                echo "  -h, --help      Show this help message"
                echo
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done
    
    echo "=================================================="
    echo "  OpenFGA Demo Applications Validation"
    echo "=================================================="
    echo
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    # Define test functions
    local tests=(
        "validate_prerequisites"
        "validate_deployments"
        "test_openfga_api"
    )
    
    # Add application-specific tests
    if [[ $test_banking == true ]]; then
        tests+=("test_banking_app_api")
    fi
    
    if [[ $test_genai == true ]]; then
        tests+=("test_genai_app_api")
    fi
    
    if [[ $test_auth == true ]]; then
        tests+=("test_authorization_scenarios")
    fi
    
    # Run tests
    for test in "${tests[@]}"; do
        echo
        ((total_tests++))
        if $test; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
    done
    
    # Generate final report
    generate_report "$total_tests" "$passed_tests" "$failed_tests"
    print_usage_instructions
    
    # Return appropriate exit code
    if [[ $failed_tests -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Execute main function with all arguments
main "$@"