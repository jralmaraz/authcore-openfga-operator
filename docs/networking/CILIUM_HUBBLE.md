# Cilium Network Policies and Hubble Observability

This document explains the Cilium-based network security and observability features implemented for the OpenFGA platform.

## Overview

The OpenFGA platform leverages Cilium for advanced network security and observability:

- **Layer 3/4 and Layer 7 Network Policies**: Fine-grained traffic control
- **Hubble Network Observability**: Real-time network flow visualization
- **Security Monitoring**: Automated detection of policy violations
- **Flow Analysis**: Deep packet inspection and analysis
- **Service Mesh Integration**: Advanced traffic management capabilities

## Architecture

### Cilium Components

1. **Cilium Agent**: Provides networking and security enforcement
2. **Hubble Relay**: Centralized observability data collection
3. **Hubble UI**: Web-based network flow visualization
4. **Flow Processor**: Custom flow analysis and alerting

### Network Segmentation

The platform implements microsegmentation with the following zones:

- **openfga-system**: Core platform components
- **openfga-workloads**: OpenFGA instances and related services
- **openfga-demos**: Demo applications
- **External Services**: Database and secrets management

## Network Policies

### Layer 3/4 Policies

#### OpenFGA Operator Protection

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: openfga-operator-policy
spec:
  endpointSelector:
    matchLabels:
      app: openfga-operator
  ingress:
  - fromEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: kube-system
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      - port: "8443"
        protocol: TCP
```

**Key Features:**
- Restricts operator access to Kubernetes API and authorized clients
- Allows webhook traffic from admission controllers
- Permits database connectivity for OpenFGA instances

#### Database Security

```yaml
egress:
- toEndpoints:
  - matchLabels:
      app.kubernetes.io/name: postgresql
  toPorts:
  - ports:
    - port: "5432"
      protocol: TCP
```

**Security Benefits:**
- Only authorized pods can connect to databases
- Connection attempts are logged and monitored
- Prevents lateral movement in case of compromise

### Layer 7 Policies

#### HTTP/gRPC Traffic Control

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: openfga-http-policy
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: openfga
  ingress:
  - fromEndpoints:
    - matchLabels:
        app.kubernetes.io/component: application
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/healthz"
        - method: "POST"
          path: "/stores/.*/check"
        - method: "POST"
          path: "/stores/.*/expand"
```

**Advanced Features:**
- Method and path-based access control
- API endpoint protection
- Request rate limiting and throttling

## Hubble Observability

### Flow Monitoring

Hubble provides comprehensive network flow observability:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hubble-tracing-config
data:
  config.yaml: |
    tracing:
      enabled: true
      filters:
        - name: "openfga-http"
          sourceLabels:
            app.kubernetes.io/name: "openfga"
          protocols:
            - "http"
        - name: "database-connections"
          sourceLabels:
            app.kubernetes.io/component: "database"
          protocols:
            - "tcp"
```

### Real-time Monitoring

Access live network flows:

```bash
# Monitor all OpenFGA traffic
hubble observe --from-label app.kubernetes.io/name=openfga

# Monitor database connections
hubble observe --to-port 5432,3306

# Monitor policy violations
hubble observe --verdict DENIED
```

### Flow Analysis

The platform includes custom flow analysis:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hubble-flow-processor
spec:
  template:
    spec:
      containers:
      - name: flow-processor
        image: quay.io/cilium/hubble:v0.12.2
        command:
        - hubble
        - observe
        - --follow
        - --output
        - json
```

**Capabilities:**
- Real-time flow analysis and correlation
- Anomaly detection using machine learning
- Integration with SIEM systems
- Custom alerting based on flow patterns

## Security Monitoring

### Policy Violation Detection

Automated monitoring for security violations:

```yaml
monitoring:
  networkPolicies:
    - name: "policy-violations"
      conditions:
        - field: "verdict"
          operator: "equals"
          value: "DENIED"
      actions:
        - type: "alert"
          severity: "warning"
          webhook: "http://alertmanager:9093/api/v1/alerts"
```

### Database Access Monitoring

Specialized monitoring for database access:

```yaml
- name: "unauthorized-database-access"
  conditions:
    - field: "destination_port"
      operator: "in"
      values: ["5432", "3306"]
    - field: "verdict"
      operator: "equals"
      value: "DENIED"
  actions:
    - type: "alert"
      severity: "critical"
```

### Secrets Access Monitoring

Monitor DSV secrets access patterns:

