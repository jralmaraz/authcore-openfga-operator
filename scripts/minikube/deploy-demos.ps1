# deploy-demos.ps1 - Deploy OpenFGA Operator demo applications to Minikube (Windows)

param(
    [switch]$Banking,
    [switch]$GenAI,
    [switch]$SkipBuild,
    [switch]$SkipSetup,
    [switch]$Help
)

# Configuration
$OPERATOR_NAMESPACE = "openfga-system"
$DEMO_NAMESPACE = "default"
$BANKING_APP_IMAGE = "banking-app:latest"
$GENAI_APP_IMAGE = "genai-rag-agent:latest"
$TIMEOUT = 300
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Demo application configuration
$BANKING_APP_PORT = 3000
$GENAI_APP_PORT = 8000

# Logging functions
function Write-Info($message) {
    Write-Host "[INFO] $message" -ForegroundColor Blue
}

function Write-Success($message) {
    Write-Host "[SUCCESS] $message" -ForegroundColor Green
}

function Write-Warning($message) {
    Write-Host "[WARNING] $message" -ForegroundColor Yellow
}

function Write-Error($message) {
    Write-Host "[ERROR] $message" -ForegroundColor Red
}

# Check if command exists
function Test-Command($command) {
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

# Wait for deployment to be ready
function Wait-ForDeployment($deploymentName, $namespace, $timeoutSec) {
    Write-Info "Waiting for deployment $deploymentName to be ready (timeout: ${timeoutSec}s)..."
    
    try {
        kubectl wait --for=condition=available --timeout="${timeoutSec}s" deployment/$deploymentName -n $namespace 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Deployment $deploymentName is ready"
            return $true
        } else {
            Write-Warning "Deployment $deploymentName may not be fully ready yet"
            return $false
        }
    } catch {
        Write-Warning "Deployment $deploymentName may not be fully ready yet"
        return $false
    }
}

# Check prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    if (-not (Test-Command "kubectl")) {
        Write-Error "kubectl is not installed. Please run setup-minikube.ps1 first."
        exit 1
    }
    
    if (-not (Test-Command "minikube")) {
        Write-Error "minikube is not installed. Please run setup-minikube.ps1 first."
        exit 1
    }
    
    # Check if Minikube is running
    try {
        minikube status 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Minikube is not running. Please start Minikube first."
            exit 1
        }
    } catch {
        Write-Error "Minikube is not running. Please start Minikube first."
        exit 1
    }
    
    # Check container runtime
    $runtime = $null
    if (Test-Command "docker") {
        try {
            docker info 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $runtime = "docker"
            }
        } catch {}
    }
    
    if (-not $runtime -and (Test-Command "podman")) {
        try {
            podman info 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $runtime = "podman"
            }
        } catch {}
    }
    
    if (-not $runtime) {
        Write-Error "No container runtime (Docker or Podman) is available."
        exit 1
    }
    
    Write-Info "Using container runtime: $runtime"
    
    # Check if Node.js is available for banking app
    if (-not (Test-Command "node")) {
        Write-Warning "Node.js not found. Banking app build may fail."
    }
    
    # Check if Python is available for GenAI app
    if (-not (Test-Command "python")) {
        Write-Warning "Python not found. GenAI app build may fail."
    }
    
    Write-Success "Prerequisites check passed"
    return $runtime
}

# Verify operator is deployed
function Test-OperatorDeployment {
    Write-Info "Verifying OpenFGA operator deployment..."
    
    # Check if operator namespace exists
    try {
        kubectl get namespace $OPERATOR_NAMESPACE 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "OpenFGA operator namespace '$OPERATOR_NAMESPACE' does not exist."
            Write-Info "Please run deploy-operator.ps1 first to deploy the operator."
            exit 1
        }
    } catch {
        Write-Error "OpenFGA operator namespace '$OPERATOR_NAMESPACE' does not exist."
        Write-Info "Please run deploy-operator.ps1 first to deploy the operator."
        exit 1
    }
    
    # Check if operator deployment exists and is ready
    try {
        kubectl get deployment openfga-operator -n $OPERATOR_NAMESPACE 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "OpenFGA operator deployment does not exist."
            Write-Info "Please run deploy-operator.ps1 first to deploy the operator."
            exit 1
        }
    } catch {
        Write-Error "OpenFGA operator deployment does not exist."
        Write-Info "Please run deploy-operator.ps1 first to deploy the operator."
        exit 1
    }
    
    # Wait for operator to be ready
    try {
        kubectl wait --for=condition=available --timeout=60s deployment/openfga-operator-project-controller-manager -n $OPERATOR_NAMESPACE 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "OpenFGA operator deployment is not ready."
            Write-Info "Please ensure the operator is running properly."
            exit 1
        }
    } catch {
        Write-Error "OpenFGA operator deployment is not ready."
        Write-Info "Please ensure the operator is running properly."
        exit 1
    }
    
    Write-Success "OpenFGA operator is deployed and ready"
}

