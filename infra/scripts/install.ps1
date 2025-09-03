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
    Write-Host "Required tools: kind, kubectl, helm, flux, flux-operator-mcp"
    Write-Host ""
    Write-Host "Supported package managers:"
    Write-Host "  - Winget (winget) - Windows 10/11 (preferred)"
    Write-Host "  - Chocolatey (choco) - Windows (fallback)"
    Write-Host "  - Manual downloads (fallback)"
}

function Test-Tool {
    param(
        [string]$Tool,
        [string]$InstallCommand = "",
        [string]$WingetPackage = ""
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
            "yq" {
                try {
                    $output = yq --version 2>$null
                    if ($LASTEXITCODE -eq 0 -and $output -match 'version\s+v?([0-9.]+)') {
                        $version = $matches[1]
                    }
                } catch { }
            }
            "flux-operator-mcp" {
                try {
                    $output = flux-operator-mcp --version 2>$null
                    if ($LASTEXITCODE -eq 0 -and $output -match 'v?([0-9.]+)') {
                        $version = $matches[1]
                    }
                } catch { }
            }
        }

        if ($version) {
            Log-DebugWithColor -Tool $Tool -Version $version
        } else {
            Log-DebugWithColor -Tool $Tool -Version "installed"
        }
        return $true
    }

    # First check if tool is installed via winget (more reliable than PATH check)
    $isInstalled = $false
    if ($WingetPackage -and (Test-WingetPackage $WingetPackage)) {
        $isInstalled = $true
    } elseif (Test-Command $Tool) {
        $isInstalled = $true
    }

    if ($isInstalled) {
        # Tool is installed, try to get version (refresh PATH if needed)
        RefreshEnvironmentPath
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
                    "yq" {
                        try {
                            $output = yq --version 2>$null
                            if ($LASTEXITCODE -eq 0 -and $output -match 'version\s+v?([0-9.]+)') {
                                $version = $matches[1]
                            }
                        } catch { }
                    }
                    "flux-operator-mcp" {
                        try {
                            $output = flux-operator-mcp --version 2>$null
                            if ($LASTEXITCODE -eq 0 -and $output -match 'v?([0-9.]+)') {
                                $version = $matches[1]
                            }
                        } catch { }
                    }
                }

        if ($version) {
            Log-DebugWithColor -Tool $Tool -Version $version
        } else {
            Log-DebugWithColor -Tool $Tool -Version "installed"
        }
        return $true
    }

    # Tool not found, try to install it
    if ($InstallCommand) {
        Log-Info "Installing $Tool..."
        try {
            Invoke-Expression $InstallCommand
            # Check if tool is now available after installation
            if (Test-Command $Tool) {
                Log-Success "  ${Tool}: installed"
                return $true
            } else {
                Log-Error "Failed to install ${Tool}"
                return $false
            }
        } catch {
            Log-Error "Failed to install ${Tool}: $_"
            return $false
        }
    } else {
        Log-Error "$Tool not found and no install command provided"
        return $false
    }
}

function Install-WithWinget {
    Log-Info "Tools"

    # Check if winget is available
    if (-not (Test-Command "winget")) {
        Log-Error "Winget not available. Please install App Installer from Microsoft Store."
        return $false
    }

    $tools = @(
        @{ Name = "kind"; Command = "winget install Kubernetes.kind --accept-source-agreements --accept-package-agreements"; WingetPackage = "Kubernetes.kind" }
        @{ Name = "kubectl"; Command = "winget install Kubernetes.kubectl --accept-source-agreements --accept-package-agreements"; WingetPackage = "Kubernetes.kubectl" }
        @{ Name = "helm"; Command = "winget install Helm.Helm --accept-source-agreements --accept-package-agreements"; WingetPackage = "Helm.Helm" }
        @{ Name = "flux"; Command = "winget install FluxCD.Flux --accept-source-agreements --accept-package-agreements"; WingetPackage = "FluxCD.Flux" }
        @{ Name = "yq"; Command = "winget install MikeFarah.yq --accept-source-agreements --accept-package-agreements"; WingetPackage = "MikeFarah.yq" }
        @{ Name = "flux-operator-mcp"; Command = "Invoke-WebRequest -Uri 'https://github.com/controlplaneio-fluxcd/flux-operator/releases/download/v0.27.0/flux-operator-mcp_0.27.0_windows_amd64.zip' -OutFile 'flux-operator-mcp.zip'; Expand-Archive -Path 'flux-operator-mcp.zip' -DestinationPath 'temp-flux' -Force; `$fluxPath = Split-Path (Get-Command flux).Source; Move-Item 'temp-flux/flux-operator-mcp.exe' `$fluxPath; Remove-Item 'flux-operator-mcp.zip', 'temp-flux' -Force -Recurse"; WingetPackage = "" }
    )

    $allSuccess = $true
    foreach ($tool in $tools) {
        if (-not (Test-Tool -Tool $tool.Name -InstallCommand $tool.Command -WingetPackage $tool.WingetPackage)) {
            $allSuccess = $false
        }
    }

    return $allSuccess
}

