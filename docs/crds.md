# OpenFGA Operator CRDs Documentation

This document provides comprehensive documentation for the Custom Resource Definitions (CRDs) provided by the OpenFGA Operator.

## Overview

The OpenFGA Operator provides three main CRDs:

- **OpenFGAServer**: Manages OpenFGA server instances
- **OpenFGAStore**: Manages OpenFGA stores (authorization tenants)
- **AuthorizationModel**: Manages OpenFGA authorization models

## OpenFGAServer CRD

### Purpose
The OpenFGAServer CRD manages the lifecycle of OpenFGA server instances, including deployment, configuration, scaling, and monitoring.

### API Version
`openfga.io/v1alpha1`

### Key Features
- Multi-replica deployment support
- Database configuration (PostgreSQL, MySQL, SQLite)
- HTTP and gRPC server configuration
- OpenTelemetry integration for observability
- Cilium network policy support
- Resource management and scheduling
- TLS/SSL configuration
- Security contexts and RBAC

### Spec Fields

#### Required Fields
- `image`: Container image for the OpenFGA server
- `database`: Database configuration object

#### Optional Fields
- `replicas`: Number of server instances (default: 1, max: 10)
- `port`: HTTP port (default: 8080)
- `grpcPort`: gRPC port (default: 8081)
- `config`: Server configuration object
- `resources`: Kubernetes resource requirements
- `openTelemetry`: OpenTelemetry configuration
- `networkPolicy`: Network policy configuration
- `securityContext`: Pod security context
- `serviceAccountName`: Service account name
- `nodeSelector`: Node selection constraints
- `tolerations`: Pod tolerations
- `affinity`: Pod affinity rules

#### Database Configuration
```yaml
database:
  type: postgres|mysql|sqlite  # Required
  host: string                 # Database host
  port: int32                 # Database port (1-65535)
  database: string            # Database name
  username: string            # Username
  passwordSecret:             # Secret reference for password
    name: string
    key: string
  sslMode: disable|require|verify-ca|verify-full
  maxOpenConns: int32         # Max open connections
  maxIdleConns: int32         # Max idle connections
```

#### OpenTelemetry Configuration
```yaml
openTelemetry:
  enabled: bool               # Default: true
  serviceName: string         # Service name for traces
  endpoint: string            # Collector endpoint
  samplingRate: float64       # 0.0-1.0
  headers:                    # Additional headers
    key: value
```

#### Network Policy Configuration
```yaml
networkPolicy:
  enabled: bool               # Default: false
  allowedIngress:             # Ingress rules
    - from:
        - podSelector: {}
        - namespaceSelector: {}
        - ipBlock:
            cidr: string
            except: [string]
      ports:
        - port: int32
          protocol: TCP|UDP|SCTP
  allowedEgress: []           # Egress rules (same structure)
  ciliumLabels:               # Cilium-specific labels
    key: value
```

### Status Fields
- `conditions`: Standard Kubernetes conditions
- `phase`: Current phase (Pending|Running|Failed|Unknown)
- `readyReplicas`: Number of ready replicas
- `replicas`: Total number of replicas
- `observedGeneration`: Last observed generation
- `serviceURL`: HTTP service URL
- `grpcServiceURL`: gRPC service URL
- `lastReconcileTime`: Last reconciliation time

### Examples

#### Basic OpenFGAServer
```yaml
apiVersion: openfga.io/v1alpha1
kind: OpenFGAServer
metadata:
  name: basic-server
spec:
  image: openfga/openfga:latest
  database:
    type: postgres
    host: postgres-service
    port: 5432
    database: openfga
    username: openfga
    passwordSecret:
      name: postgres-secret
      key: password
```

