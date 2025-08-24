# OpenFGA Operator

A Kubernetes operator for managing [OpenFGA](https://openfga.dev/) authorization service instances and authorization models.

## Overview

The OpenFGA Operator simplifies the deployment and management of OpenFGA instances in Kubernetes environments. It provides custom resources for defining authorization stores and models, handles database configuration, and integrates seamlessly with cloud-native tools and security practices.

## Features

### 🎯 Core Functionality
- **Custom Resource Definitions (CRDs)**:
  - `OpenFGAStore`: Manages OpenFGA service instances with database connectivity
  - `OpenFGAAuthModel`: Manages authorization models and their lifecycle
- **Automated Deployment**: Automatically creates and manages Kubernetes deployments and services
- **Database Integration**: Supports PostgreSQL, MySQL, and SQLite with flexible connection configuration
- **Status Management**: Comprehensive status reporting and condition tracking

### 🔒 Security & Integration
- **Vault Integration**: Seamless integration with HashiCorp Vault via External Secrets Operator
- **Secret Management**: Secure handling of database credentials and sensitive configuration
- **RBAC**: Comprehensive role-based access control for operator permissions
- **Security Context**: Runs with minimal privileges and security best practices

### 🚀 DevOps & GitOps
- **Argo CD Compatibility**: Full support for GitOps workflows with Argo CD
- **Helm Charts**: Production-ready Helm charts for easy deployment
- **Custom Resource Validation**: Schema validation for custom resources
- **Event Handling**: Kubernetes events for operational visibility

### ⚡ Performance & Observability
- **eBPF-Friendly**: Optimized for eBPF-based monitoring and security tools
- **Structured Logging**: Comprehensive logging with configurable levels
- **Metrics**: Prometheus-compatible metrics (planned)
- **Health Checks**: Built-in health and readiness probes

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   OpenFGA       │    │  OpenFGA         │    │   Demo          │
│   Operator      │────│  Store           │────│   Service       │
│                 │    │  (CRD)           │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌──────────────────┐            │
         └──────────────│  OpenFGA         │────────────┘
                        │  Auth Model      │
                        │  (CRD)           │
                        └──────────────────┘
                                 │
                        ┌──────────────────┐
                        │   Database       │
                        │ (PostgreSQL/     │
                        │  MySQL/SQLite)   │
                        └──────────────────┘
```

## Quick Start

### Prerequisites

- Kubernetes cluster (v1.24+)
- `kubectl` configured to access your cluster
- Rust 1.75+ (for building from source)
- Docker (for building container images)

### Installation

#### Option 1: Using Helm (Recommended)

```bash
# Add the helm repository (when available)
helm repo add openfga-operator https://jralmaraz.github.io/Openfga-operator
helm repo update

# Install the operator
helm install openfga-operator openfga-operator/openfga-operator \
  --namespace openfga-system \
  --create-namespace
```

#### Option 2: Using Kubectl

```bash
# Clone the repository
git clone https://github.com/jralmaraz/Openfga-operator.git
cd Openfga-operator

# Install CRDs and operator
make deploy
```

#### Option 3: Building from Source

```bash
# Clone and build
git clone https://github.com/jralmaraz/Openfga-operator.git
cd Openfga-operator

# Initialize repository structure
chmod +x init.sh
./init.sh

# Build the operator
make build

# Build and push Docker image
make docker-build
make docker-push

# Deploy to cluster
make deploy
```

### Creating Your First OpenFGA Store

1. **Create a database secret** (for PostgreSQL example):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
  namespace: default
type: Opaque
data:
  connectionString: <base64-encoded-connection-string>
```

2. **Create an OpenFGA Store**:

```yaml
apiVersion: openfga.dev/v1
kind: OpenFGAStore
metadata:
  name: my-authz-store
  namespace: default
spec:
  replicas: 2
  image: "openfga/openfga:v1.4.3"
  database:
    type: "postgres"
    connection:
      secretRef:
        name: "postgres-credentials"
        key: "connectionString"
  config:
    OPENFGA_HTTP_ADDR: "0.0.0.0:8080"
    OPENFGA_GRPC_ADDR: "0.0.0.0:8081"
    OPENFGA_LOG_LEVEL: "info"
```

3. **Define an Authorization Model**:

```yaml
apiVersion: openfga.dev/v1
kind: OpenFGAAuthModel
metadata:
  name: github-model
  namespace: default
spec:
  storeRef:
    name: my-authz-store
  model:
    schemaVersion: "1.1"
    typeDefinitions:
    - type: "user"
    - type: "organization"
      relations:
        member:
          this: {}
        admin:
          this: {}
    - type: "repository"
      relations:
        owner:
          this: {}
        reader:
          this: {}
        writer:
          union:
            child:
            - this: {}
            - computed_userset:
                object: ""
                relation: "owner"
```

4. **Apply the resources**:

```bash
kubectl apply -f my-store.yaml
kubectl apply -f my-auth-model.yaml
```

### Deploying the Demo Service

```bash
# Build and deploy the demo microservice
make demo-build
make demo-docker
kubectl apply -f demo/manifests/demo-deployment.yaml

# Test the demo service
kubectl port-forward service/openfga-demo 3000:80
curl http://localhost:3000/health
```

## Configuration

### OpenFGA Store Configuration

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `spec.replicas` | `int` | Number of OpenFGA pod replicas | No (default: 1) |
| `spec.image` | `string` | OpenFGA container image | No (default: openfga/openfga:latest) |
| `spec.database.type` | `string` | Database type (postgres/mysql/sqlite) | Yes |
| `spec.database.connection` | `object` | Database connection configuration | Yes |
| `spec.config` | `map[string]string` | Additional OpenFGA configuration | No |

### Database Connection Options

#### Using Connection String

```yaml
database:
  type: "postgres"
  connection:
    connectionString: "postgres://user:pass@host:5432/dbname"
```

#### Using Secret Reference

```yaml
database:
  type: "postgres"
  connection:
    secretRef:
      name: "db-credentials"
      key: "connectionString"
```

### Integration with External Secrets

For Vault integration using External Secrets Operator:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: default
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "openfga-operator"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: openfga-db-credentials
  namespace: default
spec:
  refreshInterval: 5m
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: postgres-credentials
    creationPolicy: Owner
  data:
  - secretKey: connectionString
    remoteRef:
      key: openfga/database
      property: connectionString
```

## Development

### Project Structure

```
├── src/                    # Rust operator source code
│   ├── controller/         # Controller logic
│   ├── models/            # CRD models and types
│   └── utils/             # Utility functions
├── config/                # Kubernetes manifests
│   ├── crd/              # Custom Resource Definitions
│   ├── rbac/             # RBAC configurations
│   └── manager/          # Operator deployment
├── demo/                  # Demo microservice
├── charts/               # Helm charts
├── examples/             # Usage examples
└── tests/                # Test suites
```

### Building and Testing

```bash
# Install development dependencies
make dev-setup

# Run tests
make test

# Lint code
make lint

# Watch for changes during development
make watch

# Apply sample configurations
make apply-samples
```

### Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes and add tests
4. Run tests and linting: `make test lint`
5. Commit your changes: `git commit -am 'Add my feature'`
6. Push to the branch: `git push origin feature/my-feature`
7. Submit a pull request

## Compatibility

### Kubernetes Versions
- ✅ Kubernetes 1.24+
- ✅ OpenShift 4.10+
- ✅ EKS, GKE, AKS

### OpenFGA Versions
- ✅ OpenFGA v1.3.x
- ✅ OpenFGA v1.4.x
- ✅ OpenFGA v1.5.x (when available)

### Database Support
- ✅ PostgreSQL 12+
- ✅ MySQL 8.0+
- ✅ SQLite 3.x

## Monitoring and Observability

### Logs

The operator provides structured logging with configurable levels:

```bash
# View operator logs
kubectl logs -n openfga-system deployment/openfga-operator-controller-manager

# Set log level
kubectl set env -n openfga-system deployment/openfga-operator-controller-manager RUST_LOG=openfga_operator=debug
```

### Events

Monitor Kubernetes events for operator activities:

```bash
kubectl get events --field-selector involvedObject.kind=OpenFGAStore
kubectl get events --field-selector involvedObject.kind=OpenFGAAuthModel
```

### Status Monitoring

Check resource status:

```bash
kubectl get openfgastores
kubectl get openfgaauthmodels
kubectl describe openfgastore my-store
```

## Troubleshooting

### Common Issues

1. **Store not ready**: Check database connectivity and credentials
2. **Permission denied**: Verify RBAC configuration
3. **Image pull errors**: Ensure image exists and registry access

### Debug Commands

```bash
# Check operator status
kubectl get pods -n openfga-system
kubectl logs -n openfga-system deployment/openfga-operator-controller-manager

# Check CRD status
kubectl get crd | grep openfga

# Validate resources
kubectl describe openfgastore <name>
kubectl describe openfgaauthmodel <name>
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Support

- 📖 [Documentation](https://github.com/jralmaraz/Openfga-operator/wiki)
- 🐛 [Issues](https://github.com/jralmaraz/Openfga-operator/issues)
- 💬 [Discussions](https://github.com/jralmaraz/Openfga-operator/discussions)
- 📧 Email: team@openfga.dev

## Roadmap

### v0.2.0
- [ ] Prometheus metrics integration
- [ ] Grafana dashboards
- [ ] Backup and restore functionality
- [ ] Multi-tenancy support

### v0.3.0
- [ ] Horizontal Pod Autoscaler support
- [ ] Advanced monitoring and alerting
- [ ] Performance optimizations
- [ ] Migration utilities

### v1.0.0
- [ ] Production-grade stability
- [ ] Comprehensive test suite
- [ ] Security audit
- [ ] Documentation improvements

---

**OpenFGA Operator** - Making authorization management in Kubernetes simple and secure.