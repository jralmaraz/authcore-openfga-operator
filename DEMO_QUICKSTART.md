# Quick Start Guide: Demo Applications

This guide gets you up and running with the OpenFGA Operator demo applications in 5 minutes.

## Prerequisites

Ensure you have the following installed:
- **Docker** or **Podman**
- **kubectl** 
- **Minikube** (or any Kubernetes cluster)
- **Node.js** (v18+) and **npm**
- **Python 3** and **pip3**

## Step 1: Start Minikube

```bash
# Start minikube with sufficient resources
minikube start --memory=4096 --cpus=2

# Verify cluster is running
kubectl cluster-info
```

## Step 2: Deploy OpenFGA Operator

```bash
# Navigate to project root
cd authcore-openfga-operator

# Deploy the operator (if not already deployed)
./scripts/minikube/deploy-operator.sh
```

## Step 3: Deploy Demo Applications

### Option A: Deploy Both Demos (Recommended)

```bash
# Deploy both banking and GenAI RAG demos
./scripts/deploy-demos.sh
```

### Option B: Deploy Individual Demos

```bash
# Banking demo only
./scripts/deploy-banking-demo.sh

# GenAI RAG demo only  
./scripts/deploy-genai-demo.sh
```

## Step 4: Access the Applications

### Banking Demo

```bash
# Port-forward to banking demo
kubectl port-forward service/banking-demo-service 3000:80

# Test the API (in another terminal)
curl http://localhost:3000/health
curl http://localhost:3000/api/accounts

# Access in browser: http://localhost:3000
```

### GenAI RAG Demo

```bash
# Port-forward to GenAI demo
kubectl port-forward service/genai-rag-agent-service 8000:80

# Test the API (in another terminal)
curl -H 'x-user-id: alice' http://localhost:8000/health
curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases

# Access in browser: http://localhost:8000
```

## Step 5: Explore the Demos

### Banking Demo Features
- **Multi-ownership accounts**: Joint accounts with multiple owners
- **Role-based permissions**: Customer, teller, manager, admin roles
- **Transaction controls**: Fine-grained permissions for deposits, withdrawals, transfers
- **Loan workflows**: Loan officer approval processes

**Test Commands:**
```bash
# Get all accounts
curl http://localhost:3000/api/accounts

# Get account details (replace with actual account ID)
curl http://localhost:3000/api/accounts/{account-id}

# Get transactions
curl http://localhost:3000/api/transactions
```

### GenAI RAG Demo Features  
- **Knowledge base access control**: Organization-based permissions
- **Document-level security**: Fine-grained document access
- **Chat session authorization**: User-specific conversation access
- **Role-based management**: User, curator, admin roles

**Test Commands:**
```bash
# List knowledge bases (as alice)
curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases

# Get documents from demo knowledge base
curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases/kb_demo/documents

# Query the RAG system
curl -X POST -H 'Content-Type: application/json' -H 'x-user-id: alice' \
     -d '{"query": "What is this system about?"}' \
     http://localhost:8000/api/chat/sessions/session_demo_alice/query
```

## Monitoring and Troubleshooting

### Check Status
```bash
# Comprehensive status
./scripts/deploy-demos.sh --status

# Check pods
kubectl get pods

# Check services  
kubectl get services
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

1. **Pods not starting**: Check resource limits
   ```bash
   kubectl describe pods
   kubectl top pods
   ```

2. **Connection refused**: Verify port-forwarding
   ```bash
   ps aux | grep "kubectl port-forward"
   ```

3. **OpenFGA not accessible**: Check OpenFGA deployment
   ```bash
   kubectl get pods -l app=openfga
   kubectl port-forward service/openfga-basic 8080:8080
   ```

## Cleanup

```bash
# Remove all demos
./scripts/deploy-demos.sh --cleanup

# Or remove individually
./scripts/deploy-banking-demo.sh --cleanup
./scripts/deploy-genai-demo.sh --cleanup
```

## Next Steps

1. **Explore Authorization Models**: Check `demos/*/models/` for OpenFGA authorization models
2. **Modify Permissions**: Edit authorization models and redeploy
3. **Add Custom Scenarios**: Extend demos with your own use cases
4. **Production Deployment**: Follow production guides for enterprise deployment

## Support

- **Scripts Documentation**: [scripts/README.md](scripts/README.md)
- **Banking Demo Details**: [demos/banking-app/README.md](demos/banking-app/README.md)  
- **GenAI Demo Details**: [demos/genai-rag-agent/README.md](demos/genai-rag-agent/README.md)
- **Minikube Setup Guides**: [docs/minikube/](docs/minikube/)

## Demo Users

Both demos come with pre-configured test users:

### Banking Demo
- **alice** (customer) - Account owner
- **bob** (customer) - Joint account holder
- **charlie** (teller) - Can process deposits
- **diana** (manager) - Can approve transactions
- **eve** (loan_officer) - Can manage loans

### GenAI RAG Demo
- **alice** (user) - Can access demo knowledge base
- **bob** (user) - Limited access
- **charlie** (curator) - Can manage knowledge bases
- **diana** (admin) - Full organization access

Try different users by changing the `x-user-id` header in API requests!