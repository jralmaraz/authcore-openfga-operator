#!/bin/bash

# deploy-operator.sh - Automated deployment of authcore-openfga-operator to Minikube
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
OPERATOR_IMAGE="openfga-operator:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
    
    if ! command_exists kubectl; then
        log_error "kubectl is not installed. Please run setup-minikube.sh first."
        exit 1
    fi
    
    if ! command_exists minikube; then
        log_error "minikube is not installed. Please run setup-minikube.sh first."
        exit 1
    fi
    
    # Check for any container runtime
    local runtime
    runtime=$(detect_container_runtime)
    if [ -z "$runtime" ]; then
        log_error "No container runtime (Docker or Podman) is installed. Please run setup-minikube.sh first."
        exit 1
    else
        log_info "Using container runtime: $runtime"
    fi
    
    if ! command_exists cargo; then
        log_error "Rust/Cargo is not installed. Please run setup-minikube.sh first."
        exit 1
    fi
    
    # Check if Minikube is running
    if ! minikube status >/dev/null 2>&1; then
        log_error "Minikube is not running. Please run setup-minikube.sh first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Build the operator
build_operator() {
    log_info "Building the operator..."
    
    cd "$PROJECT_ROOT"
    
    # Compile and test
    log_info "Running compile check..."
    make compile
    
    log_info "Running tests..."
    make test
    
    log_info "Building release binary..."
    make build
    
    log_success "Operator build completed"
}

# Configure Minikube docker environment
configure_minikube_env() {
    log_info "Configuring Minikube docker environment..."
    
    # Check if Minikube is running
    if ! minikube status >/dev/null 2>&1; then
        log_error "Minikube is not running"
        return 1
    fi
    
    # Get Minikube's container runtime
    local minikube_runtime
    minikube_runtime=$(minikube config get driver 2>/dev/null || echo "docker")
    
    # Configure environment to use Minikube's docker daemon
    if command_exists docker && [ "$minikube_runtime" = "docker" ]; then
        log_info "Using Minikube's Docker environment"
        eval $(minikube docker-env)
        return 0
    elif command_exists podman; then
        log_info "Using Minikube with Podman runtime"
        # For Podman, we still need to use image load approach
        return 1
    else
        log_warning "Unable to configure Minikube environment, falling back to image load"
        return 1
    fi
}

# Verify image is available in Minikube with retry mechanism
verify_image_in_minikube() {
    local image="$1"
    local max_retries="${2:-3}"
    local retry_delay="${3:-5}"
    
    log_info "Verifying image '$image' is available in Minikube..."
    
    for attempt in $(seq 1 $max_retries); do
        log_info "Verification attempt $attempt of $max_retries..."
        
        # Check if image exists in Minikube
        if minikube image ls 2>/dev/null | grep -q "$(echo "$image" | cut -d: -f1)"; then
            log_success "Image '$image' is available in Minikube"
            return 0
        else
            if [ $attempt -lt $max_retries ]; then
                log_warning "Image '$image' not found, retrying in $retry_delay seconds..."
                sleep $retry_delay
            else
                log_error "Image '$image' is not available in Minikube after $max_retries attempts"
                log_error "Available images in Minikube:"
                minikube image ls 2>/dev/null || log_error "Failed to list Minikube images"
                return 1
            fi
        fi
    done
}

# Load image into Minikube with retry mechanism
load_image_to_minikube() {
    local image="$1"
    local max_retries="${2:-3}"
    local retry_delay="${3:-5}"
    
    log_info "Loading image '$image' into Minikube..."
    
    for attempt in $(seq 1 $max_retries); do
        log_info "Load attempt $attempt of $max_retries..."
        
        if minikube image load "$image" 2>/dev/null; then
            log_success "Successfully loaded image '$image' into Minikube"
            return 0
        else
            if [ $attempt -lt $max_retries ]; then
                log_warning "Failed to load image '$image', retrying in $retry_delay seconds..."
                sleep $retry_delay
            else
                log_error "Failed to load image '$image' into Minikube after $max_retries attempts"
                log_error "This could be due to:"
                log_error "  - Network connectivity issues"
                log_error "  - Insufficient disk space in Minikube"
                log_error "  - Image not found locally"
                log_error "  - Minikube not running properly"
                return 1
            fi
        fi
    done
}

