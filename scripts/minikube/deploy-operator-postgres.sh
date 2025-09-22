#!/bin/bash

# Deploy OpenFGA Operator with PostgreSQL datastore for Minikube
# Automates the deployment of Postgres using HashiCorp Vault for secret management
# Compatible with Linux and macOS, POSIX-compliant shell syntax

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

POSTGRES_DEPLOYMENT_NAME="postgres"
POSTGRES_SERVICE_NAME="postgres-service"
POSTGRES_NAMESPACE="openfga-system"
POSTGRES_IMAGE="postgres:14"
POSTGRES_DB="openfga"
POSTGRES_USER="postgres"
# SECURITY: No hardcoded password - using Vault-managed secrets
# Default password only used if Vault integration is not available
POSTGRES_PASSWORD_DEFAULT="CHANGE_ME_INSECURE"  
POSTGRES_PORT=5432

OPERATOR_NAMESPACE="openfga-system"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# Check if vault integration is available
check_vault_available() {
    # Check if vault kustomization exists
    if [ -d "$PROJECT_ROOT/kustomize/base/vault" ]; then
        log_info "HashiCorp Vault integration available - using secure secret management"
        return 0
    else
        log_warning "HashiCorp Vault integration not available - falling back to legacy mode"
        log_warning "⚠️  Legacy mode uses less secure secret management"
        log_warning "Consider upgrading to vault-managed secrets for better security"
        return 1
    fi
}

# Deploy using vault-managed secrets (recommended)
deploy_with_vault() {
    log_info "Deploying PostgreSQL with HashiCorp Vault-managed secrets..."
    
    # Deploy vault infrastructure which includes PostgreSQL
    log_info "Deploying Vault infrastructure..."
    kubectl apply -k "$PROJECT_ROOT/kustomize/base/vault/"
    
    # Wait for vault to be ready
    log_info "Waiting for Vault to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/vault -n "$POSTGRES_NAMESPACE"
    
    # Wait for VSO to be ready  
    log_info "Waiting for Vault Secrets Operator to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/vault-secrets-operator -n "$POSTGRES_NAMESPACE"
    
    # Wait for PostgreSQL to be ready (deployed as part of vault kustomization)
    log_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready --timeout=300s statefulset/postgresql-openfga-vault -n "$POSTGRES_NAMESPACE"
    
    log_success "PostgreSQL deployed with Vault-managed secrets"
    
    # Update service references for vault-managed deployment
    POSTGRES_DEPLOYMENT_NAME="postgresql-openfga-vault"
    POSTGRES_SERVICE_NAME="postgresql-openfga-vault"
}

# Create namespace if it doesn't exist
ensure_namespace() {
    log_info "Ensuring namespace '$POSTGRES_NAMESPACE' exists..."
    
    if kubectl get namespace "$POSTGRES_NAMESPACE" >/dev/null 2>&1; then
        log_success "Namespace '$POSTGRES_NAMESPACE' already exists"
    else
        log_info "Creating namespace '$POSTGRES_NAMESPACE'..."
        kubectl create namespace "$POSTGRES_NAMESPACE"
        log_success "Namespace '$POSTGRES_NAMESPACE' created"
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    if ! command_exists minikube; then
        log_error "Minikube is not installed."
        exit 1
    fi
    if ! command_exists kubectl; then
        log_error "kubectl is not installed."
        exit 1
    fi
    if ! minikube status >/dev/null 2>&1; then
        log_error "Minikube is not running. Please start Minikube first."
        exit 1
    fi
    local runtime
    if command_exists docker && docker info >/dev/null 2>&1; then
        runtime="docker"
    elif command_exists podman && podman info >/dev/null 2>&1; then
        runtime="podman"
    else
        log_warning "No container runtime (Docker/Podman) found. Continuing, but builds may fail."
    fi
    log_success "Prerequisites check passed."
}

