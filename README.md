# OpenFGA Operator

A security-first Kubernetes operator for managing [OpenFGA](https://openfga.dev/) instances with enterprise-grade protection against malicious code injection and comprehensive security controls.

## Overview

The OpenFGA Operator provides a Kubernetes-native way to deploy and manage OpenFGA (Fine-Grained Authorization) instances with industry-leading security features. Built with a security-first approach, it implements comprehensive admission controllers, malicious code analysis, and cryptographic verification systems to ensure the highest level of security for authorization infrastructure.

## 🛡️ Security Features

### Advanced Security Architecture
- **Admission Controller Framework**: Comprehensive validation webhook system with policy enforcement
- **Malicious Code Injection Analysis**: AI-powered static and dynamic security analysis
- **Git Commit Verification**: Cryptographic GPG signature verification for all commits
- **Developer Authentication**: Multi-factor authentication with certificate-based validation
- **Container Image Security**: Vulnerability scanning and signature verification
- **Zero Trust Architecture**: No implicit trust, continuous verification of all components

### Security by Design
- **Defense in Depth**: Multiple layers of security controls
- **Supply Chain Security**: End-to-end security for deployment pipeline
- **Behavioral Analysis**: ML-based anomaly detection and threat intelligence
- **Automated Incident Response**: Self-healing security violations
- **Compliance Ready**: SOC 2, ISO 27001, and NIST framework compliance

## 🚀 Core Features

- **Security-First Design**: Comprehensive security architecture with admission controllers
- **Custom Resource Definition (CRD)**: Define OpenFGA instances using Kubernetes-native resources
- **Automatic Resource Management**: Creates and maintains Deployments and Services for OpenFGA instances
- **Configurable Datastores**: Support for memory, PostgreSQL, and MySQL datastores
- **Playground Support**: Optional OpenFGA playground interface
- **Status Tracking**: Real-time status updates and conditions
- **Enterprise Ready**: Multi-tenancy, SSO integration, and compliance automation

## Documentation

### 📚 Comprehensive Documentation
- **[Security Architecture](docs/security/SECURITY_ARCHITECTURE.md)**: Detailed security design and implementation
- **[Design Documentation](docs/design/ARCHITECTURE.md)**: Complete system architecture and design patterns
- **[Product Roadmap](docs/roadmap/ROADMAP.md)**: Strategic vision and release planning
- **[Product Log](docs/product-log/PRODUCT_LOG.md)**: Comprehensive product documentation
- **[Security Policy](docs/security/SECURITY_POLICY.md)**: Security requirements and standards
- **[Incident Response](docs/security/INCIDENT_RESPONSE.md)**: Security incident response procedures

### 🌐 AuthCore Showcase
- **[AuthCore Website](docs/authcore-website/)**: Professional showcase website with content management
- **Live Demo**: [AuthCore Demo](docs/authcore-website/index.html) - Interactive demonstration
- **Stakeholder Presentation**: Comprehensive demo for business stakeholders

### 🎯 Demo Applications
- **[Banking Application Demo](demos/banking-app/)**: Complete banking microservice with fine-grained authorization
- **[GenAI RAG Agent Demo](demos/genai-rag-agent/)**: AI-powered RAG agent with OpenFGA authorization
- **[Demo Overview](demos/README.md)**: Introduction to all demonstration applications

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

## Security Implementation

### Admission Controller Setup

The OpenFGA Operator includes a comprehensive admission controller for security validation:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionWebhook
metadata:
  name: openfga-security-validator
spec:
  clientConfig:
    service:
      name: openfga-operator-webhook
      namespace: openfga-system
      path: "/validate"
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: ["authorization.openfga.dev"]
    apiVersions: ["v1alpha1"]
    resources: ["openfgas"]
```

### Git Commit Verification

Enable GPG signature verification for all commits:

```bash
# Configure Git signing
git config --global user.signingkey YOUR_GPG_KEY_ID
git config --global commit.gpgsign true

# Pre-commit hook for verification
#!/bin/bash
if ! git verify-commit HEAD; then
    echo "ERROR: Commit must be signed with GPG"
    exit 1
fi
```

### Security Policy Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: openfga-security-policy
  namespace: openfga-system
data:
  policy.yaml: |
    securityPolicy:
      imageVerification:
        enforced: true
        allowedRegistries:
          - "gcr.io/openfga"
          - "quay.io/openfga"
      developerAuth:
        enforced: true
        requiredSignatures: ["gpg"]
      vulnerabilityScanning:
        enforced: true
        maxSeverity: "medium"
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
├── docs/                 # Comprehensive documentation
│   ├── security/         # Security architecture and policies
│   │   ├── SECURITY_ARCHITECTURE.md
│   │   ├── SECURITY_POLICY.md
│   │   └── INCIDENT_RESPONSE.md
│   ├── design/           # System design documentation
│   │   └── ARCHITECTURE.md
│   ├── roadmap/          # Product roadmap and strategy
│   │   └── ROADMAP.md
│   ├── product-log/      # Product documentation
│   │   └── PRODUCT_LOG.md
│   └── authcore-website/ # AuthCore showcase website
│       ├── index.html
│       ├── styles.css
│       ├── script.js
│       └── README.md
├── Makefile              # Build and development commands
└── .github/workflows/    # CI/CD workflows
    └── ci.yml
```

## Enterprise Features

### 🏢 Enterprise Security
- **Multi-tenancy**: Secure tenant isolation with namespace-based segmentation
- **Enterprise SSO**: Integration with SAML, OIDC, and Active Directory
- **Compliance Automation**: Automated compliance reporting and validation
- **Audit Logging**: Comprehensive audit trails for all operations
- **Risk Management**: Risk-based security policies and controls

### 📊 Observability and Monitoring
- **Prometheus Integration**: Comprehensive metrics collection
- **Grafana Dashboards**: Pre-built monitoring dashboards
- **Distributed Tracing**: OpenTelemetry integration for request tracing
- **Alert Management**: Intelligent alerting with reduced false positives
- **SLA Monitoring**: Service level agreement tracking and reporting

### 🔧 Operations Excellence
- **GitOps Ready**: Native GitOps workflow integration
- **Multi-cluster**: Cross-cluster OpenFGA management
- **Disaster Recovery**: Automated backup and recovery procedures
- **Performance Optimization**: Intelligent resource allocation and scaling
- **Cost Management**: Resource optimization and cost tracking

## Roadmap and Releases

### Current Release (v1.0.0) - Security Foundation ✅
- Core operator functionality with security-first design
- Advanced admission controller framework
- Git commit verification and developer authentication
- Malicious code injection analysis
- Container image scanning and vulnerability assessment

### Next Release (v1.1.0) - Enhanced Protection 🚧
- AI-powered threat detection and behavioral analysis
- Advanced incident response automation
- Multi-tenancy support with enhanced isolation
- Enterprise SSO integration
- Advanced compliance reporting

### Future Releases 📋
- **v1.2.0**: Multi-cluster management and edge computing
- **v2.0.0**: Next-generation features

For detailed roadmap information, see [Product Roadmap](docs/roadmap/ROADMAP.md).

## Contributing

### Security-First Development
All contributions must follow our security guidelines:

1. **GPG Signed Commits**: All commits must be signed with GPG keys
2. **Security Review**: Security review required for all PRs
3. **Vulnerability Scanning**: Automated scanning of all dependencies
4. **Code Analysis**: Static analysis for security vulnerabilities

### Development Process
1. Fork the repository
2. Create a feature branch
3. Implement changes with security considerations
4. Run security checks: `make security-check`
5. Run tests: `make test`
6. Run all quality checks: `make check-all`
7. Submit a pull request with detailed security impact analysis

### Security Contributions
We especially welcome contributions in:
- Security architecture improvements
- Threat detection enhancements
- Compliance framework additions
- Documentation and security guides

For security vulnerabilities, please follow our [Security Policy](docs/security/SECURITY_POLICY.md) and contact security@openfga.dev.

## Support and Community

### 📞 Getting Help
- **Documentation**: [Complete documentation](docs/) available
- **Issues**: [GitHub Issues](https://github.com/jralmaraz/Openfga-operator/issues) for bug reports
- **Discussions**: [GitHub Discussions](https://github.com/jralmaraz/Openfga-operator/discussions) for questions
- **Security**: security@openfga.dev for security-related inquiries

### 🌟 Community
- **Star the Project**: Show your support on GitHub
- **Join Discussions**: Participate in community discussions
- **Contribute**: Help improve the project through contributions
- **Share**: Help others discover AuthCore and OpenFGA Operator

## License and Open Source

This project is licensed under the **Apache 2.0 License**, ensuring:
- **Open Source**: Fully open source with no vendor lock-in
- **Commercial Use**: Free for commercial and enterprise use
- **Community Driven**: Transparent development and governance
- **Extensible**: Permissive license for modifications and integrations

See [LICENSE](LICENSE) for complete details.

## Related Projects

- [OpenFGA](https://github.com/openfga/openfga) - Fine-Grained Authorization system
- [kube-rs](https://github.com/kube-rs/kube) - Kubernetes client library for Rust