#!/bin/bash

# validate-deployment.sh - Validation script for authcore-openfga-operator deployment
# Compatible with Linux and macOS

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OPERATOR_NAMESPACE="openfga-system"
TIMEOUT=300

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

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    local issues=0
    
    if ! command_exists kubectl; then
        log_error "kubectl is not installed"
        ((issues++))
    fi
    
    if ! command_exists minikube; then
        log_error "minikube is not installed"
        ((issues++))
    fi
    
    if ! minikube status >/dev/null 2>&1; then
        log_error "Minikube is not running"
        ((issues++))
    fi
    
    if [ $issues -eq 0 ]; then
        log_success "Prerequisites validation passed"
        return 0
    else
        log_error "Prerequisites validation failed with $issues issues"
        return 1
    fi
}

# Validate cluster connectivity
validate_cluster() {
    log_info "Validating cluster connectivity..."
    
    if kubectl cluster-info >/dev/null 2>&1; then
        log_success "Cluster is accessible"
        
        # Show cluster info
        echo "Cluster information:"
        kubectl cluster-info
        echo
        
        return 0
    else
        log_error "Cannot connect to cluster"
        return 1
    fi
}

# Validate CRDs
validate_crds() {
    log_info "Validating Custom Resource Definitions..."
    
    if kubectl get crd openfgas.authorization.openfga.dev >/dev/null 2>&1; then
        log_success "OpenFGA CRD is installed"
        
        # Show CRD details
        echo "CRD details:"
        kubectl get crd openfgas.authorization.openfga.dev -o custom-columns=NAME:.metadata.name,VERSION:.spec.versions[0].name,SCOPE:.spec.scope
        echo
        
        return 0
    else
        log_error "OpenFGA CRD is not installed"
        return 1
    fi
}

