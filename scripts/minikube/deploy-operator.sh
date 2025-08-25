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
    
    if ! command_exists docker; then
        log_error "docker is not installed. Please run setup-minikube.sh first."
        exit 1
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

# Build Docker image
build_docker_image() {
    log_info "Building Docker image..."
    
    cd "$PROJECT_ROOT"
    
    # Build the Docker image
    docker build -t "$OPERATOR_IMAGE" .
    
    # Load image into Minikube
    log_info "Loading image into Minikube..."
    minikube image load "$OPERATOR_IMAGE"
    
    log_success "Docker image built and loaded into Minikube"
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
    
    # Build Docker image
    build_docker_image
    
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