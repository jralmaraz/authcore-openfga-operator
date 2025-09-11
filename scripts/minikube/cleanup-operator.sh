#!/bin/bash

# cleanup-operator.sh - Comprehensive OpenFGA Operator Cleanup Script
# This script removes all OpenFGA operator-related resources from a Kubernetes cluster
# Compatible with Linux, macOS, and Windows (WSL)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OPERATOR_NAMESPACE="openfga-system"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Cleanup options (can be set via flags)
CLEANUP_CRDS=true
CLEANUP_NAMESPACE=true
CLEANUP_DEMOS=true
FORCE_CLEANUP=false
DRY_RUN=false

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

# Check if kubectl is available and cluster is reachable
check_kubectl() {
    if ! command_exists kubectl; then
        log_error "kubectl is not installed or not in PATH"
        return 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        return 1
    fi
    
    log_success "Kubernetes cluster is accessible"
    return 0
}

# Clean up OpenFGA custom resources
cleanup_openfga_resources() {
    log_info "Cleaning up OpenFGA custom resources..."
    
    # Check if OpenFGA CRD exists
    if ! kubectl get crd openfgas.authorization.openfga.dev >/dev/null 2>&1; then
        log_warning "OpenFGA CRD not found, skipping custom resource cleanup"
        return 0
    fi
    
    # Get list of OpenFGA resources
    local openfga_resources
    openfga_resources=$(kubectl get openfgas --all-namespaces -o name 2>/dev/null || echo "")
    
    if [ -n "$openfga_resources" ]; then
        log_info "Found OpenFGA resources to delete:"
        kubectl get openfgas --all-namespaces 2>/dev/null || true
        echo
        
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would delete all OpenFGA custom resources"
        else
            log_info "Deleting all OpenFGA custom resources..."
            kubectl delete openfgas --all --all-namespaces --timeout=60s || true
            log_success "OpenFGA custom resources deleted"
        fi
    else
        log_info "No OpenFGA custom resources found"
    fi
}

# Clean up demo applications
cleanup_demo_applications() {
    if [ "$CLEANUP_DEMOS" = false ]; then
        log_info "Skipping demo application cleanup (disabled)"
        return 0
    fi
    
    log_info "Cleaning up demo applications..."
    
    # Banking demo cleanup
    if [ -f "$PROJECT_ROOT/demos/banking-app/k8s/deployment.yaml" ] || [ -f "$PROJECT_ROOT/demos/banking-app/k8s/deployment-distroless.yaml" ]; then
        log_info "Cleaning up banking demo..."
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would delete banking demo resources"
        else
            kubectl delete -f "$PROJECT_ROOT/demos/banking-app/k8s/" --ignore-not-found=true || true
            pkill -f "kubectl port-forward.*banking" 2>/dev/null || true
        fi
    fi
    
    # GenAI RAG demo cleanup
    if [ -f "$PROJECT_ROOT/demos/genai-rag-agent/k8s/deployment.yaml" ] || [ -f "$PROJECT_ROOT/demos/genai-rag-agent/k8s/deployment-distroless.yaml" ]; then
        log_info "Cleaning up GenAI RAG demo..."
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would delete GenAI RAG demo resources"
        else
            kubectl delete -f "$PROJECT_ROOT/demos/genai-rag-agent/k8s/" --ignore-not-found=true || true
            pkill -f "kubectl port-forward.*genai" 2>/dev/null || true
        fi
    fi
    
    # Alternative cleanup using demo scripts if they exist
    for demo_script in "$PROJECT_ROOT/scripts/deploy-banking-demo.sh" "$PROJECT_ROOT/scripts/deploy-genai-demo.sh"; do
        if [ -f "$demo_script" ] && [ "$DRY_RUN" = false ]; then
            log_info "Running cleanup via $(basename "$demo_script")..."
            "$demo_script" --cleanup 2>/dev/null || true
        fi
    done
    
    log_success "Demo application cleanup completed"
}

