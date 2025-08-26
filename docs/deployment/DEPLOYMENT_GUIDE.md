# OpenFGA Platform Deployment Guide

This guide provides comprehensive instructions for deploying the enhanced OpenFGA platform with persistent storage, secrets management, network security, and ArgoCD automation.

## 🚀 New Features

The OpenFGA platform now includes:

- **Dual Storage Support**: Both Portworx and Longhorn storage providers
- **Delinea Vault Integration**: Automated secrets management with DSV injector
- **Enhanced Network Security**: Cilium network policies with Hubble observability
- **ArgoCD Automation**: GitOps-based deployment and management workflows
- **Comprehensive Database Support**: PostgreSQL and MySQL with persistent storage
- **Demo Applications**: Banking and GenAI RAG demos with full authorization models

## 📋 Prerequisites

### Infrastructure Requirements

1. **Kubernetes Cluster**: v1.25+ with the following components:
   - CNI with Cilium for network policies and observability
   - Storage provider (Portworx or Longhorn)
   - Cert-manager for TLS certificate management
   - ArgoCD for GitOps automation

2. **External Services**:
   - Delinea DevOps Secrets Vault (cloud or on-premises)
   - Container registry access
   - Git repository access

### Storage Prerequisites

#### For Portworx

```bash
# Install Portworx operator
kubectl apply -f 'https://install.portworx.com/2.13?comp=pxoperator'

# Verify Portworx installation
kubectl get pods -n portworx
```

#### For Longhorn

```bash
# Install Longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.1/deploy/longhorn.yaml

# Verify Longhorn installation
kubectl get pods -n longhorn-system
```

### Network Prerequisites

#### Cilium Installation

```bash
# Install Cilium with Hubble
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.14.2 \
  --namespace kube-system \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
```

### Secrets Management Prerequisites

#### Delinea Vault Setup

1. **Create DSV Account**: Set up tenant at https://vault.delinea.com
2. **Generate Client Credentials**:
   ```bash
   # Create client credentials in DSV
   dsv client create --role admin --name k8s-openfga
   ```
3. **Organize Secrets** in the following structure:
   ```
   /databases/openfga-postgres/
   /databases/openfga-mysql/
   /applications/openfga/
   /identity/keycloak/
   ```

## 🛠️ Installation

### 1. Clone Repository

```bash
git clone https://github.com/jralmaraz/authcore-openfga-operator.git
cd authcore-openfga-operator
```

### 2. Configure Secrets

Create DSV configuration:

```bash
kubectl create namespace openfga-system
kubectl create secret generic dsv-config \
  --from-literal=server="https://your-tenant.secretsvaultcloud.com" \
  --from-literal=clientId="your-client-id" \
  --from-literal=clientSecret="your-client-secret" \
  -n openfga-system
```

### 3. Deploy Platform

#### Option A: Using ArgoCD (Recommended)

```bash
# Install ArgoCD applications
kubectl apply -k kustomize/base/argocd/

# Sync platform configuration
argocd app sync openfga-operator-config
argocd app sync openfga-secrets-management
argocd app sync openfga-monitoring
```

#### Option B: Direct Deployment

```bash
# Deploy base platform
kubectl apply -k kustomize/base/

# Deploy to specific environment
kubectl apply -k kustomize/overlays/dev/
```

### 4. Verify Installation

```bash
# Check operator status
kubectl get pods -n openfga-system

# Verify storage classes
kubectl get storageclass

# Check network policies
kubectl get networkpolicies -n openfga-system

# Validate secrets injection
kubectl get mutatingadmissionwebhook dsv-injector
```

## 📊 Storage Configuration

### Choosing Storage Provider

#### Portworx (Enterprise)
- High availability with 3-replica database storage
- Built-in disaster recovery and cross-cluster replication
- Advanced data services (encryption, compression, QoS)

```yaml
apiVersion: authorization.openfga.dev/v1alpha1
kind: OpenFGA
metadata:
  name: openfga-prod
spec:
  datastore:
    engine: "postgres"
    uri: "postgresql://$(DATABASE_USERNAME):$(DATABASE_PASSWORD)@postgresql-openfga:5432/openfga"
  persistence:
    storageClass: "portworx-sc-db"
    size: "100Gi"
```

#### Longhorn (Open Source)
- Cloud-native distributed storage
- Automatic backups to S3-compatible storage
- Cross-zone replication

```yaml
apiVersion: authorization.openfga.dev/v1alpha1
kind: OpenFGA
metadata:
  name: openfga-dev
spec:
  datastore:
    engine: "postgres"
    uri: "postgresql://$(DATABASE_USERNAME):$(DATABASE_PASSWORD)@postgresql-openfga:5432/openfga"
  persistence:
    storageClass: "longhorn-sc-db"
    size: "50Gi"
```

### Database Deployment

#### PostgreSQL with Persistent Storage

```bash
# Deploy PostgreSQL with Portworx storage
kubectl apply -f kustomize/base/storage/postgresql-persistent.yaml

# Or with Longhorn storage (modify storageClassName in the file)
sed 's/portworx-sc-db/longhorn-sc-db/g' \
  kustomize/base/storage/postgresql-persistent.yaml | kubectl apply -f -
```

#### MySQL with Persistent Storage

```bash
# Deploy MySQL with persistent storage
kubectl apply -f kustomize/base/storage/mysql-persistent.yaml
```

## 🔐 Secrets Management

### DSV Integration

The platform automatically injects secrets using the DSV injector:

```yaml
# Example pod with secret injection
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
```

### Secret Organization

Organize secrets in DSV with this recommended structure:

