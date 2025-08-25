# MacOS Setup Guide for authcore-openfga-operator with Minikube

This guide provides step-by-step instructions for setting up and running the authcore-openfga-operator on MacOS using Minikube.

## Prerequisites

- macOS 10.15 (Catalina) or later
- Administrative privileges
- At least 4GB of available RAM
- At least 10GB of free disk space

## Step 1: Install Required Tools

### Install Homebrew (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Install Docker Desktop

1. **Download Docker Desktop:**
   - Visit https://www.docker.com/products/docker-desktop
   - Download Docker Desktop for Mac
   - Install and start Docker Desktop

2. **Verify Docker installation:**
   ```bash
   docker --version
   docker run hello-world
   ```

### Install kubectl

```bash
# Install kubectl via Homebrew
brew install kubectl

# Verify installation
kubectl version --client
```

### Install Minikube

```bash
# Install Minikube via Homebrew
brew install minikube

# Verify installation
minikube version
```

### Install Rust (for building the operator)

```bash
# Install Rust via rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Source the environment
source ~/.zshrc  # or ~/.bash_profile if using bash

# Verify installation
rustc --version
cargo --version
```

## Step 2: Start Minikube

```bash
# Start Minikube with Docker driver
minikube start --driver=docker --memory=4096 --cpus=2

# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server

# Verify Minikube is running
minikube status
kubectl cluster-info
```

## Step 3: Set Up the Project

### Clone the Repository (if not already done)

```bash
git clone https://github.com/jralmaraz/authcore-openfga-operator.git
cd authcore-openfga-operator
```

### Build the Operator

```bash
# Compile and check the project
make compile

# Run tests to ensure everything works
make test

# Build the release binary
make build
```

## Step 4: Deploy to Minikube

### Install Custom Resource Definitions

```bash
# Install the OpenFGA CRDs
make install-crds

# Verify CRDs are installed
kubectl get crd openfgas.authorization.openfga.dev
```

### Build and Deploy the Operator

```bash
# Build Docker image
make docker-build

# Load image into Minikube
minikube image load openfga-operator:latest

# Create namespace for the operator
kubectl create namespace openfga-system

# Create deployment for the operator
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openfga-operator
  namespace: openfga-system
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
        imagePullPolicy: Never
        ports:
        - containerPort: 8080
          name: metrics
        env:
        - name: RUST_LOG
          value: "info"
        resources:
          limits:
            memory: "128Mi"
            cpu: "250m"
          requests:
            memory: "64Mi"
            cpu: "100m"
EOF
```

### Create RBAC Resources

```bash
# Create service account and RBAC
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openfga-operator
  namespace: openfga-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: openfga-operator
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["authorization.openfga.dev"]
  resources: ["openfgas"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["authorization.openfga.dev"]
  resources: ["openfgas/status"]
  verbs: ["get", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: openfga-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: openfga-operator
subjects:
- kind: ServiceAccount
  name: openfga-operator
  namespace: openfga-system
EOF
```

### Update Deployment to Use Service Account

```bash
kubectl patch deployment openfga-operator -n openfga-system -p '{"spec":{"template":{"spec":{"serviceAccountName":"openfga-operator"}}}}'
```

## Step 5: Deploy OpenFGA Instances

### Deploy Basic OpenFGA Instance

```bash
# Deploy a basic OpenFGA instance
kubectl apply -f examples/basic-openfga.yaml

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s deployment/openfga-basic
```

### Deploy PostgreSQL-backed OpenFGA Instance (Optional)

```bash
# First deploy PostgreSQL
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: openfga
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_PASSWORD
          value: password
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: default
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
EOF

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=available --timeout=300s deployment/postgres

# Deploy PostgreSQL-backed OpenFGA
kubectl apply -f examples/postgres-openfga.yaml
```

## Step 6: Validation

### Verify Operator Status

```bash
# Check operator pod status
kubectl get pods -n openfga-system

# Check operator logs
kubectl logs -n openfga-system deployment/openfga-operator

# Check for any errors
kubectl describe pods -n openfga-system
```

### Verify OpenFGA Instances

```bash
# List OpenFGA custom resources
kubectl get openfgas

# Check OpenFGA deployments
kubectl get deployments

# Check OpenFGA services
kubectl get services
```

### Test OpenFGA API Access

```bash
# Port-forward to access OpenFGA API
kubectl port-forward service/openfga-basic-http 8080:8080 &

# Test API (in another terminal)
curl -X GET http://localhost:8080/healthz

# Test stores endpoint
curl -X GET http://localhost:8080/stores

# Stop port-forward
kill %1
```

## Step 7: Deploy Demo Applications (Optional)

### Deploy Banking Demo

```bash
# Navigate to banking demo
cd demos/banking-app

# Build and deploy
docker build -t banking-app:latest .
minikube image load banking-app:latest
kubectl apply -f k8s/

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s deployment/banking-app
```

### Access Demo Applications

```bash
# Port-forward to banking app
kubectl port-forward service/banking-app 3000:3000 &

# Open in browser
open http://localhost:3000

# Stop port-forward when done
kill %1
```

## Troubleshooting

### Common Issues

1. **Minikube fails to start:**
   ```bash
   # Delete and recreate
   minikube delete
   minikube start --driver=docker --memory=4096 --cpus=2
   ```

2. **Docker build fails:**
   ```bash
   # Ensure Docker Desktop is running
   docker ps
   
   # Restart Docker if needed
   # Use Docker Desktop restart option
   ```

3. **Operator pod not starting:**
   ```bash
   # Check events
   kubectl describe pod -n openfga-system
   
   # Check resource limits
   kubectl top nodes
   kubectl top pods -n openfga-system
   ```

4. **Permission issues:**
   ```bash
   # Verify RBAC setup
   kubectl get clusterrole openfga-operator
   kubectl get clusterrolebinding openfga-operator
   ```

### Resource Management

```bash
# Monitor resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# If running low on resources
minikube config set memory 6144
minikube config set cpus 4
minikube delete && minikube start
```

## Cleanup

When you're done testing:

```bash
# Delete OpenFGA instances
kubectl delete openfgas --all

# Delete demo applications
kubectl delete -f demos/banking-app/k8s/ 2>/dev/null || true

# Delete operator
kubectl delete namespace openfga-system

# Uninstall CRDs
make uninstall-crds

# Stop Minikube
minikube stop

# Delete Minikube cluster (optional)
minikube delete
```

## Next Steps

- Explore the [Demo Applications](../../demos/)
- Read the [Architecture Documentation](../design/ARCHITECTURE.md)
- Try the [GenAI RAG Demo](../../demos/genai-rag-agent/)
- Check out the [Security Features](../security/SECURITY_ARCHITECTURE.md)

## Automation

For a fully automated setup, use the provided script:

```bash
# Run the automated setup script
./scripts/minikube/setup-minikube.sh
./scripts/minikube/deploy-operator.sh
./scripts/minikube/validate-deployment.sh
```