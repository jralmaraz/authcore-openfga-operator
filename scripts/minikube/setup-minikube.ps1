# setup-minikube.ps1 - Automated Minikube setup for authcore-openfga-operator on Windows
# Compatible with Windows 10/11 with PowerShell 5.1+

param(
    [switch]$SkipChocolatey,
    [switch]$SkipDocker,
    [switch]$Force
)

# Error handling
$ErrorActionPreference = "Stop"

# Colors for output (using Write-Host with colors)
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

# Check if running as administrator
function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if command exists
function Test-CommandExists($command) {
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

# Check Windows version
function Test-WindowsVersion {
    $version = [System.Environment]::OSVersion.Version
    $build = $version.Build
    
    # Windows 10 version 2004 (build 19041) or later
    if ($build -ge 19041) {
        return $true
    }
    
    return $false
}

# Install Chocolatey
function Install-Chocolatey {
    Write-Info "Installing Chocolatey package manager..."
    
    if (Test-CommandExists "choco") {
        Write-Info "Chocolatey is already installed"
        return
    }
    
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Success "Chocolatey installed successfully"
}

# Install Docker Desktop
function Install-DockerDesktop {
    Write-Info "Checking Docker Desktop installation..."
    
    if (Test-CommandExists "docker") {
        Write-Info "Docker is already installed"
        
        # Test Docker
        try {
            docker --version | Out-Null
            Write-Success "Docker is working"
            return
        }
        catch {
            Write-Warning "Docker is installed but not working properly"
        }
    }
    
    if ($SkipDocker) {
        Write-Warning "Skipping Docker installation (use -SkipDocker to enable)"
        Write-Warning "Please install Docker Desktop manually from https://www.docker.com/products/docker-desktop"
        return
    }
    
    Write-Info "Docker Desktop needs to be installed manually"
    Write-Info "Please download and install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    Write-Info "Make sure to enable WSL 2 based engine during installation"
    
    $response = Read-Host "Have you installed Docker Desktop? (y/N)"
    if ($response -notmatch "^[Yy]") {
        Write-Error-Custom "Docker Desktop is required. Please install it and run this script again."
        exit 1
    }
}

# Enable WSL2
function Enable-WSL2 {
    Write-Info "Enabling WSL2..."
    
    # Check if WSL is already enabled
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux"
    $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform"
    
    $needsRestart = $false
    
    if ($wslFeature.State -ne "Enabled") {
        Write-Info "Enabling Windows Subsystem for Linux..."
        Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -All -NoRestart
        $needsRestart = $true
    }
    
    if ($vmFeature.State -ne "Enabled") {
        Write-Info "Enabling Virtual Machine Platform..."
        Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -All -NoRestart
        $needsRestart = $true
    }
    
    if ($needsRestart) {
        Write-Warning "A restart is required to complete WSL2 setup"
        Write-Warning "Please restart your computer and run this script again"
        return $false
    }
    
    # Set WSL2 as default
    wsl --set-default-version 2
    
    Write-Success "WSL2 is enabled"
    return $true
}

# Install tools via Chocolatey
function Install-Tools {
    Write-Info "Installing required tools..."
    
    $tools = @(
        @{Name="kubernetes-cli"; Command="kubectl"; Description="Kubernetes CLI"},
        @{Name="minikube"; Command="minikube"; Description="Minikube"},
        @{Name="git"; Command="git"; Description="Git"}
    )
    
    foreach ($tool in $tools) {
        if (Test-CommandExists $tool.Command) {
            Write-Info "$($tool.Description) is already installed"
        } else {
            Write-Info "Installing $($tool.Description)..."
            choco install $tool.Name -y
        }
    }
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Success "Tools installation completed"
}

# Install Rust
function Install-Rust {
    Write-Info "Installing Rust..."
    
    if (Test-CommandExists "rustc") {
        Write-Info "Rust is already installed"
        return
    }
    
    Write-Info "Downloading and installing Rust..."
    
    # Download rustup-init.exe
    $rustupUrl = "https://win.rustup.rs/x86_64"
    $rustupPath = "$env:TEMP\rustup-init.exe"
    
    Invoke-WebRequest -Uri $rustupUrl -OutFile $rustupPath
    
    # Run rustup installer with default options
    Start-Process -FilePath $rustupPath -ArgumentList "-y" -Wait
    
    # Add Rust to path
    $cargoPath = "$env:USERPROFILE\.cargo\bin"
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$cargoPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$cargoPath", "User")
    }
    
    # Refresh environment variables for current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Success "Rust installed successfully"
}

