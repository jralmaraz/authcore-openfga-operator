# Running authcore-openfga-operator with Minikube

This guide provides comprehensive instructions for running the authcore-openfga-operator locally using Minikube across different operating systems.

## Overview

The authcore-openfga-operator is a Kubernetes operator that manages OpenFGA instances with enterprise-grade security features. This documentation helps you set up a local development environment using Minikube to test and validate the operator.

## Quick Start

1. **Choose your operating system guide:**
   - [MacOS Setup Guide](./setup-macos.md)
   - [Linux Setup Guide](./setup-linux.md)
   - [Windows Setup Guide](./setup-windows.md)

2. **Use automation scripts:**
   - [Setup Scripts](../../scripts/minikube/) - Automated setup, deployment, and validation

## Prerequisites

Before starting, ensure you have:
- Administrative/sudo access on your system
- At least 4GB of available RAM
- At least 10GB of free disk space
- Active internet connection for downloading dependencies

## Architecture Overview

When running locally with Minikube, the setup includes:

```
┌─────────────────────────────────────────────────────────────┐
│                        Minikube Cluster                      │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │                 │  │                 │  │                 │  │
│  │ OpenFGA         │  │ authcore-       │  │ Demo            │  │
│  │ Operator        │  │ openfga-        │  │ Applications    │  │
│  │ (Deployment)    │  │ operator        │  │ (Optional)      │  │
│  │                 │  │ (Custom         │  │                 │  │
│  │                 │  │ Resources)      │  │                 │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## What You'll Deploy

- **Minikube**: Local Kubernetes cluster
- **authcore-openfga-operator**: The operator managing OpenFGA instances
- **Custom Resource Definitions (CRDs)**: OpenFGA resource definitions
- **Example OpenFGA instances**: Basic and PostgreSQL-backed instances
- **Demo applications** (optional): Banking and GenAI RAG applications

## Validation Steps

After deployment, you'll be able to:
1. Verify the operator is running in your cluster
2. Create OpenFGA instances using custom resources
3. Access OpenFGA APIs through port-forwarding
4. Run demo applications that use OpenFGA for authorization

## Troubleshooting

Common issues and solutions:

### Minikube Won't Start
```bash
# Delete and recreate Minikube
minikube delete
minikube start --driver=docker --memory=4096 --cpus=2
```

### Operator Pods Not Starting
```bash
# Check pod status
kubectl get pods -n openfga-system

# Check logs
kubectl logs -n openfga-system deployment/openfga-operator
```

### Resource Constraints
```bash
# Increase Minikube resources
minikube config set memory 6144
minikube config set cpus 4
minikube delete && minikube start
```

## Next Steps

1. Follow the setup guide for your operating system
2. Use the automation scripts for quick deployment
3. Explore the demo applications
4. Read the [Architecture Documentation](../design/ARCHITECTURE.md)

## Support

For issues specific to Minikube setup:
- Check the troubleshooting section above
- Review the OS-specific setup guides
- Check Minikube official documentation: https://minikube.sigs.k8s.io/

For issues with the operator itself:
- Check the main [README](../../README.md)
- Review the [Security Architecture](../security/SECURITY_ARCHITECTURE.md)
- Open an issue in the repository