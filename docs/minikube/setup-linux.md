# Linux Setup Guide for authcore-openfga-operator with Minikube

This guide provides step-by-step instructions for setting up and running the authcore-openfga-operator on Linux using Minikube.

## Prerequisites

- Linux distribution (Ubuntu 18.04+, CentOS 7+, or equivalent)
- Sudo privileges
- At least 4GB of available RAM
- At least 10GB of free disk space

## Step 1: Install Required Tools

### Update Package Manager

```bash
# For Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# For CentOS/RHEL/Fedora
sudo yum update -y
# OR for newer versions
sudo dnf update -y
```

### Install curl and wget

```bash
# For Ubuntu/Debian
sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

# For CentOS/RHEL/Fedora
sudo yum install -y curl wget
# OR
sudo dnf install -y curl wget
```

### Install Container Runtime

You can choose between Docker (default) or Podman as your container runtime.

#### Option A: Install Docker

##### For Ubuntu/Debian:

```bash
# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index and install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Add user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker
```

#### For CentOS/RHEL/Fedora:

```bash
# Install Docker
sudo yum install -y docker
# OR for newer versions
sudo dnf install -y docker

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER
```

**Note:** Log out and log back in for group changes to take effect, or run:
```bash
newgrp docker
```

#### Option B: Install Podman (Alternative to Docker)

Podman provides a secure, rootless alternative to Docker.

##### For Ubuntu/Debian:

```bash
# Install Podman
sudo apt install -y podman

# Enable user session for rootless containers
systemctl --user enable --now podman.socket
```

##### For CentOS/RHEL/Fedora:

```bash
# Install Podman
sudo yum install -y podman
# OR for newer versions
sudo dnf install -y podman

# Enable user session for rootless containers
systemctl --user enable --now podman.socket
```

### Verify Container Runtime Installation

```bash
# For Docker
docker --version
docker run hello-world

# For Podman
podman --version
podman run hello-world
```

**Note for Podman Users:** The Dockerfile has been updated to handle Cargo home directory issues that can occur with rootless Podman builds. If you encounter build issues, see the [Podman Compatibility Guide](../../PODMAN.md) for additional troubleshooting steps.

### Install kubectl

```bash
# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client
```

### Install Minikube

```bash
# Download Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Install Minikube
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Verify installation
minikube version
```

### Install Rust

```bash
# Install Rust via rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Source the environment
source ~/.bashrc  # or ~/.zshrc if using zsh

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

### Troubleshoot Minikube Start Issues

If Minikube fails to start:

```bash
# For VirtualBox driver (alternative)
sudo apt install -y virtualbox virtualbox-ext-pack  # Ubuntu/Debian
# OR
sudo yum install -y VirtualBox  # CentOS/RHEL

# Start with VirtualBox driver
minikube start --driver=virtualbox --memory=4096 --cpus=2

# For KVM driver (alternative)
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils  # Ubuntu/Debian
sudo usermod -a -G libvirt $USER
newgrp libvirt

# Install KVM driver
curl -LO https://storage.googleapis.com/minikube/releases/latest/docker-machine-driver-kvm2
sudo install docker-machine-driver-kvm2 /usr/local/bin/

# Start with KVM driver
minikube start --driver=kvm2 --memory=4096 --cpus=2
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

## Step 4: Use the Operator Dockerfile

The project includes a production-ready Dockerfile that handles all necessary build requirements including proper home directory setup for Cargo (essential for Podman compatibility).

The Dockerfile is already present in the project root and includes:
- Multi-stage build with Chainguard secure base images
- Proper permission handling for rootless containers
- Cargo home directory configuration for Podman compatibility
- Optimized layer caching for dependencies

You can inspect the Dockerfile:
```bash
cat Dockerfile
```

## Step 5: Deploy to Minikube

### Install Custom Resource Definitions

```bash
# Install the OpenFGA CRDs
make install-crds

# Verify CRDs are installed
kubectl get crd openfgas.authorization.openfga.dev
```

### Build and Deploy the Operator

```bash
# Build container image (automatically detects Docker/Podman)
make container-build

# Alternatively, specify container runtime explicitly:
# CONTAINER_RUNTIME=docker make container-build
# CONTAINER_RUNTIME=podman make container-build

# Load image into Minikube
minikube image load openfga-operator:latest

# Deploy the operator with comprehensive RBAC configuration
# This includes namespace, service account, cluster role, cluster role binding, and deployment
kubectl apply -f examples/distroless-operator-deployment.yaml
```

## Step 6: Deploy OpenFGA Instances

### Deploy Basic OpenFGA Instance

```bash
# Deploy a basic OpenFGA instance
kubectl apply -f examples/basic-openfga.yaml

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s deployment/openfga-basic
```

