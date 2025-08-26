# validate-deployment.ps1 - Validation script for authcore-openfga-operator deployment on Windows
# Compatible with Windows 10/11 with PowerShell 5.1+

param(
    [switch]$Detailed
)

# Error handling
$ErrorActionPreference = "Continue"  # Continue on non-critical errors for validation

# Configuration
$OperatorNamespace = "openfga-system"
$Timeout = 300

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

# Validate prerequisites
function Test-Prerequisites {
    Write-Info "Validating prerequisites..."
    
    $issues = 0
    
    if (-not (Test-CommandExists "kubectl")) {
        Write-Error-Custom "kubectl is not installed"
        $issues++
    }
    
    if (-not (Test-CommandExists "minikube")) {
        Write-Error-Custom "minikube is not installed"
        $issues++
    }
    
    try {
        minikube status | Out-Null
        Write-Success "Minikube is running"
    }
    catch {
        Write-Error-Custom "Minikube is not running"
        $issues++
    }
    
    if ($issues -eq 0) {
        Write-Success "Prerequisites validation passed"
        return $true
    }
    else {
        Write-Error-Custom "Prerequisites validation failed with $issues issues"
        return $false
    }
}

# Validate cluster connectivity
function Test-Cluster {
    Write-Info "Validating cluster connectivity..."
    
    try {
        kubectl cluster-info | Out-Null
        Write-Success "Cluster is accessible"
        
        if ($Detailed) {
            Write-Host "Cluster information:"
            kubectl cluster-info
            Write-Host ""
        }
        
        return $true
    }
    catch {
        Write-Error-Custom "Cannot connect to cluster"
        return $false
    }
}

# Validate CRDs
function Test-CRDs {
    Write-Info "Validating Custom Resource Definitions..."
    
    try {
        kubectl get crd openfgas.authorization.openfga.dev | Out-Null
        Write-Success "OpenFGA CRD is installed"
        
        if ($Detailed) {
            Write-Host "CRD details:"
            kubectl get crd openfgas.authorization.openfga.dev -o custom-columns=NAME:.metadata.name,VERSION:.spec.versions[0].name,SCOPE:.spec.scope
            Write-Host ""
        }
        
        return $true
    }
    catch {
        Write-Error-Custom "OpenFGA CRD is not installed"
        return $false
    }
}

# Validate operator deployment
function Test-Operator {
    Write-Info "Validating operator deployment..."
    
    $issues = 0
    
    # Check if namespace exists
    try {
        kubectl get namespace $OperatorNamespace | Out-Null
        Write-Success "Operator namespace exists"
    }
    catch {
        Write-Error-Custom "Operator namespace '$OperatorNamespace' does not exist"
        $issues++
    }
    
    # Check if deployment exists
    try {
        kubectl get deployment openfga-operator -n $OperatorNamespace | Out-Null
        Write-Success "Operator deployment exists"
    }
    catch {
        Write-Error-Custom "Operator deployment does not exist"
        $issues++
    }
    
    # Check if deployment is ready
    try {
        kubectl wait --for=condition=available --timeout=30s deployment/openfga-operator-project-controller-manager -n $OperatorNamespace 2>$null | Out-Null
        Write-Success "Operator deployment is available"
    }
    catch {
        Write-Warning "Operator deployment may not be fully ready yet"
        $issues++
    }
    
    # Check pods
    try {
        $podStatus = kubectl get pods -n $OperatorNamespace -l app=openfga-operator --no-headers -o custom-columns=STATUS:.status.phase 2>$null | Select-Object -First 1
        
        if ($podStatus -eq "Running") {
            Write-Success "Operator pod is running"
        }
        else {
            Write-Error-Custom "Operator pod is not running (status: $podStatus)"
            $issues++
        }
    }
    catch {
        Write-Error-Custom "Cannot get operator pod status"
        $issues++
    }
    
    # Show deployment status
    if ($Detailed) {
        Write-Host "Operator deployment status:"
        kubectl get deployment openfga-operator -n $OperatorNamespace
        Write-Host ""
        
        Write-Host "Operator pods:"
        kubectl get pods -n $OperatorNamespace
        Write-Host ""
    }
    
    return ($issues -eq 0)
}

