# OpenFGA Operator

A Kubernetes operator for managing [OpenFGA](https://openfga.dev/) authorization servers, stores, and models in a cloud-native environment.

## Overview

The OpenFGA Operator provides Custom Resource Definitions (CRDs) and a controller to declaratively manage OpenFGA resources in Kubernetes clusters. It simplifies the deployment, configuration, and lifecycle management of OpenFGA authorization infrastructure.

## Features

- **Declarative Management**: Define OpenFGA servers, stores, and authorization models using Kubernetes manifests
- **High Availability**: Support for multi-replica OpenFGA server deployments with proper load balancing
- **Observability**: Integrated OpenTelemetry support for comprehensive monitoring and tracing
- **Network Security**: Cilium-compatible network policies for enhanced security
- **Backup & Recovery**: Automated backup capabilities for authorization data
- **Access Control**: Fine-grained RBAC for store and model management
- **Scalability**: Resource management and autoscaling support

## Custom Resource Definitions (CRDs)

### OpenFGAServer

Manages OpenFGA server instances with comprehensive configuration options.

**Key Features:**
- Database configuration (PostgreSQL, MySQL, SQLite)
- HTTP and gRPC server settings
- Resource management and scheduling
- Security contexts and network policies
- OpenTelemetry integration
- TLS configuration

### OpenFGAStore

Manages OpenFGA stores (tenants) with advanced features.

**Key Features:**
- Store lifecycle management
- Data retention policies
- Automated backups with encryption
- Access control and RBAC
- Metrics collection and monitoring
- Custom labeling and annotations

### AuthorizationModel

Manages OpenFGA authorization models using the OpenFGA DSL.

**Key Features:**
- Complete OpenFGA 1.1 schema support
- Type definitions with relations
- Union, intersection, and difference operations
- Tuple-to-userset relationships
- Computed usersets
- Model validation and versioning

## Quick Start

### Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl configured to access your cluster
- Database (PostgreSQL, MySQL, or SQLite)

### Installation

1. **Install the CRDs:**
   ```bash
   kubectl apply -f config/crd/bases/
   ```

2. **Deploy the operator:**
   ```bash
   kubectl apply -f config/samples/
   ```

### Basic Usage

1. **Create an OpenFGA Server:**
   ```yaml
   apiVersion: openfga.io/v1alpha1
   kind: OpenFGAServer
   metadata:
     name: my-openfga-server
   spec:
     image: openfga/openfga:latest
     replicas: 2
     database:
       type: postgres
       host: postgres-service
       port: 5432
       database: openfga
       username: openfga
       passwordSecret:
         name: postgres-credentials
         key: password
   ```

2. **Create a Store:**
   ```yaml
   apiVersion: openfga.io/v1alpha1
   kind: OpenFGAStore
   metadata:
     name: my-store
   spec:
     serverRef:
       name: my-openfga-server
     displayName: "My Application Store"
   ```

3. **Create an Authorization Model:**
   ```yaml
   apiVersion: openfga.io/v1alpha1
   kind: AuthorizationModel
   metadata:
     name: my-model
   spec:
     storeRef:
       name: my-store
     schema:
       type_definitions:
         - type: "user"
           relations: {}
         - type: "document"
           relations:
             owner:
               this: {}
             viewer:
               union:
                 children:
                   - this: {}
                   - computedUserset:
                       object: ""
                       relation: "owner"
   ```

## Configuration

### OpenTelemetry Integration

Enable distributed tracing and monitoring:

```yaml
spec:
  openTelemetry:
    enabled: true
    serviceName: openfga-server
    endpoint: http://otel-collector:4317
    samplingRate: 0.1
    headers:
      x-honeycomb-team: "your-api-key"
```

### Network Policies (Cilium)

Secure your OpenFGA deployment with network policies:

```yaml
spec:
  networkPolicy:
    enabled: true
    allowedIngress:
      - from:
          - namespaceSelector:
              matchLabels:
                name: application-namespace
        ports:
          - port: 8080
            protocol: TCP
    ciliumLabels:
      app: openfga-server
      version: v1
```

### Backup Configuration

Enable automated backups with encryption:

```yaml
spec:
  backup:
    enabled: true
    schedule: "0 2 * * *"  # Daily at 2 AM
    retentionCount: 7
    compression: true
    encryption:
      enabled: true
      algorithm: "AES256"
      keySecret:
        name: "backup-encryption-key"
        key: "encryption-key"
```

## Architecture

The OpenFGA Operator follows the Kubernetes operator pattern:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   OpenFGA       │    │   OpenFGA       │    │ Authorization   │
│   Server        │────│   Store         │────│   Model         │
│                 │    │                 │    │                 │
│ • HTTP/gRPC     │    │ • Retention     │    │ • Type Defs     │
│ • Database      │    │ • Backup        │    │ • Relations     │
│ • Monitoring    │    │ • Access Control│    │ • Validation    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Controller    │
                    │                 │
                    │ • Reconciliation│
                    │ • Status Updates│
                    │ • Event Handling│
                    └─────────────────┘
```

## Observability

### Metrics

The operator exposes metrics for:
- Server health and performance
- Store statistics (tuple count, model count)
- Authorization request metrics
- Backup status and performance

### Tracing

OpenTelemetry integration provides:
- Request tracing across components
- Performance monitoring
- Error tracking and debugging
- Custom span attributes

### Logging

Structured logging with configurable levels:
- JSON format for machine parsing
- Contextual information for debugging
- Correlation IDs for request tracking

## Security

### Access Control

- RBAC integration for Kubernetes permissions
- Store-level access control with fine-grained permissions
- Service account based authentication
- Group and user-based authorization

### Network Security

- Cilium network policies for microsegmentation
- Ingress and egress traffic control
- IP-based access restrictions
- TLS encryption for all communications

### Data Protection

- Encryption at rest for backups
- Secret management for credentials
- Secure configuration handling
- Audit logging for compliance

## Development

### Prerequisites

- Go 1.21+
- Docker
- kubectl
- Kind or Minikube (for local testing)

### Building

```bash
# Build the manager binary
make build

# Run tests
make test

# Generate manifests
make manifests

# Build and push Docker image
make docker-build docker-push IMG=<registry>/openfga-operator:tag
```

### Local Development

```bash
# Install CRDs
make install

# Run locally
make run

# Deploy to cluster
make deploy IMG=<registry>/openfga-operator:tag
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Support

- [Documentation](https://openfga.dev/)
- [Community Slack](https://openfga.dev/community)
- [GitHub Issues](https://github.com/jralmaraz/openfga-operator/issues)

## Roadmap

- [ ] Advanced scheduling and placement policies
- [ ] Multi-cluster federation support
- [ ] Enhanced monitoring dashboards
- [ ] Integration with external secret managers
- [ ] Performance optimization features
- [ ] Advanced backup strategies (cross-region, incremental)
- [ ] Disaster recovery automation