# Start Minikube
function Start-Minikube {
    Write-Info "Starting Minikube..."
    
    # Check if Minikube is already running
    try {
        $status = minikube status 2>$null
        if ($status -match "Running") {
            Write-Info "Minikube is already running"
            return
        }
    }
    catch {
        # Minikube not running or not configured
    }
    
    # Try to start with Docker driver
    Write-Info "Starting Minikube with Docker driver..."
    try {
        minikube start --driver=docker --memory=4096 --cpus=2
        Write-Success "Minikube started with Docker driver"
    }
    catch {
        Write-Warning "Docker driver failed, trying Hyper-V driver..."
        try {
            minikube start --driver=hyperv --memory=4096 --cpus=2
            Write-Success "Minikube started with Hyper-V driver"
        }
        catch {
            Write-Error-Custom "Failed to start Minikube. Please check your virtualization settings."
            throw
        }
    }
    
    # Enable addons
    Write-Info "Enabling Minikube addons..."
    minikube addons enable ingress
    minikube addons enable metrics-server
    
    Write-Success "Minikube started successfully"
}

# Verify installation
function Test-Installation {
    Write-Info "Verifying installation..."
    
    $issues = 0
    
    # Test Docker
    try {
        docker --version | Out-Null
        Write-Success "Docker is working"
    }
    catch {
        Write-Error-Custom "Docker is not working properly"
        $issues++
    }
    
    # Test kubectl
    try {
        kubectl version --client | Out-Null
        Write-Success "kubectl is working"
    }
    catch {
        Write-Error-Custom "kubectl is not working properly"
        $issues++
    }
    
    # Test Minikube
    try {
        minikube status | Out-Null
        Write-Success "Minikube is running"
    }
    catch {
        Write-Error-Custom "Minikube is not running properly"
        $issues++
    }
    
    # Test Rust
    try {
        rustc --version | Out-Null
        Write-Success "Rust is working"
    }
    catch {
        Write-Error-Custom "Rust is not working properly"
        $issues++
    }
    
    if ($issues -eq 0) {
        Write-Success "All tools are working correctly"
        
        # Show cluster info
        Write-Info "Cluster information:"
        kubectl cluster-info
        
        return $true
    }
    else {
        Write-Error-Custom "Installation verification failed with $issues issues"
        return $false
    }
}

# Main function
function Main {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  authcore-openfga-operator Minikube Setup" -ForegroundColor Cyan
    Write-Host "  Windows PowerShell Edition" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if running as administrator
    if (-not (Test-IsAdmin)) {
        Write-Error-Custom "This script must be run as Administrator"
        Write-Error-Custom "Please right-click PowerShell and select 'Run as Administrator'"
        exit 1
    }
    
    # Check Windows version
    if (-not (Test-WindowsVersion)) {
        Write-Error-Custom "Windows 10 version 2004 (build 19041) or later is required"
        exit 1
    }
    
    try {
        # Enable WSL2
        if (-not (Enable-WSL2)) {
            exit 1
        }
        
        # Install Chocolatey
        if (-not $SkipChocolatey) {
            Install-Chocolatey
        }
        
        # Install Docker Desktop
        Install-DockerDesktop
        
        # Install tools
        Install-Tools
        
        # Install Rust
        Install-Rust
        
        # Start Minikube
        Start-Minikube
        
        # Verify installation
        if (Test-Installation) {
            Write-Host ""
            Write-Success "Minikube setup completed successfully!"
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Yellow
            Write-Host "1. Run '.\scripts\minikube\deploy-operator.ps1' to deploy the operator"
            Write-Host "2. Run '.\scripts\minikube\validate-deployment.ps1' to validate the deployment"
            Write-Host ""
            Write-Host "For manual deployment, see the Windows setup guide in docs/minikube/"
        }
        else {
            Write-Error-Custom "Setup completed with issues. Please check the errors above."
            exit 1
        }
    }
    catch {
        Write-Error-Custom "Setup failed: $($_.Exception.Message)"
        exit 1
    }
}

# Run main function
Main