# Deploy basic OpenFGA instance if needed
function Deploy-OpenFGAInstance {
    Write-Info "Checking for OpenFGA instances..."
    
    # Check if basic OpenFGA instance exists
    try {
        kubectl get openfga openfga-basic -n $DEMO_NAMESPACE 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Basic OpenFGA instance already exists"
        } else {
            Write-Info "Deploying basic OpenFGA instance..."
            Set-Location $PROJECT_ROOT
            kubectl apply -f examples/basic-openfga.yaml
            
            # Wait for OpenFGA deployment
            Write-Info "Waiting for OpenFGA instance to be ready..."
            Start-Sleep 10  # Give it a moment to start creating resources
            
            try {
                kubectl wait --for=condition=available --timeout=300s deployment/openfga-basic -n $DEMO_NAMESPACE 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "OpenFGA instance is ready"
                } else {
                    Write-Warning "OpenFGA instance may need more time to start"
                }
            } catch {
                Write-Warning "OpenFGA instance may need more time to start"
            }
        }
    } catch {
        Write-Info "Deploying basic OpenFGA instance..."
        Set-Location $PROJECT_ROOT
        kubectl apply -f examples/basic-openfga.yaml
    }
}

# Build and load banking app image
function Build-BankingApp($runtime) {
    Write-Info "Building Banking Application..."
    
    Set-Location "$PROJECT_ROOT/demos/banking-app"
    
    # Install dependencies if package.json exists
    if (Test-Path "package.json") {
        Write-Info "Installing Node.js dependencies..."
        npm install
        
        Write-Info "Building TypeScript application..."
        npm run build
    }
    
    # Build Docker image
    Write-Info "Building Docker image: $BANKING_APP_IMAGE"
    & $runtime build -t $BANKING_APP_IMAGE .
    
    # Load image into Minikube
    Write-Info "Loading image into Minikube..."
    minikube image load $BANKING_APP_IMAGE
    
    Write-Success "Banking app image built and loaded"
}

# Build and load GenAI RAG app image
function Build-GenAIApp($runtime) {
    Write-Info "Building GenAI RAG Agent..."
    
    Set-Location "$PROJECT_ROOT/demos/genai-rag-agent"
    
    # Build Docker image
    Write-Info "Building Docker image: $GENAI_APP_IMAGE"
    & $runtime build -t $GENAI_APP_IMAGE .
    
    # Load image into Minikube
    Write-Info "Loading image into Minikube..."
    minikube image load $GENAI_APP_IMAGE
    
    Write-Success "GenAI RAG agent image built and loaded"
}

# Deploy banking application
function Deploy-BankingApp {
    Write-Info "Deploying Banking Application..."
    
    Set-Location "$PROJECT_ROOT/demos/banking-app"
    
    # Apply Kubernetes manifests
    kubectl apply -f k8s/deployment.yaml
    
    # Wait for deployment
    Wait-ForDeployment "banking-demo-app" $DEMO_NAMESPACE $TIMEOUT
    
    Write-Success "Banking application deployed"
}

# Deploy GenAI RAG application  
function Deploy-GenAIApp {
    Write-Info "Deploying GenAI RAG Agent..."
    
    Set-Location "$PROJECT_ROOT/demos/genai-rag-agent"
    
    # Apply Kubernetes manifests
    kubectl apply -f k8s/deployment.yaml
    
    # Wait for deployment
    Wait-ForDeployment "genai-rag-agent" $DEMO_NAMESPACE $TIMEOUT
    
    Write-Success "GenAI RAG agent deployed"
}

