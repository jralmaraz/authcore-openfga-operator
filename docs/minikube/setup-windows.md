# Windows Setup Guide for authcore-openfga-operator with Minikube

This guide provides step-by-step instructions for setting up and running the authcore-openfga-operator on Windows using Minikube.

## Prerequisites

- Windows 10 version 2004 or higher, or Windows 11
- Administrator privileges
- At least 4GB of available RAM
- At least 10GB of free disk space
- Hyper-V or Docker Desktop support

## Step 1: Install Required Tools

### Enable WSL2 (Windows Subsystem for Linux)

1. **Open PowerShell as Administrator** and run:
   ```powershell
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   ```

2. **Restart your computer**

3. **Download and install the WSL2 kernel update:**
   - Visit https://aka.ms/wsl2kernel
   - Download and install the WSL2 Linux kernel update package

4. **Set WSL2 as default:**
   ```powershell
   wsl --set-default-version 2
   ```

### Install Docker Desktop

1. **Download Docker Desktop:**
   - Visit https://www.docker.com/products/docker-desktop
   - Download Docker Desktop for Windows
   - Install with default settings
   - Ensure "Use WSL 2 based engine" is enabled

2. **Start Docker Desktop** and verify installation:
   ```powershell
   docker --version
   docker run hello-world
   ```

### Install Chocolatey (Package Manager)

1. **Open PowerShell as Administrator** and run:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
   iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
   ```

2. **Restart PowerShell** and verify:
   ```powershell
   choco --version
   ```

### Install kubectl

```powershell
# Install kubectl via Chocolatey
choco install kubernetes-cli

# Verify installation
kubectl version --client
```

### Install Minikube

```powershell
# Install Minikube via Chocolatey
choco install minikube

# Verify installation
minikube version
```

### Install Git (if not already installed)

```powershell
# Install Git via Chocolatey
choco install git

# Verify installation
git --version
```

### Install Rust

1. **Download and install Rust:**
   - Visit https://rustup.rs/
   - Download and run rustup-init.exe
   - Follow the installation prompts (select default options)

2. **Restart PowerShell** and verify:
   ```powershell
   rustc --version
   cargo --version
   ```

## Step 2: Start Minikube

### Option A: Using Docker Driver (Recommended)

```powershell
# Start Minikube with Docker driver
minikube start --driver=docker --memory=4096 --cpus=2

# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server

# Verify Minikube is running
minikube status
kubectl cluster-info
```

### Option B: Using Hyper-V Driver

If you prefer Hyper-V:

1. **Enable Hyper-V** (if not already enabled):
   ```powershell
   # Run as Administrator
   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
   ```

2. **Restart your computer**

3. **Start Minikube with Hyper-V:**
   ```powershell
   minikube start --driver=hyperv --memory=4096 --cpus=2
   ```

## Step 3: Set Up the Project

### Clone the Repository

```powershell
# Clone the repository
git clone https://github.com/jralmaraz/authcore-openfga-operator.git
cd authcore-openfga-operator
```

### Build the Operator

```powershell
# Compile and check the project
make compile

# Run tests to ensure everything works
make test

# Build the release binary
make build
```

**Note:** If `make` is not available, install it via Chocolatey:
```powershell
choco install make
```

## Step 4: Create Dockerfile for the Operator

Create a Dockerfile in the project root:

```powershell
# Create Dockerfile
@"
# Build stage
FROM cgr.dev/chainguard/rust:latest as builder

WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src/ ./src/

# Build the application
RUN cargo build --release

# Runtime stage
FROM cgr.dev/chainguard/wolfi-base:latest

# Install CA certificates and other runtime dependencies
RUN apk add --no-cache \
    ca-certificates

# Create non-root user
RUN groupadd -r openfga && useradd -r -g openfga openfga

# Copy binary from builder stage
COPY --from=builder /app/target/release/openfga-operator /usr/local/bin/openfga-operator

# Set ownership and permissions
RUN chown openfga:openfga /usr/local/bin/openfga-operator
USER openfga

EXPOSE 8080

CMD ["openfga-operator"]
"@ | Out-File -FilePath Dockerfile -Encoding ASCII
```

## Step 5: Deploy to Minikube

### Install Custom Resource Definitions

```powershell
# Install the OpenFGA CRDs
make install-crds

# Verify CRDs are installed
kubectl get crd openfgas.authorization.openfga.dev
```

### Build and Deploy the Operator

```powershell
# Build Docker image
docker build -t openfga-operator:latest .

# Load image into Minikube
minikube image load openfga-operator:latest

