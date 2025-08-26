# Delinea Vault Secrets Management

This document explains how to configure and use Delinea DevOps Secrets Vault (DSV) for secrets management in the OpenFGA platform.

## Overview

The OpenFGA platform integrates with Delinea Vault to provide:

- **Automatic Secret Injection**: Secrets are automatically injected into pods using the DSV injector
- **Secret Rotation**: Automated rotation of secrets with configurable schedules
- **Volume Mounting**: Secrets can be mounted as files in containers
- **Environment Variables**: Secrets can be injected as environment variables
- **Audit Logging**: Comprehensive logging of all secret access operations

## Architecture

The DSV integration consists of several components:

1. **DSV Injector**: Mutating admission webhook that injects secrets into pods
2. **Secret Policies**: Configuration for secret rotation, access control, and auditing
3. **Credential Management**: Secure storage and management of DSV credentials
4. **Certificate Management**: TLS certificates for secure webhook communication

## Prerequisites

### Delinea Vault Setup

1. **Create DSV Tenant**: Set up a tenant in Delinea Cloud or on-premises DSV
2. **Client Credentials**: Create a client ID and secret for Kubernetes access
3. **Secret Paths**: Organize secrets in logical paths for different components

```
/databases/
  ├── openfga-postgres/
  │   ├── username
  │   ├── password
  │   └── connection-string
  ├── openfga-mysql/
  │   ├── username
  │   ├── password
  │   └── root-password
/applications/
  ├── openfga/
  │   ├── jwt-secret
  │   ├── encryption-key
  │   └── api-token
/identity/
  └── keycloak/
      ├── admin-password
      ├── db-password
      └── client-secret
```

### Kubernetes Configuration

1. **Cert-Manager**: Required for TLS certificate generation
2. **RBAC**: Appropriate permissions for the DSV injector
3. **Network Policies**: Allow communication with Delinea Vault

## Installation

### 1. Configure DSV Credentials

Create the DSV configuration secret:

```bash
kubectl create secret generic dsv-config \
  --from-literal=server="https://vault.company.com" \
  --from-literal=clientId="your-client-id" \
  --from-literal=clientSecret="your-client-secret" \
  -n openfga-system
```

### 2. Deploy DSV Injector

```bash
kubectl apply -k kustomize/base/secrets-management/
```

### 3. Enable Namespace for Injection

```bash
kubectl label namespace openfga-system dsv-injection=enabled
kubectl label namespace openfga-workloads dsv-injection=enabled
```

## Usage

### Basic Secret Injection

To inject secrets into a pod, use annotations:

```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    dsv.delinea.com/inject: "true"
    dsv.delinea.com/secrets: |
      - path: "/databases/openfga-postgres"
        secrets:
          - key: "username"
            env: "POSTGRES_USER"
          - key: "password"
            env: "POSTGRES_PASSWORD"
spec:
  containers:
  - name: app
    image: myapp:latest
    env:
    - name: POSTGRES_DB
      value: "openfga"
```

### Volume Mounting

Mount secrets as files in containers:

```yaml
metadata:
  annotations:
    dsv.delinea.com/inject: "true"
    dsv.delinea.com/secrets: |
      - path: "/applications/openfga"
        volumeMount:
          name: "app-secrets"
          mountPath: "/etc/secrets"
          readOnly: true
spec:
  containers:
  - name: openfga
    volumeMounts:
    - name: app-secrets
      mountPath: /etc/secrets
      readOnly: true
```

### Secret Configuration

Define secrets in Kubernetes that will be populated by DSV:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
  annotations:
    dsv.delinea.com/inject: "true"
    dsv.delinea.com/path: "/databases/openfga-postgres"
    dsv.delinea.com/secrets: "username,password"
type: Opaque
stringData:
  username: "placeholder"  # Will be replaced by DSV
  password: "placeholder"  # Will be replaced by DSV
```

## Secret Rotation

### Automatic Rotation

Configure automatic secret rotation using CronJobs:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-secret-rotation
spec:
  schedule: "0 2 * * 1"  # Weekly rotation
  jobTemplate:
    spec:
      template:
        metadata:
          annotations:
            dsv.delinea.com/inject: "true"
            dsv.delinea.com/secrets: |
              - path: "/databases/openfga-postgres"
                secrets:
                  - key: "new-password"
                    env: "NEW_PASSWORD"
        spec:
          containers:
          - name: rotate-secrets
            image: postgres:15-alpine
            command: ["/bin/sh", "-c"]
            args:
            - |
              echo "Rotating PostgreSQL password..."
              PGPASSWORD=$CURRENT_PASSWORD psql -h postgresql-openfga \
                -U $POSTGRES_USER -d openfga \
                -c "ALTER USER $POSTGRES_USER PASSWORD '$NEW_PASSWORD';"
```

### Manual Rotation

Rotate secrets manually using the DSV CLI or API:

```bash
# Update secret in DSV
dsv secret update --path "/databases/openfga-postgres" \
  --data '{"password": "new-secure-password"}'

# Restart pods to pick up new secrets
kubectl rollout restart deployment/postgresql-openfga -n openfga-system
```