# Setup demo data for applications
function Set-DemoData {
    Write-Info "Setting up demo data..."
    
    # Wait a bit for services to stabilize
    Start-Sleep 10
    
    # Setup banking app demo data
    Write-Info "Setting up banking app demo data..."
    try {
        kubectl get pod -l app=banking-demo -n $DEMO_NAMESPACE 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $bankingPod = kubectl get pod -l app=banking-demo -n $DEMO_NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>$null
            
            if ($bankingPod) {
                try {
                    kubectl exec -n $DEMO_NAMESPACE $bankingPod -- npm run setup 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Banking app demo data setup complete"
                    } else {
                        Write-Warning "Banking app demo data setup failed - this is normal if OpenFGA is still starting"
                    }
                } catch {
                    Write-Warning "Banking app demo data setup failed - this is normal if OpenFGA is still starting"
                }
            }
        }
    } catch {
        Write-Warning "Banking app not found for demo data setup"
    }
    
    # Setup GenAI app demo data
    Write-Info "Setting up GenAI RAG agent demo data..."
    try {
        kubectl get pod -l app=genai-rag-agent -n $DEMO_NAMESPACE 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $genaiPod = kubectl get pod -l app=genai-rag-agent -n $DEMO_NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>$null
            
            if ($genaiPod) {
                try {
                    kubectl exec -n $DEMO_NAMESPACE $genaiPod -- python setup.py 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "GenAI RAG agent demo data setup complete"
                    } else {
                        Write-Warning "GenAI RAG agent demo data setup failed - this is normal if OpenFGA is still starting"
                    }
                } catch {
                    Write-Warning "GenAI RAG agent demo data setup failed - this is normal if OpenFGA is still starting"
                }
            }
        }
    } catch {
        Write-Warning "GenAI RAG agent not found for demo data setup"
    }
}

# Display deployment status
function Show-DeploymentStatus {
    Write-Info "Deployment Status:"
    Write-Host ""
    
    Write-Host "OpenFGA Operator:"
    try {
        kubectl get pods -n $OPERATOR_NAMESPACE --no-headers 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  No pods found"
        }
    } catch {
        Write-Host "  No pods found"
    }
    Write-Host ""
    
    Write-Host "OpenFGA Instances:"
    try {
        kubectl get openfgas -n $DEMO_NAMESPACE --no-headers 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  No instances found"
        }
    } catch {
        Write-Host "  No instances found"
    }
    Write-Host ""
    
    Write-Host "Demo Applications:"
    try {
        kubectl get deployments -n $DEMO_NAMESPACE -l app=banking-demo --no-headers 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Banking app: Not deployed"
        }
    } catch {
        Write-Host "  Banking app: Not deployed"
    }
    
    try {
        kubectl get deployments -n $DEMO_NAMESPACE -l app=genai-rag-agent --no-headers 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  GenAI app: Not deployed"
        }
    } catch {
        Write-Host "  GenAI app: Not deployed"
    }
    Write-Host ""
    
    Write-Host "Services:"
    try {
        kubectl get services -n $DEMO_NAMESPACE -l app=banking-demo --no-headers 2>$null
    } catch {}
    try {
        kubectl get services -n $DEMO_NAMESPACE -l app=genai-rag-agent --no-headers 2>$null
    } catch {}
    Write-Host ""
}

