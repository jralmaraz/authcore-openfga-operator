# Enterprise OpenFGA Operator Deployment

This directory contains enterprise-ready Kubernetes deployment configurations for the OpenFGA Operator using Kustomize. The deployment includes all supporting services and enterprise-grade security features.

## Architecture Overview

The enterprise deployment consists of the following components:

### Core Components
- **OpenFGA Operator**: Manages OpenFGA instances with enterprise security
- **Custom Resource Definitions (CRDs)**: Kubernetes-native OpenFGA resource definitions
- **Admission Controllers**: Validates and mutates resources for security compliance

### Identity and Access Management
- **Keycloak**: Enterprise identity provider with SAML, OIDC, and Active Directory integration
- **Authentication**: Comprehensive SSO integration for OpenFGA instances
- **Authorization**: Role-based access control and fine-grained permissions

### Storage
- **Portworx**: Enterprise-grade persistent storage with high availability
- **Storage Classes**: Optimized storage classes for different workload types
- **Backup Policies**: Automated backup and disaster recovery

### Network Observability
- **Cilium Hubble**: Advanced network observability and monitoring
- **Hubble UI**: Web interface for network flow visualization
- **Hubble Relay**: Centralized access to network observability data

### Security
- **Network Policies**: Comprehensive network segmentation and security
- **Admission Controllers**: Validation and mutation of Kubernetes resources
- **Security Policies**: Enforcement of security best practices

## Directory Structure

```
kustomize/
├── base/                          # Base configurations
│   ├── admission-controller/      # Admission controller configurations
│   ├── crds/                     # Custom Resource Definitions
│   ├── keycloak/                 # Keycloak identity provider
│   ├── network-observability/    # Cilium Hubble configuration
│   ├── network-policies/         # Network security policies
│   ├── operator/                 # OpenFGA operator deployment
│   ├── storage/                  # Portworx storage configuration
│   ├── namespace.yaml            # Namespace definitions
│   └── kustomization.yaml        # Base kustomization
└── overlays/                     # Environment-specific configurations
    ├── dev/                      # Development environment
    ├── staging/                  # Staging environment
    └── prod/                     # Production environment
```

## Quick Start

### Prerequisites

1. **Kubernetes Cluster**: Version 1.25+
2. **Kustomize**: Version 4.5+
3. **kubectl**: Configured for your cluster
4. **Cert-Manager**: For TLS certificate management
5. **Portworx**: For persistent storage (or alternative storage solution)
6. **Cilium**: For network observability (optional)

### Deployment

#### Development Environment

```bash
# Deploy to development environment
kubectl apply -k kustomize/overlays/dev/

# Verify deployment
kubectl get pods -n openfga-system
kubectl get openfgas -A
```

#### Production Environment

```bash
# Deploy to production environment
kubectl apply -k kustomize/overlays/prod/

# Verify deployment
kubectl get pods -n openfga-system
kubectl get openfgas -A
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RUST_LOG` | Logging level | `info` |
| `OPERATOR_NAMESPACE` | Operator namespace | `openfga-system` |
| `ENABLE_ADMISSION_CONTROLLER` | Enable admission validation | `true` |
| `ENABLE_NETWORK_POLICIES` | Enable network policies | `true` |

### Storage Configuration

The deployment uses Portworx storage classes:

- `portworx-sc-db`: High-performance database storage (3 replicas)
- `portworx-sc-replicated`: General purpose replicated storage (2 replicas)
- `portworx-sc-single`: Single replica storage for development

### Network Policies

Comprehensive network policies are implemented:

- **Default Deny**: All traffic denied by default
- **Operator Policies**: Allow operator communication
- **Keycloak Policies**: Secure identity provider access
- **Storage Policies**: Portworx communication rules
- **Monitoring Policies**: Observability tool access

## Security Features

### Admission Controllers

The deployment includes validating and mutating admission controllers:

#### Validating Webhooks
- **Security Validation**: Enforces security policies on OpenFGA resources
- **Policy Validation**: Validates network policies and security configurations
- **Image Validation**: Ensures only approved container images are used

#### Mutating Webhooks
- **Security Defaults**: Applies secure defaults to deployments
- **Resource Defaults**: Sets resource limits and requests
- **Label Injection**: Adds required labels for monitoring and security