# Validate operator deployment
validate_operator() {
    log_info "Validating operator deployment..."
    
    local issues=0
    
    # Check if namespace exists
    if ! kubectl get namespace "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        log_error "Operator namespace '$OPERATOR_NAMESPACE' does not exist"
        ((issues++))
    else
        log_success "Operator namespace exists"
    fi
    
    # Check if deployment exists
    if ! kubectl get deployment openfga-operator -n "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        log_error "Operator deployment does not exist"
        ((issues++))
    else
        log_success "Operator deployment exists"
    fi
    
    # Check if deployment is ready
    if kubectl wait --for=condition=available --timeout=30s deployment/openfga-operator-project-controller-manager -n "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        log_success "Operator deployment is available"
    else
        log_warning "Operator deployment may not be fully ready yet"
        ((issues++))
    fi
    
    # Check pods
    local pod_status
    pod_status=$(kubectl get pods -n "$OPERATOR_NAMESPACE" -l app=openfga-operator --no-headers 2>/dev/null | awk '{print $3}' | head -1)
    
    if [ "$pod_status" = "Running" ]; then
        log_success "Operator pod is running"
    else
        log_error "Operator pod is not running (status: $pod_status)"
        ((issues++))
    fi
    
    # Show deployment status
    echo "Operator deployment status:"
    kubectl get deployment openfga-operator -n "$OPERATOR_NAMESPACE"
    echo
    
    echo "Operator pods:"
    kubectl get pods -n "$OPERATOR_NAMESPACE"
    echo
    
    if [ $issues -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Validate RBAC
validate_rbac() {
    log_info "Validating RBAC configuration..."
    
    local issues=0
    
    # Check service account
    if kubectl get serviceaccount openfga-operator -n "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        log_success "Operator service account exists"
    else
        log_error "Operator service account does not exist"
        ((issues++))
    fi
    
    # Check cluster role
    if kubectl get clusterrole openfga-operator >/dev/null 2>&1; then
        log_success "Operator cluster role exists"
    else
        log_error "Operator cluster role does not exist"
        ((issues++))
    fi
    
    # Check cluster role binding
    if kubectl get clusterrolebinding openfga-operator >/dev/null 2>&1; then
        log_success "Operator cluster role binding exists"
    else
        log_error "Operator cluster role binding does not exist"
        ((issues++))
    fi
    
    if [ $issues -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Validate OpenFGA instances
validate_openfga_instances() {
    log_info "Validating OpenFGA instances..."
    
    # Check if any OpenFGA instances exist
    local instances
    instances=$(kubectl get openfgas --no-headers 2>/dev/null | wc -l)
    
    if [ "$instances" -eq 0 ]; then
        log_warning "No OpenFGA instances found"
        echo "You can create one with: kubectl apply -f examples/basic-openfga.yaml"
        echo
        return 0
    fi
    
    log_success "Found $instances OpenFGA instance(s)"
    
    # Show instances
    echo "OpenFGA instances:"
    kubectl get openfgas
    echo
    
    # Check if deployments are created for instances
    local openfga_deployments
    openfga_deployments=$(kubectl get deployments -l app=openfga --no-headers 2>/dev/null | wc -l)
    
    if [ "$openfga_deployments" -gt 0 ]; then
        log_success "Found $openfga_deployments OpenFGA deployment(s)"
        
        echo "OpenFGA deployments:"
        kubectl get deployments -l app=openfga
        echo
    else
        log_warning "No OpenFGA deployments found. The operator may still be processing the instances."
    fi
    
    return 0
}

# Test API connectivity
test_api_connectivity() {
    log_info "Testing OpenFGA API connectivity..."
    
    # Find OpenFGA services
    local services
    services=$(kubectl get services -l app=openfga --no-headers 2>/dev/null | grep -E '(http|8080)' | head -1 | awk '{print $1}')
    
    if [ -z "$services" ]; then
        log_warning "No OpenFGA HTTP services found"
        echo "Deploy an OpenFGA instance first: kubectl apply -f examples/basic-openfga.yaml"
        return 0
    fi
    
    local service_name="$services"
    log_info "Testing connectivity to service: $service_name"
    
    # Start port-forward in background
    local port_forward_pid
    kubectl port-forward service/"$service_name" 8080:8080 >/dev/null 2>&1 &
    port_forward_pid=$!
    
    # Give port-forward time to establish
    sleep 5
    
    # Test the API
    local api_test_result=0
    
    if command_exists curl; then
        if curl -f -s http://localhost:8080/healthz >/dev/null 2>&1; then
            log_success "OpenFGA health endpoint is accessible"
        else
            log_warning "OpenFGA health endpoint is not responding (this may be normal if the pod is still starting)"
            api_test_result=1
        fi
        
        # Test stores endpoint
        if curl -f -s http://localhost:8080/stores >/dev/null 2>&1; then
            log_success "OpenFGA stores endpoint is accessible"
        else
            log_warning "OpenFGA stores endpoint is not responding"
            api_test_result=1
        fi
    else
        log_warning "curl not available, skipping API connectivity test"
    fi
    
    # Clean up port-forward
    kill $port_forward_pid 2>/dev/null || true
    wait $port_forward_pid 2>/dev/null || true
    
    if [ $api_test_result -eq 0 ]; then
        log_success "API connectivity test passed"
    else
        log_warning "API connectivity test had issues (this may be normal during startup)"
    fi
    
    return 0
}

# Check operator logs for errors
check_operator_logs() {
    log_info "Checking operator logs for errors..."
    
    # Get recent logs from operator
    local logs
    logs=$(kubectl logs -n "$OPERATOR_NAMESPACE" deployment/openfga-operator-project-controller-manager --tail=50 2>/dev/null || echo "")
    
    if [ -z "$logs" ]; then
        log_warning "No operator logs available"
        return 0
    fi
    
    # Check for error patterns
    local error_count
    error_count=$(echo "$logs" | grep -i -E "(error|failed|panic)" | wc -l)
    
    if [ "$error_count" -eq 0 ]; then
        log_success "No errors found in operator logs"
    else
        log_warning "Found $error_count potential error(s) in operator logs"
        echo "Recent errors:"
        echo "$logs" | grep -i -E "(error|failed|panic)" | tail -5
        echo
    fi
    
    # Show last few log lines
    echo "Recent operator logs:"
    echo "$logs" | tail -10
    echo
    
    return 0
}

# Generate validation report
generate_report() {
    log_info "Generating validation report..."
    
    echo "=========================================="
    echo "         VALIDATION REPORT"
    echo "=========================================="
    echo
    
    echo "Cluster Information:"
    kubectl cluster-info
    echo
    
    echo "Node Status:"
    kubectl get nodes
    echo
    
    echo "Operator Status:"
    kubectl get all -n "$OPERATOR_NAMESPACE"
    echo
    
    echo "OpenFGA Resources:"
    kubectl get openfgas
    echo
    
    echo "All Deployments:"
    kubectl get deployments
    echo
    
    echo "All Services:"
    kubectl get services
    echo
    
    echo "Resource Usage:"
    kubectl top nodes 2>/dev/null || echo "Metrics not available"
    kubectl top pods -n "$OPERATOR_NAMESPACE" 2>/dev/null || echo "Pod metrics not available"
    echo
}

# Print next steps
print_next_steps() {
    echo "=========================================="
    echo "            NEXT STEPS"
    echo "=========================================="
    echo
    echo "1. Access OpenFGA API:"
    echo "   kubectl port-forward service/openfga-basic-http 8080:8080"
    echo "   curl http://localhost:8080/healthz"
    echo "   curl http://localhost:8080/stores"
    echo
    echo "2. Deploy demo applications:"
    echo "   cd demos/banking-app"
    echo "   kubectl apply -f k8s/"
    echo "   kubectl port-forward service/banking-app 3000:3000"
    echo
    echo "3. Monitor the system:"
    echo "   kubectl logs -n $OPERATOR_NAMESPACE deployment/openfga-operator-project-controller-manager -f"
    echo "   kubectl get events --sort-by=.metadata.creationTimestamp"
    echo
    echo "4. Create more OpenFGA instances:"
    echo "   kubectl apply -f examples/postgres-openfga.yaml"
    echo
    echo "For troubleshooting, see docs/minikube/README.md"
}

# Main function
main() {
    echo "=================================================="
    echo "  authcore-openfga-operator Deployment Validation"
    echo "=================================================="
    echo
    
    local total_checks=0
    local passed_checks=0
    
    # Run validations
    tests=(
        "validate_prerequisites"
        "validate_cluster"
        "validate_crds"
        "validate_operator"
        "validate_rbac"
        "validate_openfga_instances"
        "test_api_connectivity"
        "check_operator_logs"
    )
    
    for test in "${tests[@]}"; do
        ((total_checks++))
        if $test; then
            ((passed_checks++))
        fi
        echo
    done
    
    # Generate report
    generate_report
    
    # Summary
    echo "=========================================="
    echo "            VALIDATION SUMMARY"
    echo "=========================================="
    echo
    
    if [ $passed_checks -eq $total_checks ]; then
        log_success "All validation checks passed ($passed_checks/$total_checks)"
        echo
        log_success "🎉 authcore-openfga-operator is successfully deployed and running!"
    else
        log_warning "Some validation checks had issues ($passed_checks/$total_checks passed)"
        echo
        log_warning "⚠️  authcore-openfga-operator may need attention"
    fi
    
    echo
    print_next_steps
}

# Run main function
main "$@"