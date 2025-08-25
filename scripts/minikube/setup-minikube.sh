#!/bin/bash

# setup-minikube.sh - Automated Minikube setup for authcore-openfga-operator
# Compatible with Linux and macOS

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

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Minikube is running
is_minikube_running() {
    minikube status >/dev/null 2>&1
}

# Install Docker on Linux
install_docker_linux() {
    log_info "Installing Docker on Linux..."
    
    # Detect Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        log_error "Cannot detect Linux distribution"
        exit 1
    fi

    case $DISTRO in
        ubuntu|debian)
            log_info "Installing Docker for Ubuntu/Debian..."
            sudo apt-get update
            sudo apt-get install -y ca-certificates curl gnupg lsb-release
            
            # Add Docker's official GPG key
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Add repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        centos|rhel|fedora)
            log_info "Installing Docker for CentOS/RHEL/Fedora..."
            if command_exists dnf; then
                sudo dnf install -y docker
            else
                sudo yum install -y docker
            fi
            ;;
        *)
            log_error "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac

    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker

    # Add user to docker group
    sudo usermod -aG docker $USER
    log_warning "You may need to log out and log back in for Docker group membership to take effect"
}

# Install kubectl
install_kubectl() {
    local os=$1
    
    log_info "Installing kubectl..."
    
    case $os in
        macos)
            if command_exists brew; then
                brew install kubectl
            else
                log_error "Homebrew is required for macOS installation"
                exit 1
            fi
            ;;
        linux)
            # Download latest stable kubectl
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm kubectl
            ;;
    esac
    
    log_success "kubectl installed successfully"
}

# Install Minikube
install_minikube() {
    local os=$1
    
    log_info "Installing Minikube..."
    
    case $os in
        macos)
            if command_exists brew; then
                brew install minikube
            else
                log_error "Homebrew is required for macOS installation"
                exit 1
            fi
            ;;
        linux)
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
            sudo install minikube-linux-amd64 /usr/local/bin/minikube
            rm minikube-linux-amd64
            ;;
    esac
    
    log_success "Minikube installed successfully"
}

# Install Rust
install_rust() {
    log_info "Installing Rust..."
    
    if ! command_exists rustc; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
        log_success "Rust installed successfully"
    else
        log_info "Rust is already installed"
    fi
}

# Check prerequisites
check_prerequisites() {
    local os=$1
    
    log_info "Checking prerequisites..."
    
    # Check for required tools
    local missing_tools=()
    
    if ! command_exists docker; then
        if [ "$os" = "macos" ]; then
            log_warning "Docker Desktop for Mac is required. Please install it from https://www.docker.com/products/docker-desktop"
            missing_tools+=("docker")
        else
            log_info "Docker will be installed automatically"
        fi
    fi
    
    if ! command_exists kubectl; then
        log_info "kubectl will be installed automatically"
    fi
    
    if ! command_exists minikube; then
        log_info "Minikube will be installed automatically"
    fi
    
    if ! command_exists rustc; then
        log_info "Rust will be installed automatically"
    fi
    
    # For macOS, check if Homebrew is available
    if [ "$os" = "macos" ] && ! command_exists brew; then
        log_error "Homebrew is required for macOS. Please install it from https://brew.sh/"
        exit 1
    fi
    
    # Check if any critical tools are missing on macOS
    if [ "$os" = "macos" ] && [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Please install the following tools manually on macOS: ${missing_tools[*]}"
        exit 1
    fi
}

# Start Minikube
start_minikube() {
    log_info "Starting Minikube..."
    
    if is_minikube_running; then
        log_info "Minikube is already running"
        return
    fi
    
    # Try Docker driver first
    if minikube start --driver=docker --memory=4096 --cpus=2; then
        log_success "Minikube started with Docker driver"
    else
        log_warning "Docker driver failed, trying alternative drivers..."
        
        # Try VirtualBox as fallback
        if command_exists VBoxManage; then
            log_info "Trying VirtualBox driver..."
            minikube start --driver=virtualbox --memory=4096 --cpus=2
        else
            log_error "Failed to start Minikube. Please check your virtualization settings."
            exit 1
        fi
    fi
    
    # Enable addons
    log_info "Enabling Minikube addons..."
    minikube addons enable ingress
    minikube addons enable metrics-server
    
    log_success "Minikube started successfully"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check Docker
    if docker --version >/dev/null 2>&1; then
        log_success "Docker is working"
    else
        log_error "Docker is not working properly"
        exit 1
    fi
    
    # Check kubectl
    if kubectl version --client >/dev/null 2>&1; then
        log_success "kubectl is working"
    else
        log_error "kubectl is not working properly"
        exit 1
    fi
    
    # Check Minikube
    if minikube status >/dev/null 2>&1; then
        log_success "Minikube is running"
    else
        log_error "Minikube is not running properly"
        exit 1
    fi
    
    # Check Rust
    if rustc --version >/dev/null 2>&1; then
        log_success "Rust is working"
    else
        log_error "Rust is not working properly"
        exit 1
    fi
    
    # Show cluster info
    log_info "Cluster information:"
    kubectl cluster-info
}

# Main function
main() {
    echo "=========================================="
    echo "  authcore-openfga-operator Minikube Setup"
    echo "=========================================="
    echo
    
    # Detect operating system
    OS=$(detect_os)
    log_info "Detected OS: $OS"
    
    if [ "$OS" = "unknown" ]; then
        log_error "Unsupported operating system"
        exit 1
    fi
    
    # Check prerequisites
    check_prerequisites "$OS"
    
    # Install Docker (Linux only)
    if [ "$OS" = "linux" ] && ! command_exists docker; then
        install_docker_linux
    fi
    
    # Install kubectl
    if ! command_exists kubectl; then
        install_kubectl "$OS"
    fi
    
    # Install Minikube
    if ! command_exists minikube; then
        install_minikube "$OS"
    fi
    
    # Install Rust
    install_rust
    
    # Start Minikube
    start_minikube
    
    # Verify installation
    verify_installation
    
    echo
    log_success "Minikube setup completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Run './scripts/minikube/deploy-operator.sh' to deploy the operator"
    echo "2. Run './scripts/minikube/validate-deployment.sh' to validate the deployment"
    echo
    echo "For manual deployment, see the OS-specific guides in docs/minikube/"
}

# Run main function
main "$@"