# HashiCorp Vault Integration for OpenFGA

This document provides setup instructions and workflows for using HashiCorp Vault with the OpenFGA Operator to manage secrets in a local development environment.

## Overview

The OpenFGA platform now supports HashiCorp Vault integration alongside the existing Delinea Vault (DSV) integration. This implementation uses:

- **HashiCorp Vault**: Local instance with auto-unseal for development
- **Vault Secrets Operator (VSO)**: Syncs Vault secrets to Kubernetes Secrets
- **Kubernetes Secrets**: Referenced by PostgreSQL and OpenFGA deployments

## Prerequisites

- Kubernetes cluster (Minikube recommended for local development)
- kubectl configured to access your cluster
- HashiCorp Vault CLI (optional, for manual secret management)

## Quick Start

### 1. Deploy Vault and VSO

Deploy the complete Vault infrastructure to the `openfga-system` namespace:

```bash
# Create namespace if it doesn't exist
kubectl create namespace openfga-system

# Deploy Vault, VSO, and PostgreSQL
kubectl apply -k kustomize/base/vault/
```

### 2. Wait for Vault to be Ready

Wait for all components to be ready:

```bash
# Wait for Vault deployment
kubectl wait --for=condition=available --timeout=300s deployment/vault -n openfga-system

# Wait for VSO deployment
kubectl wait --for=condition=available --timeout=300s deployment/vault-secrets-operator -n openfga-system

# Check status
kubectl get pods -n openfga-system
```

### 3. Initialize Vault with Demo Secrets

Run the initialization script to set up demo secrets:

```bash
# Forward Vault port for local access
kubectl port-forward -n openfga-system svc/vault 8200:8200 &

# Initialize with demo secrets
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root
./scripts/init-vault.sh
```

### 4. Deploy OpenFGA with Vault-Managed Secrets

```bash
# Deploy OpenFGA instance using Vault secrets
kubectl apply -f examples/postgres-openfga-vault.yaml
```

## Manual Secret Management

### Using kubectl and Vault CLI

#### 1. Access Vault UI

Forward the Vault port and access the UI:

```bash
kubectl port-forward -n openfga-system svc/vault-ui 8200:8200
```

Access Vault UI at: http://localhost:8200/ui
- **Token**: `root` (development only)

#### 2. Update PostgreSQL Secrets

```bash
# Set environment
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root

# Update PostgreSQL password
vault kv put secret/databases/openfga-postgres \
    username=openfga_user \
    password=new_secure_password_456 \
    database=openfga \
    host=postgresql-openfga-vault \
    port=5432

# Verify the update
vault kv get secret/databases/openfga-postgres
```

#### 3. Update OpenFGA Application Secrets

```bash
# Update OpenFGA secrets
vault kv put secret/applications/openfga \
    jwt_secret=new_jwt_secret_key_789 \
    encryption_key=new_encryption_key_012 \
    api_token=new_api_token_xyz789

# Verify the update
vault kv get secret/applications/openfga
```

### Using curl (REST API)

#### 1. Get Vault Token

```bash
# For development, the root token is 'root'
export VAULT_TOKEN=root
export VAULT_ADDR=http://localhost:8200
```

#### 2. Update PostgreSQL Secrets

```bash
curl -X POST $VAULT_ADDR/v1/secret/data/databases/openfga-postgres \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "username": "openfga_user",
      "password": "updated_password_via_curl",
      "database": "openfga",
      "host": "postgresql-openfga-vault",
      "port": "5432"
    }
  }'
```

#### 3. Read Secrets

```bash
# Read PostgreSQL secrets
curl -X GET $VAULT_ADDR/v1/secret/data/databases/openfga-postgres \
  -H "X-Vault-Token: $VAULT_TOKEN" | jq '.data.data'

# Read OpenFGA secrets
curl -X GET $VAULT_ADDR/v1/secret/data/applications/openfga \
  -H "X-Vault-Token: $VAULT_TOKEN" | jq '.data.data'
```

## Secret Synchronization

The Vault Secrets Operator automatically syncs secrets from Vault to Kubernetes:

- **Source**: Vault KV store at `secret/databases/openfga-postgres`
- **Destination**: Kubernetes Secret `postgres-credentials` in `openfga-system` namespace
- **Refresh**: Every 1 hour (configurable in VaultStaticSecret resource)

### Check Secret Sync Status

```bash
# Check VaultStaticSecret status
kubectl get vaultstaticsecret postgres-credentials -n openfga-system -o yaml

# Check actual Kubernetes secret
kubectl get secret postgres-credentials -n openfga-system -o yaml

# Verify secret data
kubectl get secret postgres-credentials -n openfga-system -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key): \(.value | @base64d)"'
```

### Force Secret Refresh

To force an immediate secret refresh:

