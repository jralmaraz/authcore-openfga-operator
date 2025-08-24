# OpenFGA Operator

A Kubernetes operator for managing [OpenFGA](https://openfga.dev/) instances.

## Overview

This operator provides a Kubernetes-native way to deploy and manage OpenFGA (Fine-Grained Authorization) instances in your cluster. It uses Custom Resource Definitions (CRDs) to define OpenFGA instances and automatically creates and manages the necessary Kubernetes resources.

## Features

- **Custom Resource Definition (CRD)**: Define OpenFGA instances using Kubernetes-native resources
- **Automatic Resource Management**: Creates and maintains Deployments and Services for OpenFGA instances
- **Configurable Datastores**: Support for memory, PostgreSQL, and MySQL datastores
- **Playground Support**: Optional OpenFGA playground interface
- **Status Tracking**: Real-time status updates and conditions

## Prerequisites

- Kubernetes cluster (v1.20+)
- `kubectl` configured to access your cluster
- Rust (1.70+) for development

## Installation

### Install CRDs

```bash
make install-crds
```

### Deploy the Operator

```bash
# Build the operator
make build

# Deploy to your cluster (deployment manifests coming soon)
kubectl apply -f k8s/
```

## Usage

### Basic Example

Create an OpenFGA instance with in-memory storage:

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
    engine: "memory"
  grpc:
    port: 8081
  http:
    port: 8080
```

### PostgreSQL Example

Create an OpenFGA instance with PostgreSQL storage:

```yaml
apiVersion: authorization.openfga.dev/v1alpha1
kind: OpenFGA
metadata:
  name: openfga-postgres
  namespace: default
spec:
  replicas: 3
  image: "openfga/openfga:v1.4.0"
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

## Configuration

### OpenFGA Spec

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `replicas` | `int32` | Number of OpenFGA replicas | `1` |
| `image` | `string` | OpenFGA Docker image | `openfga/openfga:latest` |
| `datastore` | `DatastoreConfig` | Datastore configuration | Required |
| `playground` | `PlaygroundConfig` | Playground configuration | Optional |
| `grpc` | `GrpcConfig` | gRPC server configuration | Optional |
| `http` | `HttpConfig` | HTTP server configuration | Optional |

### Datastore Configuration

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `engine` | `string` | Datastore engine (`memory`, `postgres`, `mysql`) | `memory` |
| `uri` | `string` | Database connection URI (required for postgres/mysql) | `nil` |

### Playground Configuration

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `enabled` | `bool` | Enable the playground interface | `false` |
| `port` | `int32` | Playground server port | `3000` |

## Development

### Building

```bash
# Check syntax
make compile

# Build release binary
make build

# Run tests
make test

# Format code
make fmt

# Run linter
make clippy

# Run all checks
make check-all
```

### Running Locally

```bash
# Install CRDs first
make install-crds

# Run the operator locally
make run
```

### Development Mode

```bash
# Run with auto-reload (requires cargo-watch)
make dev
```

## CI/CD

The project includes GitHub Actions workflows for:

- **Compile Check**: Validates code compilation
- **Build Check**: Validates release build
- **Test Suite**: Runs unit tests
- **Format Check**: Validates code formatting
- **Clippy Check**: Runs Rust linter

These checks run automatically on pull requests and provide status checks.

## Project Structure

```
├── src/
│   ├── main.rs           # Application entry point
│   ├── types.rs          # Custom Resource Definitions and types
│   └── controller.rs     # Controller logic and reconciliation
├── crds/                 # CRD YAML definitions
│   └── openfga-crd.yaml
├── k8s/                  # Kubernetes manifests
├── Makefile              # Build and development commands
└── .github/workflows/    # CI/CD workflows
    └── ci.yml
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Run checks: `make check-all`
6. Submit a pull request

## License

Apache 2.0 License. See [LICENSE](LICENSE) for details.

## Related Projects

- [OpenFGA](https://github.com/openfga/openfga) - Fine-Grained Authorization system
- [kube-rs](https://github.com/kube-rs/kube) - Kubernetes client library for Rust