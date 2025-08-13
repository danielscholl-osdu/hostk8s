# infra/scripts/install.ps1 - Install required dependencies for Windows
. "$PSScriptRoot\common.ps1"

function Show-Usage {
    Write-Host "Usage: install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Install required dependencies for HostK8s on Windows."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -h, -help    Show this help"
    Write-Host ""
    Write-Host "Required tools: kind, kubectl, helm, flux, docker-desktop"
    Write-Host ""
    Write-Host "Supported package managers:"
    Write-Host "  - Winget (winget) - Windows 10/11 (preferred)"
    Write-Host "  - Chocolatey (choco) - Windows (fallback)"
    Write-Host "  - Manual downloads (fallback)"
}

function Test-Tool {
    param(
        [string]$Tool,
        [string]$InstallCommand = ""
    )
    
    if (Test-Command $Tool) {
        $version = ""
        
        switch ($Tool) {
            "kind" {
                try {
                    $output = kind version 2>$null
                    if ($LASTEXITCODE -eq 0 -and $output -match 'v(\d+\.\d+\.\d+)') {
                        $version = $matches[1]
                    }
                } catch { }
            }
            "kubectl" {
                try {
                    $output = kubectl version --client --output=yaml 2>$null
                    if ($LASTEXITCODE -eq 0 -and $output -match 'gitVersion:\s*"?v?([^"]+)"?') {
                        $version = $matches[1]
                    }
                } catch { }
            }
            "helm" {
                try {
                    $output = helm version --template='{{.Version}}' 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        $version = $output -replace '^v', ''
                    }
                } catch { }
            }
            "flux" {
                try {
                    $output = flux version --client 2>$null
                    if ($LASTEXITCODE -eq 0 -and $output -match 'v(\d+\.\d+\.\d+)') {
                        $version = $matches[1]
                    }
                } catch { }
            }
            "docker" {
                try {
                    $output = docker version --format '{{.Client.Version}}' 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        $version = $output
                    }
                } catch { }
            }
        }
        
        if ($env:LOG_LEVEL -ne "info") {
            if ($version) {
                Log-Debug "  $Tool`: $version"
            } else {
                Log-Debug "  $Tool`: installed"
            }
        }
        return $true
    }
    
    if ($InstallCommand) {
        Log-Debug "Installing $Tool..."
        try {
            Invoke-Expression $InstallCommand
            if ($LASTEXITCODE -eq 0) {
                # Check version after installation
                $version = ""
                switch ($Tool) {
                    "kind" {
                        try {
                            $output = kind version 2>$null
                            if ($LASTEXITCODE -eq 0 -and $output -match 'v(\d+\.\d+\.\d+)') {
                                $version = $matches[1]
                            }
                        } catch { }
                    }
                    "kubectl" {
                        try {
                            $output = kubectl version --client --output=yaml 2>$null
                            if ($LASTEXITCODE -eq 0 -and $output -match 'gitVersion:\s*"?v?([^"]+)"?') {
                                $version = $matches[1]
                            }
                        } catch { }
                    }
                    "helm" {
                        try {
                            $output = helm version --template='{{.Version}}' 2>$null
                            if ($LASTEXITCODE -eq 0) {
                                $version = $output -replace '^v', ''
                            }
                        } catch { }
                    }
                    "flux" {
                        try {
                            $output = flux version --client 2>$null
                            if ($LASTEXITCODE -eq 0 -and $output -match 'v(\d+\.\d+\.\d+)') {
                                $version = $matches[1]
                            }
                        } catch { }
                    }
                    "docker" {
                        try {
                            $output = docker version --format '{{.Client.Version}}' 2>$null
                            if ($LASTEXITCODE -eq 0) {
                                $version = $output
                            }
                        } catch { }
                    }
                }
                
                if ($env:LOG_LEVEL -ne "info") {
                    if ($version) {
                        Log-Debug "  $Tool`: $version"
                    } else {
                        Log-Debug "  $Tool`: installed"
                    }
                }
                return $true
            }
        } catch {
            Log-Error "Failed to install $Tool`: $_"
            return $false
        }
    } else {
        Log-Error "$Tool not found"
        return $false
    }
}

