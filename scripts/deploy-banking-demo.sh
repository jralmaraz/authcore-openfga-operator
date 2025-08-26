#!/bin/bash

# deploy-banking-demo.sh - Deploy Banking Demo Application for Local Testing
# This script builds and deploys the banking demo application to Minikube/Kubernetes
# Compatible with Linux, macOS, and Windows (WSL)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEMO_NAME="banking-demo"
DEMO_IMAGE="banking-demo:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BANKING_DEMO_DIR="$PROJECT_ROOT/demos/banking-app"
NAMESPACE="openfga-system"

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

# Detect available container runtime
detect_container_runtime() {
    if [ -n "${CONTAINER_RUNTIME:-}" ]; then
        case "$CONTAINER_RUNTIME" in
            docker|podman)
                if command_exists "$CONTAINER_RUNTIME"; then
                    echo "$CONTAINER_RUNTIME"
                    return 0
                else
                    log_warning "Specified runtime '$CONTAINER_RUNTIME' not found, falling back to auto-detection"
                fi
                ;;
            *)
                log_warning "Invalid CONTAINER_RUNTIME '$CONTAINER_RUNTIME', falling back to auto-detection"
                ;;
        esac
    fi
    
    # Auto-detect available runtime
    if command_exists docker; then
        echo "docker"
    elif command_exists podman; then
        echo "podman"
    else
        echo ""
    fi
}

# Get container runtime or exit with error
get_container_runtime() {
    local runtime
    runtime=$(detect_container_runtime)
    
    if [ -z "$runtime" ]; then
        log_error "No container runtime found. Please install Docker or Podman."
        exit 1
    fi
    
    echo "$runtime"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for required tools
    local missing_tools=()
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists node; then
        missing_tools+=("node (Node.js)")
    fi
    
    if ! command_exists npm; then
        missing_tools+=("npm")
    fi
    
    local runtime
    runtime=$(detect_container_runtime)
    if [ -z "$runtime" ]; then
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

# Check if OpenFGA instance exists
check_openfga_instance() {
    log_info "Checking for OpenFGA instance..."
    
    local openfga_services
    openfga_services=$(kubectl get services -l app=openfga --no-headers 2>/dev/null | wc -l)
    
    if [ "$openfga_services" -eq 0 ]; then
        log_warning "No OpenFGA instance found"
        echo "You need to deploy an OpenFGA instance first."
        echo "Run: kubectl apply -f examples/basic-openfga.yaml"
        echo ""
        read -p "Do you want to deploy a basic OpenFGA instance now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deploying basic OpenFGA instance..."
            kubectl apply -f "$PROJECT_ROOT/examples/basic-openfga.yaml"
            
            log_info "Waiting for OpenFGA to be ready..."
            kubectl wait --for=condition=available --timeout=300s deployment/openfga-basic || {
                log_warning "OpenFGA deployment is taking longer than expected"
                log_info "You can check the status with: kubectl get pods -l app=openfga"
            }
        else
            log_error "OpenFGA instance is required for the banking demo"
            exit 1
        fi
    else
        log_success "Found OpenFGA instance"
    fi
}

# Build the banking demo application
build_demo_app() {
    log_info "Building banking demo application..."
    
    cd "$BANKING_DEMO_DIR"
    
    # Install dependencies
    log_info "Installing Node.js dependencies..."
    npm ci
    
    # Build the application
    log_info "Building TypeScript application..."
    npm run build
    
    log_success "Banking demo application built successfully"
}

# Build Docker image
build_docker_image() {
    log_info "Building Docker image for banking demo..."
    
    cd "$BANKING_DEMO_DIR"
    
    local runtime
    runtime=$(get_container_runtime)
    
    # Build the image
    $runtime build -t "$DEMO_IMAGE" .
    
    # Load image into Minikube if using Docker
    if command_exists minikube && [ "$runtime" = "docker" ]; then
        log_info "Loading image into Minikube..."
        minikube image load "$DEMO_IMAGE"
    fi
    
    log_success "Docker image built and loaded"
}

# Setup OpenFGA store and authorization model
setup_openfga_store() {
    log_info "Setting up OpenFGA store and authorization model..."
    
    cd "$BANKING_DEMO_DIR"
    
    # Port-forward to OpenFGA in background
    log_info "Setting up port-forward to OpenFGA..."
    kubectl port-forward service/openfga-basic-http 8080:8080 >/dev/null 2>&1 &
    local port_forward_pid=$!
    
    # Give port-forward time to establish
    sleep 5
    
    # Setup the demo data
    if [ -f "package.json" ] && grep -q '"setup"' package.json; then
        log_info "Running demo setup..."
        OPENFGA_API_URL=http://localhost:8080 npm run setup || {
            log_warning "Demo setup failed, but continuing with deployment"
        }
    else
        log_warning "Setup script not found, skipping demo data initialization"
    fi
    
    # Stop port-forward
    kill $port_forward_pid 2>/dev/null || true
    
    log_success "OpenFGA setup completed"
}

# Deploy to Kubernetes
deploy_to_kubernetes() {
    log_info "Deploying banking demo to Kubernetes..."
    
    cd "$BANKING_DEMO_DIR"
    
    # Apply Kubernetes manifests
    kubectl apply -f k8s/
    
    # Wait for deployment to be ready
    log_info "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/banking-demo-app || {
        log_warning "Deployment is taking longer than expected"
        log_info "You can check the status with: kubectl get pods -l app=banking-demo"
    }
    
    log_success "Banking demo deployed successfully"
}

