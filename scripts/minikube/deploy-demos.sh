#!/bin/bash

# deploy-demos.sh - Deploy OpenFGA Operator demo applications to Minikube
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
DEMO_NAMESPACE="default"
BANKING_APP_IMAGE="banking-app:latest"
GENAI_APP_IMAGE="genai-rag-agent:latest"
TIMEOUT=300
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Demo application configuration
BANKING_APP_PORT=3000
GENAI_APP_PORT=8000

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

# Wait for deployment to be ready with timeout
wait_for_deployment() {
    local deployment_name="$1"
    local namespace="$2"
    local timeout="$3"
    
    log_info "Waiting for deployment $deployment_name to be ready (timeout: ${timeout}s)..."
    
    if kubectl wait --for=condition=available --timeout="${timeout}s" deployment/"$deployment_name" -n "$namespace" >/dev/null 2>&1; then
        log_success "Deployment $deployment_name is ready"
        return 0
    else
        log_warning "Deployment $deployment_name may not be fully ready yet"
        return 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command_exists kubectl; then
        log_error "kubectl is not installed. Please run setup-minikube.sh first."
        exit 1
    fi
    
    if ! command_exists minikube; then
        log_error "minikube is not installed. Please run setup-minikube.sh first."
        exit 1
    fi
    
    # Check if Minikube is running
    if ! minikube status >/dev/null 2>&1; then
        log_error "Minikube is not running. Please start Minikube first."
        exit 1
    fi
    
    # Check container runtime
    local runtime
    if command_exists docker && docker info >/dev/null 2>&1; then
        runtime="docker"
    elif command_exists podman && podman info >/dev/null 2>&1; then
        runtime="podman"
    else
        log_error "No container runtime (Docker or Podman) is available."
        exit 1
    fi
    
    log_info "Using container runtime: $runtime"
    
    # Check if Node.js is available for banking app
    if ! command_exists node; then
        log_warning "Node.js not found. Banking app build may fail."
    fi
    
    # Check if Python is available for GenAI app
    if ! command_exists python3; then
        log_warning "Python 3 not found. GenAI app build may fail."
    fi
    
    log_success "Prerequisites check passed"
}

# Verify operator is deployed
verify_operator_deployment() {
    log_info "Verifying OpenFGA operator deployment..."
    
    # Check if operator namespace exists
    if ! kubectl get namespace "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        log_error "OpenFGA operator namespace '$OPERATOR_NAMESPACE' does not exist."
        log_info "Please run deploy-operator.sh first to deploy the operator."
        exit 1
    fi
    
    # Check if operator deployment exists and is ready
    if ! kubectl get deployment openfga-operator -n "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        log_error "OpenFGA operator deployment does not exist."
        log_info "Please run deploy-operator.sh first to deploy the operator."
        exit 1
    fi
    
    # Wait for operator to be ready
    if ! kubectl wait --for=condition=available --timeout=60s deployment/openfga-operator-project-controller-manager -n "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        log_error "OpenFGA operator deployment is not ready."
        log_info "Please ensure the operator is running properly."
        exit 1
    fi
    
    log_success "OpenFGA operator is deployed and ready"
}

# Deploy basic OpenFGA instance if needed
deploy_openfga_instance() {
    log_info "Checking for OpenFGA instances..."
    
    # Check if basic OpenFGA instance exists
    if kubectl get openfga openfga-basic -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
        log_info "Basic OpenFGA instance already exists"
    else
        log_info "Deploying basic OpenFGA instance..."
        cd "$PROJECT_ROOT"
        kubectl apply -f examples/basic-openfga.yaml
        
        # Wait for OpenFGA deployment
        log_info "Waiting for OpenFGA instance to be ready..."
        sleep 10  # Give it a moment to start creating resources
        
        if kubectl wait --for=condition=available --timeout=300s deployment/openfga-basic -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
            log_success "OpenFGA instance is ready"
        else
            log_warning "OpenFGA instance may need more time to start"
        fi
    fi
}

# Build and load banking app image
build_banking_app() {
    log_info "Building Banking Application..."
    
    cd "$PROJECT_ROOT/demos/banking-app"
    
    # Install dependencies if package.json exists
    if [[ -f "package.json" ]]; then
        log_info "Installing Node.js dependencies..."
        npm install
        
        log_info "Building TypeScript application..."
        npm run build
    fi
    
    # Build Docker image
    log_info "Building Docker image: $BANKING_APP_IMAGE"
    local runtime
    if command_exists docker; then
        runtime="docker"
    else
        runtime="podman"
    fi
    
    $runtime build -t "$BANKING_APP_IMAGE" .
    
    # Load image into Minikube
    log_info "Loading image into Minikube..."
    minikube image load "$BANKING_APP_IMAGE"
    
    log_success "Banking app image built and loaded"
}

