# Persistent Storage Configuration

This document explains the persistent storage configurations available for the OpenFGA platform, including support for both Portworx and Longhorn storage providers.

## Overview

The OpenFGA platform supports multiple persistent storage backends to ensure data durability and high availability:

- **Portworx**: Enterprise-grade storage with built-in high availability, snapshots, and disaster recovery
- **Longhorn**: Cloud-native distributed storage with automatic backups and cross-cluster disaster recovery
- **Database Support**: Optimized configurations for PostgreSQL and MySQL with persistent storage

## Storage Classes

### Portworx Storage Classes

#### `portworx-sc-db`
- **Use Case**: High-performance database workloads
- **Replication**: 3 replicas for maximum availability
- **IO Profile**: Database-optimized with remote storage
- **Features**: High IO priority, automated snapshots

#### `portworx-sc-replicated`
- **Use Case**: General application data with redundancy
- **Replication**: 2 replicas for balanced performance and availability
- **IO Profile**: Auto-optimized based on workload

#### `portworx-sc-single`
- **Use Case**: Development and testing environments
- **Replication**: Single replica for cost efficiency
- **Features**: Fast provisioning, suitable for non-critical workloads

### Longhorn Storage Classes

#### `longhorn-sc-db`
- **Use Case**: Database workloads requiring high availability
- **Replication**: 3 replicas across different nodes
- **Features**: Automatic backup, disaster recovery support

#### `longhorn-sc-fast`
- **Use Case**: High-performance workloads
- **Node Selection**: Prefers SSD/NVMe storage nodes
- **Data Locality**: Best-effort placement for optimal performance

## Database Configurations

### PostgreSQL with Persistent Storage

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql-openfga
spec:
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      storageClassName: portworx-sc-db  # or longhorn-sc-db
      resources:
        requests:
          storage: 100Gi
```

**Key Features:**
- Automatic PVC provisioning per replica
- Health checks with PostgreSQL-specific probes
- Resource limits optimized for database workloads
- Secret-based credential management

### MySQL with Persistent Storage

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-openfga
spec:
  volumeClaimTemplates:
  - metadata:
      name: mysql-storage
    spec:
      storageClassName: portworx-sc-db  # or longhorn-sc-db
      resources:
        requests:
          storage: 100Gi
```

**Key Features:**
- MySQL 8.0 optimized configuration
- Persistent storage for data directory
- Comprehensive health monitoring
- Multi-user credential support

## Backup and Recovery

### Portworx Backup Policies

```yaml
apiVersion: stork.libopenstorage.org/v1alpha1
kind: SchedulePolicy
metadata:
  name: openfga-daily-backup
policy:
  daily:
    time: "10:14PM"
    retain: 30
```

**Features:**
- Daily automated backups
- 30-day retention policy
- Cross-cluster disaster recovery support
- Point-in-time recovery capabilities

### Longhorn Backup Policies

```yaml
apiVersion: longhorn.io/v1beta2
kind: RecurringJob
metadata:
  name: openfga-daily-backup
spec:
  cron: "0 2 * * *"
  task: "backup"
  retain: 30
```

**Features:**
- Automated daily backups to external storage
- Snapshot-based incremental backups
- S3-compatible backup targets
- Volume-level restore capabilities

## Performance Considerations

### Storage Performance Tuning

1. **Database Workloads:**
   - Use `portworx-sc-db` or `longhorn-sc-db` for optimal IOPS
   - Configure appropriate storage size for working set
   - Enable compression for large datasets

2. **Application Data:**
   - Use replicated storage classes for production
   - Consider data locality for performance-critical applications
   - Monitor storage metrics and adjust as needed

### Monitoring Storage Health

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: storage-metrics
spec:
  selector:
    matchLabels:
      app.kubernetes.io/component: storage
  endpoints:
  - port: metrics
```

## Troubleshooting

### Common Issues

1. **PVC Stuck in Pending State:**
   ```bash
   kubectl describe pvc <pvc-name>
   kubectl get storageclass
   kubectl logs -n portworx-system -l name=portworx
   ```

2. **Storage Performance Issues:**
   ```bash
   # Check Portworx volume status
   pxctl volume list
   pxctl volume inspect <volume-id>
   
   # Check Longhorn volume status
   kubectl -n longhorn-system get volumes
   ```

3. **Backup Failures:**
   ```bash
   # Check backup job status
   kubectl get backup
   kubectl describe backup <backup-name>
   ```

### Disaster Recovery

1. **Cross-Cluster Backup Restoration:**
   - Configure cluster pairing for Portworx
   - Set up S3 backup targets for Longhorn
   - Test restore procedures regularly

2. **Volume Migration:**
   - Use storage provider tools for volume migration
   - Ensure consistent backup before migration
   - Validate data integrity after migration

## Security Considerations

### Storage Encryption

Both Portworx and Longhorn support encryption at rest:

```yaml
parameters:
  secure: "true"
  encryption_key: "cluster-wide-secret-key"
```

### Access Control

- Use Kubernetes RBAC for storage resource access
- Implement storage quotas per namespace
- Monitor storage access patterns

## Best Practices

1. **Capacity Planning:**
   - Monitor storage usage trends
   - Plan for growth with appropriate storage classes
   - Implement automated alerting for capacity thresholds

2. **Backup Strategy:**
   - Test backup and restore procedures regularly
   - Maintain offsite backup copies
   - Document recovery procedures

3. **Performance Optimization:**
   - Use appropriate storage classes for workload types
   - Monitor and tune storage performance
   - Consider node affinity for storage-intensive workloads

## Integration with OpenFGA

### Database Connection Configuration

```yaml
spec:
  datastore:
    engine: "postgres"
    uri: "postgresql://$(DATABASE_USERNAME):$(DATABASE_PASSWORD)@postgresql-openfga:5432/openfga"
  persistence:
    enabled: true
    storageClass: "portworx-sc-db"
    size: "100Gi"
```

### Secrets Integration

Storage credentials are managed through the Delinea Vault integration:

```yaml
metadata:
  annotations:
    dsv.delinea.com/inject: "true"
    dsv.delinea.com/path: "/databases/openfga-postgres"
```

This ensures secure credential management for database connections while maintaining persistent storage capabilities.