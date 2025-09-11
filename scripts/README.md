# Demo Application Deployment Scripts

This directory contains comprehensive deployment scripts for local testing of the OpenFGA Operator demo applications. These scripts automate the entire deployment process, from building Docker images to setting up OpenFGA authorization models.

## Overview

The authcore-openfga-operator includes two sophisticated demo applications that showcase fine-grained authorization patterns:

1. **Banking Application Demo** - Demonstrates role-based access control for financial services
2. **GenAI RAG Agent Demo** - Shows knowledge base and document access control for AI applications

## Prerequisites

Before running the deployment scripts, ensure you have the following tools installed:

### Required Tools
- **kubectl** - Kubernetes command-line tool
- **docker** or **podman** - Container runtime
- **minikube** or any Kubernetes cluster - For local deployment
- **node** and **npm** - For banking demo (Node.js 18+)
- **python3** and **pip3** - For GenAI RAG demo (Python 3.8+)

### Optional Tools
- **curl** - For API testing and validation
- **jq** - For JSON processing in examples

## Quick Start

### 1. Deploy Both Demo Applications

```bash
# Deploy both banking and GenAI demos
./scripts/deploy-demos.sh

# Deploy with specific container runtime
CONTAINER_RUNTIME=podman ./scripts/deploy-demos.sh
```

### 2. Deploy Individual Demos

```bash
# Banking demo only
./scripts/deploy-banking-demo.sh

# GenAI RAG demo only  
./scripts/deploy-genai-demo.sh

# Or using the unified script
./scripts/deploy-demos.sh --banking-only
./scripts/deploy-demos.sh --genai-only
```

### 3. Quick Testing

```bash
# Test existing deployments
./scripts/deploy-demos.sh --test-only

# Show comprehensive status
./scripts/deploy-demos.sh --status
```

## Script Details

### cleanup-operator.sh (OpenFGA Operator Cleanup)

**Location:** `scripts/minikube/cleanup-operator.sh`

Comprehensive cleanup script that removes all OpenFGA operator resources from the cluster.

**Features:**
- Removes all OpenFGA custom resources and instances
- Cleans up demo applications (banking, genai-rag)
- Deletes operator deployment, services, and RBAC resources
- Removes openfga-system namespace (optional)
- Uninstalls Custom Resource Definitions (optional)
- Stops running port-forwards
- Provides dry-run mode and status checking
- Supports selective cleanup options

**Usage:**
```bash
./scripts/minikube/cleanup-operator.sh [OPTIONS]

Options:
  --keep-crds          Do not delete Custom Resource Definitions
  --keep-namespace     Do not delete the openfga-system namespace
  --skip-demos         Do not clean up demo applications
  --force              Skip confirmation prompt
  --dry-run            Show what would be deleted without actually deleting
  --status             Show current status of OpenFGA resources
  --help               Show help message
```

**Examples:**
```bash
# Complete cleanup with confirmation
./scripts/minikube/cleanup-operator.sh

# Quick cleanup without confirmation
./scripts/minikube/cleanup-operator.sh --force

# Keep CRDs for faster re-deployment
./scripts/minikube/cleanup-operator.sh --keep-crds

# Preview cleanup without changes
./scripts/minikube/cleanup-operator.sh --dry-run

# Check current resource status
./scripts/minikube/cleanup-operator.sh --status
```

### deploy-demos.sh (Unified Script)

The main script that can deploy both demo applications together or individually.

**Usage:**
```bash
./scripts/deploy-demos.sh [OPTIONS]

Options:
  --banking-only    Deploy only the banking demo
  --genai-only      Deploy only the GenAI RAG demo
  --cleanup         Remove all demo deployments
  --test-only       Only test existing deployments
  --status          Show comprehensive status of all demos
  --skip-build      Skip building applications and Docker images
  --help           Show help message
```

**Examples:**
```bash
# Deploy both demos
./scripts/deploy-demos.sh

# Deploy only banking demo
./scripts/deploy-demos.sh --banking-only

# Clean up all deployments
./scripts/deploy-demos.sh --cleanup

# Test and show status
./scripts/deploy-demos.sh --test-only
./scripts/deploy-demos.sh --status
```

### deploy-banking-demo.sh (Banking Demo Script)

Deploys the banking application demo with full authorization model setup.

**Features:**
- Builds Node.js/TypeScript application
- Creates Docker image and loads into Minikube
- Sets up OpenFGA store with banking authorization model
- Deploys to Kubernetes with proper configuration
- Provides API testing examples

**Usage:**
```bash
./scripts/deploy-banking-demo.sh [OPTIONS]

Options:
  --cleanup         Remove the banking demo deployment
  --test-only       Only test an existing deployment
  --skip-build      Skip building the application and Docker image
  --help           Show help message
```

### deploy-genai-demo.sh (GenAI RAG Demo Script)

Deploys the GenAI RAG agent demo with knowledge base authorization.

**Features:**
- Sets up Python virtual environment and dependencies
- Creates Docker image and loads into Minikube
- Configures OpenFGA store with GenAI authorization model
- Deploys to Kubernetes with optional OpenAI integration
- Provides comprehensive API testing examples

**Usage:**
```bash
./scripts/deploy-genai-demo.sh [OPTIONS]

Options:
  --cleanup         Remove the GenAI RAG demo deployment
  --test-only       Only test an existing deployment
  --skip-build      Skip building the application and Docker image
  --help           Show help message
```