# Build and load GenAI RAG app image
build_genai_app() {
    log_info "Building GenAI RAG Agent..."
    
    cd "$PROJECT_ROOT/demos/genai-rag-agent"
    
    # Build Docker image
    log_info "Building Docker image: $GENAI_APP_IMAGE"
    local runtime
    if command_exists docker; then
        runtime="docker"
    else
        runtime="podman"
    fi
    
    $runtime build -t "$GENAI_APP_IMAGE" .
    
    # Load image into Minikube
    log_info "Loading image into Minikube..."
    minikube image load "$GENAI_APP_IMAGE"
    
    log_success "GenAI RAG agent image built and loaded"
}

# Deploy banking application
deploy_banking_app() {
    log_info "Deploying Banking Application..."
    
    cd "$PROJECT_ROOT/demos/banking-app"
    
    # Apply Kubernetes manifests
    kubectl apply -f k8s/deployment.yaml
    
    # Wait for deployment
    wait_for_deployment "banking-demo-app" "$DEMO_NAMESPACE" "$TIMEOUT"
    
    log_success "Banking application deployed"
}

# Deploy GenAI RAG application  
deploy_genai_app() {
    log_info "Deploying GenAI RAG Agent..."
    
    cd "$PROJECT_ROOT/demos/genai-rag-agent"
    
    # Apply Kubernetes manifests
    kubectl apply -f k8s/deployment.yaml
    
    # Wait for deployment
    wait_for_deployment "genai-rag-agent" "$DEMO_NAMESPACE" "$TIMEOUT"
    
    log_success "GenAI RAG agent deployed"
}