deploy_postgres() {
    log_warning "⚠️  SECURITY WARNING: Using legacy PostgreSQL deployment with hardcoded secrets"
    log_warning "This is NOT recommended for any environment"
    log_warning "Consider using the vault-managed deployment for better security"
    log_info "Deploying Postgres to Minikube with legacy secrets..."

    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${POSTGRES_DEPLOYMENT_NAME}
  namespace: ${POSTGRES_NAMESPACE}
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
        image: ${POSTGRES_IMAGE}
        env:
        - name: POSTGRES_DB
          value: ${POSTGRES_DB}
        - name: POSTGRES_USER
          value: ${POSTGRES_USER}
        - name: POSTGRES_PASSWORD
          value: ${POSTGRES_PASSWORD_DEFAULT}  # ⚠️ INSECURE - change this!
        ports:
        - containerPort: ${POSTGRES_PORT}
        readinessProbe:
          exec:
            command:
            - sh
            - -c
            - "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        livenessProbe:
          exec:
            command:
            - sh
            - -c
            - "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
---
apiVersion: v1
kind: Service
metadata:
  name: ${POSTGRES_SERVICE_NAME}
  namespace: ${POSTGRES_NAMESPACE}
spec:
  selector:
    app: postgres
  ports:
  - port: ${POSTGRES_PORT}
    targetPort: ${POSTGRES_PORT}
EOF

    log_success "Postgres deployment and service created."
}

wait_for_postgres() {
    log_info "Waiting for Postgres to be ready..."
    
    # Wait for deployment to be available
    if kubectl wait --for=condition=available --timeout=300s deployment/${POSTGRES_DEPLOYMENT_NAME} -n ${POSTGRES_NAMESPACE}; then
        log_success "Postgres deployment is available."
    else
        log_error "Postgres deployment failed to become available within 5 minutes."
        exit 1
    fi
    
    # Additional check for pod readiness
    log_info "Waiting for Postgres pod to be ready..."
    if kubectl wait --for=condition=ready --timeout=60s pod -l app=postgres -n ${POSTGRES_NAMESPACE}; then
        log_success "Postgres pod is ready."
    else
        log_error "Postgres pod failed to become ready."
        exit 1
    fi
}

check_operator_deployment() {
    log_info "Checking if OpenFGA operator is already deployed..."
    
    if kubectl get namespace ${OPERATOR_NAMESPACE} >/dev/null 2>&1; then
        if kubectl get deployment -n ${OPERATOR_NAMESPACE} | grep -q openfga-operator; then
            log_info "OpenFGA operator is already deployed."
            return 0
        fi
    fi
    
    return 1
}

deploy_operator() {
    log_info "Deploying OpenFGA operator..."
    
    local deploy_script="${SCRIPT_DIR}/deploy-operator.sh"
    
    if [ ! -f "$deploy_script" ]; then
        log_error "deploy-operator.sh not found at $deploy_script"
        exit 1
    fi
    
    # Run the deploy-operator.sh script in non-interactive mode
    if "$deploy_script" --non-interactive --deployment-mode registry; then
        log_success "OpenFGA operator deployed successfully."
    else
        log_error "Failed to deploy OpenFGA operator."
        exit 1
    fi
}