function Install-WithWinget {
    if ($env:LOG_LEVEL -ne "info") {
        Log-Debug "Tools"
    }
    
    # Check if winget is available
    if (-not (Test-Command "winget")) {
        Log-Error "Winget not available. Please install App Installer from Microsoft Store."
        return $false
    }
    
    $tools = @(
        @{ Name = "kind"; Command = "winget install Kubernetes.kind --accept-source-agreements --accept-package-agreements" }
        @{ Name = "kubectl"; Command = "winget install Kubernetes.kubectl --accept-source-agreements --accept-package-agreements" }
        @{ Name = "helm"; Command = "winget install Helm.Helm --accept-source-agreements --accept-package-agreements" }
        @{ Name = "flux"; Command = "winget install fluxcd.flux2 --accept-source-agreements --accept-package-agreements" }
        @{ Name = "docker"; Command = "winget install Docker.DockerDesktop --accept-source-agreements --accept-package-agreements" }
    )
    
    $allSuccess = $true
    foreach ($tool in $tools) {
        if (-not (Test-Tool -Tool $tool.Name -InstallCommand $tool.Command)) {
            $allSuccess = $false
        }
    }
    
    return $allSuccess
}

function Install-WithChocolatey {
    if ($env:LOG_LEVEL -ne "info") {
        Log-Debug "Tools"
    }
    
    # Check if chocolatey is available
    if (-not (Test-Command "choco")) {
        Log-Error "Chocolatey not available. Please install from https://chocolatey.org/install"
        return $false
    }
    
    $tools = @(
        @{ Name = "kind"; Command = "choco install kind -y" }
        @{ Name = "kubectl"; Command = "choco install kubernetes-cli -y" }
        @{ Name = "helm"; Command = "choco install kubernetes-helm -y" }
        @{ Name = "flux"; Command = "choco install flux -y" }
        @{ Name = "docker"; Command = "choco install docker-desktop -y" }
    )
    
    $allSuccess = $true
    foreach ($tool in $tools) {
        if (-not (Test-Tool -Tool $tool.Name -InstallCommand $tool.Command)) {
            $allSuccess = $false
        }
    }
    
    return $allSuccess
}

function Install-Manually {
    Log-Warn "Manual installation required. Please install the following tools:"
    Log-Info "Required tools and installation links:"
    Log-Info "  - kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    Log-Info "  - kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
    Log-Info "  - helm: https://helm.sh/docs/intro/install/#from-chocolatey-windows"
    Log-Info "  - flux: https://fluxcd.io/flux/installation/#install-the-flux-cli"
    Log-Info "  - Docker Desktop: https://docs.docker.com/desktop/install/windows-install/"
    
    Log-Info ""
    Log-Info "Alternatively, install a package manager:"
    Log-Info "  - Winget (recommended): Included with Windows 11, or install App Installer from Microsoft Store"
    Log-Info "  - Chocolatey: https://chocolatey.org/install"
    
    return $false
}

function Test-DockerDesktop {
    # Check if Docker Desktop is running
    try {
        $null = docker info 2>$null
        if ($LASTEXITCODE -eq 0) {
            if ($env:LOG_LEVEL -ne "info") {
                Log-Debug "  Docker: Running"
            }
            return $true
        }
    } catch {
        # Docker command failed
    }
    
    # Check if Docker Desktop is installed but not running
    if (Test-Command "docker") {
        Log-Warn "Docker Desktop is installed but not running"
        Log-Info "Please start Docker Desktop and try again"
        return $false
    } else {
        Log-Error "Docker Desktop not found"
        Log-Info "Install Docker Desktop: https://docs.docker.com/desktop/install/windows-install/"
        return $false
    }
}

