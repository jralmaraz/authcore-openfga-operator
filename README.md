# OpenFGA Operator - AuthCore Authorization Platform

A comprehensive Kubernetes operator for managing [OpenFGA](https://openfga.dev/) authorization infrastructure in cloud-native environments. This project provides both **Rust** and **Go** implementations to offer maximum flexibility and ecosystem integration.

## Overview

The OpenFGA Operator enables declarative management of OpenFGA authorization infrastructure in Kubernetes clusters. As part of the **AuthCore authorization platform**, it provides enterprise-grade authorization capabilities with support for OpenTelemetry observability, Cilium network policies, high availability, Vault integration, and Argo CD compatibility.

## Dual Implementation Architecture

This operator uniquely supports both **Rust** and **Go** implementations:

- **Rust Implementation**: Lightweight, memory-efficient operator with basic OpenFGA CRD management
- **Go Implementation**: Feature-rich operator with comprehensive CRDs, advanced integrations, and enterprise features

### API Groups

- **Rust**: `authorization.openfga.dev/v1alpha1` - Single `OpenFGA` CRD
- **Go**: `openfga.io/v1alpha1` - Three comprehensive CRDs:
  - `OpenFGAServer` - Server instance management
  - `OpenFGAStore` - Store/tenant management  
  - `AuthorizationModel` - Authorization model management

## Features

### Core Authorization Features
- **Declarative Management**: Define OpenFGA resources using Kubernetes manifests
- **Complete OpenFGA 1.1 Support**: Full DSL implementation with complex authorization patterns
- **Multi-Tenancy**: Store-based isolation and management
- **Model Versioning**: Authorization model lifecycle management

### Enterprise & Cloud-Native Features
- **High Availability**: Multi-replica deployments with pod anti-affinity and load balancing
- **OpenTelemetry Integration**: Comprehensive distributed tracing and monitoring
- **Cilium Network Policies**: Enhanced microsegmentation and network security
- **Backup & Recovery**: Automated encrypted backups with configurable retention
- **Vault Integration**: Secure secret management and credential handling
- **Argo CD Compatibility**: GitOps-ready manifests and deployment strategies
- **Database Integration**: PostgreSQL, MySQL, and SQLite support with connection pooling

### Observability & Operations
- **Prometheus Metrics**: Custom metrics with ServiceMonitor support
- **Structured Logging**: JSON logging with correlation IDs
- **Health Checks**: Readiness and liveness probes
- **Resource Management**: CPU/memory limits and requests
- **Scaling Support**: Horizontal pod autoscaling

## Quick Start

### Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl configured to access your cluster
- For Rust: Rust 1.70+ and Cargo
- For Go: Go 1.21+ and Docker

### Installation

#### Using Rust Implementation

```bash
# Build and run locally
make rust-build
make rust-install-crds
make rust-run
```

#### Using Go Implementation

```bash
# Install CRDs and deploy operator
make go-install
make go-deploy IMG=openfga-operator:latest
```

#### Both Implementations

```bash
# Build both implementations
make all

# Install all CRDs (both API groups)
make install

# Run all tests
make test
```

## Usage Examples

### Rust Implementation (Basic)

```yaml
apiVersion: authorization.openfga.dev/v1alpha1
kind: OpenFGA
metadata:
  name: my-openfga
  namespace: default
spec:
  replicas: 2
  image: "openfga/openfga:latest"
  datastore:
    engine: "postgres"
    uri: "postgresql://user:password@postgres:5432/openfga"
  playground:
    enabled: true
    port: 3000
  grpc:
    port: 8081
  http:
    port: 8080
```

### Go Implementation (Advanced)

#### OpenFGA Server with Full Configuration

```yaml
apiVersion: openfga.io/v1alpha1
kind: OpenFGAServer
metadata:
  name: production-server
  namespace: openfga-system
spec:
  image: openfga/openfga:v1.4.3
  replicas: 3
  
  database:
    type: postgres
    host: postgres-ha-service
    port: 5432
    database: openfga_prod
    username: openfga
    passwordSecret:
      name: postgres-credentials
      key: password
    sslMode: require
    maxOpenConns: 50
    maxIdleConns: 25
  
  openTelemetry:
    enabled: true
    serviceName: openfga-server
    endpoint: http://otel-collector:4317
    samplingRate: 0.1
    headers:
      x-environment: production
  
  networkPolicy:
    enabled: true
    allowedIngress:
      - from:
          - namespaceSelector:
              matchLabels:
                name: application
        ports:
          - port: 8080
    ciliumLabels:
      app: openfga-server
      environment: production
  
  resources:
    requests:
      memory: "512Mi"
      cpu: "200m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
```

#### OpenFGA Store with Backup and RBAC

```yaml
apiVersion: openfga.io/v1alpha1
kind: OpenFGAStore
metadata:
  name: production-store
  namespace: openfga-system
spec:
  serverRef:
    name: production-server
  
  displayName: "Production Authorization Store"
  
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retentionCount: 30
    encryption:
      enabled: true
      algorithm: "AES256"
      keySecret:
        name: "backup-encryption-key"
        key: "encryption-key"
  
  accessControl:
    enabled: true
    rbacRules:
      - subjects:
          - kind: ServiceAccount
            name: "api-service"
            namespace: "production"
        permissions: ["read", "write"]
        resources: ["tuples"]
```

#### Complex Authorization Model

```yaml
apiVersion: openfga.io/v1alpha1
kind: AuthorizationModel
metadata:
  name: organization-model
  namespace: openfga-system
spec:
  storeRef:
    name: production-store
  
  schema:
    type_definitions:
      - type: "user"
        relations: {}
      
      - type: "organization"
        relations:
          member:
            this: {}
          admin:
            this: {}
      
      - type: "document"
        relations:
          owner:
            this: {}
          viewer:
            union:
              children:
                - this: {}
                - computedUserset:
                    relation: "owner"
          can_read:
            computedUserset:
              relation: "viewer"
```

## Configuration

### OpenTelemetry Integration

```yaml
openTelemetry:
  enabled: true
  serviceName: openfga-server
  endpoint: http://otel-collector:4317
  samplingRate: 0.1
  headers:
    x-environment: production
    x-service-version: v1.4.3
```

### Cilium Network Policies

```yaml
networkPolicy:
  enabled: true
  allowedIngress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: application
      ports:
        - port: 8080
          protocol: TCP
  ciliumLabels:
    app: openfga-server
    version: v1
```

### Vault Integration

```yaml
database:
  passwordSecret:
    name: vault-database-credentials
    key: password
    
backup:
  encryption:
    keySecret:
      name: vault-backup-keys
      key: encryption-key
```

## Development

### Building Both Implementations

```bash
# Check all code
make compile

# Build both implementations
make build

# Run tests for both
make test

# Format code
make fmt

# Run linting
make vet
```

### Rust-Specific Development

```bash
# Rust development mode with auto-reload
make rust-dev

# Rust clippy linting
make rust-clippy

# Rust tests only
make rust-test
```

### Go-Specific Development

```bash
# Generate Go manifests and code
make go-manifests go-generate

# Run Go operator locally
make go-run

# Go tests only
make go-test
```

## CI/CD & GitOps

### GitHub Actions

The project includes comprehensive CI/CD workflows:

- **Rust CI**: Cargo build, test, clippy, and formatting checks
- **Go CI**: Go build, test, vet, and manifest generation
- **Integration Tests**: End-to-end testing with real Kubernetes clusters
- **Security Scanning**: Container image and dependency vulnerability scanning

### Argo CD Integration

```yaml
# argo-cd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: openfga-operator
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/jralmaraz/openfga-operator
    path: config/samples
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: openfga-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Architecture

### AuthCore Authorization Platform

```
┌─────────────────────────────────────────────────────────────────┐
│                   AuthCore Authorization Platform                │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐│
│  │   OpenFGA       │    │   OpenFGA       │    │ Authorization   ││
│  │   Server        │────│   Store         │────│   Model         ││
│  │                 │    │                 │    │                 ││
│  │ • HTTP/gRPC     │    │ • Multi-tenancy │    │ • Type Defs     ││
│  │ • HA Deployment │    │ • Backup/Restore│    │ • Relations     ││
│  │ • Load Balancing│    │ • Access Control│    │ • Validation    ││
│  │ • Health Checks │    │ • Retention     │    │ • Versioning    ││
│  └─────────────────┘    └─────────────────┘    └─────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                        Integration Layer                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │OpenTelemetry│ │   Cilium    │ │    Vault    │ │  Argo CD    │ │
│  │   Tracing   │ │  Policies   │ │  Secrets    │ │   GitOps    │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                     Kubernetes Platform                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │   Rust      │ │     Go      │ │   Custom    │ │   Service   │ │
│  │ Operator    │ │  Operator   │ │ Resources   │ │   Mesh      │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Common Issues

1. **CRD Conflicts**: Different API groups prevent conflicts between Rust and Go implementations
2. **Database Connectivity**: Check connection strings and credentials in secrets
3. **Network Policies**: Ensure Cilium is installed and policies allow required traffic
4. **OpenTelemetry**: Verify collector endpoint and sampling configuration

### Debugging Commands

```bash
# Check both implementations
kubectl get openfgas.authorization.openfga.dev
kubectl get openfgaservers.openfga.io
kubectl get openfgastores.openfga.io
kubectl get authorizationmodels.openfga.io

# Operator logs
kubectl logs -n openfga-operator-system deployment/openfga-operator-controller-manager

# Rust operator logs (if running locally)
make rust-run

# Validate manifests
make go-manifests
kubectl apply --dry-run=client -f config/crd/bases/
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Choose implementation (Rust or Go) or work on both
4. Make changes and add tests
5. Run appropriate test suite:
   - `make rust-check-all` for Rust changes
   - `make go-test` for Go changes
   - `make check-all` for both
6. Submit a pull request

## Project Structure

```
├── src/                     # Rust implementation
│   ├── main.rs             # Rust main entry point
│   ├── types.rs            # Rust CRD definitions
│   └── controller.rs       # Rust controller logic
├── api/v1alpha1/           # Go API definitions
│   ├── openfgaserver_types.go
│   ├── openfgastore_types.go
│   └── authorizationmodel_types.go
├── config/                 # Go operator manifests
│   ├── crd/bases/         # Generated CRDs
│   ├── samples/           # Example manifests
│   └── default/           # Default deployment
├── crds/                  # Rust CRD YAML
│   └── openfga-crd.yaml
├── examples/              # Usage examples
├── docs/                  # Documentation
├── main.go               # Go main entry point
├── Cargo.toml            # Rust dependencies
├── go.mod                # Go dependencies
└── Makefile              # Unified build system
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Support & Community

- **Documentation**: [OpenFGA Documentation](https://openfga.dev/)
- **Community**: [OpenFGA Slack](https://openfga.dev/community)
- **Issues**: [GitHub Issues](https://github.com/jralmaraz/openfga-operator/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jralmaraz/openfga-operator/discussions)

## Roadmap

- [x] Rust implementation with basic CRDs
- [x] Go implementation with comprehensive CRDs
- [x] OpenTelemetry integration
- [x] Cilium network policy support
- [x] Backup and recovery features
- [x] RBAC and access control
- [ ] Vault secret management integration
- [ ] Advanced Argo CD integration patterns
- [ ] Multi-cluster federation
- [ ] Performance optimization
- [ ] Enhanced monitoring dashboards
- [ ] Disaster recovery automation
- [ ] Machine learning-based optimization

---

**AuthCore Authorization Platform** - Empowering cloud-native authorization at scale.