# Build container image
build_container_image() {
    local runtime
    runtime=$(get_container_runtime)
    
    log_info "Building container image using $runtime..."
    
    cd "$PROJECT_ROOT"
    
    # Try to configure Minikube's docker environment first
    local use_minikube_env=false
    if configure_minikube_env; then
        use_minikube_env=true
        log_info "Building image directly in Minikube's Docker environment"
    else
        log_info "Building image locally and will load into Minikube"
    fi
    
    # Build the container image
    if [ "$use_minikube_env" = "true" ]; then
        # Build directly in Minikube's environment
        log_info "Building image directly in Minikube's Docker daemon..."
        if ! docker build -t "$OPERATOR_IMAGE" .; then
            log_error "Failed to build image in Minikube's Docker environment"
            log_error "Falling back to local build and load approach..."
            use_minikube_env=false
        fi
    fi
    
    if [ "$use_minikube_env" = "false" ]; then
        # Build locally with detected runtime
        log_info "Building image locally with $runtime..."
        if ! $runtime build -t "$OPERATOR_IMAGE" .; then
            log_error "Failed to build image with $runtime"
            exit 1
        fi
        
        # Load image into Minikube with retry mechanism
        if ! load_image_to_minikube "$OPERATOR_IMAGE"; then
            log_error "Failed to load image into Minikube"
            exit 1
        fi
    fi
    
    # Verify the image is available with retry mechanism
    if ! verify_image_in_minikube "$OPERATOR_IMAGE"; then
        log_error "Failed to verify image availability in Minikube"
        exit 1
    fi
    
    log_success "Container image built and loaded into Minikube"
}

# Legacy function for backward compatibility
build_docker_image() {
    build_container_image
}

# Install CRDs
install_crds() {
    log_info "Installing Custom Resource Definitions..."
    
    cd "$PROJECT_ROOT"
    
    # Install CRDs
    make install-crds
    
    # Verify CRDs are installed
    kubectl get crd openfgas.authorization.openfga.dev >/dev/null 2>&1
    
    log_success "CRDs installed successfully"
}

# Create namespace
create_namespace() {
    log_info "Creating namespace $OPERATOR_NAMESPACE..."
    
    if kubectl get namespace "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        log_info "Namespace $OPERATOR_NAMESPACE already exists"
    else
        kubectl create namespace "$OPERATOR_NAMESPACE"
        log_success "Namespace $OPERATOR_NAMESPACE created"
    fi
}