#### Production OpenFGAServer with Full Configuration
```yaml
apiVersion: openfga.io/v1alpha1
kind: OpenFGAServer
metadata:
  name: production-server
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
  
  config:
    logLevel: info
    logFormat: json
    maxTuplesPerWrite: 100
    playgroundEnabled: false
    
    httpConfig:
      readTimeout: 30s
      writeTimeout: 30s
      corsAllowedOrigins:
        - "https://app.example.com"
    
    grpcConfig:
      enabled: true
      tlsConfig:
        enabled: true
        certSecret:
          name: tls-cert
          key: tls.crt
        keySecret:
          name: tls-cert
          key: tls.key
  
  openTelemetry:
    enabled: true
    serviceName: openfga-prod
    endpoint: http://otel-collector:4317
    samplingRate: 0.1
  
  networkPolicy:
    enabled: true
    allowedIngress:
      - from:
          - namespaceSelector:
              matchLabels:
                name: application
        ports:
          - port: 8080
  
  resources:
    requests:
      memory: "512Mi"
      cpu: "200m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
  
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app.kubernetes.io/name: openfgaserver
            topologyKey: kubernetes.io/hostname
```

## OpenFGAStore CRD

### Purpose
The OpenFGAStore CRD manages OpenFGA stores, which are isolated authorization tenants within an OpenFGA server.

### API Version
`openfga.io/v1alpha1`

### Key Features
- Store lifecycle management
- Data retention policies
- Automated backup with encryption
- Access control and RBAC
- Metrics collection
- Custom labeling and annotations

### Spec Fields

#### Required Fields
- `serverRef`: Reference to OpenFGAServer

#### Optional Fields
- `displayName`: Human-readable store name
- `description`: Store description
- `retentionPolicy`: Data retention configuration
- `accessControl`: Access control settings
- `backup`: Backup configuration
- `metrics`: Metrics collection settings
- `openTelemetry`: OpenTelemetry configuration
- `labels`: Custom labels
- `annotations`: Custom annotations

#### Server Reference
```yaml
serverRef:
  name: string                # Required: OpenFGAServer name
  namespace: string           # Server namespace
  endpoint: string            # Direct endpoint (alternative)
```

#### Retention Policy
```yaml
retentionPolicy:
  enabled: bool               # Default: false
  tupleRetentionDays: int32   # 1-3650 days
  modelRetentionDays: int32   # 1-3650 days
  logRetentionDays: int32     # 1-3650 days
  autoCleanup: bool           # Default: true
```

#### Access Control
```yaml
accessControl:
  enabled: bool               # Default: true
  allowedServiceAccounts: [string]
  allowedUsers: [string]
  allowedGroups: [string]
  rbacRules:
    - subjects:
        - kind: User|Group|ServiceAccount
          name: string
          namespace: string   # For ServiceAccount
      permissions: [string]   # Required
      resources: [string]
      conditions:
        key: value
```

#### Backup Configuration
```yaml
backup:
  enabled: bool               # Default: false
  schedule: string            # Cron format
  retentionCount: int32       # 1-100
  storageClass: string
  storageSize: string
  compression: bool           # Default: true
  encryption:
    enabled: bool             # Default: false
    algorithm: AES256|AES128|ChaCha20Poly1305
    keySecret:
      name: string
      key: string
```

#### Metrics Configuration
```yaml
metrics:
  enabled: bool               # Default: true
  interval: string            # Default: "30s"
  customMetrics:
    - name: string            # Required
      type: counter|gauge|histogram  # Required
      description: string
      labels:
        key: value
  prometheusConfig:
    serviceMonitor: bool      # Default: true
    serviceMonitorNamespace: string
    serviceMonitorLabels:
      key: value
    additionalLabels:
      key: value
```

### Status Fields
- `conditions`: Standard Kubernetes conditions
- `phase`: Current phase (Pending|Ready|Failed|Unknown)
- `storeID`: OpenFGA store ID
- `observedGeneration`: Last observed generation
- `lastReconcileTime`: Last reconciliation time
- `createdAt`: Store creation timestamp
- `tupleCount`: Approximate tuple count
- `modelCount`: Number of models
- `lastBackup`: Last successful backup timestamp
- `backupStatus`: Backup status information
- `metricsEndpoint`: Metrics endpoint URL

### Examples

#### Basic Store
```yaml
apiVersion: openfga.io/v1alpha1
kind: OpenFGAStore
metadata:
  name: my-app-store
spec:
  serverRef:
    name: openfga-server
  displayName: "My Application Store"
```