```
/databases/
  ├── openfga-postgres/
  │   ├── username: "openfga_user"
  │   ├── password: "secure_password"
  │   └── connection-string: "postgresql://..."
  └── openfga-mysql/
      ├── username: "openfga_user"
      ├── password: "secure_password"
      └── root-password: "root_password"
/applications/
  └── openfga/
      ├── jwt-secret: "jwt_signing_key"
      ├── encryption-key: "encryption_key"
      └── api-token: "api_access_token"
```

## 🌐 Network Security

### Cilium Network Policies

The platform includes comprehensive network policies:

- **Default Deny**: All traffic denied by default
- **Microsegmentation**: Fine-grained access control between components
- **Database Protection**: Secure database access from authorized pods only
- **Secrets Security**: Protected communication with DSV

### Hubble Observability

Monitor network traffic in real-time:

```bash
# Install Hubble CLI
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/latest/download/hubble-linux-amd64.tar.gz
tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin

# Monitor OpenFGA traffic
hubble observe --from-label app.kubernetes.io/name=openfga

# Monitor policy violations
hubble observe --verdict DENIED
```

## 🔄 ArgoCD Automation

### GitOps Workflows

The platform includes ArgoCD applications for:

1. **Platform Configuration**: Core operator and infrastructure
2. **Store Management**: OpenFGA store lifecycle
3. **Authorization Models**: Model deployment and validation
4. **Demo Applications**: Banking and GenAI demos

### Environment Management

#### Development Environment

```bash
# Automatic sync from develop branch
argocd app get openfga-dev
argocd app sync openfga-dev
```

#### Production Environment

```bash
# Manual sync with approval process
argocd app get openfga-prod
argocd app sync openfga-prod --dry-run
argocd app sync openfga-prod  # After approval
```

## 🎯 Demo Applications

### Banking Application

Deploy the banking demo with full authorization model:

```bash
# Deploy banking demo
argocd app sync openfga-banking-demo

# Access demo application
kubectl port-forward service/banking-app 3000:3000 -n openfga-demos
open http://localhost:3000
```

### GenAI RAG Agent

Deploy the AI-powered document access demo:

```bash
# Deploy GenAI demo
argocd app sync openfga-genai-demo

# Access demo application
kubectl port-forward service/genai-rag-agent 8000:8000 -n openfga-demos
open http://localhost:8000
```

## 📊 Monitoring and Observability

### Metrics Collection

Monitor platform health using Prometheus metrics:

```bash
# OpenFGA metrics
kubectl port-forward service/openfga-basic-http 8080:8080
curl http://localhost:8080/metrics

# Storage metrics
kubectl get events -n openfga-system --field-selector type=Warning
```

### Network Observability

Use Hubble for network monitoring:

```bash
# Access Hubble UI
kubectl port-forward service/hubble-ui 12000:80 -n kube-system
open http://localhost:12000
```

### Log Aggregation

Collect logs from all components:

```bash
# Operator logs
kubectl logs -n openfga-system deployment/openfga-operator

# DSV injector logs
kubectl logs -n openfga-system deployment/dsv-injector

# OpenFGA instance logs
kubectl logs -n openfga-workloads deployment/openfga-banking
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Storage Issues

```bash
# Check storage class availability
kubectl get storageclass

# Verify PVC status
kubectl get pvc -n openfga-system
kubectl describe pvc postgres-pvc-portworx -n openfga-system

# Check storage provider logs
kubectl logs -n portworx-system -l name=portworx
kubectl logs -n longhorn-system -l app=longhorn-manager
```

#### 2. Secrets Injection Issues

```bash
# Check DSV injector status
kubectl get pods -n openfga-system -l app.kubernetes.io/name=dsv-injector

# Verify webhook configuration
kubectl get mutatingadmissionwebhook dsv-injector

# Test secret injection
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-injection
  namespace: openfga-system
  annotations:
    dsv.delinea.com/inject: "true"
    dsv.delinea.com/secrets: |
      - path: "/test/secret"
        secrets:
          - key: "test-key"
            env: "TEST_VALUE"
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
EOF
```

#### 3. Network Connectivity Issues

```bash
# Check Cilium status
kubectl get pods -n kube-system -l k8s-app=cilium

# Test network policies
hubble observe --verdict DENIED --namespace openfga-system

# Verify DNS resolution
kubectl exec -n openfga-system deployment/openfga-operator -- nslookup postgresql-openfga
```

### Advanced Debugging

#### Enable Debug Logging

```bash
# Operator debug logs
kubectl set env deployment/openfga-operator RUST_LOG=debug -n openfga-system

# DSV injector debug logs
kubectl set env deployment/dsv-injector LOG_LEVEL=debug -n openfga-system
```

#### Performance Analysis

```bash
# Check resource usage
kubectl top pods -n openfga-system

# Analyze network performance
hubble metrics flows --namespace openfga-system
```

## 📚 Documentation

### Additional Resources

- [Persistent Storage Configuration](docs/deployment/PERSISTENT_STORAGE.md)
- [Delinea Vault Integration](docs/secrets/DELINEA_VAULT.md)
- [Cilium Network Policies](docs/networking/CILIUM_HUBBLE.md)
- [ArgoCD Workflows](docs/argocd/ARGOCD_FLOWS.md)
- [Security Architecture](docs/security/SECURITY_POLICY.md)

### API Reference

- [OpenFGA CRD Specification](docs/design/ARCHITECTURE.md)
- [Operator Configuration](README.md#configuration)
- [Demo Applications](DEMOS.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following the contribution guidelines
4. Test thoroughly in development environment
5. Submit a pull request with comprehensive description

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: Report bugs and feature requests in GitHub Issues
- **Discussions**: Join community discussions in GitHub Discussions
- **Documentation**: Comprehensive docs in the `/docs` directory
- **Examples**: Working examples in the `/examples` directory