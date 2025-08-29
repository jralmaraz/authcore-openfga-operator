#!/bin/bash

# deploy-genai-demo.sh - Deploy GenAI RAG Agent Demo Application for Local Testing
# This script builds and deploys the GenAI RAG Agent demo application to Minikube/Kubernetes
# Compatible with Linux, macOS, and Windows (WSL)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEMO_NAME="genai-rag-agent"
DEMO_IMAGE="genai-rag-agent:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENAI_DEMO_DIR="$PROJECT_ROOT/demos/genai-rag-agent"
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
    
    if ! command_exists python3; then
        missing_tools+=("python3")
    fi
    
    if ! command_exists pip3; then
        missing_tools+=("pip3")
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

# Check if OpenFGA operator is available
check_openfga_operator() {
    log_info "Checking for OpenFGA operator..."
    
    # Check if the OpenFGA CRD exists
    if ! kubectl get crd openfgas.authorization.openfga.dev >/dev/null 2>&1; then
        log_warning "OpenFGA operator CRD not found"
        echo "The OpenFGA operator needs to be deployed first."
        echo "Run: ./scripts/minikube/deploy-operator.sh"
        echo ""
        read -p "Do you want to continue without the operator? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "OpenFGA operator is recommended for this demo"
            exit 1
        fi
        return 1
    fi
    
    # Check if operator is running
    local operator_pods
    operator_pods=$(kubectl get pods -n openfga-system -l app.kubernetes.io/name=openfga-operator --no-headers 2>/dev/null | wc -l)
    
    if [ "$operator_pods" -eq 0 ]; then
        log_warning "OpenFGA operator not running"
        echo "The OpenFGA operator needs to be deployed first."
        echo "Run: ./scripts/minikube/deploy-operator.sh"
        echo ""
        read -p "Do you want to continue without the operator? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "OpenFGA operator is recommended for this demo"
            exit 1
        fi
        return 1
    fi
    
    log_success "Found OpenFGA operator"
    return 0
}

# Check if OpenFGA instance exists
check_openfga_instance() {
    log_info "Checking for OpenFGA instance..."
    
    # First check if operator is available
    local has_operator=false
    if check_openfga_operator; then
        has_operator=true
    fi
    
    # Check for operator-managed OpenFGA instances first
    local openfga_resources=0
    if [ "$has_operator" = true ]; then
        openfga_resources=$(kubectl get openfgas.authorization.openfga.dev --no-headers 2>/dev/null | wc -l)
        
        if [ "$openfga_resources" -gt 0 ]; then
            log_success "Found operator-managed OpenFGA instance(s)"
            
            # Check if basic instance exists
            if kubectl get openfgas.authorization.openfga.dev openfga-basic >/dev/null 2>&1; then
                log_success "Found basic OpenFGA instance managed by operator"
                return 0
            fi
        fi
    fi
    
    # Fall back to checking for standard services
    local openfga_services
    openfga_services=$(kubectl get services -l app=openfga --no-headers 2>/dev/null | wc -l)
    
    if [ "$openfga_services" -eq 0 ] && [ "$openfga_resources" -eq 0 ]; then
        log_warning "No OpenFGA instance found"
        
        if [ "$has_operator" = true ]; then
            echo "You need to deploy an OpenFGA instance using the operator."
            echo "Run: kubectl apply -f examples/basic-openfga.yaml"
            echo ""
            read -p "Do you want to deploy a basic OpenFGA instance now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Deploying basic OpenFGA instance using operator..."
                kubectl apply -f "$PROJECT_ROOT/examples/basic-openfga.yaml"
                
                log_info "Waiting for OpenFGA to be ready..."
                # Wait for the OpenFGA resource to be created
                kubectl wait --for=condition=Ready --timeout=300s openfgas.authorization.openfga.dev/openfga-basic 2>/dev/null || {
                    # Fall back to waiting for deployment if condition is not available
                    kubectl wait --for=condition=available --timeout=300s deployment/openfga-basic 2>/dev/null || {
                        log_warning "OpenFGA deployment is taking longer than expected"
                        log_info "You can check the status with: kubectl get openfgas.authorization.openfga.dev"
                        log_info "Or check pods with: kubectl get pods -l app=openfga"
                    }
                }
            else
                log_error "OpenFGA instance is required for the GenAI RAG demo"
                exit 1
            fi
        else
            echo "You need to deploy an OpenFGA instance first."
            echo "Recommended: Use the operator by running ./scripts/minikube/deploy-operator.sh"
            echo "Alternative: Run kubectl apply -f examples/basic-openfga.yaml"
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
                log_error "OpenFGA instance is required for the GenAI RAG demo"
                exit 1
            fi
        fi
    else
        log_success "Found OpenFGA instance"
    fi
}