# Validate RBAC
function Test-RBAC {
    Write-Info "Validating RBAC configuration..."
    
    $issues = 0
    
    # Check service account
    try {
        kubectl get serviceaccount openfga-operator -n $OperatorNamespace | Out-Null
        Write-Success "Operator service account exists"
    }
    catch {
        Write-Error-Custom "Operator service account does not exist"
        $issues++
    }
    
    # Check cluster role
    try {
        kubectl get clusterrole openfga-operator | Out-Null
        Write-Success "Operator cluster role exists"
    }
    catch {
        Write-Error-Custom "Operator cluster role does not exist"
        $issues++
    }
    
    # Check cluster role binding
    try {
        kubectl get clusterrolebinding openfga-operator | Out-Null
        Write-Success "Operator cluster role binding exists"
    }
    catch {
        Write-Error-Custom "Operator cluster role binding does not exist"
        $issues++
    }
    
    return ($issues -eq 0)
}

# Validate OpenFGA instances
function Test-OpenFGAInstances {
    Write-Info "Validating OpenFGA instances..."
    
    # Check if any OpenFGA instances exist
    try {
        $instances = kubectl get openfgas --no-headers 2>$null
        $instanceCount = ($instances | Measure-Object).Count
        
        if ($instanceCount -eq 0) {
            Write-Warning "No OpenFGA instances found"
            Write-Host "You can create one with: kubectl apply -f examples/basic-openfga.yaml"
            Write-Host ""
            return $true
        }
        
        Write-Success "Found $instanceCount OpenFGA instance(s)"
        
        if ($Detailed) {
            Write-Host "OpenFGA instances:"
            kubectl get openfgas
            Write-Host ""
        }
        
        # Check if deployments are created for instances
        $openfgaDeployments = kubectl get deployments -l app=openfga --no-headers 2>$null
        $deploymentCount = ($openfgaDeployments | Measure-Object).Count
        
        if ($deploymentCount -gt 0) {
            Write-Success "Found $deploymentCount OpenFGA deployment(s)"
            
            if ($Detailed) {
                Write-Host "OpenFGA deployments:"
                kubectl get deployments -l app=openfga
                Write-Host ""
            }
        }
        else {
            Write-Warning "No OpenFGA deployments found. The operator may still be processing the instances."
        }
        
        return $true
    }
    catch {
        Write-Error-Custom "Error checking OpenFGA instances"
        return $false
    }
}

# Test API connectivity
function Test-APIConnectivity {
    Write-Info "Testing OpenFGA API connectivity..."
    
    # Find OpenFGA services
    try {
        $services = kubectl get services -l app=openfga --no-headers 2>$null | Where-Object { $_ -match "(http|8080)" } | Select-Object -First 1
        
        if (-not $services) {
            Write-Warning "No OpenFGA HTTP services found"
            Write-Host "Deploy an OpenFGA instance first: kubectl apply -f examples/basic-openfga.yaml"
            return $true
        }
        
        $serviceName = ($services -split '\s+')[0]
        Write-Info "Testing connectivity to service: $serviceName"
        
        # Start port-forward in background
        $job = Start-Job -ScriptBlock {
            param($serviceName)
            kubectl port-forward service/$serviceName 8080:8080
        } -ArgumentList $serviceName
        
        # Give port-forward time to establish
        Start-Sleep -Seconds 5
        
        # Test the API
        $apiTestResult = $true
        
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:8080/healthz" -Method Get -TimeoutSec 10
            Write-Success "OpenFGA health endpoint is accessible"
        }
        catch {
            Write-Warning "OpenFGA health endpoint is not responding (this may be normal if the pod is still starting)"
            $apiTestResult = $false
        }
        
        # Test stores endpoint
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:8080/stores" -Method Get -TimeoutSec 10
            Write-Success "OpenFGA stores endpoint is accessible"
        }
        catch {
            Write-Warning "OpenFGA stores endpoint is not responding"
            $apiTestResult = $false
        }
        
        # Clean up port-forward
        Stop-Job $job -ErrorAction SilentlyContinue
        Remove-Job $job -ErrorAction SilentlyContinue
        
        if ($apiTestResult) {
            Write-Success "API connectivity test passed"
        }
        else {
            Write-Warning "API connectivity test had issues (this may be normal during startup)"
        }
        
        return $true
    }
    catch {
        Write-Warning "API connectivity test failed: $($_.Exception.Message)"
        return $false
    }
}

