#!/bin/bash

# deploy-demos.sh - Deploy Both Demo Applications for Local Testing
# This script builds and deploys both the banking and GenAI RAG demo applications to Minikube/Kubernetes
# Compatible with Linux, macOS, and Windows (WSL)

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

# Check prerequisites for both demos
check_prerequisites() {
    log_info "Checking prerequisites for demo deployment..."
    
    # Check for required tools
    local missing_tools=()
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists node; then
        missing_tools+=("node (for banking demo)")
    fi
    
    if ! command_exists npm; then
        missing_tools+=("npm (for banking demo)")
    fi
    
    if ! command_exists python3; then
        missing_tools+=("python3 (for GenAI demo)")
    fi
    
    if ! command_exists pip3; then
        missing_tools+=("pip3 (for GenAI demo)")
    fi
    
    if ! command_exists docker && ! command_exists podman; then
        missing_tools+=("docker or podman")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check Kubernetes cluster access
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster"
        echo "Please ensure kubectl is configured and cluster is accessible."
        echo "For Minikube: run 'minikube start'"
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Deploy both demo applications
deploy_both_demos() {
    local banking_success=true
    local genai_success=true
    
    echo "=========================================="
    echo "  DEPLOYING BANKING DEMO APPLICATION"
    echo "=========================================="
    echo
    
    # Deploy banking demo
    if "$SCRIPT_DIR/deploy-banking-demo.sh" "$@"; then
        log_success "Banking demo deployment completed"
    else
        log_error "Banking demo deployment failed"
        banking_success=false
    fi
    
    echo
    echo "=========================================="
    echo "  DEPLOYING GENAI RAG DEMO APPLICATION"
    echo "=========================================="
    echo
    
    # Deploy GenAI demo
    if "$SCRIPT_DIR/deploy-genai-demo.sh" "$@"; then
        log_success "GenAI RAG demo deployment completed"
    else
        log_error "GenAI RAG demo deployment failed"
        genai_success=false
    fi
    
    # Summary
    echo
    echo "=========================================="
    echo "           DEPLOYMENT SUMMARY"
    echo "=========================================="
    echo
    
    if [ "$banking_success" = true ]; then
        echo "✅ Banking Demo: Successfully deployed"
    else
        echo "❌ Banking Demo: Deployment failed"
    fi
    
    if [ "$genai_success" = true ]; then
        echo "✅ GenAI RAG Demo: Successfully deployed"
    else
        echo "❌ GenAI RAG Demo: Deployment failed"
    fi
    
    if [ "$banking_success" = true ] || [ "$genai_success" = true ]; then
        show_combined_access_guide "$banking_success" "$genai_success"
    fi
    
    if [ "$banking_success" = false ] || [ "$genai_success" = false ]; then
        echo
        log_warning "Some deployments failed. Check the logs above for details."
        return 1
    fi
}

# Show combined access guide for both demos
show_combined_access_guide() {
    local banking_success=$1
    local genai_success=$2
    
    echo
    echo "=========================================="
    echo "        DEMO ACCESS GUIDE"
    echo "=========================================="
    echo
    
    if [ "$banking_success" = true ]; then
        echo "🏦 BANKING DEMO:"
        echo "   Access: kubectl port-forward service/banking-demo-service 3000:80"
        echo "   URL: http://localhost:3000"
        echo "   Health: curl http://localhost:3000/health"
        echo "   API: curl http://localhost:3000/api/accounts"
        echo
    fi
    
    if [ "$genai_success" = true ]; then
        echo "🤖 GENAI RAG DEMO:"
        echo "   Access: kubectl port-forward service/genai-rag-agent-service 8000:80"
        echo "   URL: http://localhost:8000"
        echo "   Health: curl http://localhost:8000/health"
        echo "   API: curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases"
        echo
    fi
    
    echo "🔍 MONITORING:"
    if [ "$banking_success" = true ]; then
        echo "   Banking logs: kubectl logs -l app=banking-demo -f"
    fi
    if [ "$genai_success" = true ]; then
        echo "   GenAI logs: kubectl logs -l app=genai-rag-agent -f"
    fi
    echo "   All pods: kubectl get pods"
    echo "   All services: kubectl get services"
    echo
    
    echo "🧹 CLEANUP:"
    echo "   Remove all demos: $0 --cleanup"
    if [ "$banking_success" = true ]; then
        echo "   Banking only: $SCRIPT_DIR/deploy-banking-demo.sh --cleanup"
    fi
    if [ "$genai_success" = true ]; then
        echo "   GenAI only: $SCRIPT_DIR/deploy-genai-demo.sh --cleanup"
    fi
    echo
    
    echo "💡 DEMO SCENARIOS:"
    echo "   Both demos showcase fine-grained authorization with OpenFGA:"
    if [ "$banking_success" = true ]; then
        echo "   - Banking: Role-based access, multi-ownership, transaction controls"
    fi
    if [ "$genai_success" = true ]; then
        echo "   - GenAI: Knowledge base permissions, document access, chat sessions"
    fi
    echo
}

# Test both demos
test_both_demos() {
    local banking_test=true
    local genai_test=true
    
    echo "=========================================="
    echo "        TESTING DEPLOYED DEMOS"
    echo "=========================================="
    echo
    
    # Test banking demo
    echo "Testing Banking Demo..."
    if ! "$SCRIPT_DIR/deploy-banking-demo.sh" --test-only; then
        banking_test=false
    fi
    
    echo
    echo "Testing GenAI RAG Demo..."
    if ! "$SCRIPT_DIR/deploy-genai-demo.sh" --test-only; then
        genai_test=false
    fi
    
    echo
    echo "Test Results:"
    if [ "$banking_test" = true ]; then
        echo "✅ Banking Demo: Tests passed"
    else
        echo "❌ Banking Demo: Tests failed"
    fi
    
    if [ "$genai_test" = true ]; then
        echo "✅ GenAI RAG Demo: Tests passed"
    else
        echo "❌ GenAI RAG Demo: Tests failed"
    fi
    
    if [ "$banking_test" = true ] || [ "$genai_test" = true ]; then
        show_combined_access_guide "$banking_test" "$genai_test"
    fi
}

# Cleanup both demos
cleanup_both_demos() {
    log_info "Cleaning up all demo deployments..."
    
    local banking_cleanup=true
    local genai_cleanup=true
    
    # Cleanup banking demo
    if ! "$SCRIPT_DIR/deploy-banking-demo.sh" --cleanup; then
        banking_cleanup=false
    fi
    
    # Cleanup GenAI demo
    if ! "$SCRIPT_DIR/deploy-genai-demo.sh" --cleanup; then
        genai_cleanup=false
    fi
    
    # Summary
    echo
    if [ "$banking_cleanup" = true ] && [ "$genai_cleanup" = true ]; then
        log_success "All demo applications cleaned up successfully"
    else
        log_warning "Some cleanup operations may have failed"
    fi
}

# Show comprehensive status of both demos
show_comprehensive_status() {
    echo "=========================================="
    echo "        COMPREHENSIVE DEMO STATUS"
    echo "=========================================="
    echo
    
    # OpenFGA status
    echo "OpenFGA Status:"
    kubectl get pods -l app=openfga 2>/dev/null || echo "No OpenFGA pods found"
    kubectl get services -l app=openfga 2>/dev/null || echo "No OpenFGA services found"
    echo
    
    # Banking demo status
    echo "Banking Demo Status:"
    kubectl get pods -l app=banking-demo 2>/dev/null || echo "No banking demo pods found"
    kubectl get services -l app=banking-demo 2>/dev/null || echo "No banking demo services found"
    echo
    
    # GenAI demo status
    echo "GenAI RAG Demo Status:"
    kubectl get pods -l app=genai-rag-agent 2>/dev/null || echo "No GenAI demo pods found"
    kubectl get services -l app=genai-rag-agent 2>/dev/null || echo "No GenAI demo services found"
    echo
    
    # Resource usage (if metrics are available)
    echo "Resource Usage (if available):"
    kubectl top pods 2>/dev/null || echo "Pod metrics not available"
    echo
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Deploy both demo applications (Banking and GenAI RAG) for local testing"
    echo
    echo "Options:"
    echo "  --banking-only    Deploy only the banking demo"
    echo "  --genai-only      Deploy only the GenAI RAG demo"
    echo "  --cleanup         Remove all demo deployments"
    echo "  --test-only       Only test existing deployments"
    echo "  --status          Show comprehensive status of all demos"
    echo "  --skip-build      Skip building applications and Docker images"
    echo "  --help           Show this help message"
    echo
    echo "Environment Variables:"
    echo "  CONTAINER_RUNTIME  Specify container runtime (docker|podman)"
    echo "  OPENAI_API_KEY    Optional: Your OpenAI API key for GenAI demo"
    echo
    echo "Examples:"
    echo "  $0                      # Deploy both demos"
    echo "  $0 --banking-only       # Deploy only banking demo"
    echo "  $0 --genai-only         # Deploy only GenAI demo"
    echo "  $0 --cleanup            # Remove all deployments"
    echo "  $0 --test-only          # Test existing deployments"
    echo "  $0 --status             # Show status of all demos"
    echo "  $0 --skip-build         # Deploy without rebuilding"
    echo
    echo "Individual Demo Scripts:"
    echo "  $SCRIPT_DIR/deploy-banking-demo.sh   # Banking demo only"
    echo "  $SCRIPT_DIR/deploy-genai-demo.sh     # GenAI demo only"
}

# Main function
main() {
    echo "=================================================="
    echo "    OpenFGA Demo Applications Deployment"
    echo "=================================================="
    echo

    # Initialize script_args as an empty array to avoid unbound variable error
    local script_args=()
    
    # Parse command line arguments
    local banking_only=false
    local genai_only=false
    local test_only=false
    local skip_build=false
    local show_status_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --banking-only)
                banking_only=true
                shift
                ;;
            --genai-only)
                genai_only=true
                shift
                ;;
            --cleanup)
                cleanup_both_demos
                exit 0
                ;;
            --test-only)
                test_only=true
                shift
                ;;
            --status)
                show_status_only=true
                shift
                ;;
            --skip-build)
                skip_build=true
                shift
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
    
    # Handle status-only request
    if [ "$show_status_only" = true ]; then
        show_comprehensive_status
        exit 0
    fi
    
    # Handle test-only request
    if [ "$test_only" = true ]; then
        check_prerequisites
        test_both_demos
        exit 0
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Handle individual demo deployments
    if [ "$banking_only" = true ] && [ "$genai_only" = true ]; then
        log_error "Cannot specify both --banking-only and --genai-only"
        exit 1
    fi
    
    if [ "$skip_build" = true ]; then
        script_args+=("--skip-build")
    fi
    
    if [ "$banking_only" = true ]; then
        echo "Deploying Banking Demo only..."
        "$SCRIPT_DIR/deploy-banking-demo.sh" "${script_args[@]}"
    elif [ "$genai_only" = true ]; then
        echo "Deploying GenAI RAG Demo only..."
        "$SCRIPT_DIR/deploy-genai-demo.sh" "${script_args[@]}"
    else
        # Deploy both demos
        deploy_both_demos "${script_args[@]}"
    fi
    
    log_success "Demo deployment process completed!"
}

# Handle script termination
trap 'log_warning "Script interrupted"' INT TERM

# Run main function with all arguments
main "$@"