#!/bin/bash

# Enhanced Minikube deployment script with registry support
# This script provides both registry-based and local build deployment options
# Supports both Docker and Podman as container runtimes

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_REGISTRY="ghcr.io/jralmaraz/authcore-openfga-operator"
DEFAULT_TAG="latest"
LOCAL_IMAGE="openfga-operator:latest"

# Functions
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
    # Check environment variable first
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

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command_exists minikube; then
        log_error "Minikube is not installed. Please install Minikube first."
        exit 1
    fi
    
    if ! command_exists kubectl; then
        log_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    if ! minikube status &> /dev/null; then
        log_error "Minikube is not running. Please start Minikube first: minikube start"
        exit 1
    fi
    
    # Check for any container runtime (Docker or Podman)
    local runtime
    runtime=$(detect_container_runtime)
    if [ -z "$runtime" ]; then
        log_error "No container runtime (Docker or Podman) is installed. Please install Docker or Podman for local builds."
        log_info "Note: Registry-based deployment does not require a local container runtime."
    else
        log_info "Using container runtime: $runtime"
    fi
    
    log_success "All prerequisites satisfied"
}

show_deployment_options() {
    echo ""
    echo "=========================================="
    echo "OpenFGA Operator Minikube Deployment"
    echo "=========================================="
    echo ""
    echo "Choose deployment method:"
    echo ""
    echo "1) Registry-based deployment (Recommended)"
    echo "   - Uses pre-built images from GitHub Container Registry"
    echo "   - More reliable, avoids local image loading issues"
    echo "   - Faster deployment, no local building required"
    echo "   - Supports automatic updates"
    echo ""
    echo "2) Local build deployment"
    echo "   - Builds image locally and loads into Minikube"
    echo "   - Good for development and testing local changes"
    echo "   - May encounter image loading issues in some environments"
    echo ""
    echo "3) Exit"
    echo ""
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Enhanced Minikube deployment script with registry support"
    echo "Supports both Docker and Podman as container runtimes"
    echo ""
    echo "Options:"
    echo "  --image-tag TAG    Specify the image tag to deploy (default: latest)"
    echo "  --registry URL     Specify the image registry (default: $DEFAULT_REGISTRY)"
    echo "  --interactive      Run in interactive mode (default behavior)"
    echo "  --registry-deploy  Deploy using registry image directly (non-interactive)"
    echo "  --local-deploy     Deploy using local build directly (non-interactive)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  CONTAINER_RUNTIME  Specify container runtime (docker|podman)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Interactive mode with default settings"
    echo "  $0 --image-tag v0.1.0-alpha          # Interactive mode with specific tag"
    echo "  $0 --registry-deploy --image-tag v1.0 # Direct registry deployment with specific tag"
    echo "  $0 --local-deploy                     # Direct local deployment"
    echo "  CONTAINER_RUNTIME=podman $0 --local-deploy # Use Podman for local deployment"
}

deploy_registry_based() {
    local registry="${IMAGE_REGISTRY:-$DEFAULT_REGISTRY}"
    local tag="${IMAGE_TAG:-$DEFAULT_TAG}"
    local full_image="$registry:$tag"
    
    log_info "Starting registry-based deployment..."
    log_info "Using image: $full_image"
    
    # Check if image exists (optional, as Kubernetes will pull it)
    log_info "Verifying image accessibility..."
    local runtime
    runtime=$(detect_container_runtime)
    if [ -n "$runtime" ]; then
        if $runtime pull "$full_image" &> /dev/null; then
            log_success "Image successfully verified: $full_image"
            $runtime rmi "$full_image" &> /dev/null || true  # Clean up local copy
        else
            log_warning "Could not pre-verify image, but deployment will attempt to pull it"
        fi
    else
        log_warning "No container runtime available for image verification, but deployment will attempt to pull it"
    fi
    
    # Deploy using Makefile
    log_info "Deploying operator to Minikube..."
    if IMAGE_REGISTRY="$registry" IMAGE_TAG="$tag" make minikube-setup-and-deploy-registry; then
        log_success "Registry-based deployment completed successfully!"
        show_success_info "$full_image"
        return 0
    else
        log_error "Registry-based deployment failed"
        return 1
    fi
}