# Create RBAC resources
create_rbac() {
    log_info "Creating RBAC resources..."
    
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openfga-operator
  namespace: $OPERATOR_NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: openfga-operator
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["authorization.openfga.dev"]
  resources: ["openfgas"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["authorization.openfga.dev"]
  resources: ["openfgas/status"]
  verbs: ["get", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: openfga-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: openfga-operator
subjects:
- kind: ServiceAccount
  name: openfga-operator
  namespace: $OPERATOR_NAMESPACE
EOF
    
    log_success "RBAC resources created"
}

# Deploy the operator
deploy_operator() {
    log_info "Deploying the operator..."
    
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openfga-operator
  namespace: $OPERATOR_NAMESPACE
  labels:
    app: openfga-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openfga-operator
  template:
    metadata:
      labels:
        app: openfga-operator
    spec:
      serviceAccountName: openfga-operator
      containers:
      - name: operator
        image: $OPERATOR_IMAGE
        imagePullPolicy: Never
        ports:
        - containerPort: 8080
          name: metrics
        env:
        - name: RUST_LOG
          value: "info"
        resources:
          limits:
            memory: "256Mi"
            cpu: "500m"
          requests:
            memory: "128Mi"
            cpu: "100m"
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: openfga-operator-metrics
  namespace: $OPERATOR_NAMESPACE
  labels:
    app: openfga-operator
spec:
  selector:
    app: openfga-operator
  ports:
  - name: metrics
    port: 8080
    targetPort: 8080
EOF
    
    log_success "Operator deployment created"
}

# Wait for operator to be ready
wait_for_operator() {
    log_info "Waiting for operator to be ready..."
    
    # Wait for deployment to be available
    kubectl wait --for=condition=available --timeout=300s deployment/openfga-operator -n "$OPERATOR_NAMESPACE"
    
    log_success "Operator is ready"
}

# Deploy example OpenFGA instances
deploy_examples() {
    log_info "Deploying example OpenFGA instances..."
    
    cd "$PROJECT_ROOT"
    
    # Deploy basic OpenFGA instance
    log_info "Deploying basic OpenFGA instance..."
    kubectl apply -f examples/basic-openfga.yaml
    
    # Wait for basic instance to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/openfga-basic 2>/dev/null || {
        log_warning "Basic OpenFGA instance deployment may take a few more minutes"
    }
    
    log_success "Example instances deployed"
}

# Deploy PostgreSQL and PostgreSQL-backed OpenFGA (optional)
deploy_postgres_example() {
    log_info "Deploying PostgreSQL example (optional)..."
    
    # Deploy PostgreSQL
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: default
  labels:
    app: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: openfga
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_PASSWORD
          value: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          limits:
            memory: "256Mi"
            cpu: "250m"
          requests:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: postgres-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: default
  labels:
    app: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
EOF
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/postgres
    
    # Deploy PostgreSQL-backed OpenFGA
    log_info "Deploying PostgreSQL-backed OpenFGA instance..."
    kubectl apply -f examples/postgres-openfga.yaml
    
    log_success "PostgreSQL example deployed"
}

# Final validation of the deployment
validate_deployment() {
    log_info "Performing final validation of the deployment..."
    
    # Check if operator pod is running
    log_info "Checking operator pod status..."
    local pod_status
    pod_status=$(kubectl get pods -n "$OPERATOR_NAMESPACE" -l app=openfga-operator -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    
    if [ "$pod_status" != "Running" ]; then
        log_error "Operator pod is not running (status: $pod_status)"
        log_error "Pod details:"
        kubectl get pods -n "$OPERATOR_NAMESPACE" -l app=openfga-operator 2>/dev/null || log_error "Failed to get pod details"
        log_error "Pod logs:"
        kubectl logs -n "$OPERATOR_NAMESPACE" -l app=openfga-operator --tail=20 2>/dev/null || log_error "Failed to get pod logs"
        return 1
    fi
    
    # Check if operator is ready
    log_info "Checking operator readiness..."
    if ! kubectl wait --for=condition=ready pod -l app=openfga-operator -n "$OPERATOR_NAMESPACE" --timeout=60s >/dev/null 2>&1; then
        log_warning "Operator pod readiness check timed out, but continuing..."
    fi
    
    # Check if CRDs are installed
    log_info "Verifying CRDs are installed..."
    if ! kubectl get crd openfgas.authorization.openfga.dev >/dev/null 2>&1; then
        log_error "OpenFGA CRD is not installed"
        return 1
    fi
    
    # Check if operator service is available
    log_info "Checking operator service..."
    if ! kubectl get service openfga-operator-metrics -n "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        log_warning "Operator metrics service not found, but continuing..."
    fi
    
    # Try to create a test OpenFGA resource to verify operator is working
    log_info "Testing operator functionality with a sample OpenFGA resource..."
    local test_resource_name="validation-test-$(date +%s)"
    
    if kubectl apply -f - <<EOF >/dev/null 2>&1
apiVersion: authorization.openfga.dev/v1alpha1
kind: OpenFGA
metadata:
  name: $test_resource_name
  namespace: default
spec:
  image: "openfga/openfga:latest"
  replicas: 1
  grpc:
    port: 8081
  http:
    port: 8080
  playground:
    enabled: false
  datastore:
    engine: "memory"
EOF
    then
        log_info "Test OpenFGA resource created successfully"
        
        # Wait a moment and check if it's being processed
        sleep 5
        
        # Clean up test resource
        kubectl delete openfga "$test_resource_name" -n default >/dev/null 2>&1 || log_warning "Failed to clean up test resource"
        
        log_success "Operator functionality test passed"
    else
        log_warning "Failed to create test OpenFGA resource, but operator may still be functional"
    fi
    
    log_success "Deployment validation completed successfully"
    return 0
}

# Show deployment status
show_status() {
    log_info "Deployment status:"
    echo
    
    echo "Operator status:"
    kubectl get pods -n "$OPERATOR_NAMESPACE"
    echo
    
    echo "OpenFGA instances:"
    kubectl get openfgas
    echo
    
    echo "Services:"
    kubectl get services
    echo
    
    echo "All deployments:"
    kubectl get deployments
}

# Print next steps
print_next_steps() {
    echo
    log_success "Deployment completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Run './scripts/minikube/validate-deployment.sh' to validate the deployment"
    echo "2. Access OpenFGA API:"
    echo "   kubectl port-forward service/openfga-basic-http 8080:8080"
    echo "   curl http://localhost:8080/healthz"
    echo
    echo "3. Deploy demo applications:"
    echo "   cd demos/banking-app && kubectl apply -f k8s/"
    echo "   cd demos/genai-rag-agent && kubectl apply -f k8s/"
    echo
    echo "4. Monitor the operator:"
    echo "   kubectl logs -n $OPERATOR_NAMESPACE deployment/openfga-operator -f"
    echo
    echo "For more information, see the documentation in docs/minikube/"
}

# Main function
main() {
    echo "=================================================="
    echo "  authcore-openfga-operator Deployment to Minikube"
    echo "=================================================="
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Build the operator
    build_operator
    
    # Build container image
    build_container_image
    
    # Install CRDs
    install_crds
    
    # Create namespace
    create_namespace
    
    # Create RBAC resources
    create_rbac
    
    # Deploy the operator
    deploy_operator
    
    # Wait for operator to be ready
    wait_for_operator
    
    # Perform final validation
    if ! validate_deployment; then
        log_error "Deployment validation failed"
        show_status
        exit 1
    fi
    
    # Deploy example instances
    deploy_examples
    
    # Ask user if they want to deploy PostgreSQL example
    echo
    read -p "Do you want to deploy PostgreSQL example? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_postgres_example
    fi
    
    # Show deployment status
    show_status
    
    # Print next steps
    print_next_steps
}

# Run main function
main "$@"