#### Production Store with Full Configuration
```yaml
apiVersion: openfga.io/v1alpha1
kind: OpenFGAStore
metadata:
  name: production-store
spec:
  serverRef:
    name: production-server
    namespace: openfga-system
  
  displayName: "Production Authorization Store"
  description: "Main store for production workloads"
  
  retentionPolicy:
    enabled: true
    tupleRetentionDays: 90
    modelRetentionDays: 365
    logRetentionDays: 30
  
  accessControl:
    enabled: true
    allowedServiceAccounts:
      - "api-service"
      - "worker-service"
    rbacRules:
      - subjects:
          - kind: ServiceAccount
            name: "api-service"
            namespace: "production"
        permissions: ["read", "write"]
        resources: ["tuples"]
  
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retentionCount: 30
    compression: true
    encryption:
      enabled: true
      algorithm: "AES256"
      keySecret:
        name: "backup-key"
        key: "key"
  
  metrics:
    enabled: true
    customMetrics:
      - name: "app_auth_requests_total"
        type: "counter"
        description: "Total authorization requests"
  
  labels:
    environment: "production"
    team: "platform"
```

## AuthorizationModel CRD

### Purpose
The AuthorizationModel CRD manages OpenFGA authorization models, defining the types and relationships used for authorization decisions.

### API Version
`openfga.io/v1alpha1`

### Key Features
- Complete OpenFGA 1.1 schema support
- Type definitions with relations
- Union, intersection, and difference operations
- Tuple-to-userset relationships
- Computed usersets
- Model validation

### Spec Fields

#### Required Fields
- `storeRef`: Reference to OpenFGAStore
- `schema`: Authorization model schema

#### Optional Fields
- `schemaVersion`: Schema version (default: "1.1")
- `conditions`: Additional conditions
- `openTelemetry`: OpenTelemetry configuration

#### Store Reference
```yaml
storeRef:
  name: string                # Store name
  namespace: string           # Store namespace
  storeID: string             # Direct store ID (alternative)
  serverRef:                  # Server reference
    name: string              # Required
    namespace: string
    endpoint: string          # Alternative
```

#### Schema Definition
```yaml
schema:
  type_definitions:           # Required, min 1 item
    - type: string            # Required, pattern: ^[a-zA-Z][a-zA-Z0-9_]*$
      relations:              # Map of relation definitions
        relation_name:
          this: {}            # Direct relation
          union:              # Union of relations
            children: []      # Min 2 items
          intersection:       # Intersection of relations
            children: []      # Min 2 items
          difference:         # Difference between relations
            base: {}
            subtract: {}
          tupleToUserset:     # Tuple-to-userset
            tupleSet:
              relation: string
            computedUserset:
              object: string
              relation: string
          computedUserset:    # Computed userset
            object: string
            relation: string
      metadata:               # Optional metadata
        key: value
```

#### Relation Types

1. **Direct Relation (this)**
   ```yaml
   viewer:
     this: {}
   ```

2. **Union**
   ```yaml
   reader:
     union:
       children:
         - this: {}
         - computedUserset:
             relation: "editor"
   ```

3. **Intersection**
   ```yaml
   admin_viewer:
     intersection:
       children:
         - computedUserset:
             relation: "admin"
         - computedUserset:
             relation: "viewer"
   ```

4. **Difference**
   ```yaml
   member_not_banned:
     difference:
       base:
         computedUserset:
           relation: "member"
       subtract:
         computedUserset:
           relation: "banned"
   ```

5. **Tuple-to-Userset**
   ```yaml
   org_viewer:
     tupleToUserset:
       tupleSet:
         relation: "parent"
       computedUserset:
         relation: "viewer"
   ```

6. **Computed Userset**
   ```yaml
   can_read:
     computedUserset:
       relation: "viewer"
   ```

### Status Fields
- `conditions`: Standard Kubernetes conditions
- `phase`: Current phase (Pending|Ready|Failed|Unknown)
- `modelID`: OpenFGA model ID
- `storeID`: Associated store ID
- `observedGeneration`: Last observed generation
- `lastReconcileTime`: Last reconciliation time
- `validationErrors`: Model validation errors
- `appliedAt`: Model application timestamp

### Examples

#### Simple Document Model
```yaml
apiVersion: openfga.io/v1alpha1
kind: AuthorizationModel
metadata:
  name: simple-docs
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
                    relation: "owner"
          can_read:
            computedUserset:
              relation: "viewer"
          can_write:
            computedUserset:
              relation: "owner"
```