# Build the GenAI RAG demo application
build_demo_app() {
    log_info "Building GenAI RAG demo application..."
    
    cd "$GENAI_DEMO_DIR"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        log_info "Creating Python virtual environment..."
        python3 -m venv venv
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Install dependencies
    log_info "Installing Python dependencies..."
    pip install --upgrade pip
    pip install --upgrade setuptools
    pip install -r requirements.txt
    
    log_success "GenAI RAG demo application built successfully"
}

# Build Docker image
build_docker_image() {
    log_info "Building Docker image for GenAI RAG demo..."
    
    cd "$GENAI_DEMO_DIR"
    
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
    
    cd "$GENAI_DEMO_DIR"
    
    # Find the OpenFGA HTTP service
    local openfga_service=""
    
    # First try to find operator-managed service
    if kubectl get openfgas.authorization.openfga.dev openfga-basic >/dev/null 2>&1; then
        # Look for the HTTP service created by the operator
        openfga_service=$(kubectl get services -l app.kubernetes.io/name=openfga,app.kubernetes.io/instance=openfga-basic --no-headers 2>/dev/null | grep http | head -1 | awk '{print $1}')
        
        # If not found, try the standard naming pattern
        if [ -z "$openfga_service" ]; then
            openfga_service="openfga-basic-http"
        fi
    else
        # Fall back to looking for basic service
        openfga_service="openfga-basic-http"
    fi
    
    # Verify the service exists
    if ! kubectl get service "$openfga_service" >/dev/null 2>&1; then
        log_warning "Could not find OpenFGA HTTP service: $openfga_service"
        log_info "Looking for any OpenFGA HTTP service..."
        
        # Try to find any OpenFGA service with 'http' in the name
        openfga_service=$(kubectl get services --no-headers 2>/dev/null | grep -E "(openfga.*http|http.*openfga)" | head -1 | awk '{print $1}')
        
        if [ -z "$openfga_service" ]; then
            log_error "No OpenFGA HTTP service found. Please ensure OpenFGA is deployed correctly."
            return 1
        fi
        
        log_info "Found OpenFGA service: $openfga_service"
    fi
    
    # Port-forward to OpenFGA in background
    log_info "Setting up port-forward to OpenFGA service: $openfga_service"
    kubectl port-forward "service/$openfga_service" 8080:8080 >/dev/null 2>&1 &
    local port_forward_pid=$!
    
    # Give port-forward time to establish
    sleep 5
    
    # Setup the demo data
    if [ -f "setup.py" ]; then
        log_info "Running demo setup..."
        if [ -d "venv" ]; then
            source venv/bin/activate
        fi
        OPENFGA_API_URL=http://localhost:8080 python3 setup.py || {
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
    log_info "Deploying GenAI RAG demo to Kubernetes..."
    
    cd "$GENAI_DEMO_DIR"
    
    # Apply Kubernetes manifests
    kubectl apply -f k8s/
    
    # Wait for deployment to be ready
    log_info "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/genai-rag-agent || {
        log_warning "Deployment is taking longer than expected"
        log_info "You can check the status with: kubectl get pods -l app=genai-rag-agent"
    }
    
    log_success "GenAI RAG demo deployed successfully"
}

# Show deployment status
show_status() {
    log_info "Deployment status:"
    echo
    
    echo "GenAI RAG demo pods:"
    kubectl get pods -l app=genai-rag-agent
    echo
    
    echo "GenAI RAG demo services:"
    kubectl get services -l app=genai-rag-agent
    echo
    
    # Check for operator-managed OpenFGA instances
    if kubectl get crd openfgas.authorization.openfga.dev >/dev/null 2>&1; then
        echo "OpenFGA operator-managed instances:"
        kubectl get openfgas.authorization.openfga.dev 2>/dev/null || echo "No operator-managed instances found"
        echo
    fi
    
    echo "OpenFGA pods:"
    kubectl get pods -l app=openfga
    echo
    
    echo "OpenFGA services:"
    kubectl get services -l app=openfga
    echo
}

