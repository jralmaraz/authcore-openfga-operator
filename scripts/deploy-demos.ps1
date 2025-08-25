# deploy-demos.ps1 - Deploy Both Demo Applications for Local Testing (Windows)
# This script builds and deploys both the banking and GenAI RAG demo applications to Minikube/Kubernetes
# Compatible with Windows PowerShell and PowerShell Core

param(
    [switch]$BankingOnly,
    [switch]$GenaiOnly,
    [switch]$Cleanup,
    [switch]$TestOnly,
    [switch]$Status,
    [switch]$SkipBuild,
    [switch]$Help
)

# Configuration
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

# Colors for output (if supported)
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$Blue = [System.ConsoleColor]::Blue

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

# Check if command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Check prerequisites for both demos
function Test-Prerequisites {
    Write-Info "Checking prerequisites for demo deployment..."
    
    $missingTools = @()
    
    if (!(Test-Command "kubectl")) {
        $missingTools += "kubectl"
    }
    
    if (!(Test-Command "node")) {
        $missingTools += "node (for banking demo)"
    }
    
    if (!(Test-Command "npm")) {
        $missingTools += "npm (for banking demo)"
    }
    
    if (!(Test-Command "python")) {
        $missingTools += "python (for GenAI demo)"
    }
    
    if (!(Test-Command "pip")) {
        $missingTools += "pip (for GenAI demo)"
    }
    
    if (!(Test-Command "docker") -and !(Test-Command "podman")) {
        $missingTools += "docker or podman"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Error "Missing required tools: $($missingTools -join ', ')"
        Write-Host "Please install the missing tools and try again."
        exit 1
    }
    
    # Check Kubernetes cluster access
    try {
        kubectl cluster-info | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "kubectl cluster-info failed"
        }
    }
    catch {
        Write-Error "Cannot connect to Kubernetes cluster"
        Write-Host "Please ensure kubectl is configured and cluster is accessible."
        Write-Host "For Minikube: run 'minikube start'"
        exit 1
    }
    
    Write-Success "All prerequisites satisfied"
}

# Deploy both demo applications
function Deploy-BothDemos {
    param([string[]]$ScriptArgs)
    
    $bankingSuccess = $true
    $genaiSuccess = $true
    
    Write-Host "=========================================="
    Write-Host "  DEPLOYING BANKING DEMO APPLICATION"
    Write-Host "=========================================="
    Write-Host ""
    
    # Deploy banking demo
    try {
        & "$SCRIPT_DIR\deploy-banking-demo.ps1" @ScriptArgs
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Banking demo deployment completed"
        } else {
            throw "Banking demo deployment failed"
        }
    }
    catch {
        Write-Error "Banking demo deployment failed"
        $bankingSuccess = $false
    }
    
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  DEPLOYING GENAI RAG DEMO APPLICATION"
    Write-Host "=========================================="
    Write-Host ""
    
    # Deploy GenAI demo  
    try {
        & "$SCRIPT_DIR\deploy-genai-demo.ps1" @ScriptArgs
        if ($LASTEXITCODE -eq 0) {
            Write-Success "GenAI RAG demo deployment completed"
        } else {
            throw "GenAI RAG demo deployment failed"
        }
    }
    catch {
        Write-Error "GenAI RAG demo deployment failed"
        $genaiSuccess = $false
    }
    
    # Summary
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "           DEPLOYMENT SUMMARY"
    Write-Host "=========================================="
    Write-Host ""
    
    if ($bankingSuccess) {
        Write-Host "✅ Banking Demo: Successfully deployed"
    } else {
        Write-Host "❌ Banking Demo: Deployment failed"
    }
    
    if ($genaiSuccess) {
        Write-Host "✅ GenAI RAG Demo: Successfully deployed"
    } else {
        Write-Host "❌ GenAI RAG Demo: Deployment failed"
    }
    
    if ($bankingSuccess -or $genaiSuccess) {
        Show-CombinedAccessGuide $bankingSuccess $genaiSuccess
    }
    
    if (-not $bankingSuccess -or -not $genaiSuccess) {
        Write-Host ""
        Write-Warning "Some deployments failed. Check the logs above for details."
        return $false
    }
    
    return $true
}