# Check operator logs for errors
function Test-OperatorLogs {
    Write-Info "Checking operator logs for errors..."
    
    try {
        # Get recent logs from operator
        $logs = kubectl logs -n $OperatorNamespace deployment/openfga-operator-project-controller-manager --tail=50 2>$null
        
        if (-not $logs) {
            Write-Warning "No operator logs available"
            return $true
        }
        
        # Check for error patterns
        $errors = $logs | Select-String -Pattern "(error|failed|panic)" -CaseSensitive:$false
        $errorCount = ($errors | Measure-Object).Count
        
        if ($errorCount -eq 0) {
            Write-Success "No errors found in operator logs"
        }
        else {
            Write-Warning "Found $errorCount potential error(s) in operator logs"
            if ($Detailed) {
                Write-Host "Recent errors:"
                $errors | Select-Object -Last 5 | ForEach-Object { Write-Host $_.Line }
                Write-Host ""
            }
        }
        
        # Show last few log lines
        if ($Detailed) {
            Write-Host "Recent operator logs:"
            $logs | Select-Object -Last 10 | ForEach-Object { Write-Host $_ }
            Write-Host ""
        }
        
        return $true
    }
    catch {
        Write-Warning "Could not retrieve operator logs"
        return $false
    }
}

# Generate validation report
function New-ValidationReport {
    Write-Info "Generating validation report..."
    
    Write-Host "=========================================="
    Write-Host "         VALIDATION REPORT"
    Write-Host "=========================================="
    Write-Host ""
    
    Write-Host "Cluster Information:"
    kubectl cluster-info
    Write-Host ""
    
    Write-Host "Node Status:"
    kubectl get nodes
    Write-Host ""
    
    Write-Host "Operator Status:"
    kubectl get all -n $OperatorNamespace
    Write-Host ""
    
    Write-Host "OpenFGA Resources:"
    kubectl get openfgas
    Write-Host ""
    
    Write-Host "All Deployments:"
    kubectl get deployments
    Write-Host ""
    
    Write-Host "All Services:"
    kubectl get services
    Write-Host ""
    
    Write-Host "Resource Usage:"
    try {
        kubectl top nodes
        kubectl top pods -n $OperatorNamespace
    }
    catch {
        Write-Host "Metrics not available"
    }
    Write-Host ""
}

# Print next steps
function Write-NextSteps {
    Write-Host "=========================================="
    Write-Host "            NEXT STEPS"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "1. Access OpenFGA API:"
    Write-Host "   kubectl port-forward service/openfga-basic-http 8080:8080"
    Write-Host "   Invoke-RestMethod -Uri 'http://localhost:8080/healthz'"
    Write-Host "   Invoke-RestMethod -Uri 'http://localhost:8080/stores'"
    Write-Host ""
    Write-Host "2. Deploy demo applications:"
    Write-Host "   cd demos/banking-app"
    Write-Host "   kubectl apply -f k8s/"
    Write-Host "   kubectl port-forward service/banking-app 3000:3000"
    Write-Host ""
    Write-Host "3. Monitor the system:"
    Write-Host "   kubectl logs -n $OperatorNamespace deployment/openfga-operator-project-controller-manager -f"
    Write-Host "   kubectl get events --sort-by=.metadata.creationTimestamp"
    Write-Host ""
    Write-Host "4. Create more OpenFGA instances:"
    Write-Host "   kubectl apply -f examples/postgres-openfga.yaml"
    Write-Host ""
    Write-Host "For troubleshooting, see docs/minikube/README.md"
}

# Main function
function Main {
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "  authcore-openfga-operator Deployment Validation" -ForegroundColor Cyan
    Write-Host "  Windows PowerShell Edition" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $totalChecks = 0
    $passedChecks = 0
    
    # Run validations
    $tests = @(
        "Test-Prerequisites",
        "Test-Cluster",
        "Test-CRDs",
        "Test-Operator",
        "Test-RBAC",
        "Test-OpenFGAInstances",
        "Test-APIConnectivity",
        "Test-OperatorLogs"
    )
    
    foreach ($test in $tests) {
        $totalChecks++
        try {
            if (& $test) {
                $passedChecks++
            }
        }
        catch {
            Write-Error-Custom "Test $test failed: $($_.Exception.Message)"
        }
        Write-Host ""
    }
    
    # Generate report
    if ($Detailed) {
        New-ValidationReport
    }
    
    # Summary
    Write-Host "=========================================="
    Write-Host "            VALIDATION SUMMARY"
    Write-Host "=========================================="
    Write-Host ""
    
    if ($passedChecks -eq $totalChecks) {
        Write-Success "All validation checks passed ($passedChecks/$totalChecks)"
        Write-Host ""
        Write-Host "🎉 authcore-openfga-operator is successfully deployed and running!" -ForegroundColor Green
    }
    else {
        Write-Warning "Some validation checks had issues ($passedChecks/$totalChecks passed)"
        Write-Host ""
        Write-Host "⚠️  authcore-openfga-operator may need attention" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-NextSteps
}

# Run main function
Main