print_connection_instructions() {
    echo ""
    echo "==========================================="
    echo "      DEPLOYMENT SUCCESSFUL!"
    echo "==========================================="
    echo ""
    echo "📊 PostgreSQL Database Information:"
    echo "   Service: ${POSTGRES_SERVICE_NAME}.${POSTGRES_NAMESPACE}.svc.cluster.local"
    echo "   Port: ${POSTGRES_PORT}"
    echo "   Database: ${POSTGRES_DB}"
    echo "   User: ${POSTGRES_USER}"
    
    if [ -d "$PROJECT_ROOT/kustomize/base/vault" ]; then
        echo ""
        echo "🔐 Security: Using HashiCorp Vault-managed secrets"
        echo "   Secrets are managed securely through Vault"
        echo "   Password: Retrieved from Kubernetes secret 'postgres-credentials'"
        echo ""
        echo "📋 To access Vault:"
        echo "   kubectl port-forward -n ${POSTGRES_NAMESPACE} svc/vault 8200:8200 &"
        echo "   export VAULT_ADDR=http://localhost:8200"
        echo "   export VAULT_TOKEN=root"
        echo "   vault kv get secret/databases/openfga-postgres"
        echo ""
        echo "📋 To rotate secrets:"
        echo "   ./scripts/manage-vault-secrets.sh rotate-postgres"
        echo ""
        echo "📝 To deploy an OpenFGA instance with Vault secrets:"
        echo "   kubectl apply -f examples/postgres-openfga-vault.yaml"
    else
        echo "   Password: ${POSTGRES_PASSWORD_DEFAULT} ⚠️  INSECURE - CHANGE THIS!"
        echo ""
        echo "⚠️  SECURITY WARNING: Using hardcoded password"
        echo "   This is NOT secure for any environment"
        echo "   Consider upgrading to vault-managed secrets"
        local datastore_uri="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD_DEFAULT}@${POSTGRES_SERVICE_NAME}:${POSTGRES_PORT}/${POSTGRES_DB}"
        echo ""
        echo "🔗 Connection URI (INSECURE):"
        echo "   ${datastore_uri}"
        echo ""
        echo "📝 To deploy an OpenFGA instance with hardcoded secrets (NOT RECOMMENDED):"
        echo "   kubectl apply -f examples/postgres-openfga.yaml"
    fi
    
    echo ""
    echo "🌐 Access OpenFGA API:"
    echo "   kubectl port-forward service/openfga-*-http 8080:8080"
    echo "   Then access: http://localhost:8080"
    echo ""
    echo "🎮 Access OpenFGA Playground (if enabled):"
    echo "   kubectl port-forward service/openfga-*-playground 3000:3000"
    echo "   Then access: http://localhost:3000"
    echo ""
    echo "🔧 Useful commands:"
    echo "   - Check PostgreSQL status: kubectl get pods -l app.kubernetes.io/name=postgresql -n ${POSTGRES_NAMESPACE}"
    echo "   - Check operator status: kubectl get pods -n ${OPERATOR_NAMESPACE}"
    echo "   - View operator logs: kubectl logs -n ${OPERATOR_NAMESPACE} -l app=openfga-operator"
    echo "   - List OpenFGA instances: kubectl get openfgas -A"
    echo ""
    echo "💡 Next steps:"
    if [ -d "$PROJECT_ROOT/kustomize/base/vault" ]; then
        echo "   1. Deploy an OpenFGA instance: kubectl apply -f examples/postgres-openfga-vault.yaml"
    else
        echo "   1. Deploy an OpenFGA instance: kubectl apply -f examples/postgres-openfga.yaml"
    fi
    echo "   2. Validate deployment: ./scripts/minikube/validate-deployment.sh"
    echo "   3. Explore the demos in the demos/ directory"
    echo ""
}

cleanup_on_error() {
    log_warning "Cleaning up due to error..."
    kubectl delete deployment ${POSTGRES_DEPLOYMENT_NAME} -n ${POSTGRES_NAMESPACE} 2>/dev/null || true
    kubectl delete service ${POSTGRES_SERVICE_NAME} -n ${POSTGRES_NAMESPACE} 2>/dev/null || true
}

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy OpenFGA Operator with PostgreSQL datastore to Minikube"
    echo ""
    echo "🔐 Security Modes:"
    echo "  • Vault-managed (Recommended): Uses HashiCorp Vault for secure secret management"
    echo "  • Legacy mode (Fallback): Uses hardcoded secrets (NOT recommended)"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  --postgres-db           Set Postgres database name (default: openfga)"
    echo "  --postgres-user         Set Postgres username (default: postgres)"
    echo "  --skip-operator         Deploy only Postgres, skip operator deployment"
    echo ""
    echo "⚠️  Security Note:"
    echo "  • Password management is handled automatically based on available integrations"
    echo "  • Vault-managed secrets are used when HashiCorp Vault integration is available"
    echo "  • Legacy hardcoded secrets are only used as fallback (NOT secure)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy with auto-detected security mode"
    echo "  $0 --postgres-db mydb                # Use custom database name"
    echo "  $0 --skip-operator                   # Deploy only Postgres"
    echo ""
}

main() {
    # Parse command line arguments
    while [ $# -gt 0 ]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --postgres-db)
                POSTGRES_DB="$2"
                shift 2
                ;;
            --postgres-user)
                POSTGRES_USER="$2"
                shift 2
                ;;
            --skip-operator)
                SKIP_OPERATOR=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    echo ""
    echo "==========================================="
    echo "  OpenFGA Operator + Postgres Deployment"
    echo "==========================================="
    echo ""
    
    # Main deployment flow
    check_prerequisites
    ensure_namespace
    
    # Check if vault integration is available and use it preferentially
    if check_vault_available; then
        deploy_with_vault
    else
        deploy_postgres
        wait_for_postgres
    fi
    
    if [ "${SKIP_OPERATOR:-false}" != "true" ]; then
        if ! check_operator_deployment; then
            deploy_operator
        fi
    fi
    
    print_connection_instructions
    
    log_success "Deployment completed successfully!"
}

# Only run main if script is executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi