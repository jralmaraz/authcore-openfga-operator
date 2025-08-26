# ArgoCD Flows for OpenFGA Management

This document explains the ArgoCD workflows and configurations for managing OpenFGA authorization models, stores, and platform deployments.

## Overview

The OpenFGA platform uses ArgoCD for GitOps-based deployment and management:

- **Declarative Configuration**: All OpenFGA resources defined as code
- **Multi-Environment Support**: Separate workflows for dev, staging, and production
- **Authorization Model Management**: Automated deployment of OpenFGA authorization models
- **Store Lifecycle Management**: Automated OpenFGA store provisioning and updates
- **Demo Application Orchestration**: Coordinated deployment of demo applications

## Architecture

### ArgoCD Project Structure

```
argocd/
├── projects/
│   ├── openfga-platform      # Core platform management
│   └── openfga-demos         # Demo applications
├── applications/
│   ├── openfga-stores        # Store management
│   ├── authorization-models  # Model management
│   ├── platform-config       # Platform configuration
│   └── demo-apps            # Demo applications
└── applicationsets/
    ├── environment-matrix    # Multi-environment deployments
    └── demo-matrix          # Demo environment matrix
```

### Repository Organization

```
github.com/jralmaraz/authcore-openfga-operator/
├── kustomize/base/           # Base platform configuration
├── kustomize/overlays/       # Environment-specific overlays
├── examples/stores/          # OpenFGA store definitions
├── examples/authorization-models/  # Authorization model templates
├── demos/*/k8s/             # Demo application manifests
└── docs/argocd/             # ArgoCD documentation
```

## Project Configuration

### OpenFGA Platform Project

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: openfga-platform
spec:
  description: "OpenFGA Platform Management Project"
  sourceRepos:
  - 'https://github.com/jralmaraz/authcore-openfga-operator'
  - 'https://charts.openfga.dev'
  destinations:
  - namespace: openfga-system
    server: 'https://kubernetes.default.svc'
  - namespace: openfga-workloads
    server: 'https://kubernetes.default.svc'
  roles:
  - name: admin
    policies:
    - p, proj:openfga-platform:admin, applications, *, openfga-platform/*, allow
    groups:
    - openfga-admins
  - name: developer
    policies:
    - p, proj:openfga-platform:developer, applications, get, openfga-platform/*, allow
    - p, proj:openfga-platform:developer, applications, sync, openfga-platform/*, allow
    groups:
    - openfga-developers
```

**Key Features:**
- Role-based access control for different user groups
- Multi-repository support for platform and charts
- Controlled access to specific namespaces
- Granular permissions for different operations

## Application Management

### OpenFGA Stores Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: openfga-stores
spec:
  project: openfga-platform
  source:
    repoURL: 'https://github.com/jralmaraz/authcore-openfga-operator'
    targetRevision: HEAD
    path: examples/stores
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: openfga-workloads
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

**Deployment Strategy:**
- Automated synchronization with self-healing
- Namespace creation if not exists
- Retry logic for resilient deployments
- Pruning of obsolete resources

### Authorization Models Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: openfga-authorization-models
spec:
  project: openfga-platform
  source:
    repoURL: 'https://github.com/jralmaraz/authcore-openfga-operator'
    path: examples/authorization-models
  syncPolicy:
    automated:
      prune: false  # Safety: don't auto-prune authorization models
      selfHeal: true
    syncOptions:
    - Replace=false
```

**Safety Features:**
- Manual pruning for authorization models (safety)
- Self-healing for configuration drift
- Replace=false to prevent accidental deletions
- Careful handling of security-critical resources

## Multi-Environment Management

### Environment ApplicationSet

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: openfga-environments
spec:
  generators:
  - list:
      elements:
      - env: dev
        cluster: https://kubernetes.default.svc
        namespace: openfga-dev
        branch: develop
        syncPolicy: automated
      - env: staging
        cluster: https://kubernetes.default.svc
        namespace: openfga-staging
        branch: main
        syncPolicy: manual
      - env: prod
        cluster: https://kubernetes.default.svc
        namespace: openfga-production
        branch: main
        syncPolicy: manual
  template:
    metadata:
      name: 'openfga-{{env}}'
    spec:
      project: openfga-platform
      source:
        repoURL: 'https://github.com/jralmaraz/authcore-openfga-operator'
        targetRevision: '{{branch}}'
        path: kustomize/overlays/{{env}}
      destination:
        server: '{{cluster}}'
        namespace: '{{namespace}}'
      syncPolicy:
        syncOptions:
        - CreateNamespace=true
```

**Environment Strategy:**
- **Development**: Automated sync from develop branch
- **Staging**: Manual sync from main branch for validation
- **Production**: Manual sync with strict change control

### Demo Applications Matrix

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: openfga-demo-environments
spec:
  generators:
  - matrix:
      generators:
      - list:
          elements:
          - demo: banking
            path: demos/banking-app/k8s
          - demo: genai
            path: demos/genai-rag-agent/k8s
      - list:
          elements:
          - env: dev
            replicas: "1"
          - env: staging
            replicas: "2"
  template:
    metadata:
      name: 'openfga-{{demo}}-{{env}}'
    spec:
      source:
        kustomize:
          patches:
          - target:
              kind: Deployment
            patch: |
              - op: replace
                path: /spec/replicas
                value: {{replicas}}
```

**Matrix Features:**
- Cross-product of demos and environments
- Dynamic replica scaling per environment
- Consistent labeling and naming conventions
- Automated deployment coordination

## Workflow Automation

### Backup and Restore Workflows

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: authorization-model-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: model-backup
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              TIMESTAMP=$(date +%Y%m%d_%H%M%S)
              BACKUP_DIR="/backup/authorization-models/$TIMESTAMP"
              mkdir -p $BACKUP_DIR
              
              # Export all OpenFGA resources
              kubectl get openfgas -A -o yaml > $BACKUP_DIR/openfga-instances.yaml
              kubectl get configmaps -l app.kubernetes.io/component=authorization-model -A -o yaml > $BACKUP_DIR/authorization-models.yaml
              
              # Compress and store
              cd /backup
              tar -czf "authorization-models-backup-$TIMESTAMP.tar.gz" authorization-models/$TIMESTAMP/
```

### Validation Workflows

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: authorization-model-validation
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: model-validator
            image: openfga/cli:latest
            command:
            - /bin/sh
            - -c
            - |
              # Validate all OpenFGA instances
              INSTANCES=$(kubectl get openfgas -A -o jsonpath='{.items[*].metadata.name}')
              
              for instance in $INSTANCES; do
                NAMESPACE=$(kubectl get openfgas -A -o jsonpath="{.items[?(@.metadata.name=='$instance')].metadata.namespace}")
                SERVICE_URL="http://$instance.$NAMESPACE.svc.cluster.local:8080"
                
                fga model validate --api-url=$SERVICE_URL || echo "Validation failed for $instance"
              done
```

## Health Monitoring

### Application Health Checks

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: demo-health-check
spec:
  schedule: "*/15 * * * *"  # Every 15 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: health-checker
            image: curlimages/curl:latest
            command:
            - /bin/sh
            - -c
            - |
              # Check banking demo
              BANKING_URL="http://banking-app.openfga-demos.svc.cluster.local:3000/health"
              if curl -f --max-time 10 $BANKING_URL; then
                echo "✓ Banking demo is healthy"
              else
                echo "✗ Banking demo is unhealthy"
              fi
              
              # Check GenAI demo
              GENAI_URL="http://genai-rag-agent.openfga-demos.svc.cluster.local:8000/health"
              if curl -f --max-time 10 $GENAI_URL; then
                echo "✓ GenAI demo is healthy"
              else
                echo "✗ GenAI demo is unhealthy"
              fi