### Deploy PostgreSQL-backed OpenFGA Instance (Vault-Managed Secrets - Recommended)

```bash
# Deploy Vault-managed PostgreSQL and OpenFGA
kubectl apply -k kustomize/base/vault/

# Initialize Vault with demo secrets
kubectl port-forward -n openfga-system svc/vault 8200:8200 &
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root
./scripts/init-vault.sh

# Deploy OpenFGA with Vault secrets
kubectl apply -f examples/postgres-openfga-vault.yaml
```

### Deploy PostgreSQL-backed OpenFGA Instance (Legacy - Manual Secrets)

⚠️ **SECURITY WARNING**: This approach uses hardcoded passwords and is NOT recommended for any environment. Use the Vault-managed approach above instead.

```bash
# First deploy PostgreSQL with manual secrets (NOT RECOMMENDED)
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
          value: CHANGE_ME_INSECURE_PASSWORD  # ⚠️ CHANGE THIS!
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        emptyDir: {}
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

## Step 7: Validation

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
pkill -f "kubectl port-forward"
```

## Step 8: Deploy Demo Applications (Optional)

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

# Port-forward to access
kubectl port-forward service/banking-app 3000:3000 &

echo "Banking app available at http://localhost:3000"
```

## Troubleshooting

### Common Issues

1. **Permission denied for Docker:**
   ```bash
   # Ensure user is in docker group
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **Minikube fails to start:**
   ```bash
   # Check system resources
   free -h
   df -h
   
   # Delete and recreate
   minikube delete
   minikube start --driver=docker --memory=4096 --cpus=2
   ```

3. **Pod stuck in ImagePullBackOff:**
   ```bash
   # Verify image is loaded
   minikube image ls | grep openfga-operator
   
   # Option 1: Use improved Minikube build (recommended)
   make minikube-build
   
   # Option 2: Reload image if needed (fallback)
   docker build -t openfga-operator:latest .
   minikube image load openfga-operator:latest
   ```

4. **Image not available in Minikube cluster:**
   ```bash
   # Use Minikube's Docker environment to build directly
   eval $(minikube docker-env)
   docker build -t openfga-operator:latest .
   
   # Verify image is now available
   minikube image ls | grep openfga-operator
   
   # Reset your shell environment when done
   eval $(minikube docker-env -u)
   ```

4. **DNS resolution issues:**
   ```bash
   # Check DNS pods
   kubectl get pods -n kube-system | grep coredns
   
   # Restart DNS if needed
   kubectl delete pod -n kube-system -l k8s-app=kube-dns
   ```

### Performance Tuning

```bash
# Monitor resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Increase Minikube resources if needed
minikube config set memory 6144
minikube config set cpus 4
minikube delete && minikube start
```

### Firewall Issues

```bash
# For Ubuntu/Debian with UFW
sudo ufw allow 2376/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 3000/tcp

# For CentOS/RHEL with firewalld
sudo firewall-cmd --permanent --add-port=2376/tcp
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
```

## Cleanup

When you're done testing, you have two options for cleanup:

### Option 1: Automated Cleanup (Recommended)

Use the comprehensive cleanup script that handles all operator resources:

```bash
# Complete cleanup with confirmation
scripts/minikube/cleanup-operator.sh

# Quick cleanup without confirmation
scripts/minikube/cleanup-operator.sh --force

# Cleanup but keep CRDs for faster re-deployment
scripts/minikube/cleanup-operator.sh --keep-crds

# Preview what would be deleted
scripts/minikube/cleanup-operator.sh --dry-run

# Show current status
scripts/minikube/cleanup-operator.sh --status
```

### Option 2: Manual Cleanup

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

The automated cleanup script provides better error handling, comprehensive resource removal, and additional options for different cleanup scenarios.

## Next Steps

- Explore the [Demo Applications](../../demos/)
- Read the [Architecture Documentation](../design/ARCHITECTURE.md)
- Try the [GenAI RAG Demo](../../demos/genai-rag-agent/)
- Check out the [Security Features](../security/SECURITY_ARCHITECTURE.md)

## Automation

For a fully automated setup, use the provided scripts with container runtime selection:

```bash
# Make scripts executable
chmod +x scripts/minikube/*.sh

# Setup with Docker (default)
./scripts/minikube/setup-minikube.sh
./scripts/minikube/deploy-operator.sh
./scripts/minikube/validate-deployment.sh

# Or setup with Podman
./scripts/minikube/setup-minikube.sh --runtime podman
CONTAINER_RUNTIME=podman ./scripts/minikube/deploy-operator.sh
./scripts/minikube/validate-deployment.sh
```

The scripts will automatically:
- Install the specified container runtime if not present
- Set up Minikube with the appropriate driver
- Build and deploy the operator using your chosen runtime