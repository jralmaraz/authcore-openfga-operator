#!/bin/bash

# Consolidated Minikube deployment script for authcore-openfga-operator
# Supports both registry-based and local build deployments with Docker/Podman compatibility
# Compatible with Linux and macOS, POSIX-compliant shell syntax

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
ALPHA_TAG="0.1.0-alpha"
LOCAL_IMAGE="openfga-operator:latest"
OPERATOR_NAMESPACE="openfga-system"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Retry configuration for container runtime compatibility
PODMAN_LOAD_RETRIES=2      # Number of retries for Podman image loading
DOCKER_LOAD_RETRIES=3      # Number of retries for Docker image loading
RETRY_DELAY=2              # Delay between Podman retries (seconds)
DOCKER_RETRY_DELAY=5       # Delay between Docker retries (seconds)

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

# Check prerequisites
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
    
    if ! minikube status >/dev/null 2>&1; then
        log_error "Minikube is not running. Please start Minikube first: minikube start"
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Show deployment options for interactive mode
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
    echo "   - Supports both Docker and Podman"
    echo "   - May encounter image loading issues in some environments"
    echo ""
    echo "3) Exit"
    echo ""
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Consolidated Minikube deployment script with registry and local build support"
    echo ""
    echo "Options:"
    echo "  --image-tag TAG        Specify the image tag to deploy"
    echo "                         (default: latest, alpha: $ALPHA_TAG)"
    echo "  --registry URL         Specify the image registry"
    echo "                         (default: $DEFAULT_REGISTRY)"
    echo "  --container-runtime RT Specify container runtime (docker|podman)"
    echo "                         (default: auto-detect)"
    echo "  --interactive          Run in interactive mode (default behavior)"
    echo "  --registry-deploy      Deploy using registry image directly (non-interactive)"
    echo "  --local-deploy         Deploy using local build directly (non-interactive)"
    echo "  --alpha                Use alpha tag ($ALPHA_TAG) for registry deployment"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                          # Interactive mode with default settings"
    echo "  $0 --alpha                                  # Interactive mode with alpha tag"
    echo "  $0 --image-tag v1.0.0                      # Interactive mode with specific tag"
    echo "  $0 --registry-deploy --alpha                # Direct registry deployment with alpha tag"
    echo "  $0 --registry-deploy --image-tag v1.0       # Direct registry deployment with specific tag"
    echo "  $0 --local-deploy --container-runtime podman # Direct local deployment with Podman"
    echo ""
    echo "Default registry images:"
    echo "  latest: $DEFAULT_REGISTRY:$DEFAULT_TAG"
    echo "  alpha:  $DEFAULT_REGISTRY:$ALPHA_TAG"
}

# Deploy using registry-based approach
deploy_registry_based() {
    local registry="${IMAGE_REGISTRY:-$DEFAULT_REGISTRY}"
    local tag="${IMAGE_TAG:-$DEFAULT_TAG}"
    local full_image="$registry:$tag"
    
    log_info "Starting registry-based deployment..."
    log_info "Using image: $full_image"
    
    # Try to verify image accessibility with available container runtime
    local runtime
    runtime=$(detect_container_runtime)
    
    if [ -n "$runtime" ]; then
        log_info "Verifying image accessibility with $runtime..."
        if $runtime pull "$full_image" >/dev/null 2>&1; then
            log_success "Image successfully verified: $full_image"
            $runtime rmi "$full_image" >/dev/null 2>&1 || true  # Clean up local copy
        else
            log_warning "Could not pre-verify image, but deployment will attempt to pull it"
        fi
    else
        log_warning "No container runtime available for image verification"
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

# Deploy using local build approach
deploy_local_build() {
    log_info "Starting local build deployment..."
    
    # Get container runtime
    local runtime
    runtime=$(get_container_runtime)
    log_info "Using container runtime: $runtime"
    
    # Export container runtime for Makefile
    export CONTAINER_RUNTIME="$runtime"
    
    # Build and deploy using Makefile
    log_info "Building and deploying operator to Minikube..."
    if make minikube-setup-and-deploy-local; then
        log_success "Local build deployment completed successfully!"
        show_success_info "$LOCAL_IMAGE"
        return 0
    else
        log_error "Local build deployment failed"
        return 1
    fi
}

# Show success information
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

# Main function
main() {
    # Parse command line arguments
    local interactive_mode=true
    local deployment_mode=""
    local custom_registry=""
    local custom_tag=""
    local use_alpha=false
    
    while [ $# -gt 0 ]; do
        case $1 in
            --image-tag)
                custom_tag="$2"
                shift 2
                ;;
            --registry)
                custom_registry="$2"
                shift 2
                ;;
            --container-runtime)
                export CONTAINER_RUNTIME="$2"
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
            --alpha)
                use_alpha=true
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
    
    # Set image registry and tag based on arguments
    if [ -n "$custom_registry" ]; then
        IMAGE_REGISTRY="$custom_registry"
    elif [ -z "${IMAGE_REGISTRY:-}" ]; then
        IMAGE_REGISTRY="$DEFAULT_REGISTRY"
    fi
    
    if [ -n "$custom_tag" ]; then
        IMAGE_TAG="$custom_tag"
    elif [ "$use_alpha" = "true" ]; then
        IMAGE_TAG="$ALPHA_TAG"
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
                    # Use POSIX-compliant string comparison instead of regex
                    if [ "$retry" = "y" ] || [ "$retry" = "Y" ]; then
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
                    # Use POSIX-compliant string comparison instead of regex
                    if [ "$retry" = "y" ] || [ "$retry" = "Y" ]; then
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