# Print access instructions
function Show-AccessInstructions {
    Write-Host ""
    Write-Success "Demo applications deployed successfully!"
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "            ACCESS INSTRUCTIONS" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Banking Application:"
    Write-Host "   # Port-forward to access:"
    Write-Host "   kubectl port-forward service/banking-demo-service 3000:80"
    Write-Host "   # Then open: http://localhost:3000"
    Write-Host "   # API Health: curl http://localhost:3000/health"
    Write-Host ""
    Write-Host "2. GenAI RAG Agent:"
    Write-Host "   # Port-forward to access:"
    Write-Host "   kubectl port-forward service/genai-rag-agent-service 8000:80"
    Write-Host "   # Then open: http://localhost:8000/docs"
    Write-Host "   # API Health: curl http://localhost:8000/health"
    Write-Host ""
    Write-Host "3. OpenFGA API (if needed):"
    Write-Host "   # Port-forward to access:"
    Write-Host "   kubectl port-forward service/openfga-basic-http 8080:8080"
    Write-Host "   # API Health: curl http://localhost:8080/healthz"
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "            DEMO USAGE EXAMPLES" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Banking App API Examples:"
    Write-Host "   # List accounts"
    Write-Host "   curl -H 'x-user-id: alice' http://localhost:3000/api/accounts"
    Write-Host ""
    Write-Host "   # Create transaction"
    Write-Host "   curl -X POST http://localhost:3000/api/transactions \"
    Write-Host "     -H 'x-user-id: alice' \"
    Write-Host "     -H 'Content-Type: application/json' \"
    Write-Host "     -d '{\"from\": \"acc_001\", \"to\": \"acc_002\", \"amount\": 100}'"
    Write-Host ""
    Write-Host "GenAI RAG API Examples:"
    Write-Host "   # List knowledge bases"
    Write-Host "   curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases"
    Write-Host ""
    Write-Host "   # Create chat session"
    Write-Host "   curl -X POST http://localhost:8000/api/chat/sessions \"
    Write-Host "     -H 'x-user-id: alice' \"
    Write-Host "     -H 'Content-Type: application/json' \"
    Write-Host "     -d '{\"name\": \"Demo Chat\", \"organization_id\": \"demo-org\", \"knowledge_base_ids\": [\"kb_demo\"], \"model_id\": \"gpt-3.5-turbo\"}'"
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "            TROUBLESHOOTING" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "If services are not accessible:"
    Write-Host "1. Check pod status: kubectl get pods"
    Write-Host "2. Check logs: kubectl logs -l app=banking-demo"
    Write-Host "3. Check logs: kubectl logs -l app=genai-rag-agent"
    Write-Host "4. Restart setup: ./scripts/minikube/validate-demos.ps1"
    Write-Host ""
    Write-Host "To stop port-forwarding:"
    Write-Host "   Get-Process | Where-Object {`$_.ProcessName -eq 'kubectl'} | Stop-Process"
    Write-Host ""
    Write-Host "For more help, see: docs/minikube/"
}

# Show help
function Show-Help {
    Write-Host "Usage: .\deploy-demos.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Deploy OpenFGA Operator demo applications to Minikube"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Banking      Deploy only the banking application"
    Write-Host "  -GenAI        Deploy only the GenAI RAG agent"
    Write-Host "  -SkipBuild    Skip building container images"
    Write-Host "  -SkipSetup    Skip setting up demo data"
    Write-Host "  -Help         Show this help message"
    Write-Host ""
    Write-Host "If no specific demo is selected, both will be deployed."
}

# Main function
function Main {
    if ($Help) {
        Show-Help
        exit 0
    }
    
    $demoApps = @()
    
    # Determine which demos to deploy
    if ($Banking) {
        $demoApps += "banking"
    }
    if ($GenAI) {
        $demoApps += "genai"
    }
    
    # If no specific demo selected, deploy both
    if ($demoApps.Count -eq 0) {
        $demoApps = @("banking", "genai")
    }
    
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "  OpenFGA Demo Applications Deployment to Minikube" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Deploying: $($demoApps -join ', ')"
    if ($SkipBuild) { Write-Host "Skipping: Image building" }
    if ($SkipSetup) { Write-Host "Skipping: Demo data setup" }
    Write-Host ""
    
    try {
        # Run deployment steps
        $runtime = Test-Prerequisites
        Test-OperatorDeployment
        Deploy-OpenFGAInstance
        
        # Build and deploy selected applications
        foreach ($app in $demoApps) {
            switch ($app) {
                "banking" {
                    if (-not $SkipBuild) {
                        Build-BankingApp $runtime
                    }
                    Deploy-BankingApp
                }
                "genai" {
                    if (-not $SkipBuild) {
                        Build-GenAIApp $runtime
                    }
                    Deploy-GenAIApp
                }
            }
        }
        
        # Setup demo data if not skipped
        if (-not $SkipSetup) {
            Set-DemoData
        }
        
        # Show status and instructions
        Show-DeploymentStatus
        Show-AccessInstructions
        
    } catch {
        Write-Error "Deployment failed: $($_.Exception.Message)"
        Write-Host ""
        Write-Host "Common issues and solutions:"
        Write-Host "1. Minikube not running: minikube start"
        Write-Host "2. Operator not deployed: .\scripts\minikube\deploy-operator.ps1"
        Write-Host "3. Resource issues: minikube config set memory 8192"
        Write-Host "4. Build failures: Check Docker and Node.js/Python installations"
        exit 1
    }
}

# Execute main function
Main