# Setup port forwarding and provide access instructions
setup_access() {
    log_info "Setting up access to the GenAI RAG demo..."
    
    # Get service details
    local service_name
    service_name=$(kubectl get services -l app=genai-rag-agent --no-headers | head -1 | awk '{print $1}')
    
    if [ -z "$service_name" ]; then
        log_error "GenAI RAG demo service not found"
        return 1
    fi
    
    echo
    echo "=========================================="
    echo "      GENAI RAG DEMO ACCESS GUIDE"
    echo "=========================================="
    echo
    echo "✅ GenAI RAG demo deployed successfully!"
    echo
    echo "🌐 Access the GenAI RAG demo:"
    echo "   kubectl port-forward service/$service_name 8000:80"
    echo "   Then visit: http://localhost:8000"
    echo
    echo "📋 API Testing:"
    echo "   # Health check"
    echo "   curl http://localhost:8000/health"
    echo
    echo "   # Get knowledge bases (after port-forward)"
    echo "   curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases"
    echo
    echo "   # List documents"
    echo "   curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases/kb_demo/documents"
    echo
    echo "   # Query the RAG system"
    echo "   curl -X POST -H 'Content-Type: application/json' -H 'x-user-id: alice' \\"
    echo "        -d '{\"query\": \"What is this system about?\"}' \\"
    echo "        http://localhost:8000/api/chat/sessions/session_demo_alice/query"
    echo
    echo "🔍 Monitoring:"
    echo "   # Check pod logs"
    echo "   kubectl logs -l app=genai-rag-agent -f"
    echo
    echo "   # Check pod status"
    echo "   kubectl get pods -l app=genai-rag-agent"
    echo
    echo "🧹 Cleanup:"
    echo "   # Remove the demo"
    echo "   kubectl delete -f $GENAI_DEMO_DIR/k8s/"
    echo
    echo "💡 Note: The demo includes realistic GenAI/RAG authorization scenarios"
    echo "   with knowledge bases, documents, chat sessions, and organization-based access control."
    echo
    echo "👥 Demo Users:"
    echo "   - alice (user) - Can access demo knowledge base"
    echo "   - bob (user) - Limited access"
    echo "   - charlie (curator) - Can manage knowledge bases"
    echo "   - diana (admin) - Full organization access"
    echo
    echo "⚠️  Note: OpenAI API key is optional for testing. The demo will work"
    echo "   without it, but RAG responses will be simulated."
    echo
}

# Test the deployment
test_deployment() {
    log_info "Testing GenAI RAG demo deployment..."
    
    # Check if pods are running
    local running_pods
    running_pods=$(kubectl get pods -l app=genai-rag-agent --field-selector=status.phase=Running --no-headers | wc -l)
    
    if [ "$running_pods" -eq 0 ]; then
        log_error "No running pods found for GenAI RAG demo"
        return 1
    fi
    
    log_success "Found $running_pods running pod(s)"
    
    # Test API connectivity (optional)
    local service_name
    service_name=$(kubectl get services -l app=genai-rag-agent --no-headers | head -1 | awk '{print $1}')
    
    if [ -n "$service_name" ]; then
        log_info "Testing API connectivity..."
        
        # Start port-forward in background for testing
        kubectl port-forward service/"$service_name" 8000:80 >/dev/null 2>&1 &
        local test_port_forward_pid=$!
        
        # Give port-forward time to establish
        sleep 5
        
        # Test the health endpoint
        if command_exists curl; then
            if curl -s http://localhost:8000/health >/dev/null 2>&1; then
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
    log_info "Cleaning up GenAI RAG demo deployment..."
    
    cd "$GENAI_DEMO_DIR"
    kubectl delete -f k8s/ || true
    
    # Clean up any running port-forwards
    pkill -f "kubectl port-forward.*genai" 2>/dev/null || true
    
    log_success "GenAI RAG demo cleanup completed"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Deploy the GenAI RAG Agent Demo Application for local testing"
    echo
    echo "Options:"
    echo "  --operator-tag TAG   Specify the operator image tag for validation"
    echo "  --cleanup            Remove the GenAI RAG demo deployment"
    echo "  --test-only          Only test an existing deployment"
    echo "  --skip-build         Skip building the application and Docker image"
    echo "  --help              Show this help message"
    echo
    echo "Environment Variables:"
    echo "  CONTAINER_RUNTIME  Specify container runtime (docker|podman)"
    echo "  OPENAI_API_KEY    Optional: Your OpenAI API key for real RAG responses"
    echo
    echo "Examples:"
    echo "  $0                       # Deploy the GenAI RAG demo"
    echo "  $0 --operator-tag v1.0   # Deploy with specific operator version validation"
    echo "  $0 --cleanup             # Remove the GenAI RAG demo"
    echo "  $0 --test-only           # Test existing deployment"
    echo "  CONTAINER_RUNTIME=podman $0  # Use Podman instead of Docker"
    echo "  OPENAI_API_KEY=sk-... $0     # Deploy with OpenAI integration"
}

# Main function
main() {
    echo "=================================================="
    echo "  GenAI RAG Demo Deployment for Local Testing"
    echo "=================================================="
    echo
    
    # Parse command line arguments
    local skip_build=false
    local test_only=false
    local operator_tag=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --operator-tag)
                operator_tag="$2"
                shift 2
                ;;
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
    
    # Set operator tag for validation if provided
    if [ -n "$operator_tag" ]; then
        log_info "Using operator tag for validation: $operator_tag"
        export OPERATOR_TAG="$operator_tag"
    fi
    
    if [ "$test_only" = true ]; then
        check_prerequisites
        test_deployment
        show_status
        setup_access
        exit 0
    fi
    
    # Main deployment flow
    check_prerequisites
    
    # Check for operator and OpenFGA instance  
    if check_openfga_operator; then
        log_info "Using OpenFGA operator for deployment"
    else
        log_info "Proceeding without OpenFGA operator"
    fi
    
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
    
    log_success "GenAI RAG demo deployment completed successfully!"
}

# Handle script termination
trap 'log_warning "Script interrupted"' INT TERM

# Run main function with all arguments
main "$@"