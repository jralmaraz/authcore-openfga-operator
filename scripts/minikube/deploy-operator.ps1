# deploy-operator.ps1 - Automated deployment of authcore-openfga-operator to Minikube on Windows
# Compatible with Windows 10/11 with PowerShell 5.1+

param(
    [switch]$SkipPostgres,
    [switch]$Force
)

# Error handling
$ErrorActionPreference = "Stop"

# Configuration
$OperatorNamespace = "openfga-system"
$OperatorImage = "openfga-operator:latest"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Colors for output
function Write-Info($message) {
    Write-Host "[INFO] $message" -ForegroundColor Blue
}

function Write-Success($message) {
    Write-Host "[SUCCESS] $message" -ForegroundColor Green
}

function Write-Warning($message) {
    Write-Host "[WARNING] $message" -ForegroundColor Yellow
}

function Write-Error-Custom($message) {
    Write-Host "[ERROR] $message" -ForegroundColor Red
}

# Check if command exists
function Test-CommandExists($command) {
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

# Check prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    $issues = 0
    
    if (-not (Test-CommandExists "kubectl")) {
        Write-Error-Custom "kubectl is not installed. Please run setup-minikube.ps1 first."
        $issues++
    }
    
    if (-not (Test-CommandExists "minikube")) {
        Write-Error-Custom "minikube is not installed. Please run setup-minikube.ps1 first."
        $issues++
    }
    
    if (-not (Test-CommandExists "docker")) {
        Write-Error-Custom "docker is not installed. Please run setup-minikube.ps1 first."
        $issues++
    }
    
    if (-not (Test-CommandExists "cargo")) {
        Write-Error-Custom "Rust/Cargo is not installed. Please run setup-minikube.ps1 first."
        $issues++
    }
    
    # Check if Minikube is running
    try {
        minikube status | Out-Null
        Write-Success "Minikube is running"
    }
    catch {
        Write-Error-Custom "Minikube is not running. Please run setup-minikube.ps1 first."
        $issues++
    }
    
    if ($issues -eq 0) {
        Write-Success "Prerequisites check passed"
        return $true
    }
    else {
        Write-Error-Custom "Prerequisites check failed with $issues issues"
        return $false
    }
}

# Build the operator
function Build-Operator {
    Write-Info "Building the operator..."
    
    Set-Location $ProjectRoot
    
    # Compile and test
    Write-Info "Running compile check..."
    make compile
    
    Write-Info "Running tests..."
    make test
    
    Write-Info "Building release binary..."
    make build
    
    Write-Success "Operator build completed"
}

# Build Docker image
function Build-DockerImage {
    Write-Info "Building Docker image..."
    
    Set-Location $ProjectRoot
    
    # Build the Docker image
    docker build -t $OperatorImage .
    
    # Load image into Minikube
    Write-Info "Loading image into Minikube..."
    minikube image load $OperatorImage
    
    Write-Success "Docker image built and loaded into Minikube"
}

# Install CRDs
function Install-CRDs {
    Write-Info "Installing Custom Resource Definitions..."
    
    Set-Location $ProjectRoot
    
    # Install CRDs
    make install-crds
    
    # Verify CRDs are installed
    kubectl get crd openfgas.authorization.openfga.dev | Out-Null
    
    Write-Success "CRDs installed successfully"
}

# Create namespace
function New-Namespace {
    Write-Info "Creating namespace $OperatorNamespace..."
    
    try {
        kubectl get namespace $OperatorNamespace | Out-Null
        Write-Info "Namespace $OperatorNamespace already exists"
    }
    catch {
        kubectl create namespace $OperatorNamespace
        Write-Success "Namespace $OperatorNamespace created"
    }
}

# Create RBAC resources
function New-RBAC {
    Write-Info "Creating RBAC resources..."
    
    $rbacYaml = @"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openfga-operator
  namespace: $OperatorNamespace
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
  namespace: $OperatorNamespace
"@
    
    $rbacYaml | kubectl apply -f -
    
    Write-Success "RBAC resources created"
}

# Deploy the operator
function Deploy-Operator {
    Write-Info "Deploying the operator..."
    
    $deploymentYaml = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openfga-operator
  namespace: $OperatorNamespace
  labels:
    app: openfga-operator
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
        image: $OperatorImage
        imagePullPolicy: Never
        ports:
        - containerPort: 8080
          name: metrics
        env:
        - name: RUST_LOG
          value: "info"
        resources:
          limits:
            memory: "256Mi"
            cpu: "500m"
          requests:
            memory: "128Mi"
            cpu: "100m"
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
---
apiVersion: v1
kind: Service
metadata:
  name: openfga-operator-metrics
  namespace: $OperatorNamespace
  labels:
    app: openfga-operator
spec:
  selector:
    app: openfga-operator
  ports:
  - name: metrics
    port: 8080
    targetPort: 8080
"@
    
    $deploymentYaml | kubectl apply -f -
    
    Write-Success "Operator deployment created"
}

