#!/bin/bash

# Complete Minikube Deployment Script for OpenFGA with HashiCorp Vault
# This script sets up a complete local development environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="openfga-system"

echo -e "${BLUE}🚀 OpenFGA Minikube Deployment with HashiCorp Vault${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}📋 Checking prerequisites...${NC}"

if ! command -v minikube &> /dev/null; then
    echo -e "${RED}❌ Minikube not found. Please install Minikube${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl${NC}"
    exit 1
fi

if ! command -v vault &> /dev/null; then
    echo -e "${YELLOW}⚠️  Vault CLI not found. Installing is recommended for secret management${NC}"
fi

echo -e "${GREEN}✅ Prerequisites check completed${NC}"

# Start Minikube if not running
if ! minikube status | grep -q "Running"; then
    echo -e "${BLUE}🔧 Starting Minikube...${NC}"
    minikube start --driver=docker --memory=4096 --cpus=2
    echo -e "${GREEN}✅ Minikube started${NC}"
else
    echo -e "${GREEN}✅ Minikube already running${NC}"
fi

# Create namespace
echo -e "${BLUE}🔧 Creating namespace...${NC}"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✅ Namespace $NAMESPACE ready${NC}"

# Install OpenFGA CRDs
echo -e "${BLUE}🔧 Installing OpenFGA CRDs...${NC}"
make install-crds
echo -e "${GREEN}✅ CRDs installed${NC}"

# Deploy the operator
echo -e "${BLUE}🔧 Deploying OpenFGA Operator...${NC}"
make minikube-deploy-local
echo -e "${GREEN}✅ OpenFGA Operator deployed${NC}"

# Deploy Vault infrastructure
echo -e "${BLUE}🔧 Deploying HashiCorp Vault and VSO...${NC}"
kubectl apply -k kustomize/base/vault/

echo -e "${BLUE}⏳ Waiting for Vault to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/vault -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/vault-secrets-operator -n $NAMESPACE

echo -e "${GREEN}✅ Vault infrastructure deployed${NC}"

# Setup port forwarding for Vault
echo -e "${BLUE}🔧 Setting up Vault access...${NC}"
kubectl port-forward -n $NAMESPACE svc/vault 8200:8200 &
PORT_FORWARD_PID=$!

# Wait for port forward to establish
sleep 5

# Initialize Vault with demo secrets
echo -e "${BLUE}🔐 Initializing Vault with demo secrets...${NC}"
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root

if command -v vault &> /dev/null; then
    ./scripts/init-vault.sh
    echo -e "${GREEN}✅ Vault initialized with demo secrets${NC}"
else
    echo -e "${YELLOW}⚠️  Vault CLI not available, skipping automatic initialization${NC}"
    echo -e "${BLUE}💡 To initialize manually:${NC}"
    echo "  1. Install Vault CLI: https://developer.hashicorp.com/vault/downloads"
    echo "  2. Run: ./scripts/init-vault.sh"
fi

# Deploy PostgreSQL with Vault secrets
echo -e "${BLUE}🔧 Deploying PostgreSQL with Vault-managed secrets...${NC}"

# Wait a bit for VSO to sync secrets (if vault was initialized)
if command -v vault &> /dev/null; then
    echo -e "${BLUE}⏳ Waiting for secrets to sync...${NC}"
    sleep 30
    
    # Check if secret was created
    if kubectl get secret postgres-credentials -n $NAMESPACE &> /dev/null; then
        echo -e "${GREEN}✅ Secrets synced successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Secrets not yet synced, will create manually${NC}"
        # Create a temporary secret to allow PostgreSQL to start
        kubectl create secret generic postgres-credentials \
            --from-literal=username=openfga_user \
            --from-literal=password=demo_password_123 \
            --from-literal=database=openfga \
            -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    fi
fi

# The PostgreSQL deployment is included in the vault kustomization, so it should already be deployed
echo -e "${BLUE}⏳ Waiting for PostgreSQL to be ready...${NC}"
kubectl wait --for=condition=ready --timeout=300s statefulset/postgresql-openfga-vault -n $NAMESPACE
echo -e "${GREEN}✅ PostgreSQL deployed and ready${NC}"

# Deploy OpenFGA with Vault secrets
echo -e "${BLUE}🔧 Deploying OpenFGA with Vault-managed secrets...${NC}"
kubectl apply -f examples/postgres-openfga-vault.yaml

echo -e "${BLUE}⏳ Waiting for OpenFGA to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/openfga-vault -n openfga-system
echo -e "${GREEN}✅ OpenFGA deployed and ready${NC}"

# Setup additional port forwards
echo -e "${BLUE}🔧 Setting up service access...${NC}"

# OpenFGA HTTP API
kubectl port-forward -n openfga-system svc/openfga-vault 8080:8080 &
OPENFGA_HTTP_PID=$!

# OpenFGA Playground (if enabled)
kubectl port-forward -n openfga-system svc/openfga-vault 3000:3000 &
OPENFGA_PLAYGROUND_PID=$!

echo -e "${GREEN}✅ Port forwarding setup complete${NC}"

# Display summary
echo ""
echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Service URLs:${NC}"
echo "  • Vault UI:       http://localhost:8200/ui (token: root)"
echo "  • OpenFGA API:    http://localhost:8080"
echo "  • OpenFGA Playground: http://localhost:3000"
echo ""
echo -e "${BLUE}📋 Useful Commands:${NC}"
echo "  • Check status:   kubectl get pods -n $NAMESPACE"
echo "  • View secrets:   ./scripts/manage-vault-secrets.sh list"
echo "  • Rotate secrets: ./scripts/manage-vault-secrets.sh rotate-postgres"
echo "  • Vault CLI:      export VAULT_ADDR=http://localhost:8200 VAULT_TOKEN=root"
echo ""
echo -e "${BLUE}📋 Clean up:${NC}"
echo "  • Stop services:  kill $PORT_FORWARD_PID $OPENFGA_HTTP_PID $OPENFGA_PLAYGROUND_PID"
echo "  • Delete resources: kubectl delete namespace $NAMESPACE"
echo "  • Stop Minikube:   minikube stop"
echo ""
echo -e "${YELLOW}⚠️  Note: This is a development setup. Do not use in production!${NC}"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"