# Show combined access guide for both demos
function Show-CombinedAccessGuide {
    param([bool]$BankingSuccess, [bool]$GenaiSuccess)
    
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "        DEMO ACCESS GUIDE"
    Write-Host "=========================================="
    Write-Host ""
    
    if ($BankingSuccess) {
        Write-Host "🏦 BANKING DEMO:"
        Write-Host "   Access: kubectl port-forward service/banking-demo-service 3000:80"
        Write-Host "   URL: http://localhost:3000"
        Write-Host "   Health: curl http://localhost:3000/health"
        Write-Host "   API: curl http://localhost:3000/api/accounts"
        Write-Host ""
    }
    
    if ($GenaiSuccess) {
        Write-Host "🤖 GENAI RAG DEMO:"
        Write-Host "   Access: kubectl port-forward service/genai-rag-agent-service 8000:80"
        Write-Host "   URL: http://localhost:8000"
        Write-Host "   Health: curl http://localhost:8000/health"
        Write-Host "   API: curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases"
        Write-Host ""
    }
    
    Write-Host "🔍 MONITORING:"
    if ($BankingSuccess) {
        Write-Host "   Banking logs: kubectl logs -l app=banking-demo -f"
    }
    if ($GenaiSuccess) {
        Write-Host "   GenAI logs: kubectl logs -l app=genai-rag-agent -f"
    }
    Write-Host "   All pods: kubectl get pods"
    Write-Host "   All services: kubectl get services"
    Write-Host ""
    
    Write-Host "🧹 CLEANUP:"
    Write-Host "   Remove all demos: $($MyInvocation.MyCommand.Name) -Cleanup"
    if ($BankingSuccess) {
        Write-Host "   Banking only: $SCRIPT_DIR\deploy-banking-demo.ps1 -Cleanup"
    }
    if ($GenaiSuccess) {
        Write-Host "   GenAI only: $SCRIPT_DIR\deploy-genai-demo.ps1 -Cleanup"
    }
    Write-Host ""
    
    Write-Host "💡 DEMO SCENARIOS:"
    Write-Host "   Both demos showcase fine-grained authorization with OpenFGA:"
    if ($BankingSuccess) {
        Write-Host "   - Banking: Role-based access, multi-ownership, transaction controls"
    }
    if ($GenaiSuccess) {
        Write-Host "   - GenAI: Knowledge base permissions, document access, chat sessions"
    }
    Write-Host ""
}

# Cleanup both demos
function Remove-BothDemos {
    Write-Info "Cleaning up all demo deployments..."
    
    $bankingCleanup = $true
    $genaiCleanup = $true
    
    # Cleanup banking demo
    try {
        & "$SCRIPT_DIR\deploy-banking-demo.ps1" -Cleanup
        if ($LASTEXITCODE -ne 0) {
            $bankingCleanup = $false
        }
    }
    catch {
        $bankingCleanup = $false
    }
    
    # Cleanup GenAI demo
    try {
        & "$SCRIPT_DIR\deploy-genai-demo.ps1" -Cleanup
        if ($LASTEXITCODE -ne 0) {
            $genaiCleanup = $false
        }
    }
    catch {
        $genaiCleanup = $false
    }
    
    # Summary
    Write-Host ""
    if ($bankingCleanup -and $genaiCleanup) {
        Write-Success "All demo applications cleaned up successfully"
    } else {
        Write-Warning "Some cleanup operations may have failed"
    }
}

# Show comprehensive status of both demos
function Show-ComprehensiveStatus {
    Write-Host "=========================================="
    Write-Host "        COMPREHENSIVE DEMO STATUS"
    Write-Host "=========================================="
    Write-Host ""
    
    # OpenFGA status
    Write-Host "OpenFGA Status:"
    try {
        kubectl get pods -l app=openfga 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "No OpenFGA pods found"
        }
        kubectl get services -l app=openfga 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "No OpenFGA services found"
        }
    }
    catch {
        Write-Host "Error checking OpenFGA status"
    }
    Write-Host ""
    
    # Banking demo status
    Write-Host "Banking Demo Status:"
    try {
        kubectl get pods -l app=banking-demo 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "No banking demo pods found"
        }
        kubectl get services -l app=banking-demo 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "No banking demo services found"
        }
    }
    catch {
        Write-Host "Error checking banking demo status"
    }
    Write-Host ""
    
    # GenAI demo status
    Write-Host "GenAI RAG Demo Status:"
    try {
        kubectl get pods -l app=genai-rag-agent 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "No GenAI demo pods found"
        }
        kubectl get services -l app=genai-rag-agent 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "No GenAI demo services found"
        }
    }
    catch {
        Write-Host "Error checking GenAI demo status"
    }
    Write-Host ""
    
    # Resource usage (if available)
    Write-Host "Resource Usage (if available):"
    try {
        kubectl top pods 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Pod metrics not available"
        }
    }
    catch {
        Write-Host "Pod metrics not available"
    }
    Write-Host ""
}