function Install-WithChocolatey {
    Log-Info "Tools"

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
        @{ Name = "yq"; Command = "choco install yq -y" }
        @{ Name = "flux-operator-mcp"; Command = "Invoke-WebRequest -Uri 'https://github.com/controlplaneio-fluxcd/flux-operator/releases/download/v0.27.0/flux-operator-mcp_0.27.0_windows_amd64.zip' -OutFile 'flux-operator-mcp.zip'; Expand-Archive -Path 'flux-operator-mcp.zip' -DestinationPath 'temp-flux' -Force; `$fluxPath = Split-Path (Get-Command flux).Source; Move-Item 'temp-flux/flux-operator-mcp.exe' `$fluxPath; Remove-Item 'flux-operator-mcp.zip', 'temp-flux' -Force -Recurse" }
    )

    $allSuccess = $true
    foreach ($tool in $tools) {
        if (-not (Test-Tool -Tool $tool.Name -InstallCommand $tool.Command -WingetPackage $tool.WingetPackage)) {
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
    Log-Info "  - flux-operator-mcp: https://github.com/controlplaneio-fluxcd/flux-operator/releases/latest"

    Log-Info ""
    Log-Info "Alternatively, install a package manager:"
    Log-Info "  - Winget (recommended): Included with Windows 11, or install App Installer from Microsoft Store"
    Log-Info "  - Chocolatey: https://chocolatey.org/install"

    return $false
}


function Install-Dependencies {
    Log-Info "Checking dependencies..."
    Log-Info "------------------------"
    Log-Info "Dependency Configuration"

    $success = $false

    # Select package manager based on PACKAGE_MANAGER setting
    if (-not $env:PACKAGE_MANAGER) {
        # Auto-detect: prefer winget, then chocolatey, then manual
        if (Test-Command "winget") {
            Log-Info "  Package Manager: Winget (auto-detected)"
            Log-Info "  Platform: Windows"
            Log-Info "------------------------"
            $success = Install-WithWinget
        } elseif (Test-Command "choco") {
            Log-Info "  Package Manager: Chocolatey (auto-detected)"
            Log-Info "  Platform: Windows"
            Log-Info "------------------------"
            $success = Install-WithChocolatey
        } else {
            if ($env:LOG_LEVEL -ne "info") {
                Log-Info "------------------------"
            }
            Log-Error "No supported package manager found (winget or chocolatey)."
            $success = Install-Manually
        }
    } elseif ($env:PACKAGE_MANAGER -eq "winget") {
        # Force Winget
        if (Test-Command "winget") {
            if ($env:LOG_LEVEL -ne "info") {
                Log-Info "  Package Manager: Winget (forced)"
                Log-Info "  Platform: Windows"
                Log-Info "------------------------"
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
                Log-Info "  Package Manager: Chocolatey (forced)"
                Log-Info "  Platform: Windows"
                Log-Info "------------------------"
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
            Log-Info "  Package Manager: Manual (forced)"
            Log-Debug "  Platform: Windows"
            Log-Info "------------------------"
        }
        $success = Install-Manually
    } else {
        Log-Error "Invalid PACKAGE_MANAGER value: '$($env:PACKAGE_MANAGER)'"
        Log-Info "Valid options for Windows: winget, chocolatey, choco, manual"
        return $false
    }


    Log-Info "------------------------"

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