# Show deployment status
show_status() {
    log_info "Deployment status:"
    echo
    
    echo "Banking demo pods:"
    kubectl get pods -l app=banking-demo
    echo
    
    echo "Banking demo services:"
    kubectl get services -l app=banking-demo
    echo
    
    echo "OpenFGA pods:"
    kubectl get pods -l app=openfga
    echo
}

# Setup port forwarding and provide access instructions
setup_access() {
    log_info "Setting up access to the banking demo..."
    
    # Get service details
    local service_name
    service_name=$(kubectl get services -l app=banking-demo --no-headers | head -1 | awk '{print $1}')
    
    if [ -z "$service_name" ]; then
        log_error "Banking demo service not found"
        return 1
    fi
    
    echo
    echo "=========================================="
    echo "       BANKING DEMO ACCESS GUIDE"
    echo "=========================================="
    echo
    echo "✅ Banking demo deployed successfully!"
    echo
    echo "🌐 Access the banking demo:"
    echo "   kubectl port-forward service/$service_name 3000:80"
    echo "   Then visit: http://localhost:3000"
    echo
    echo "📋 API Testing:"
    echo "   # Health check"
    echo "   curl http://localhost:3000/health"
    echo
    echo "   # Get accounts (after port-forward)"
    echo "   curl http://localhost:3000/api/accounts"
    echo
    echo "🔍 Monitoring:"
    echo "   # Check pod logs"
    echo "   kubectl logs -l app=banking-demo -f"
    echo
    echo "   # Check pod status"
    echo "   kubectl get pods -l app=banking-demo"
    echo
    echo "🧹 Cleanup:"
    echo "   # Remove the demo"
    echo "   kubectl delete -f $BANKING_DEMO_DIR/k8s/"
    echo
    echo "💡 Note: The demo includes realistic banking authorization scenarios"
    echo "   with accounts, transactions, loans, and role-based access control."
    echo
}

# Test the deployment
test_deployment() {
    log_info "Testing banking demo deployment..."
    
    # Check if pods are running
    local running_pods
    running_pods=$(kubectl get pods -l app=banking-demo --field-selector=status.phase=Running --no-headers | wc -l)
    
    if [ "$running_pods" -eq 0 ]; then
        log_error "No running pods found for banking demo"
        return 1
    fi
    
    log_success "Found $running_pods running pod(s)"
    
    # Test API connectivity (optional)
    local service_name
    service_name=$(kubectl get services -l app=banking-demo --no-headers | head -1 | awk '{print $1}')
    
    if [ -n "$service_name" ]; then
        log_info "Testing API connectivity..."
        
        # Start port-forward in background for testing
        kubectl port-forward service/"$service_name" 3000:80 >/dev/null 2>&1 &
        local test_port_forward_pid=$!
        
        # Give port-forward time to establish
        sleep 5
        
        # Test the health endpoint
        if command_exists curl; then
            if curl -s http://localhost:3000/health >/dev/null 2>&1; then
                log_success "API health check passed"
            else
                log_warning "API health check failed (this may be normal if the app is still starting)"
            fi
        fi
        
        # Stop test port-forward
        kill $test_port_forward_pid 2>/dev/null || true
    fi
    
    log_success "Deployment test completed"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up banking demo deployment..."
    
    cd "$BANKING_DEMO_DIR"
    kubectl delete -f k8s/ || true
    
    # Clean up any running port-forwards
    pkill -f "kubectl port-forward.*banking" 2>/dev/null || true
    
    log_success "Banking demo cleanup completed"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Deploy the Banking Demo Application for local testing"
    echo
    echo "Options:"
    echo "  --cleanup         Remove the banking demo deployment"
    echo "  --test-only       Only test an existing deployment"
    echo "  --skip-build      Skip building the application and Docker image"
    echo "  --help           Show this help message"
    echo
    echo "Environment Variables:"
    echo "  CONTAINER_RUNTIME  Specify container runtime (docker|podman)"
    echo
    echo "Examples:"
    echo "  $0                    # Deploy the banking demo"
    echo "  $0 --cleanup          # Remove the banking demo"
    echo "  $0 --test-only        # Test existing deployment"
    echo "  CONTAINER_RUNTIME=podman $0  # Use Podman instead of Docker"
}

# Main function
main() {
    echo "=================================================="
    echo "  Banking Demo Deployment for Local Testing"
    echo "=================================================="
    echo
    
    # Parse command line arguments
    local skip_build=false
    local test_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cleanup)
                cleanup
                exit 0
                ;;
            --test-only)
                test_only=true
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
    
    if [ "$test_only" = true ]; then
        check_prerequisites
        test_deployment
        show_status
        setup_access
        exit 0
    fi
    
    # Main deployment flow
    check_prerequisites
    check_openfga_instance
    
    if [ "$skip_build" = false ]; then
        build_demo_app
        build_docker_image
    fi
    
    deploy_to_kubernetes
    setup_openfga_store
    test_deployment
    show_status
    setup_access
    
    log_success "Banking demo deployment completed successfully!"
}

# Handle script termination
trap 'log_warning "Script interrupted"' INT TERM

# Run main function with all arguments
main "$@"