### Security Policies

- **Non-root containers**: All containers run as non-root users
- **Read-only root filesystem**: Containers use read-only root filesystems
- **Capability dropping**: All unnecessary capabilities are dropped
- **Security contexts**: Comprehensive security context enforcement

## Monitoring and Observability

### Metrics Collection

The deployment integrates with Prometheus for metrics collection:

- **Operator Metrics**: Controller performance and health
- **Security Metrics**: Admission controller and policy violations
- **Network Metrics**: Hubble network flow metrics

### Network Observability

Cilium Hubble provides:

- **Flow Visualization**: Real-time network flow monitoring
- **Security Insights**: Network policy enforcement visibility
- **Performance Metrics**: Network latency and throughput monitoring

## High Availability

### Operator HA

- **Multiple Replicas**: 3 replicas in production
- **Leader Election**: Automatic failover between instances
- **Anti-Affinity**: Pods distributed across nodes

### Storage HA

- **Portworx Replication**: 3-way replication for critical data
- **Automated Backups**: Daily snapshots with retention policies
- **Disaster Recovery**: Cross-cluster replication support

### Identity Provider HA

- **Keycloak Clustering**: Multi-instance deployment
- **Database HA**: Replicated PostgreSQL backend
- **Session Replication**: Shared session state

## Customization

### Environment Overlays

Each environment overlay can customize:

- **Resource Limits**: CPU and memory allocations
- **Replica Counts**: Number of instances per component
- **Storage Sizes**: Persistent volume sizes
- **Security Policies**: Environment-specific security rules

### Custom Patches

Add custom patches to overlays:

```yaml
# kustomize/overlays/custom/kustomization.yaml
patchesStrategicMerge:
  - patches/custom-config.yaml

patchesJson6902:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: openfga-operator
    path: patches/custom-resources.yaml
```

## Troubleshooting

### Common Issues

1. **Storage Class Not Found**
   ```bash
   kubectl get storageclass
   kubectl describe pvc -n openfga-system
   ```

2. **Admission Controller Failures**
   ```bash
   kubectl logs -n openfga-system deployment/openfga-operator
   kubectl get validatingadmissionwebhooks
   ```

3. **Network Policy Blocking Traffic**
   ```bash
   kubectl describe networkpolicy -n openfga-system
   kubectl logs -n kube-system -l k8s-app=cilium
   ```

### Debugging Commands

```bash
# Check operator status
kubectl get pods -n openfga-system -l app.kubernetes.io/name=openfga-operator

# View operator logs
kubectl logs -n openfga-system -l app.kubernetes.io/name=openfga-operator -f

# Check OpenFGA instances
kubectl get openfgas -A

# Validate network connectivity
kubectl exec -n openfga-system deployment/openfga-operator -- nc -zv keycloak 8080
```

## Maintenance

### Updates

1. **Operator Updates**
   ```bash
   # Update image tag in overlay
   kustomize edit set image openfga-operator:v1.1.0
   kubectl apply -k kustomize/overlays/prod/
   ```

2. **Keycloak Updates**
   ```bash
   # Update Keycloak image
   kubectl patch deployment keycloak -n openfga-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"keycloak","image":"quay.io/keycloak/keycloak:24.0"}]}}}}'
   ```

### Backup and Recovery

1. **Portworx Snapshots**
   ```bash
   # Create manual snapshot
   kubectl create -f - <<EOF
   apiVersion: volumesnapshot.external-storage.k8s.io/v1
   kind: VolumeSnapshot
   metadata:
     name: openfga-backup-$(date +%Y%m%d)
     namespace: openfga-system
   spec:
     persistentVolumeClaimName: keycloak-data
   EOF
   ```

2. **Configuration Backup**
   ```bash
   # Backup all configurations
   kubectl get all,secrets,configmaps,pvc -n openfga-system -o yaml > openfga-backup.yaml
   ```

## Support

For issues and questions:

1. **GitHub Issues**: [Repository Issues](https://github.com/jralmaraz/authcore-openfga-operator/issues)
2. **Documentation**: [Project Documentation](../README.md)
3. **Security Issues**: [Security Policy](../SECURITY.md)

## License

This deployment configuration is licensed under the Apache 2.0 License. See the [LICENSE](../LICENSE) file for details.