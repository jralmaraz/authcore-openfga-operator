# OpenFGA Operator

A Kubernetes operator for managing [OpenFGA](https://openfga.dev/) authorization service instances.

## Overview

The OpenFGA Operator automates the deployment and management of OpenFGA authorization services in Kubernetes clusters. It provides:

- **Custom Resource Definitions (CRDs)** for declarative OpenFGA configuration
- **Automated deployment** and lifecycle management
- **Integration with observability tools** (OpenTelemetry, Prometheus)
- **Storage backend configuration** (PostgreSQL, MySQL, in-memory)
- **High availability** and scaling capabilities

## Features

- 🚀 **Easy Deployment**: Deploy OpenFGA instances with simple YAML manifests
- 📊 **Observability**: Built-in OpenTelemetry integration for metrics and tracing
- 🔧 **Configurable**: Support for multiple storage backends and configuration options
- 🔄 **Lifecycle Management**: Automated updates, scaling, and cleanup
- 🛡️ **Production Ready**: Designed for enterprise Kubernetes environments

## Prerequisites

- Kubernetes cluster (v1.21+)
- `kubectl` configured to access your cluster
- Rust toolchain (1.70+) for development

## Quick Start

### 1. Install the Operator

```bash
# Clone the repository
git clone https://github.com/jralmaraz/Openfga-operator.git
cd Openfga-operator

# Build and install the CRD
make install-crd

# Deploy the operator (optional - can also run locally)
make deploy
```

### 2. Create an OpenFGA Instance

Create a simple OpenFGA instance:

```yaml
apiVersion: openfga.io/v1alpha1
kind: OpenFga
metadata:
  name: my-openfga
  namespace: default
spec:
  server:
    image: "openfga/openfga:latest"
    replicas: 2
  storage:
    type: "memory"
  observability:
    metrics: true
    tracing: true
```

Apply the configuration:

```bash
kubectl apply -f my-openfga.yaml
```

### 3. Verify the Deployment

```bash
# Check the OpenFGA instance
kubectl get openfgas

# View detailed status
kubectl describe openfga my-openfga

# Check pods
kubectl get pods -l app=openfga
```

## Development Setup

### Prerequisites

- Rust 1.70 or later
- Docker (for building container images)
- Access to a Kubernetes cluster (minikube, kind, etc.)

### Local Development

1. **Set up the development environment:**

   ```bash
   make dev-setup
   ```

2. **Run the operator locally:**

   ```bash
   # Ensure your KUBECONFIG is set correctly
   export KUBECONFIG=~/.kube/config
   
   # Run with verbose logging
   make run-verbose
   ```

3. **Run tests:**

   ```bash
   # Run all tests
   make test
   
   # Run tests with verbose output
   make test-verbose
   ```

4. **Code quality checks:**

   ```bash
   # Format, lint, and test
   make check
   ```

### Building and Deployment

1. **Build the operator:**

   ```bash
   make build
   ```

2. **Build Docker image:**

   ```bash
   make docker-build
   ```

3. **Deploy to cluster:**

   ```bash
   make deploy
   ```

## Configuration

### OpenFGA Spec

The `OpenFgaSpec` defines the desired state of an OpenFGA instance:

```yaml
apiVersion: openfga.io/v1alpha1
kind: OpenFga
metadata:
  name: production-openfga
  namespace: openfga-system
spec:
  server:
    image: "openfga/openfga:v1.3.0"
    imagePullPolicy: "IfNotPresent"
    replicas: 3
    config:
      log-level: "info"
      http-addr: "0.0.0.0:8080"
      grpc-addr: "0.0.0.0:8081"
  
  storage:
    type: "postgres"
    connection: "postgres://user:pass@postgres:5432/openfga"
    config:
      max-connections: "100"
  
  observability:
    metrics: true
    tracing: true
    opentelemetry:
      endpoint: "http://jaeger:14268/api/traces"
      headers:
        "Authorization": "Bearer token123"
  
  resources:
    cpuRequest: "100m"
    memoryRequest: "128Mi"
    cpuLimit: "500m"
    memoryLimit: "512Mi"
```

### Storage Backends

The operator supports multiple storage backends:

#### In-Memory (Development Only)
```yaml
storage:
  type: "memory"
```

#### PostgreSQL
```yaml
storage:
  type: "postgres"
  connection: "postgres://user:password@host:5432/database"
  config:
    max-connections: "100"
    ssl-mode: "require"
```

#### MySQL
```yaml
storage:
  type: "mysql"
  connection: "mysql://user:password@host:3306/database"
  config:
    max-connections: "100"
```

### Observability

Enable comprehensive observability with OpenTelemetry:

```yaml
observability:
  metrics: true
  tracing: true
  opentelemetry:
    endpoint: "http://jaeger-collector:14268/api/traces"
    headers:
      "x-api-key": "your-api-key"
```

## Architecture

The OpenFGA Operator consists of:

- **Controller**: Manages the lifecycle of OpenFGA instances
- **CRDs**: Define the API for OpenFGA resources
- **Webhooks**: Validate and mutate OpenFGA resources (future)
- **Telemetry**: OpenTelemetry integration for observability

## API Reference

### OpenFga Resource

| Field | Type | Description |
|-------|------|-------------|
| `spec.server` | `OpenFgaServerSpec` | OpenFGA server configuration |
| `spec.storage` | `StorageSpec` | Storage backend configuration |
| `spec.observability` | `ObservabilitySpec` | Observability settings |
| `spec.resources` | `ResourceSpec` | Resource requirements |

### Status Fields

| Field | Type | Description |
|-------|------|-------------|
| `status.phase` | `string` | Current phase (Provisioning, Ready, Failed) |
| `status.message` | `string` | Human-readable status message |
| `status.readyReplicas` | `int32` | Number of ready replicas |
| `status.conditions` | `[]Condition` | Detailed condition information |

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make build` | Build the operator binary |
| `make test` | Run all tests |
| `make run` | Run the operator locally |
| `make check` | Run format, lint, and tests |
| `make install-crd` | Install CRDs to cluster |
| `make deploy` | Deploy operator to cluster |
| `make docker-build` | Build Docker image |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `make check` to ensure code quality
5. Submit a pull request

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## Support

- 📖 [Documentation](https://github.com/jralmaraz/Openfga-operator/wiki)
- 🐛 [Issue Tracker](https://github.com/jralmaraz/Openfga-operator/issues)
- 💬 [Discussions](https://github.com/jralmaraz/Openfga-operator/discussions)

## Related Projects

- [OpenFGA](https://openfga.dev/) - Authorization service
- [kube-rs](https://kube.rs/) - Rust Kubernetes client library
- [OpenTelemetry](https://opentelemetry.io/) - Observability framework