# Setup demo data for applications
setup_demo_data() {
    log_info "Setting up demo data..."
    
    # Wait a bit for services to stabilize
    sleep 10
    
    # Setup banking app demo data
    log_info "Setting up banking app demo data..."
    if kubectl get pod -l app=banking-demo -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
        local banking_pod
        banking_pod=$(kubectl get pod -l app=banking-demo -n "$DEMO_NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        
        if [[ -n "$banking_pod" ]]; then
            if kubectl exec -n "$DEMO_NAMESPACE" "$banking_pod" -- npm run setup 2>/dev/null; then
                log_success "Banking app demo data setup complete"
            else
                log_warning "Banking app demo data setup failed - this is normal if OpenFGA is still starting"
            fi
        fi
    fi
    
    # Setup GenAI app demo data
    log_info "Setting up GenAI RAG agent demo data..."
    if kubectl get pod -l app=genai-rag-agent -n "$DEMO_NAMESPACE" >/dev/null 2>&1; then
        local genai_pod
        genai_pod=$(kubectl get pod -l app=genai-rag-agent -n "$DEMO_NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        
        if [[ -n "$genai_pod" ]]; then
            if kubectl exec -n "$DEMO_NAMESPACE" "$genai_pod" -- python setup.py 2>/dev/null; then
                log_success "GenAI RAG agent demo data setup complete"
            else
                log_warning "GenAI RAG agent demo data setup failed - this is normal if OpenFGA is still starting"
            fi
        fi
    fi
}

# Display deployment status
show_deployment_status() {
    log_info "Deployment Status:"
    echo
    
    echo "OpenFGA Operator:"
    kubectl get pods -n "$OPERATOR_NAMESPACE" --no-headers 2>/dev/null || echo "  No pods found"
    echo
    
    echo "OpenFGA Instances:"
    kubectl get openfgas -n "$DEMO_NAMESPACE" --no-headers 2>/dev/null || echo "  No instances found"
    echo
    
    echo "Demo Applications:"
    kubectl get deployments -n "$DEMO_NAMESPACE" -l app=banking-demo --no-headers 2>/dev/null || echo "  Banking app: Not deployed"
    kubectl get deployments -n "$DEMO_NAMESPACE" -l app=genai-rag-agent --no-headers 2>/dev/null || echo "  GenAI app: Not deployed"
    echo
    
    echo "Services:"
    kubectl get services -n "$DEMO_NAMESPACE" -l app=banking-demo --no-headers 2>/dev/null || true
    kubectl get services -n "$DEMO_NAMESPACE" -l app=genai-rag-agent --no-headers 2>/dev/null || true
    echo
}

# Print access instructions
print_access_instructions() {
    echo
    log_success "Demo applications deployed successfully!"
    echo
    echo "=================================================="
    echo "            ACCESS INSTRUCTIONS"
    echo "=================================================="
    echo
    echo "1. Banking Application:"
    echo "   # Port-forward to access:"
    echo "   kubectl port-forward service/banking-demo-service 3000:80 &"
    echo "   # Then open: http://localhost:3000"
    echo "   # API Health: curl http://localhost:3000/health"
    echo
    echo "2. GenAI RAG Agent:"
    echo "   # Port-forward to access:"
    echo "   kubectl port-forward service/genai-rag-agent-service 8000:80 &"
    echo "   # Then open: http://localhost:8000/docs"
    echo "   # API Health: curl http://localhost:8000/health"
    echo
    echo "3. OpenFGA API (if needed):"
    echo "   # Port-forward to access:"
    echo "   kubectl port-forward service/openfga-basic-http 8080:8080 &"
    echo "   # API Health: curl http://localhost:8080/healthz"
    echo
    echo "=================================================="
    echo "            DEMO USAGE EXAMPLES"
    echo "=================================================="
    echo
    echo "Banking App API Examples:"
    echo "   # List accounts"
    echo "   curl -H 'x-user-id: alice' http://localhost:3000/api/accounts"
    echo
    echo "   # Create transaction"
    echo "   curl -X POST http://localhost:3000/api/transactions \\"
    echo "     -H 'x-user-id: alice' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"from\": \"acc_001\", \"to\": \"acc_002\", \"amount\": 100}'"
    echo
    echo "GenAI RAG API Examples:"
    echo "   # List knowledge bases"
    echo "   curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases"
    echo
    echo "   # Create chat session"
    echo "   curl -X POST http://localhost:8000/api/chat/sessions \\"
    echo "     -H 'x-user-id: alice' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"name\": \"Demo Chat\", \"organization_id\": \"demo-org\", \"knowledge_base_ids\": [\"kb_demo\"], \"model_id\": \"gpt-3.5-turbo\"}'"
    echo
    echo "=================================================="
    echo "            TROUBLESHOOTING"
    echo "=================================================="
    echo
    echo "If services are not accessible:"
    echo "1. Check pod status: kubectl get pods"
    echo "2. Check logs: kubectl logs -l app=banking-demo"
    echo "3. Check logs: kubectl logs -l app=genai-rag-agent"
    echo "4. Restart setup: ./scripts/minikube/validate-demos.sh"
    echo
    echo "To stop port-forwarding:"
    echo "   pkill -f 'kubectl port-forward'"
    echo
    echo "For more help, see: docs/minikube/"
}

# Handle cleanup on script exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Deployment failed. Check the logs above for details."
        echo
        echo "Common issues and solutions:"
        echo "1. Minikube not running: minikube start"
        echo "2. Operator not deployed: ./scripts/minikube/deploy-operator.sh"
        echo "3. Resource issues: minikube config set memory 8192"
        echo "4. Build failures: Check Docker/Podman and Node.js/Python installations"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Main function
main() {
    local demo_apps=()
    local skip_build=false
    local skip_setup=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --banking)
                demo_apps+=("banking")
                shift
                ;;
            --genai)
                demo_apps+=("genai")
                shift
                ;;
            --skip-build)
                skip_build=true
                shift
                ;;
            --skip-setup)
                skip_setup=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Deploy OpenFGA Operator demo applications to Minikube"
                echo
                echo "Options:"
                echo "  --banking      Deploy only the banking application"
                echo "  --genai        Deploy only the GenAI RAG agent"
                echo "  --skip-build   Skip building container images"
                echo "  --skip-setup   Skip setting up demo data"
                echo "  -h, --help     Show this help message"
                echo
                echo "If no specific demo is selected, both will be deployed."
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done
    
    # If no specific demo selected, deploy both
    if [[ ${#demo_apps[@]} -eq 0 ]]; then
        demo_apps=("banking" "genai")
    fi
    
    echo "=================================================="
    echo "  OpenFGA Demo Applications Deployment to Minikube"
    echo "=================================================="
    echo
    echo "Deploying: ${demo_apps[*]}"
    [[ $skip_build == true ]] && echo "Skipping: Image building"
    [[ $skip_setup == true ]] && echo "Skipping: Demo data setup"
    echo
    
    # Run deployment steps
    check_prerequisites
    verify_operator_deployment
    deploy_openfga_instance
    
    # Build and deploy selected applications
    for app in "${demo_apps[@]}"; do
        case $app in
            banking)
                if [[ $skip_build != true ]]; then
                    build_banking_app
                fi
                deploy_banking_app
                ;;
            genai)
                if [[ $skip_build != true ]]; then
                    build_genai_app
                fi
                deploy_genai_app
                ;;
        esac
    done
    
    # Setup demo data if not skipped
    if [[ $skip_setup != true ]]; then
        setup_demo_data
    fi
    
    # Show status and instructions
    show_deployment_status
    print_access_instructions
}

# Execute main function with all arguments
main "$@"