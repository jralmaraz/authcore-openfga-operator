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