## Accessing the Demo Applications

### Banking Demo

After deployment, access the banking demo:

```bash
# Port-forward to access the application
kubectl port-forward service/banking-demo-service 3000:80

# Test the API
curl http://localhost:3000/health
curl http://localhost:3000/api/accounts

# Access in browser
open http://localhost:3000  # macOS
# or
xdg-open http://localhost:3000  # Linux
```

**Key Features:**
- Account management with multi-ownership
- Role-based transaction permissions
- Loan processing workflows
- Branch-based employee access

### GenAI RAG Demo

After deployment, access the GenAI RAG demo:

```bash
# Port-forward to access the application
kubectl port-forward service/genai-rag-agent-service 8000:80

# Test the API with demo users
curl -H 'x-user-id: alice' http://localhost:8000/health
curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases

# Query the RAG system
curl -X POST -H 'Content-Type: application/json' -H 'x-user-id: alice' \
     -d '{"query": "What is this system about?"}' \
     http://localhost:8000/api/chat/sessions/session_demo_alice/query

# Access in browser
open http://localhost:8000  # macOS
# or  
xdg-open http://localhost:8000  # Linux
```

**Key Features:**
- Knowledge base access control
- Document-level permissions
- Organization-based user management
- Chat session authorization

**Demo Users:**
- `alice` (user) - Can access demo knowledge base
- `bob` (user) - Limited access
- `charlie` (curator) - Can manage knowledge bases  
- `diana` (admin) - Full organization access

## Environment Variables

### Container Runtime
```bash
# Use Podman instead of Docker
CONTAINER_RUNTIME=podman ./scripts/deploy-demos.sh
```

### OpenAI Integration (GenAI Demo)
```bash
# Deploy GenAI demo with real OpenAI integration
OPENAI_API_KEY=sk-your-key-here ./scripts/deploy-genai-demo.sh
```

## Monitoring and Troubleshooting

### Check Deployment Status

```bash
# Overall status
./scripts/deploy-demos.sh --status

# Kubernetes resources
kubectl get pods
kubectl get services
kubectl get deployments

# Check specific demo
kubectl get pods -l app=banking-demo
kubectl get pods -l app=genai-rag-agent
kubectl get pods -l app=openfga
```

### View Logs

```bash
# Banking demo logs
kubectl logs -l app=banking-demo -f

# GenAI demo logs  
kubectl logs -l app=genai-rag-agent -f

# OpenFGA logs
kubectl logs -l app=openfga -f
```

### Common Issues

1. **Docker image not found**: Ensure Minikube is running and image was loaded
   ```bash
   minikube status
   minikube image ls | grep demo
   ```

2. **OpenFGA not accessible**: Check if OpenFGA service is running
   ```bash
   kubectl get services -l app=openfga
   kubectl port-forward service/openfga-basic 8080:8080
   ```

3. **Permission denied**: Ensure scripts are executable
   ```bash
   chmod +x scripts/*.sh
   ```

## Cleanup

### Remove All Demos

```bash
# Clean up everything
./scripts/deploy-demos.sh --cleanup
```

### Remove Individual Demos

```bash
# Banking demo only
./scripts/deploy-banking-demo.sh --cleanup

# GenAI demo only
./scripts/deploy-genai-demo.sh --cleanup
```

### Manual Cleanup

```bash
# Remove demo applications
kubectl delete -f demos/banking-app/k8s/
kubectl delete -f demos/genai-rag-agent/k8s/

# Stop any port-forwards
pkill -f "kubectl port-forward"

# Remove OpenFGA (if needed)
kubectl delete -f examples/basic-openfga.yaml
```

## Advanced Usage

### Skip Building (Use Existing Images)

```bash
# Deploy without rebuilding
./scripts/deploy-demos.sh --skip-build
```

### Custom Development Workflow

```bash
# 1. Make code changes to demo applications
# 2. Rebuild specific demo
./scripts/deploy-banking-demo.sh --cleanup
./scripts/deploy-banking-demo.sh

# 3. Test changes
./scripts/deploy-banking-demo.sh --test-only
```

### Integration with CI/CD

The scripts can be used in automated environments:

```bash
# Non-interactive deployment
export CONTAINER_RUNTIME=docker
./scripts/deploy-demos.sh --skip-build

# Validation
./scripts/deploy-demos.sh --test-only
```

## Best Practices

1. **Start with Prerequisites**: Always run prerequisite checks first
2. **Use OpenFGA Examples**: Deploy basic OpenFGA before demos
3. **Monitor Resources**: Check cluster resources and limits
4. **Clean Up**: Remove demos when not needed to free resources
5. **Check Logs**: Use logs for troubleshooting deployment issues

## Contributing

When modifying the demo deployment scripts:

1. Maintain backward compatibility
2. Add comprehensive error handling
3. Include clear logging and status messages
4. Test on multiple platforms (Linux, macOS, Windows WSL)
5. Update documentation for any new features

## Support

For issues with the deployment scripts:

1. Check the troubleshooting section above
2. Verify all prerequisites are installed
3. Review the logs for specific error messages
4. Check Kubernetes cluster health and resources

## Related Documentation

- [Main Project README](../README.md)
- [Banking Demo Documentation](../demos/banking-app/README.md)
- [GenAI RAG Demo Documentation](../demos/genai-rag-agent/README.md)
- [Minikube Setup Guides](../docs/minikube/)
- [OpenFGA Operator Documentation](../docs/)