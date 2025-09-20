#!/bin/bash

# HashiCorp Vault Initialization Script for OpenFGA Local Development
# This script initializes Vault with demo secrets for local development

set -e

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
NAMESPACE="${NAMESPACE:-openfga-system}"

echo "🔐 Initializing HashiCorp Vault for OpenFGA Local Development"
echo "Vault Address: $VAULT_ADDR"
echo "Namespace: $NAMESPACE"

# Wait for Vault to be ready
echo "⏳ Waiting for Vault to be ready..."
timeout=300
elapsed=0
while ! vault status > /dev/null 2>&1; do
    if [ $elapsed -ge $timeout ]; then
        echo "❌ Timeout waiting for Vault to be ready"
        exit 1
    fi
    echo "   Vault not ready, waiting 5 seconds..."
    sleep 5
    elapsed=$((elapsed + 5))
done

echo "✅ Vault is ready"

# Export Vault token
export VAULT_TOKEN="$VAULT_TOKEN"

# Enable KV secrets engine v2 if not already enabled
echo "🔧 Enabling KV secrets engine..."
if ! vault secrets list | grep -q "secret/"; then
    vault secrets enable -path=secret kv-v2
    echo "✅ KV secrets engine enabled at secret/"
else
    echo "✅ KV secrets engine already enabled"
fi

# Enable Kubernetes authentication if not already enabled
echo "🔧 Enabling Kubernetes authentication..."
if ! vault auth list | grep -q "kubernetes/"; then
    vault auth enable kubernetes
    echo "✅ Kubernetes authentication enabled"
else
    echo "✅ Kubernetes authentication already enabled"
fi

# Configure Kubernetes authentication
echo "🔧 Configuring Kubernetes authentication..."

# Get Kubernetes service account token and CA certificate
SA_TOKEN=$(kubectl get secret -n $NAMESPACE vault-secrets-operator -o jsonpath='{.data.token}' | base64 -d 2>/dev/null || echo "")
if [ -z "$SA_TOKEN" ]; then
    echo "⚠️  Service account token not found, creating temporary token..."
    SA_TOKEN=$(kubectl create token vault-secrets-operator -n $NAMESPACE --duration=8760h)
fi

K8S_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')
K8S_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 -d)

vault write auth/kubernetes/config \
    token_reviewer_jwt="$SA_TOKEN" \
    kubernetes_host="$K8S_HOST" \
    kubernetes_ca_cert="$K8S_CA_CERT" \
    issuer="https://kubernetes.default.svc.cluster.local"

echo "✅ Kubernetes authentication configured"

# Create role for VSO
echo "🔧 Creating Vault role for VSO..."
vault write auth/kubernetes/role/openfga-role \
    bound_service_account_names=vault-secrets-operator \
    bound_service_account_namespaces=$NAMESPACE \
    policies=openfga-policy \
    ttl=24h

echo "✅ VSO role created"

# Create policy for PostgreSQL secrets
echo "🔧 Creating Vault policy..."
vault policy write openfga-policy - <<EOF
# Allow reading PostgreSQL secrets
path "secret/data/databases/openfga-postgres" {
  capabilities = ["read"]
}

# Allow reading OpenFGA application secrets
path "secret/data/applications/openfga" {
  capabilities = ["read"]
}

# Allow listing secrets
path "secret/metadata/*" {
  capabilities = ["list"]
}
EOF

echo "✅ Vault policy created"

# Store PostgreSQL credentials
echo "🔧 Storing PostgreSQL demo credentials..."
vault kv put secret/databases/openfga-postgres \
    username=openfga_user \
    password=demo_password_123 \
    database=openfga \
    host=postgresql-openfga-vault \
    port=5432

echo "✅ PostgreSQL credentials stored"

# Store OpenFGA application secrets
echo "🔧 Storing OpenFGA application secrets..."
vault kv put secret/applications/openfga \
    jwt_secret=demo_jwt_secret_key_12345 \
    encryption_key=demo_encryption_key_67890 \
    api_token=demo_api_token_abcdef

echo "✅ OpenFGA application secrets stored"

echo ""
echo "🎉 Vault initialization completed successfully!"
echo ""
echo "📋 Summary of stored secrets:"
echo "  • PostgreSQL credentials: secret/databases/openfga-postgres"
echo "  • OpenFGA app secrets: secret/applications/openfga"
echo ""
echo "🔍 To verify secrets are stored correctly:"
echo "  vault kv get secret/databases/openfga-postgres"
echo "  vault kv get secret/applications/openfga"
echo ""
echo "🌐 Vault UI available at: $VAULT_ADDR/ui"
echo "🔑 Root token: $VAULT_TOKEN"
echo ""
echo "⚠️  IMPORTANT: This is for development only!"
echo "   In production, use proper authentication and strong secrets."