# Show usage information
function Show-Usage {
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) [OPTIONS]"
    Write-Host ""
    Write-Host "Deploy both demo applications (Banking and GenAI RAG) for local testing"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -BankingOnly    Deploy only the banking demo"
    Write-Host "  -GenaiOnly      Deploy only the GenAI RAG demo"
    Write-Host "  -Cleanup        Remove all demo deployments"
    Write-Host "  -TestOnly       Only test existing deployments"
    Write-Host "  -Status         Show comprehensive status of all demos"
    Write-Host "  -SkipBuild      Skip building applications and Docker images"
    Write-Host "  -Help          Show this help message"
    Write-Host ""
    Write-Host "Environment Variables:"
    Write-Host "  `$env:CONTAINER_RUNTIME  Specify container runtime (docker|podman)"
    Write-Host "  `$env:OPENAI_API_KEY    Optional: Your OpenAI API key for GenAI demo"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\$($MyInvocation.MyCommand.Name)                    # Deploy both demos"
    Write-Host "  .\$($MyInvocation.MyCommand.Name) -BankingOnly       # Deploy only banking demo"
    Write-Host "  .\$($MyInvocation.MyCommand.Name) -GenaiOnly         # Deploy only GenAI demo"
    Write-Host "  .\$($MyInvocation.MyCommand.Name) -Cleanup           # Remove all deployments"
    Write-Host "  .\$($MyInvocation.MyCommand.Name) -TestOnly          # Test existing deployments"
    Write-Host "  .\$($MyInvocation.MyCommand.Name) -Status            # Show status of all demos"
    Write-Host "  .\$($MyInvocation.MyCommand.Name) -SkipBuild         # Deploy without rebuilding"
    Write-Host ""
    Write-Host "Individual Demo Scripts:"
    Write-Host "  $SCRIPT_DIR\deploy-banking-demo.ps1   # Banking demo only"
    Write-Host "  $SCRIPT_DIR\deploy-genai-demo.ps1     # GenAI demo only"
}

# Main function
function Main {
    Write-Host "=================================================="
    Write-Host "    OpenFGA Demo Applications Deployment"
    Write-Host "=================================================="
    Write-Host ""
    
    # Handle help request
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    # Handle status-only request
    if ($Status) {
        Show-ComprehensiveStatus
        exit 0
    }
    
    # Handle cleanup request
    if ($Cleanup) {
        Remove-BothDemos
        exit 0
    }
    
    # Handle test-only request
    if ($TestOnly) {
        Test-Prerequisites
        # TODO: Implement test functionality
        Write-Info "Testing functionality not yet implemented in PowerShell version"
        Write-Info "Use individual demo scripts with -TestOnly parameter"
        exit 0
    }
    
    # Check prerequisites
    Test-Prerequisites
    
    # Handle individual demo deployments
    if ($BankingOnly -and $GenaiOnly) {
        Write-Error "Cannot specify both -BankingOnly and -GenaiOnly"
        exit 1
    }
    
    $scriptArgs = @()
    if ($SkipBuild) {
        $scriptArgs += "-SkipBuild"
    }
    
    if ($BankingOnly) {
        Write-Host "Deploying Banking Demo only..."
        & "$SCRIPT_DIR\deploy-banking-demo.ps1" @scriptArgs
    } elseif ($GenaiOnly) {
        Write-Host "Deploying GenAI RAG Demo only..."
        & "$SCRIPT_DIR\deploy-genai-demo.ps1" @scriptArgs
    } else {
        # Deploy both demos
        $success = Deploy-BothDemos $scriptArgs
        if (-not $success) {
            exit 1
        }
    }
    
    Write-Success "Demo deployment process completed!"
}

# Handle script termination
trap {
    Write-Warning "Script interrupted"
    exit 1
}

# Run main function
Main