```yaml
- name: "secrets-access-monitoring"
  conditions:
    - field: "source_labels.app.kubernetes.io/name"
      operator: "equals"
      value: "dsv-injector"
    - field: "destination_port"
      operator: "equals"
      value: "443"
  actions:
    - type: "metric"
      name: "dsv_access_total"
```

## Grafana Dashboards

### Network Security Dashboard

Pre-configured dashboards for security monitoring:

1. **Traffic Overview**: High-level network traffic patterns
2. **Policy Violations**: Security policy violations and trends
3. **Database Connectivity**: Database connection monitoring
4. **Secrets Management**: DSV access patterns and security

### Custom Metrics

```prometheus
# Network policy violations
cilium_policy_verdict_total{verdict="DENIED"}

# Database connection attempts
cilium_flows_total{destination_port=~"5432|3306"}

# HTTP API calls
cilium_http_requests_total{method="POST",path=~"/stores/.*/check"}
```

## Service Mesh Integration

### Traffic Management

Cilium provides service mesh capabilities:

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumEnvoyConfig
metadata:
  name: openfga-load-balancing
spec:
  services:
  - name: openfga-banking
    namespace: openfga-workloads
  resources:
  - "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
    name: openfga-banking
    load_assignment:
      cluster_name: openfga-banking
      policy:
        weighted_lb_config:
          locality_weighted_lb_config: {}
```

### Advanced Routing

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: openfga-canary-routing
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: openfga
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: demo-app
    toPorts:
    - ports:
      - port: "8080"
      rules:
        http:
        - headerMatches:
          - name: "x-canary"
            value: "true"
          path: "/stores/.*/check"
```

## Troubleshooting

### Network Connectivity Issues

1. **Check Policy Status**:
   ```bash
   kubectl get cnp -A
   kubectl describe cnp openfga-operator-policy -n openfga-system
   ```

2. **Monitor Live Traffic**:
   ```bash
   hubble observe --namespace openfga-system
   hubble observe --verdict DENIED
   ```

3. **Validate Endpoint Selection**:
   ```bash
   cilium endpoint list
   cilium policy get <endpoint-id>
   ```

### Performance Debugging

1. **Flow Metrics**:
   ```bash
   hubble metrics list
   hubble metrics flows --namespace openfga-system
   ```

2. **Policy Enforcement**:
   ```bash
   cilium policy trace <src-endpoint> <dst-endpoint>
   ```

### Common Issues

#### Policy Not Applied

```bash
# Check Cilium agent status
kubectl get pods -n kube-system -l k8s-app=cilium

# Verify policy compilation
cilium policy validate /path/to/policy.yaml

# Check endpoint labels
kubectl get pods --show-labels -n openfga-system
```

#### Hubble Not Collecting Flows

```bash
# Check Hubble relay status
kubectl get pods -n kube-system -l k8s-app=hubble-relay

# Verify flow collection
hubble status
hubble observe --follow
```

## Best Practices

### Policy Design

1. **Default Deny**: Implement default deny policies as baseline security
2. **Least Privilege**: Grant minimal necessary network access
3. **Label Consistency**: Use consistent labeling for policy selectors
4. **Testing**: Validate policies in non-production environments first

### Monitoring Strategy

1. **Baseline Establishment**: Establish normal traffic patterns
2. **Anomaly Detection**: Implement automated anomaly detection
3. **Alert Tuning**: Fine-tune alerts to reduce false positives
4. **Regular Review**: Periodically review and update policies

### Performance Optimization

1. **Policy Efficiency**: Design efficient policy rules
2. **Flow Storage**: Configure appropriate flow retention
3. **Resource Allocation**: Allocate sufficient resources for Cilium components
4. **Metrics Collection**: Optimize metrics collection for performance

## Integration with Other Components

### ArgoCD Integration

Network policies are managed through ArgoCD:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cilium-network-policies
spec:
  source:
    path: kustomize/base/network-policies
  syncPolicy:
    automated:
      prune: false  # Safety: don't auto-delete security policies
```

### Secrets Management Integration

Cilium policies protect DSV injector communication:

```yaml
egress:
- toFQDNs:
  - matchName: "vault.company.com"
  toPorts:
  - ports:
    - port: "443"
      protocol: TCP
```

### Storage Integration

Database connectivity is secured through network policies:

```yaml
egress:
- toEndpoints:
  - matchLabels:
      app.kubernetes.io/name: postgresql
      k8s:io.kubernetes.pod.namespace: openfga-system
  toPorts:
  - ports:
    - port: "5432"
      protocol: TCP
```

This comprehensive network security and observability framework ensures that the OpenFGA platform operates with defense-in-depth security while maintaining complete visibility into network traffic patterns and security events.