# Create namespace for the operator
kubectl create namespace openfga-system
```

### Create RBAC Resources

```powershell
# Create RBAC configuration
@"
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
"@ | kubectl apply -f -
```

### Deploy the Operator

```powershell
# Create operator deployment
@"
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
      serviceAccountName: openfga-operator
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
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
"@ | kubectl apply -f -
```

## Step 6: Deploy OpenFGA Instances

### Deploy Basic OpenFGA Instance

```powershell
# Deploy a basic OpenFGA instance
kubectl apply -f examples/basic-openfga.yaml

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s deployment/openfga-basic
```

### Deploy PostgreSQL-backed OpenFGA Instance (Optional)

```powershell
# Deploy PostgreSQL
@"
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
"@ | kubectl apply -f -

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=available --timeout=300s deployment/postgres

# Deploy PostgreSQL-backed OpenFGA
kubectl apply -f examples/postgres-openfga.yaml
```

## Step 7: Validation

### Verify Operator Status

```powershell
# Check operator pod status
kubectl get pods -n openfga-system

# Check operator logs
kubectl logs -n openfga-system deployment/openfga-operator

# Check for any errors
kubectl describe pods -n openfga-system
```

### Verify OpenFGA Instances

```powershell
# List OpenFGA custom resources
kubectl get openfgas

# Check OpenFGA deployments
kubectl get deployments

# Check OpenFGA services
kubectl get services
```

### Test OpenFGA API Access

```powershell
# Start port-forward in background (using PowerShell job)
Start-Job -ScriptBlock { kubectl port-forward service/openfga-basic-http 8080:8080 }

# Wait a moment for port-forward to establish
Start-Sleep -Seconds 5

# Test API
Invoke-RestMethod -Uri "http://localhost:8080/healthz" -Method Get

# Test stores endpoint
Invoke-RestMethod -Uri "http://localhost:8080/stores" -Method Get

# Stop port-forward jobs
Get-Job | Stop-Job
Get-Job | Remove-Job
```

## Step 8: Deploy Demo Applications (Optional)

### Deploy Banking Demo

```powershell
# Navigate to banking demo
cd demos/banking-app

# Build and deploy
docker build -t banking-app:latest .
minikube image load banking-app:latest
kubectl apply -f k8s/

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s deployment/banking-app

# Port-forward to access (in background)
Start-Job -ScriptBlock { kubectl port-forward service/banking-app 3000:3000 }

Write-Host "Banking app will be available at http://localhost:3000"
Write-Host "Use 'Get-Job | Stop-Job; Get-Job | Remove-Job' to stop port-forwarding"
```

## Troubleshooting

### Common Issues

1. **Docker Desktop not starting:**
   - Restart Docker Desktop
   - Check Windows features (Hyper-V or WSL2)
   - Check antivirus software interference

2. **Minikube fails to start:**
   ```powershell
   # Check system resources
   Get-ComputerInfo | Select-Object TotalPhysicalMemory,CsProcessors
   
   # Delete and recreate
   minikube delete
   minikube start --driver=docker --memory=4096 --cpus=2
   ```

3. **Permission issues:**
   ```powershell
   # Run PowerShell as Administrator
   # Ensure Docker Desktop is running with admin privileges
   ```

4. **Network connectivity issues:**
   ```powershell
   # Check Windows Firewall
   # Allow Docker Desktop through firewall
   # Check corporate proxy settings
   ```

### Performance Issues

```powershell
# Monitor resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Increase Minikube resources
minikube config set memory 6144
minikube config set cpus 4
minikube delete
minikube start
```

### WSL2 Issues

```powershell
# Check WSL status
wsl --list --verbose

# Restart WSL if needed
wsl --shutdown
# Wait 10 seconds then restart Docker Desktop
```

## Cleanup

When you're done testing:

```powershell
# Stop any running port-forward jobs
Get-Job | Stop-Job
Get-Job | Remove-Job

# Delete OpenFGA instances
kubectl delete openfgas --all

# Delete demo applications
kubectl delete -f demos/banking-app/k8s/ 2>$null

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

For a fully automated setup, use the provided PowerShell scripts:

```powershell
# Set execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run the automated setup scripts
.\scripts\minikube\setup-minikube.ps1
.\scripts\minikube\deploy-operator.ps1
.\scripts\minikube\validate-deployment.ps1
```

## Alternative: Using Windows Terminal and WSL2

For a Linux-like experience on Windows:

1. **Install Windows Terminal** from Microsoft Store
2. **Install Ubuntu** from Microsoft Store
3. **Follow the Linux setup guide** from within Ubuntu WSL2
4. **Access applications** from Windows using `localhost`

This approach provides better compatibility with Linux-oriented tools and scripts.