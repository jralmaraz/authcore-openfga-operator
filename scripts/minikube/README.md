# Demo Applications Deployment Scripts

This directory contains comprehensive scripts for deploying and testing the OpenFGA Operator demo applications in various environments.

## Available Demo Applications

### 1. Banking Application (`demos/banking-app/`)
A comprehensive banking application demonstrating:
- **RBAC Implementation**: Customer, teller, manager, loan officer, and admin roles
- **Multi-ownership Support**: Joint accounts with multiple owners and co-owners
- **Transaction Controls**: Fine-grained permissions for deposits, withdrawals, and transfers
- **Loan Processing**: Approval workflows with proper authorization chains
- **Branch-based Security**: Employee access limited to their branch

### 2. GenAI RAG Agent (`demos/genai-rag-agent/`)
A Generative AI RAG (Retrieval-Augmented Generation) application demonstrating:
- **Knowledge Base Management**: Curator, contributor, and reader roles
- **Document-Level Security**: Individual document permissions with inheritance
- **Content Filtering**: RAG responses filtered based on document access rights
- **AI Model Access Control**: Separate permissions for using and configuring models
- **Session-Based RAG**: Controlled RAG sessions with participant management

## Deployment Options

### 🐳 Docker Compose (Recommended for Local Development)

The easiest way to get started with the demo applications:

```bash
# Deploy all applications with Docker Compose
./scripts/minikube/deploy-demos-docker.sh

# Or specific actions
./scripts/minikube/deploy-demos-docker.sh start    # Deploy and start
./scripts/minikube/deploy-demos-docker.sh status   # Check status
./scripts/minikube/deploy-demos-docker.sh logs     # View logs
./scripts/minikube/deploy-demos-docker.sh stop     # Stop services
./scripts/minikube/deploy-demos-docker.sh cleanup  # Remove everything
```

**Access URLs:**
- Banking App: http://localhost:3001
- GenAI RAG Agent: http://localhost:8001 (API docs: http://localhost:8001/docs)
- OpenFGA API: http://localhost:8080

### ☸️ Minikube Deployment

For Kubernetes-native deployment with Minikube:

```bash
# Prerequisites: Ensure operator is deployed
./scripts/minikube/deploy-operator.sh

# Or deploy operator with PostgreSQL datastore
./scripts/minikube/deploy-operator-postgres.sh

# Deploy all demo applications
./scripts/minikube/deploy-demos.sh

# Or deploy specific applications
./scripts/minikube/deploy-demos.sh --banking   # Banking app only
./scripts/minikube/deploy-demos.sh --genai     # GenAI app only

# Additional options
./scripts/minikube/deploy-demos.sh --skip-build   # Skip image building
./scripts/minikube/deploy-demos.sh --skip-setup   # Skip demo data setup
```

**Access via port-forwarding:**
```bash
# Banking Application
kubectl port-forward service/banking-demo-service 3000:80 &
curl http://localhost:3000/health

# GenAI RAG Agent
kubectl port-forward service/genai-rag-agent-service 8000:80 &
curl http://localhost:8000/health

# OpenFGA API
kubectl port-forward service/openfga-basic-http 8080:8080 &
curl http://localhost:8080/healthz
```

### 🪟 Windows PowerShell

For Windows users with PowerShell:

```powershell
# Deploy all applications
.\scripts\minikube\deploy-demos.ps1

# Deploy specific applications
.\scripts\minikube\deploy-demos.ps1 -Banking    # Banking app only
.\scripts\minikube\deploy-demos.ps1 -GenAI      # GenAI app only

# Additional options
.\scripts\minikube\deploy-demos.ps1 -SkipBuild  # Skip image building
.\scripts\minikube\deploy-demos.ps1 -SkipSetup  # Skip demo data setup
```

### 🗄️ PostgreSQL-backed OpenFGA Deployment

For deploying OpenFGA with PostgreSQL datastore support:

```bash
# Deploy operator with PostgreSQL automatically
./scripts/minikube/deploy-operator-postgres.sh

# Deploy only PostgreSQL (if operator is already deployed)
./scripts/minikube/deploy-operator-postgres.sh --skip-operator
```

This script:
- Checks prerequisites (minikube, kubectl, optional Docker/Podman)
- Creates the `openfga-system` namespace if needed
- Deploys PostgreSQL 14 with OpenFGA configuration
- Deploys the OpenFGA operator (unless `--skip-operator`)
- Provides PostgreSQL connection details and next steps

## Testing and Validation

### Automated Validation

