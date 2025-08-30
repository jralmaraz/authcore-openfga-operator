# Enhanced Logging Configuration for OpenFGA Operator

The OpenFGA operator now supports comprehensive structured logging for improved debugging and observability.

## Configuration

### Log Format

Control the output format using the `OPENFGA_LOG_FORMAT` environment variable:

**Human-readable logging (default):**
```bash
cargo run
# or explicitly:
OPENFGA_LOG_FORMAT=pretty cargo run
```

**JSON structured logging:**
```bash
OPENFGA_LOG_FORMAT=json cargo run
```

### Log Level

Control the verbosity using the `RUST_LOG` environment variable:

```bash
# Info level (default)
RUST_LOG=info cargo run

# Debug level (shows reconciliation details)
RUST_LOG=debug cargo run

# Operator-specific debug logging
RUST_LOG=openfga_operator=debug cargo run
```

## Example Log Output

### JSON Format (Production Recommended)

```json
{"timestamp":"2025-08-30T00:08:35.561550Z","level":"INFO","fields":{"message":"Starting OpenFGA Operator","operator":"openfga-operator","version":"0.1.0","log_format":"json"},"target":"openfga_operator"}
{"timestamp":"2025-08-30T00:08:35.561639Z","level":"DEBUG","fields":{"message":"Attempting to connect to Kubernetes API"},"target":"openfga_operator"}
```

### Pretty Format (Development Friendly)

```
2025-08-30T00:07:27.446760Z  INFO openfga_operator: Starting OpenFGA Operator, operator: "openfga-operator", version: "0.1.0", log_format: "pretty"
2025-08-30T00:07:27.446816Z DEBUG openfga_operator: Attempting to connect to Kubernetes API
```

## Logging Features

### 1. Reconciliation Lifecycle Logging

- **Info level**: Start and completion of reconciliation jobs
- **Debug level**: Detailed steps within reconciliation logic
- **Error level**: Failures with comprehensive error context

### 2. Kubernetes API Connectivity

- Connection success/failure with cluster information
- API operation results (create, update, patch)
- Resource existence checks

### 3. Structured Context

All log messages include relevant context:
- `namespace`: Kubernetes namespace
- `resource_name`: Name of the OpenFGA resource
- `event`: Type of operation being performed
- `error`: Detailed error information when applicable

### 4. Intelligent Error Handling

Different retry strategies based on error type:
- **NotFound errors**: 10-second retry
- **Conflict errors**: 1-second retry (immediate)
- **Other Kubernetes errors**: 30-second retry
- **Serialization errors**: 120-second retry

## Deployment Configuration

For production deployments, set environment variables in your Kubernetes deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openfga-operator
spec:
  template:
    spec:
      containers:
      - name: operator
        image: openfga-operator:latest
        env:
        - name: OPENFGA_LOG_FORMAT
          value: "json"
        - name: RUST_LOG
          value: "info,openfga_operator=debug"