#### Complex Organization Model
```yaml
apiVersion: openfga.io/v1alpha1
kind: AuthorizationModel
metadata:
  name: organization-model
spec:
  storeRef:
    name: org-store
  
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
          owner:
            this: {}
      
      - type: "team"
        relations:
          member:
            this: {}
          lead:
            this: {}
          parent_org:
            this: {}
          # Members of parent org are also team members
          org_member:
            tupleToUserset:
              tupleSet:
                relation: "parent_org"
              computedUserset:
                relation: "member"
      
      - type: "repository"
        relations:
          owner:
            this: {}
          maintainer:
            this: {}
          reader:
            union:
              children:
                - this: {}
                - computedUserset:
                    relation: "maintainer"
                - computedUserset:
                    relation: "owner"
          # Repository readers can also be inherited from team
          team:
            this: {}
          team_reader:
            tupleToUserset:
              tupleSet:
                relation: "team"
              computedUserset:
                relation: "member"
          # Final reader permission includes direct and inherited
          can_read:
            union:
              children:
                - computedUserset:
                    relation: "reader"
                - computedUserset:
                    relation: "team_reader"
          can_write:
            union:
              children:
                - computedUserset:
                    relation: "maintainer"
                - computedUserset:
                    relation: "owner"
          can_admin:
            computedUserset:
              relation: "owner"
  
  conditions:
    ip_allowlist: "request.source_ip in organization.allowed_ips"
    business_hours: "request.time >= 09:00 && request.time <= 17:00"
```

## Validation Rules

### OpenFGAServer Validation
- `image` must match pattern: `^[a-zA-Z0-9][a-zA-Z0-9._/-]*:[a-zA-Z0-9._-]+$`
- `replicas` must be between 1 and 10
- `port` and `grpcPort` must be between 1 and 65535
- Database `type` must be one of: postgres, mysql, sqlite
- OpenTelemetry `samplingRate` must be between 0.0 and 1.0

### OpenFGAStore Validation
- `retentionPolicy` days must be between 1 and 3650
- `backup.retentionCount` must be between 1 and 100
- `backup.schedule` must be valid cron format
- RBAC `subjects` must have at least 1 item
- RBAC `permissions` must have at least 1 item

### AuthorizationModel Validation
- `type` must match pattern: `^[a-zA-Z][a-zA-Z0-9_]*$`
- `schemaVersion` must match pattern: `^1\.1$`
- `type_definitions` must have at least 1 item
- Union and intersection `children` must have at least 2 items
- Required fields must be present in complex relation types

## Best Practices

### OpenFGAServer
1. Always use specific image tags in production
2. Configure appropriate resource limits
3. Enable TLS for production deployments
4. Use pod anti-affinity for high availability
5. Configure proper network policies
6. Enable OpenTelemetry for observability

### OpenFGAStore
1. Enable backups for production stores
2. Configure appropriate retention policies
3. Use RBAC for access control
4. Monitor metrics and set up alerts
5. Use meaningful display names and descriptions
6. Label resources appropriately for organization

### AuthorizationModel
1. Start with simple models and iterate
2. Use descriptive type and relation names
3. Document complex relationships
4. Test models thoroughly before deployment
5. Version models appropriately
6. Use conditions for additional security

## Troubleshooting

### Common Issues

1. **Server not starting**
   - Check database connectivity
   - Verify database credentials in secret
   - Check resource limits and node capacity

2. **Store creation failing**
   - Verify server reference is correct
   - Check server is in Ready phase
   - Validate RBAC permissions

3. **Model validation errors**
   - Check schema syntax
   - Verify type names follow naming rules
   - Ensure required relations exist

4. **Network connectivity issues**
   - Verify network policies
   - Check service mesh configuration
   - Validate DNS resolution

### Debugging Commands

```bash
# Check CRD status
kubectl get openfgaserver,openfgastore,authorizationmodel

# Describe resources for detailed status
kubectl describe openfgaserver my-server

# Check operator logs
kubectl logs -n openfga-operator-system deployment/openfga-operator-controller-manager

# Validate CRD definitions
kubectl get crd openfgaservers.openfga.io -o yaml

# Check events
kubectl get events --sort-by='.lastTimestamp'
```