function Install-Dependencies {
    Log-Debug "Checking dependencies..."
    
    if ($env:LOG_LEVEL -ne "info") {
        Log-Debug "------------------------"
        Log-Debug "Dependency Configuration"
    }
    
    $success = $false
    
    # Select package manager based on PACKAGE_MANAGER setting
    if (-not $env:PACKAGE_MANAGER) {
        # Auto-detect: prefer winget, then chocolatey, then manual
        if (Test-Command "winget") {
            if ($env:LOG_LEVEL -ne "info") {
                Log-Debug "  Package Manager: Winget (auto-detected)"
                Log-Debug "  Platform: Windows"
                Log-Debug "------------------------"
            }
            $success = Install-WithWinget
        } elseif (Test-Command "choco") {
            if ($env:LOG_LEVEL -ne "info") {
                Log-Debug "  Package Manager: Chocolatey (auto-detected)"
                Log-Debug "  Platform: Windows"
                Log-Debug "------------------------"
            }
            $success = Install-WithChocolatey
        } else {
            if ($env:LOG_LEVEL -ne "info") {
                Log-Debug "------------------------"
            }
            Log-Error "No supported package manager found (winget or chocolatey)."
            $success = Install-Manually
        }
    } elseif ($env:PACKAGE_MANAGER -eq "winget") {
        # Force Winget
        if (Test-Command "winget") {
            if ($env:LOG_LEVEL -ne "info") {
                Log-Debug "  Package Manager: Winget (forced)"
                Log-Debug "  Platform: Windows"
                Log-Debug "------------------------"
            }
            $success = Install-WithWinget
        } else {
            Log-Error "Winget not available but PACKAGE_MANAGER=winget is set"
            Log-Info "Install App Installer from Microsoft Store to get winget"
            return $false
        }
    } elseif ($env:PACKAGE_MANAGER -eq "chocolatey" -or $env:PACKAGE_MANAGER -eq "choco") {
        # Force Chocolatey
        if (Test-Command "choco") {
            if ($env:LOG_LEVEL -ne "info") {
                Log-Debug "  Package Manager: Chocolatey (forced)"
                Log-Debug "  Platform: Windows"
                Log-Debug "------------------------"
            }
            $success = Install-WithChocolatey
        } else {
            Log-Error "Chocolatey not available but PACKAGE_MANAGER=$($env:PACKAGE_MANAGER) is set"
            Log-Info "Install Chocolatey: https://chocolatey.org/install"
            return $false
        }
    } elseif ($env:PACKAGE_MANAGER -eq "manual") {
        # Force manual installation
        if ($env:LOG_LEVEL -ne "info") {
            Log-Debug "  Package Manager: Manual (forced)"
            Log-Debug "  Platform: Windows"
            Log-Debug "------------------------"
        }
        $success = Install-Manually
    } else {
        Log-Error "Invalid PACKAGE_MANAGER value: '$($env:PACKAGE_MANAGER)'"
        Log-Info "Valid options for Windows: winget, chocolatey, choco, manual"
        return $false
    }
    
    # Always check Docker Desktop separately
    if (-not (Test-DockerDesktop)) {
        return $false
    }
    
    if ($env:LOG_LEVEL -ne "info") {
        Log-Debug "------------------------"
    }
    
    if ($success) {
        Log-Info "All dependencies verified"
        return $true
    } else {
        return $false
    }
}

# Main function
function Main {
    param([string[]]$Arguments)
    
    # Parse arguments
    foreach ($arg in $Arguments) {
        switch ($arg.ToLower()) {
            "-h" { Show-Usage; exit 0 }
            "-help" { Show-Usage; exit 0 }
            "help" { Show-Usage; exit 0 }
            default {
                Log-Error "Unknown option: $arg"
                Show-Usage
                exit 1
            }
        }
    }
    
    if (Install-Dependencies) {
        exit 0
    } else {
        exit 1
    }
}

# Run if called directly
if ($MyInvocation.InvocationName -ne '.') {
    Main -Arguments $args
}