deploy_local_build() {
    log_info "Starting local build deployment..."
    
    # Check if any container runtime is available
    local runtime
    runtime=$(detect_container_runtime)
    if [ -z "$runtime" ]; then
        log_error "No container runtime (Docker or Podman) is available. Local build requires a container runtime."
        return 1
    fi
    
    log_info "Using container runtime: $runtime"
    
    # Build and deploy using Makefile (which supports both Docker and Podman)
    log_info "Building and deploying operator to Minikube..."
    if CONTAINER_RUNTIME="$runtime" make minikube-setup-and-deploy-local; then
        log_success "Local build deployment completed successfully!"
        show_success_info "$LOCAL_IMAGE"
        return 0
    else
        log_error "Local build deployment failed"
        return 1
    fi
}

show_success_info() {
    local image="$1"
    echo ""
    echo "=========================================="
    echo "Deployment Successful!"
    echo "=========================================="
    echo ""
    echo "Image deployed: $image"
    echo ""
    echo "Next steps:"
    echo "1. Validate deployment: make minikube-validate"
    echo "2. Run additional validation: ./scripts/minikube/validate-deployment.sh"
    echo "3. Access OpenFGA API: kubectl port-forward service/openfga-basic-http 8080:8080"
    echo "4. Deploy demo applications: cd demos/banking-app && kubectl apply -f k8s/"
    echo ""
    echo "Useful commands:"
    echo "- Check operator status: kubectl get pods -n openfga-system"
    echo "- View operator logs: kubectl logs -n openfga-system -l app=openfga-operator"
    echo "- List OpenFGA instances: kubectl get openfgas -A"
    echo ""
}

main() {
    # Parse command line arguments
    local interactive_mode=true
    local deployment_mode=""
    local custom_registry=""
    local custom_tag=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --image-tag)
                custom_tag="$2"
                shift 2
                ;;
            --registry)
                custom_registry="$2"
                shift 2
                ;;
            --interactive)
                interactive_mode=true
                shift
                ;;
            --registry-deploy)
                interactive_mode=false
                deployment_mode="registry"
                shift
                ;;
            --local-deploy)
                interactive_mode=false
                deployment_mode="local"
                shift
                ;;
            -h|--help)
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
    
    # Set image registry and tag based on arguments or environment variables
    if [ -n "$custom_registry" ]; then
        IMAGE_REGISTRY="$custom_registry"
    elif [ -z "${IMAGE_REGISTRY:-}" ]; then
        IMAGE_REGISTRY="$DEFAULT_REGISTRY"
    fi
    
    if [ -n "$custom_tag" ]; then
        IMAGE_TAG="$custom_tag"
    elif [ -z "${IMAGE_TAG:-}" ]; then
        IMAGE_TAG="$DEFAULT_TAG"
    fi
    
    export IMAGE_REGISTRY IMAGE_TAG
    
    log_info "Using image registry: $IMAGE_REGISTRY"
    log_info "Using image tag: $IMAGE_TAG"
    
    check_prerequisites
    
    # Handle non-interactive mode
    if [ "$interactive_mode" = "false" ]; then
        case "$deployment_mode" in
            registry)
                log_info "Starting registry-based deployment..."
                if deploy_registry_based; then
                    log_success "Deployment completed successfully!"
                else
                    log_error "Deployment failed!"
                    exit 1
                fi
                ;;
            local)
                log_info "Starting local build deployment..."
                if deploy_local_build; then
                    log_success "Deployment completed successfully!"
                else
                    log_error "Deployment failed!"
                    exit 1
                fi
                ;;
        esac
        return 0
    fi
    
    # Interactive mode
    while true; do
        show_deployment_options
        read -p "Enter your choice (1-3): " choice
        
        case $choice in
            1)
                echo ""
                if deploy_registry_based; then
                    break
                else
                    echo ""
                    log_error "Registry-based deployment failed. Would you like to try local build instead?"
                    read -p "Try local build? (y/n): " retry
                    if [[ $retry =~ ^[Yy]$ ]]; then
                        echo ""
                        if deploy_local_build; then
                            break
                        fi
                    fi
                fi
                ;;
            2)
                echo ""
                if deploy_local_build; then
                    break
                else
                    echo ""
                    log_error "Local build deployment failed. Would you like to try registry-based deployment instead?"
                    read -p "Try registry-based deployment? (y/n): " retry
                    if [[ $retry =~ ^[Yy]$ ]]; then
                        echo ""
                        if deploy_registry_based; then
                            break
                        fi
                    fi
                fi
                ;;
            3)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        echo ""
    done
}

# Run main function
main "$@"