# Wait for operator to be ready
function Wait-ForOperator {
    Write-Info "Waiting for operator to be ready..."
    
    # Wait for deployment to be available
    kubectl wait --for=condition=available --timeout=300s deployment/openfga-operator -n $OperatorNamespace
    
    Write-Success "Operator is ready"
}

# Deploy example OpenFGA instances
function Deploy-Examples {
    Write-Info "Deploying example OpenFGA instances..."
    
    Set-Location $ProjectRoot
    
    # Deploy basic OpenFGA instance
    Write-Info "Deploying basic OpenFGA instance..."
    kubectl apply -f examples/basic-openfga.yaml
    
    # Wait for basic instance to be ready
    try {
        kubectl wait --for=condition=available --timeout=300s deployment/openfga-basic 2>$null
    }
    catch {
        Write-Warning "Basic OpenFGA instance deployment may take a few more minutes"
    }
    
    Write-Success "Example instances deployed"
}

# Deploy PostgreSQL and PostgreSQL-backed OpenFGA
function Deploy-PostgresExample {
    Write-Info "Deploying PostgreSQL example..."
    
    # Deploy PostgreSQL
    $postgresYaml = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: default
  labels:
    app: postgres
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
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          limits:
            memory: "256Mi"
            cpu: "250m"
          requests:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: postgres-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: default
  labels:
    app: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
"@
    
    $postgresYaml | kubectl apply -f -
    
    # Wait for PostgreSQL to be ready
    Write-Info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/postgres
    
    # Deploy PostgreSQL-backed OpenFGA
    Write-Info "Deploying PostgreSQL-backed OpenFGA instance..."
    kubectl apply -f examples/postgres-openfga.yaml
    
    Write-Success "PostgreSQL example deployed"
}

# Show deployment status
function Show-Status {
    Write-Info "Deployment status:"
    Write-Host ""
    
    Write-Host "Operator status:"
    kubectl get pods -n $OperatorNamespace
    Write-Host ""
    
    Write-Host "OpenFGA instances:"
    kubectl get openfgas
    Write-Host ""
    
    Write-Host "Services:"
    kubectl get services
    Write-Host ""
    
    Write-Host "All deployments:"
    kubectl get deployments
}

# Print next steps
function Write-NextSteps {
    Write-Host ""
    Write-Success "Deployment completed successfully!"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Run '.\scripts\minikube\validate-deployment.ps1' to validate the deployment"
    Write-Host "2. Access OpenFGA API:"
    Write-Host "   kubectl port-forward service/openfga-basic-http 8080:8080"
    Write-Host "   Invoke-RestMethod -Uri 'http://localhost:8080/healthz'"
    Write-Host ""
    Write-Host "3. Deploy demo applications:"
    Write-Host "   cd demos/banking-app"
    Write-Host "   kubectl apply -f k8s/"
    Write-Host ""
    Write-Host "4. Monitor the operator:"
    Write-Host "   kubectl logs -n $OperatorNamespace deployment/openfga-operator -f"
    Write-Host ""
    Write-Host "For more information, see the documentation in docs/minikube/"
}

# Main function
function Main {
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "  authcore-openfga-operator Deployment to Minikube" -ForegroundColor Cyan
    Write-Host "  Windows PowerShell Edition" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Check prerequisites
        if (-not (Test-Prerequisites)) {
            exit 1
        }
        
        # Build the operator
        Build-Operator
        
        # Build Docker image
        Build-DockerImage
        
        # Install CRDs
        Install-CRDs
        
        # Create namespace
        New-Namespace
        
        # Create RBAC resources
        New-RBAC
        
        # Deploy the operator
        Deploy-Operator
        
        # Wait for operator to be ready
        Wait-ForOperator
        
        # Deploy example instances
        Deploy-Examples
        
        # Ask user if they want to deploy PostgreSQL example
        if (-not $SkipPostgres) {
            Write-Host ""
            $response = Read-Host "Do you want to deploy PostgreSQL example? (y/N)"
            if ($response -match "^[Yy]") {
                Deploy-PostgresExample
            }
        }
        
        # Show deployment status
        Show-Status
        
        # Print next steps
        Write-NextSteps
    }
    catch {
        Write-Error-Custom "Deployment failed: $($_.Exception.Message)"
        Write-Error-Custom $_.ScriptStackTrace
        exit 1
    }
}

# Run main function
Main