## Security Policies

### Access Control Policy

```yaml
apiVersion: security.delinea.com/v1
kind: SecretPolicy
metadata:
  name: openfga-secret-policy
spec:
  accessControl:
    allowedServiceAccounts:
    - dsv-injector
    - openfga-operator
    - postgresql-openfga
    allowedNamespaces:
    - openfga-system
    - openfga-workloads
  auditPolicy:
    enabled: true
    logLevel: "INFO"
    destinations:
    - type: "webhook"
      url: "https://security-audit.company.com/api/v1/secrets"
```

### Encryption Policy

```yaml
encryptionPolicy:
  transitEncryption: true
  atRestEncryption: true
  keyRotationInterval: "30d"
```

## Monitoring and Auditing

### Secret Access Monitoring

Monitor secret access using metrics and logs:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: dsv-injector-metrics
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: dsv-injector
  endpoints:
  - port: metrics
    path: /metrics
```

### Audit Logging

Configure audit logging for secret operations:

```yaml
auditPolicy:
  enabled: true
  logLevel: "INFO"
  destinations:
  - type: "file"
    path: "/var/log/dsv-audit.log"
  - type: "webhook"
    url: "http://security-audit:8080/api/v1/secrets"
```

### Alerting

Set up alerts for security events:

```yaml
- alert: UnauthorizedSecretAccess
  expr: increase(dsv_access_denied_total[5m]) > 0
  labels:
    severity: critical
  annotations:
    summary: "Unauthorized secret access detected"
    description: "{{ $labels.pod }} attempted unauthorized access to {{ $labels.secret_path }}"
```

## Troubleshooting

### Common Issues

1. **Injection Not Working**:
   ```bash
   # Check webhook configuration
   kubectl get mutatingadmissionwebhook dsv-injector
   
   # Check injector logs
   kubectl logs -n openfga-system deployment/dsv-injector
   
   # Verify namespace labels
   kubectl get namespace openfga-system --show-labels
   ```

2. **DSV Connection Issues**:
   ```bash
   # Test DSV connectivity
   kubectl exec -n openfga-system deployment/dsv-injector -- \
     curl -k https://vault.company.com/v1/token
   
   # Check DNS resolution
   kubectl exec -n openfga-system deployment/dsv-injector -- \
     nslookup vault.company.com
   ```

3. **Certificate Issues**:
   ```bash
   # Check certificate status
   kubectl get certificate -n openfga-system
   kubectl describe certificate dsv-injector-cert -n openfga-system
   
   # Verify TLS secret
   kubectl get secret dsv-injector-certs -n openfga-system -o yaml
   ```

### Debugging Secret Injection

Enable debug logging for the DSV injector:

```yaml
env:
- name: LOG_LEVEL
  value: "debug"
- name: DSV_DEBUG
  value: "true"
```

### Validation

Test secret injection with a debug pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-test
  annotations:
    dsv.delinea.com/inject: "true"
    dsv.delinea.com/secrets: |
      - path: "/test/secrets"
        secrets:
          - key: "test-key"
            env: "TEST_SECRET"
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
    env:
    - name: TEST_SECRET
      value: "placeholder"
```

## Best Practices

### Secret Organization

1. **Logical Grouping**: Organize secrets by application or component
2. **Least Privilege**: Grant minimal necessary access to secrets
3. **Regular Rotation**: Implement automated secret rotation
4. **Audit Trails**: Maintain comprehensive audit logs

### Security Hardening

1. **Network Isolation**: Use network policies to restrict DSV communication
2. **Certificate Validation**: Always validate TLS certificates
3. **Secret Scope**: Limit secret access to required namespaces only
4. **Monitoring**: Implement continuous monitoring and alerting

### Operational Excellence

1. **Backup Strategy**: Maintain backups of secret configurations
2. **Disaster Recovery**: Plan for DSV outages and failover scenarios
3. **Testing**: Regularly test secret injection and rotation procedures
4. **Documentation**: Keep secret usage documentation up to date

## Integration Examples

### OpenFGA with DSV Secrets

```yaml
apiVersion: authorization.openfga.dev/v1alpha1
kind: OpenFGA
metadata:
  name: openfga-secure
  annotations:
    dsv.delinea.com/inject: "true"
    dsv.delinea.com/secrets: |
      - path: "/applications/openfga"
        secrets:
          - key: "jwt-secret"
            env: "OPENFGA_JWT_SECRET"
          - key: "encryption-key"
            env: "OPENFGA_ENCRYPTION_KEY"
      - path: "/databases/openfga-postgres"
        secrets:
          - key: "username"
            env: "DATABASE_USERNAME"
          - key: "password"
            env: "DATABASE_PASSWORD"
spec:
  datastore:
    engine: "postgres"
    uri: "postgresql://$(DATABASE_USERNAME):$(DATABASE_PASSWORD)@postgresql-openfga:5432/openfga"
```

This integration ensures that all OpenFGA instances use securely managed credentials from Delinea Vault, with automatic injection and rotation capabilities.