Comprehensive validation script to test all deployed applications:

```bash
# Validate all deployed applications
./scripts/minikube/validate-demos.sh

# Validate specific applications
./scripts/minikube/validate-demos.sh --banking-only
./scripts/minikube/validate-demos.sh --genai-only
./scripts/minikube/validate-demos.sh --no-auth    # Skip authorization tests
```

The validation script tests:
- ✅ Service health endpoints
- ✅ API connectivity and responses
- ✅ Authorization scenarios (user permissions)
- ✅ Demo data setup verification
- ✅ Cross-service communication

### Manual Testing

#### Banking Application API Examples

```bash
# Port-forward first
kubectl port-forward service/banking-demo-service 3000:80 &

# Test health
curl http://localhost:3000/health

# Test with demo users
curl -H 'x-user-id: alice' http://localhost:3000/api/accounts
curl -H 'x-user-id: alice' http://localhost:3000/api/users/me

# Create a transaction
curl -X POST http://localhost:3000/api/transactions \
  -H 'x-user-id: alice' \
  -H 'Content-Type: application/json' \
  -d '{"from": "acc_001", "to": "acc_002", "amount": 100}'
```

#### GenAI RAG Agent API Examples

```bash
# Port-forward first
kubectl port-forward service/genai-rag-agent-service 8000:80 &

# Test health
curl http://localhost:8000/health

# Test with demo users
curl -H 'x-user-id: alice' http://localhost:8000/api/users/me
curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases

# Create a chat session
curl -X POST http://localhost:8000/api/chat/sessions \
  -H 'x-user-id: alice' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Demo Chat",
    "organization_id": "demo-org",
    "knowledge_base_ids": ["kb_demo"],
    "model_id": "gpt-3.5-turbo"
  }'

# Submit a query (replace SESSION_ID with actual ID)
curl -X POST http://localhost:8000/api/chat/sessions/SESSION_ID/query \
  -H 'x-user-id: alice' \
  -H 'Content-Type: application/json' \
  -d '{"question": "What is OpenFGA and how does it work?"}'
```

## Demo Users

Both applications include pre-configured demo users:

| User    | Role     | Banking App Access | GenAI App Access |
|---------|----------|-------------------|------------------|
| alice   | user     | Personal accounts | Demo knowledge base, basic AI models |
| bob     | user     | Limited access    | Limited access |
| charlie | curator  | Teller operations | Manage knowledge bases, contribute content |
| diana   | admin    | Full access       | Full organizational access, premium AI models |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Demo Applications Stack                       │
├─────────────────────────────────────────────────────────────────┤
│  Banking App (Node.js)     │  GenAI RAG Agent (Python)          │
│  ├── Account Management    │  ├── Knowledge Base Management     │
│  ├── Transaction Controls  │  ├── Document Upload/Search        │
│  ├── Role-based Access     │  ├── AI Model Integration          │
│  └── Branch Security       │  └── Session Management            │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                   OpenFGA Authorization                         │
│  ├── Banking Authorization Model                                │
│  ├── GenAI Authorization Model                                  │
│  ├── Fine-grained Permissions                                   │
│  └── Relationship-based Access Control                          │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                   OpenFGA Operator                              │
│  ├── Custom Resource Definitions (CRDs)                         │
│  ├── Operator Controller Logic                                  │
│  ├── OpenFGA Instance Management                                │
│  └── Kubernetes-native Operations                               │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### For Minikube Deployment
- **Kubernetes cluster**: Minikube 1.25+
- **kubectl**: Configured to access your cluster
- **Container runtime**: Docker or Podman
- **Node.js**: 18+ (for banking app)
- **Python**: 3.9+ (for GenAI app)
- **OpenFGA Operator**: Deployed and running

### For Docker Compose Deployment
- **Docker**: Docker Desktop or Docker Engine
- **Docker Compose**: Version 2.0+

## Configuration

### Environment Variables