```

This configuration enables JSON logging for log aggregation systems while providing debug-level information for the operator specifically.

## Container Resilience and Continuous Operation

### Enhanced Startup Behavior

The operator now includes robust retry logic and continuous operation features designed to address containerized deployment challenges:

**Key Improvements:**
- **Exponential Backoff Retry**: Automatically retries Kubernetes API connections (5s to 5min delays)
- **Continuous Logging**: Provides regular health status updates even during connection failures
- **Health Monitoring**: Built-in health check endpoint on port 8080
- **Graceful Shutdown**: Proper signal handling for clean container termination
- **Container Resilience**: Prevents immediate container exit on connection failures

### Container Behavior

Instead of exiting immediately on connection failure, the operator now:

1. **Starts health endpoint** on `0.0.0.0:8080` immediately
2. **Attempts connection** with exponential backoff retry (up to 10 attempts)
3. **Provides continuous logging** throughout the retry process
4. **Reports health status** every 30 seconds during initialization
5. **Continues running** with controller monitoring once connected

**Example Continuous Logging:**
```
2025-08-30T00:19:20.720612Z  INFO openfga_operator: Starting OpenFGA Operator, operator: "openfga-operator", version: "0.1.0", log_format: "pretty"
2025-08-30T00:19:20.720893Z  INFO openfga_operator: Health check endpoint started, endpoint: "health", address: 0.0.0.0:8080
2025-08-30T00:19:20.720928Z  WARN openfga_operator: Failed to connect to Kubernetes API, retrying with exponential backoff, retry_attempt: 1, max_attempts: 10, retry_delay_seconds: 5
2025-08-30T00:19:35.723924Z  INFO openfga_operator: OpenFGA Operator health check - attempting Kubernetes connection, operator_status: retrying (attempt 2), uptime_seconds: 15
```

## Health Check Endpoints

The operator exposes several health check endpoints on port 8080:

### `/health` or `/healthz` - Comprehensive Health Status
Returns detailed JSON health information:

```json
{
  "status": "running",
  "kubernetes_connected": true,
  "controller_running": true,
  "uptime_seconds": 3600,
  "version": "0.1.0",
  "timestamp": "2025-08-30T00:08:35.561550Z"
}
```

**HTTP Status Codes:**
- `200 OK`: All systems healthy (Kubernetes connected and controller running)
- `503 Service Unavailable`: System unhealthy (connection or controller issues)

### `/ready` or `/readiness` - Kubernetes Connectivity
Returns simple readiness status for Kubernetes readiness probes.

**Response:** `ready` or `not ready`

**HTTP Status Codes:**
- `200 OK`: Kubernetes API connected
- `503 Service Unavailable`: Cannot connect to Kubernetes API

### `/live` or `/liveness` - Basic Liveness
Returns simple liveness status for Kubernetes liveness probes.

**Response:** `alive`

**HTTP Status Code:** Always `200 OK` (indicates process is running)

## Enhanced Kubernetes Deployment Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openfga-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openfga-operator
  template:
    metadata:
      labels:
        app: openfga-operator
    spec:
      containers:
      - name: operator
        image: openfga-operator:latest
        env:
        - name: OPENFGA_LOG_FORMAT
          value: "json"
        - name: RUST_LOG
          value: "info,openfga_operator=debug"
        ports:
        - containerPort: 8080
          name: health
        livenessProbe:
          httpGet:
            path: /live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 5
          failureThreshold: 3
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 65532
          capabilities:
            drop:
            - ALL
```

## Enhanced Structured Fields

All log messages now include additional structured fields for comprehensive monitoring:

- `namespace`: Kubernetes namespace
- `resource_name`: OpenFGA resource name
- `event`: Operation type being performed
- `error`: Detailed error information when applicable
- `replicas`, `ports`, `image`: Resource specifications
- `retry_attempt`, `max_attempts`: Retry information
- `uptime_seconds`: Operator uptime
- `operator_status`, `controller_status`: System status
- `api_connectivity`: Kubernetes API connection status

## Troubleshooting Container Issues

### Container Exits Immediately

**Previous Behavior:** Container would exit immediately if Kubernetes API was unavailable.

**Enhanced Behavior:** Container now:
- Continues running during connection attempts
- Provides continuous logging output
- Exposes health endpoints for monitoring
- Uses exponential backoff retry with maximum 10 attempts

### No Logs in Container

**Solutions:**
1. Check log format: `OPENFGA_LOG_FORMAT=pretty` for human-readable logs
2. Verify log level: `RUST_LOG=info` or `RUST_LOG=debug`
3. Monitor health endpoint: `curl http://localhost:8080/health`

### Health Endpoint Issues

**Solutions:**
1. Verify port 8080 is exposed and accessible
2. Check operator startup logs for health endpoint initialization
3. Test different endpoints: `/live`, `/ready`, `/health`

## Production Deployment Recommendations

### Container Configuration

```dockerfile
FROM cgr.dev/chainguard/glibc-dynamic:latest

# Copy operator binary
COPY openfga-operator /usr/local/bin/

# Configure for production JSON logging
ENV OPENFGA_LOG_FORMAT=json
ENV RUST_LOG=info

# Health check configuration
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Expose health endpoint
EXPOSE 8080

# Use non-root user
USER 65532:65532

ENTRYPOINT ["/usr/local/bin/openfga-operator"]
```

### Monitoring Integration

The enhanced operator integrates seamlessly with monitoring systems:

- **Prometheus**: Monitor health endpoint and parse structured logs
- **ELK Stack**: JSON format works directly with Elasticsearch
- **Cloud Logging**: Structured fields enable advanced querying and alerting
- **Container Orchestrators**: Health endpoints support native health checks

This enhanced logging and resilience implementation ensures the OpenFGA operator provides continuous visibility and reliable operation in containerized production environments.