# Clean up operator deployment and related resources
cleanup_operator_deployment() {
    log_info "Cleaning up OpenFGA operator deployment..."
    
    # Clean up operator deployment using main deployment file
    local deployment_file="$PROJECT_ROOT/examples/distroless-operator-deployment.yaml"
    if [ -f "$deployment_file" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would delete operator deployment from $deployment_file"
        else
            log_info "Deleting operator deployment from $deployment_file"
            kubectl delete -f "$deployment_file" --ignore-not-found=true || true
        fi
    fi
    
    # Clean up any remaining operator resources in the namespace
    if kubectl get namespace "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        log_info "Cleaning up remaining resources in $OPERATOR_NAMESPACE namespace..."
        
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would delete remaining resources in $OPERATOR_NAMESPACE"
        else
            # Delete deployments
            kubectl delete deployments --all -n "$OPERATOR_NAMESPACE" --timeout=60s 2>/dev/null || true
            
            # Delete services
            kubectl delete services --all -n "$OPERATOR_NAMESPACE" --timeout=30s 2>/dev/null || true
            
            # Delete configmaps
            kubectl delete configmaps --all -n "$OPERATOR_NAMESPACE" --timeout=30s 2>/dev/null || true
            
            # Delete secrets
            kubectl delete secrets --all -n "$OPERATOR_NAMESPACE" --timeout=30s 2>/dev/null || true
        fi
    fi
    
    # Clean up cluster-wide resources
    log_info "Cleaning up cluster-wide operator resources..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would delete cluster role and cluster role binding"
    else
        # Delete cluster role binding
        kubectl delete clusterrolebinding openfga-operator --ignore-not-found=true || true
        
        # Delete cluster role
        kubectl delete clusterrole openfga-operator --ignore-not-found=true || true
    fi
    
    log_success "Operator deployment cleanup completed"
}

# Clean up operator namespace
cleanup_operator_namespace() {
    if [ "$CLEANUP_NAMESPACE" = false ]; then
        log_info "Skipping namespace cleanup (disabled)"
        return 0
    fi
    
    log_info "Cleaning up operator namespace..."
    
    if kubectl get namespace "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would delete namespace $OPERATOR_NAMESPACE"
        else
            log_info "Deleting namespace $OPERATOR_NAMESPACE..."
            kubectl delete namespace "$OPERATOR_NAMESPACE" --timeout=120s || true
            
            # Wait for namespace deletion with timeout
            local timeout=60
            local count=0
            while kubectl get namespace "$OPERATOR_NAMESPACE" >/dev/null 2>&1 && [ $count -lt $timeout ]; do
                sleep 2
                count=$((count + 2))
                if [ $((count % 10)) -eq 0 ]; then
                    log_info "Waiting for namespace deletion... (${count}s elapsed)"
                fi
            done
            
            if kubectl get namespace "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
                log_warning "Namespace $OPERATOR_NAMESPACE is still terminating after ${timeout}s"
            else
                log_success "Namespace $OPERATOR_NAMESPACE deleted successfully"
            fi
        fi
    else
        log_info "Namespace $OPERATOR_NAMESPACE not found"
    fi
}

# Clean up Custom Resource Definitions
cleanup_crds() {
    if [ "$CLEANUP_CRDS" = false ]; then
        log_info "Skipping CRD cleanup (disabled)"
        return 0
    fi
    
    log_info "Cleaning up Custom Resource Definitions..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would uninstall CRDs using 'make uninstall-crds'"
    else
        # Use the existing make target to uninstall CRDs
        cd "$PROJECT_ROOT"
        if make uninstall-crds 2>/dev/null; then
            log_success "CRDs uninstalled successfully"
        else
            log_warning "Failed to uninstall CRDs using make target, trying manual cleanup..."
            kubectl delete crd openfgas.authorization.openfga.dev --ignore-not-found=true || true
        fi
    fi
}

# Stop any running port-forwards
cleanup_port_forwards() {
    log_info "Stopping any running port-forwards..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would stop OpenFGA-related port-forwards"
    else
        pkill -f "kubectl port-forward.*openfga" 2>/dev/null || true
        pkill -f "kubectl port-forward.*8080" 2>/dev/null || true
        log_success "Port-forwards stopped"
    fi
}

# Show what would be cleaned up (for dry run or confirmation)
show_cleanup_plan() {
    echo "=========================================="
    echo "        CLEANUP PLAN"
    echo "=========================================="
    echo
    
    echo "The following resources will be cleaned up:"
    echo
    
    if [ "$CLEANUP_DEMOS" = true ]; then
        echo "✓ Demo Applications:"
        echo "  - Banking demo (if present)"
        echo "  - GenAI RAG demo (if present)"
        echo
    fi
    
    echo "✓ OpenFGA Resources:"
    echo "  - All OpenFGA custom resources (openfgas)"
    echo "  - Operator deployment"
    echo "  - Services and ConfigMaps"
    echo "  - ServiceAccount"
    echo "  - ClusterRole and ClusterRoleBinding"
    echo
    
    if [ "$CLEANUP_NAMESPACE" = true ]; then
        echo "✓ Namespace:"
        echo "  - $OPERATOR_NAMESPACE namespace"
        echo
    fi
    
    if [ "$CLEANUP_CRDS" = true ]; then
        echo "✓ Custom Resource Definitions:"
        echo "  - openfgas.authorization.openfga.dev"
        echo
    fi
    
    echo "✓ Other:"
    echo "  - Running port-forwards"
    echo
}

# Show status before cleanup
show_current_status() {
    echo "=========================================="
    echo "        CURRENT STATUS"
    echo "=========================================="
    echo
    
    echo "Checking current OpenFGA operator resources..."
    echo
    
    # Check namespace
    if kubectl get namespace "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        echo "✓ Namespace: $OPERATOR_NAMESPACE exists"
        kubectl get all -n "$OPERATOR_NAMESPACE" 2>/dev/null || echo "  No resources in namespace"
    else
        echo "✗ Namespace: $OPERATOR_NAMESPACE not found"
    fi
    echo
    
    # Check CRDs
    if kubectl get crd openfgas.authorization.openfga.dev >/dev/null 2>&1; then
        echo "✓ CRD: openfgas.authorization.openfga.dev exists"
    else
        echo "✗ CRD: openfgas.authorization.openfga.dev not found"
    fi
    echo
    
    # Check OpenFGA resources
    local openfga_count=0
    if kubectl get openfgas --all-namespaces --no-headers >/dev/null 2>&1; then
        openfga_count=$(kubectl get openfgas --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
    fi
    if [ "${openfga_count:-0}" -gt 0 ]; then
        echo "✓ OpenFGA instances: $openfga_count found"
        kubectl get openfgas --all-namespaces 2>/dev/null || true
    else
        echo "✗ OpenFGA instances: none found"
    fi
    echo
    
    # Check cluster roles
    if kubectl get clusterrole openfga-operator >/dev/null 2>&1; then
        echo "✓ ClusterRole: openfga-operator exists"
    else
        echo "✗ ClusterRole: openfga-operator not found"
    fi
    
    if kubectl get clusterrolebinding openfga-operator >/dev/null 2>&1; then
        echo "✓ ClusterRoleBinding: openfga-operator exists"
    else
        echo "✗ ClusterRoleBinding: openfga-operator not found"
    fi
    echo
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Comprehensive cleanup script for OpenFGA operator and its resources"
    echo
    echo "Options:"
    echo "  --keep-crds          Do not delete Custom Resource Definitions"
    echo "  --keep-namespace     Do not delete the openfga-system namespace"
    echo "  --skip-demos         Do not clean up demo applications"
    echo "  --force              Skip confirmation prompt"
    echo "  --dry-run            Show what would be deleted without actually deleting"
    echo "  --status             Show current status of OpenFGA resources"
    echo "  --help               Show this help message"
    echo
    echo "Examples:"
    echo "  $0                           # Full cleanup with confirmation"
    echo "  $0 --force                   # Full cleanup without confirmation"
    echo "  $0 --keep-crds               # Clean up but keep CRDs"
    echo "  $0 --keep-namespace          # Clean up but keep namespace"
    echo "  $0 --skip-demos              # Clean up operator only, not demos"
    echo "  $0 --dry-run                 # Preview what would be deleted"
    echo "  $0 --status                  # Show current status"
    echo
    echo "This script will remove:"
    echo "  • All OpenFGA custom resources"
    echo "  • Demo applications (banking, genai-rag)"
    echo "  • Operator deployment and services"
    echo "  • ServiceAccount, ClusterRole, ClusterRoleBinding"
    echo "  • openfga-system namespace (unless --keep-namespace)"
    echo "  • OpenFGA CRDs (unless --keep-crds)"
    echo "  • Running port-forwards"
}

# Main cleanup function
perform_cleanup() {
    echo "=========================================="
    echo "   OPENFGA OPERATOR CLEANUP STARTING"
    echo "=========================================="
    echo
    
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY RUN MODE - No actual changes will be made"
        echo
    fi
    
    # Show current status
    show_current_status
    
    # Show cleanup plan
    show_cleanup_plan
    
    # Confirmation (unless force or dry-run)
    if [ "$FORCE_CLEANUP" = false ] && [ "$DRY_RUN" = false ]; then
        echo "⚠️  This will permanently delete the above resources."
        echo
        read -p "Are you sure you want to continue? [y/N]: " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled by user"
            exit 0
        fi
        echo
    fi
    
    # Perform cleanup steps
    cleanup_port_forwards
    cleanup_openfga_resources
    cleanup_demo_applications
    cleanup_operator_deployment
    cleanup_operator_namespace
    cleanup_crds
    
    echo
    echo "=========================================="
    echo "   OPENFGA OPERATOR CLEANUP COMPLETED"
    echo "=========================================="
    echo
    
    if [ "$DRY_RUN" = false ]; then
        log_success "All OpenFGA operator resources have been cleaned up"
        echo
        echo "To redeploy the operator, run:"
        echo "  make install-crds"
        echo "  kubectl apply -f examples/distroless-operator-deployment.yaml"
        echo
        echo "Or use the deployment scripts:"
        echo "  scripts/minikube/deploy-operator.sh"
    else
        log_info "Dry run completed - no changes were made"
    fi
}

# Main function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --keep-crds)
                CLEANUP_CRDS=false
                shift
                ;;
            --keep-namespace)
                CLEANUP_NAMESPACE=false
                shift
                ;;
            --skip-demos)
                CLEANUP_DEMOS=false
                shift
                ;;
            --force)
                FORCE_CLEANUP=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --status)
                show_current_status
                exit 0
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    if ! check_kubectl; then
        exit 1
    fi
    
    # Perform cleanup
    perform_cleanup
}

# Run main function with all arguments
main "$@"