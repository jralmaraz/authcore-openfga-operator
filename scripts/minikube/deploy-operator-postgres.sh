#!/bin/bash

# Deploy OpenFGA Operator with PostgreSQL datastore for Minikube
# Automates the deployment of Postgres and ensures OpenFGA operator is ready
# Compatible with Linux and macOS, POSIX-compliant shell syntax

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OPERATOR_NAMESPACE="openfga-system"
POSTGRES_IMAGE="postgres:14"
POSTGRES_DB="openfga"
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="password"
POSTGRES_DEPLOYMENT_NAME="postgres"
POSTGRES_SERVICE_NAME="postgres-service"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
    
    # Check for any container runtime (Docker or Podman) - helpful but not required for registry-based deployment
    if command_exists docker; then
        log_info "Using container runtime: docker"
    elif command_exists podman; then
        log_info "Using container runtime: podman"
    else
        log_warning "No container runtime (Docker or Podman) found. Registry-based operator deployment will be used."
    fi
    
    log_success "All prerequisites satisfied"
}

# Create namespace if it doesn't exist
ensure_namespace() {
    log_info "Ensuring namespace '$OPERATOR_NAMESPACE' exists..."
    
    if kubectl get namespace "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        log_success "Namespace '$OPERATOR_NAMESPACE' already exists"
    else
        log_info "Creating namespace '$OPERATOR_NAMESPACE'..."
        kubectl create namespace "$OPERATOR_NAMESPACE"
        log_success "Namespace '$OPERATOR_NAMESPACE' created"
    fi
}

# Deploy PostgreSQL
deploy_postgres() {
    log_info "Deploying PostgreSQL in namespace '$OPERATOR_NAMESPACE'..."
    
    # Check if PostgreSQL is already deployed
    if kubectl get deployment "$POSTGRES_DEPLOYMENT_NAME" -n "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        log_warning "PostgreSQL deployment '$POSTGRES_DEPLOYMENT_NAME' already exists"
        log_info "Checking if PostgreSQL is ready..."
        if kubectl wait --for=condition=available --timeout=30s deployment/"$POSTGRES_DEPLOYMENT_NAME" -n "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
            log_success "PostgreSQL is already ready"
            return 0
        else
            log_warning "PostgreSQL exists but may not be ready yet"
        fi
    else
        # Deploy PostgreSQL
        log_info "Creating PostgreSQL deployment and service..."
        kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $POSTGRES_DEPLOYMENT_NAME
  namespace: $OPERATOR_NAMESPACE
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
        image: $POSTGRES_IMAGE
        env:
        - name: POSTGRES_DB
          value: $POSTGRES_DB
        - name: POSTGRES_USER
          value: $POSTGRES_USER
        - name: POSTGRES_PASSWORD
          value: $POSTGRES_PASSWORD
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - $POSTGRES_USER
            - -d
            - $POSTGRES_DB
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - $POSTGRES_USER
            - -d
            - $POSTGRES_DB
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: postgres-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: $POSTGRES_SERVICE_NAME
  namespace: $OPERATOR_NAMESPACE
  labels:
    app: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
  type: ClusterIP
EOF
        log_success "PostgreSQL deployment and service created"
    fi
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to become ready (this may take a few minutes)..."
    if kubectl wait --for=condition=available --timeout=300s deployment/"$POSTGRES_DEPLOYMENT_NAME" -n "$OPERATOR_NAMESPACE"; then
        log_success "PostgreSQL is ready"
    else
        log_error "PostgreSQL failed to become ready within 5 minutes"
        log_info "Checking pod status for debugging..."
        kubectl get pods -n "$OPERATOR_NAMESPACE" -l app=postgres
        kubectl describe pods -n "$OPERATOR_NAMESPACE" -l app=postgres
        return 1
    fi
}

# Check if OpenFGA operator is deployed
check_operator_deployment() {
    log_info "Checking if OpenFGA operator is deployed..."
    
    if kubectl get deployment openfga-operator -n "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        log_success "OpenFGA operator is already deployed"
        
        # Check if it's ready
        if kubectl wait --for=condition=available --timeout=30s deployment/openfga-operator -n "$OPERATOR_NAMESPACE" >/dev/null 2>&1; then
            log_success "OpenFGA operator is ready"
            return 0
        else
            log_warning "OpenFGA operator exists but may not be ready yet"
            return 1
        fi
    else
        log_info "OpenFGA operator is not deployed"
        return 1
    fi
}

# Deploy OpenFGA operator
deploy_operator() {
    log_info "Deploying OpenFGA operator..."
    
    local deploy_script="$SCRIPT_DIR/deploy-operator.sh"
    
    if [ ! -f "$deploy_script" ]; then
        log_error "Deploy operator script not found at: $deploy_script"
        return 1
    fi
    
    log_info "Running deploy-operator.sh in non-interactive mode..."
    
    # Run the operator deployment script in non-interactive registry mode
    if "$deploy_script" --registry-deploy; then
        log_success "OpenFGA operator deployed successfully"
        return 0
    else
        log_error "Failed to deploy OpenFGA operator"
        return 1
    fi
}