#### Banking Application
- `OPENFGA_API_URL`: OpenFGA server URL (default: http://localhost:8080)
- `OPENFGA_STORE_ID`: OpenFGA store identifier
- `OPENFGA_AUTH_MODEL_ID`: Authorization model identifier
- `PORT`: Application port (default: 3000)
- `NODE_ENV`: Environment (development/production)

#### GenAI RAG Agent
- `OPENFGA_API_URL`: OpenFGA server URL (default: http://localhost:8080)
- `OPENFGA_STORE_ID`: OpenFGA store identifier
- `OPENFGA_AUTH_MODEL_ID`: Authorization model identifier
- `HOST`: Server host (default: 0.0.0.0)
- `PORT`: Server port (default: 8000)
- `OPENAI_API_KEY`: OpenAI API key (optional, enables real AI responses)
- `DEMO_MODE`: Enable demo mode with mock responses

### Customizing Demo Data

The demo applications include setup scripts that create:
- **Users and roles**: Predefined users with different permission levels
- **Resources**: Sample accounts, documents, AI models
- **Relationships**: Authorization tuples defining permissions
- **Sample data**: Test content for demonstrations

To customize the demo data:
1. Edit the setup scripts in each demo application
2. Modify the authorization models in `models/` directories
3. Adjust the user and resource definitions
4. Re-run the setup process

## Troubleshooting

### Common Issues

#### Services Not Starting
1. **Check resource availability**: `kubectl get nodes` / `docker system df`
2. **Verify prerequisites**: Ensure all required tools are installed
3. **Check logs**: `kubectl logs <pod-name>` / `docker-compose logs`
4. **Restart services**: Use the respective restart commands

#### Authorization Failures
1. **Verify OpenFGA instance**: Check if OpenFGA is running and accessible
2. **Check demo data setup**: Ensure setup scripts completed successfully
3. **Validate store configuration**: Verify store and model IDs are correct
4. **Test API connectivity**: Use curl to test OpenFGA API directly

#### Port Conflicts
1. **Check port usage**: `netstat -an | grep ':8080\|:3000\|:8000'`
2. **Stop conflicting services**: Kill processes using required ports
3. **Use different ports**: Modify port-forward commands or configurations

#### Build Failures
1. **Check dependencies**: Ensure Node.js/Python dependencies are available
2. **Verify Docker**: Test Docker/Podman functionality
3. **Clear cache**: Remove old images and rebuild from scratch
4. **Check disk space**: Ensure sufficient space for image builds

### Getting Help

1. **Validation script**: Run `./scripts/minikube/validate-demos.sh` for automated diagnosis
2. **Service logs**: Check application logs for detailed error messages
3. **OpenFGA logs**: Verify OpenFGA operator and instance logs
4. **Documentation**: Review individual demo application README files
5. **Community support**: Open an issue in the repository

## Development

### Adding New Demo Applications

To add a new demo application:

1. **Create demo directory**: `demos/new-demo/`
2. **Add Dockerfile**: For containerized deployment
3. **Create Kubernetes manifests**: In `k8s/` subdirectory
4. **Define authorization model**: In `models/` subdirectory
5. **Add setup script**: For demo data initialization
6. **Update deployment scripts**: Add new demo to deployment automation
7. **Add validation tests**: Include in validation script
8. **Document usage**: Create comprehensive README

### Contributing

When contributing to demo applications:

1. **Follow existing patterns**: Use established directory structure and naming
2. **Include comprehensive tests**: Both unit and integration tests
3. **Add proper documentation**: README files and inline comments
4. **Ensure cross-platform compatibility**: Test on Linux, macOS, and Windows
5. **Validate authorization models**: Ensure proper OpenFGA integration
6. **Test deployment scripts**: Verify all deployment methods work correctly

## Security Considerations

### Demo vs Production

These demo applications are designed for **demonstration and learning purposes**. For production use:

1. **Implement proper authentication**: Replace demo user headers with JWT/OAuth
2. **Use HTTPS**: Enable TLS encryption for all communications
3. **Secure secrets management**: Use Kubernetes secrets or external secret managers
4. **Enable audit logging**: Comprehensive logging for compliance and monitoring
5. **Input validation**: Implement proper input sanitization and validation
6. **Rate limiting**: Add rate limiting and DDoS protection
7. **Security scanning**: Regular security scans and dependency updates

### Authorization Best Practices

The demo applications demonstrate OpenFGA best practices:

1. **Principle of least privilege**: Users get minimum required permissions
2. **Relationship-based access**: Permissions based on user-resource relationships
3. **Hierarchical permissions**: Role inheritance and cascading permissions
4. **Context-aware authorization**: Permissions based on request context
5. **Audit trails**: Comprehensive logging of authorization decisions
6. **Performance optimization**: Efficient authorization checks and caching

## License

These demo applications are part of the OpenFGA Operator project and are licensed under the Apache 2.0 License. See the [LICENSE](../../LICENSE) file for details.

## Support

For questions and support:

- **Documentation**: Check individual demo application READMEs
- **Issues**: Open an issue in the repository
- **Community**: Join OpenFGA community discussions
- **Examples**: Review the comprehensive API examples above