```

### Sync Status Monitoring

Monitor ArgoCD application sync status:

```bash
# Check application status
argocd app list

# Get detailed sync status
argocd app get openfga-stores

# Monitor sync health
argocd app wait openfga-stores --health
```

## Security and Compliance

### Change Control Process

1. **Development Changes**:
   - Push to feature branches
   - Automatic sync to development environment
   - Automated testing and validation

2. **Staging Validation**:
   - Merge to main branch
   - Manual sync to staging environment
   - User acceptance testing
   - Security validation

3. **Production Deployment**:
   - Manual sync to production
   - Change control approval
   - Rollback plan validation
   - Post-deployment verification

### RBAC Integration

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-openfga-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- kind: User
  name: argocd-server
  apiGroup: rbac.authorization.k8s.io
```

### Secret Management Integration

ArgoCD integrates with the DSV secrets management:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-options: "SkipDryRunOnMissingResource=true"
    dsv.delinea.com/inject: "true"
    dsv.delinea.com/path: "/argocd/credentials"
```

## Troubleshooting

### Common Issues

1. **Sync Failures**:
   ```bash
   # Check application logs
   argocd app logs openfga-stores
   
   # Review sync operation
   argocd app sync openfga-stores --dry-run
   
   # Check resource status
   kubectl get events -n openfga-workloads
   ```

2. **Authorization Issues**:
   ```bash
   # Check project permissions
   argocd proj get openfga-platform
   
   # Verify RBAC
   kubectl auth can-i create applications --as=argocd-server
   ```

3. **Repository Access**:
   ```bash
   # Test repository connectivity
   argocd repo get https://github.com/jralmaraz/authcore-openfga-operator
   
   # Update repository credentials
   argocd repo add https://github.com/jralmaraz/authcore-openfga-operator
   ```

### Debugging ApplicationSets

```bash
# Check ApplicationSet status
kubectl get applicationset openfga-environments

# Review generated applications
kubectl get applications -l app.kubernetes.io/instance=openfga-environments

# Debug generator logic
argocd appset generate openfga-environments
```

## Best Practices

### Git Repository Management

1. **Branch Strategy**:
   - Feature branches for development
   - Main branch for staging/production
   - Protected branches with required reviews

2. **Commit Standards**:
   - Descriptive commit messages
   - Atomic commits for logical changes
   - Signed commits for security

3. **Directory Structure**:
   - Logical organization by component
   - Environment-specific overlays
   - Clear separation of concerns

### Application Design

1. **Resource Organization**:
   - Group related resources in applications
   - Use ApplicationSets for similar patterns
   - Implement proper dependency management

2. **Sync Policies**:
   - Automated sync for development
   - Manual sync for production
   - Appropriate retry and backoff strategies

3. **Health Checks**:
   - Define meaningful health checks
   - Monitor application and sync status
   - Implement automated remediation where safe

### Security Considerations

1. **Access Control**:
   - Implement least-privilege RBAC
   - Use project-based isolation
   - Regular access review and auditing

2. **Secret Management**:
   - Never store secrets in Git
   - Use external secret management (DSV)
   - Rotate credentials regularly

3. **Change Management**:
   - Implement proper change control
   - Require approvals for production changes
   - Maintain audit trails for all changes

This comprehensive ArgoCD setup ensures reliable, secure, and automated management of the OpenFGA platform while maintaining proper governance and operational excellence.