```bash
# Delete the VaultStaticSecret (it will be recreated)
kubectl delete vaultstaticsecret postgres-credentials -n openfga-system

# Reapply to trigger refresh
kubectl apply -k kustomize/base/vault/
```

## Troubleshooting

### Common Issues

#### 1. Vault Not Ready

```bash
# Check Vault pods
kubectl get pods -n openfga-system -l app.kubernetes.io/name=vault

# Check Vault logs
kubectl logs -n openfga-system deployment/vault

# Check Vault status
kubectl exec -n openfga-system deployment/vault -- vault status
```

#### 2. VSO Not Syncing Secrets

```bash
# Check VSO logs
kubectl logs -n openfga-system deployment/vault-secrets-operator

# Check VaultAuth status
kubectl get vaultauth vault-auth -n openfga-system -o yaml

# Check VaultConnection status
kubectl get vaultconnection vault-connection -n openfga-system -o yaml
```

#### 3. PostgreSQL Connection Issues

```bash
# Check PostgreSQL logs
kubectl logs -n openfga-system statefulset/postgresql-openfga-vault

# Check secret content
kubectl get secret postgres-credentials -n openfga-system -o yaml

# Test database connection
kubectl exec -n openfga-system deployment/vault -- \
  psql postgresql://$(kubectl get secret postgres-credentials -n openfga-system -o jsonpath='{.data.username}' | base64 -d):$(kubectl get secret postgres-credentials -n openfga-system -o jsonpath='{.data.password}' | base64 -d)@postgresql-openfga-vault:5432/$(kubectl get secret postgres-credentials -n openfga-system -o jsonpath='{.data.database}' | base64 -d)
```

### Debug Commands

```bash
# Check all Vault-related resources
kubectl get all,secrets,configmaps,vaultauth,vaultconnection,vaultstaticsecret -n openfga-system

# Check events for issues
kubectl get events -n openfga-system --sort-by='.lastTimestamp'

# Check Vault authentication
kubectl exec -n openfga-system deployment/vault -- vault auth list

# Check Vault policies
kubectl exec -n openfga-system deployment/vault -- vault policy list
```

## Security Considerations

### Development vs Production

**Development (this setup):**
- Auto-unseal enabled
- Root token for easy access
- TLS disabled
- Permissive policies

**Production (recommended changes):**
- Use proper seal mechanism (AWS KMS, Azure Key Vault, etc.)
- Implement proper authentication (OIDC, LDAP, etc.)
- Enable TLS with proper certificates
- Implement least-privilege policies
- Regular secret rotation
- Audit logging

### Best Practices

1. **Never use root token in production**
2. **Rotate secrets regularly**
3. **Use proper RBAC for service accounts**
4. **Enable audit logging**
5. **Monitor secret access**
6. **Use encryption in transit and at rest**

## Migration from Hardcoded Secrets

To migrate existing deployments from hardcoded secrets:

1. **Deploy Vault infrastructure**:
   ```bash
   kubectl apply -k kustomize/base/vault/
   ```

2. **Initialize secrets**:
   ```bash
   ./scripts/init-vault.sh
   ```

3. **Update existing deployments**:
   ```bash
   # Replace hardcoded PostgreSQL deployment
   kubectl delete deployment postgres -n default  # if exists
   
   # Deploy Vault-managed PostgreSQL
   kubectl apply -f kustomize/base/vault/postgresql-vault.yaml
   ```

4. **Update OpenFGA instances**:
   ```bash
   # Update datastore URI to use new service
   kubectl patch openfga openfga-postgres -n default --type='merge' -p='{"spec":{"datastore":{"uri":"postgresql://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@postgresql-openfga-vault.openfga-system.svc.cluster.local:5432/$(POSTGRES_DB)"}}}'
   ```

## Example Workflows

### Daily Development Workflow

1. **Start development environment**:
   ```bash
   minikube start
   kubectl apply -k kustomize/base/vault/
   kubectl port-forward -n openfga-system svc/vault 8200:8200 &
   ```

2. **Deploy application**:
   ```bash
   kubectl apply -f examples/postgres-openfga-vault.yaml
   ```

3. **Access services**:
   - Vault UI: http://localhost:8200/ui
   - OpenFGA: `kubectl port-forward svc/openfga-vault 8080:8080`

### Secret Rotation Workflow

1. **Update secret in Vault**:
   ```bash
   vault kv put secret/databases/openfga-postgres password=new_rotated_password
   ```

2. **Wait for VSO to sync** (up to 1 hour) or force refresh:
   ```bash
   kubectl delete vaultstaticsecret postgres-credentials -n openfga-system
   kubectl apply -k kustomize/base/vault/
   ```

3. **Restart PostgreSQL** (automatic via rolloutRestartTargets):
   ```bash
   kubectl rollout status statefulset/postgresql-openfga-vault -n openfga-system
   ```

This completes the HashiCorp Vault integration for the OpenFGA platform, providing secure secret management for local development with easy scaling to production environments.