# Wait for operator to be fully ready
wait_for_operator() {
    log_info "Waiting for OpenFGA operator to be fully ready..."
    
    # Wait for deployment to be available
    if kubectl wait --for=condition=available --timeout=300s deployment/openfga-operator -n "$OPERATOR_NAMESPACE"; then
        log_success "OpenFGA operator deployment is available"
    else
        log_error "OpenFGA operator failed to become available within 5 minutes"
        return 1
    fi
    
    # Check if CRDs are installed
    if kubectl get crd openfgas.authorization.openfga.dev >/dev/null 2>&1; then
        log_success "OpenFGA CRDs are installed"
    else
        log_error "OpenFGA CRDs are not installed"
        return 1
    fi
    
    log_success "OpenFGA operator is fully ready"
}

# Show success information and next steps
show_success_info() {
    echo ""
    echo "=========================================="
    echo "Deployment Completed Successfully!"
    echo "=========================================="
    echo ""
    echo "✓ PostgreSQL deployed in namespace: $OPERATOR_NAMESPACE"
    echo "✓ OpenFGA operator deployed and ready"
    echo ""
    echo "PostgreSQL Connection Details:"
    echo "  Host: $POSTGRES_SERVICE_NAME.$OPERATOR_NAMESPACE.svc.cluster.local"
    echo "  Port: 5432"
    echo "  Database: $POSTGRES_DB"
    echo "  Username: $POSTGRES_USER"
    echo "  Password: $POSTGRES_PASSWORD"
    echo "  Connection URI: postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_SERVICE_NAME.$OPERATOR_NAMESPACE.svc.cluster.local:5432/$POSTGRES_DB"
    echo ""
    echo "Next steps:"
    echo "1. Deploy a PostgreSQL-backed OpenFGA instance:"
    echo "   kubectl apply -f - <<EOF"
    echo "   apiVersion: authorization.openfga.dev/v1alpha1"
    echo "   kind: OpenFGA"
    echo "   metadata:"
    echo "     name: openfga-postgres"
    echo "     namespace: $OPERATOR_NAMESPACE"
    echo "   spec:"
    echo "     replicas: 1"
    echo "     image: \"openfga/openfga:v1.4.0\""
    echo "     datastore:"
    echo "       engine: \"postgres\""
    echo "       uri: \"postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_SERVICE_NAME:5432/$POSTGRES_DB\""
    echo "     playground:"
    echo "       enabled: true"
    echo "       port: 3000"
    echo "     grpc:"
    echo "       port: 8081"
    echo "     http:"
    echo "       port: 8080"
    echo "   EOF"
    echo ""
    echo "2. Validate deployment: ./scripts/minikube/validate-deployment.sh"
    echo "3. Access OpenFGA API: kubectl port-forward service/openfga-postgres-http 8080:8080 -n $OPERATOR_NAMESPACE"
    echo "4. Deploy demo applications: cd demos/banking-app && kubectl apply -f k8s/"
    echo ""
    echo "Useful commands:"
    echo "- Check PostgreSQL status: kubectl get pods -n $OPERATOR_NAMESPACE -l app=postgres"
    echo "- Check operator status: kubectl get pods -n $OPERATOR_NAMESPACE -l app=openfga-operator"
    echo "- View PostgreSQL logs: kubectl logs -n $OPERATOR_NAMESPACE -l app=postgres"
    echo "- View operator logs: kubectl logs -n $OPERATOR_NAMESPACE -l app=openfga-operator"
    echo "- List OpenFGA instances: kubectl get openfgas -A"
    echo ""
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy PostgreSQL datastore and OpenFGA operator to Minikube"
    echo ""
    echo "Options:"
    echo "  --help              Show this help message"
    echo "  --skip-operator     Deploy only PostgreSQL, skip operator deployment"
    echo ""
    echo "This script will:"
    echo "1. Check prerequisites (minikube, kubectl)"
    echo "2. Create '$OPERATOR_NAMESPACE' namespace if needed"
    echo "3. Deploy PostgreSQL with OpenFGA configuration"
    echo "4. Deploy OpenFGA operator (unless --skip-operator)"
    echo "5. Wait for all components to be ready"
    echo ""
}

# Main function
main() {
    echo ""
    echo "=========================================="
    echo "OpenFGA Operator with PostgreSQL Deployment"
    echo "=========================================="
    echo ""
    
    # Parse command line arguments
    local skip_operator=false
    
    while [ $# -gt 0 ]; do
        case $1 in
            --skip-operator)
                skip_operator=true
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
    
    # Execute deployment steps
    check_prerequisites
    ensure_namespace
    deploy_postgres
    
    if [ "$skip_operator" = "false" ]; then
        if ! check_operator_deployment; then
            deploy_operator
        fi
        wait_for_operator
    else
        log_info "Skipping operator deployment (--skip-operator specified)"
    fi
    
    show_success_info
}

# Run main function
main "$@"