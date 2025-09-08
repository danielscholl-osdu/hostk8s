# infra/scripts/install.ps1 - Install required dependencies for Windows
# Error handling - equivalent to 'set -euo pipefail'
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:Verbose'] = $false

# Disable debug mode to prevent environment variable exposure
$DebugPreference = "SilentlyContinue"

# Set UTF-8 encoding for proper emoji display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Colors and formatting
$Global:GREEN = [System.ConsoleColor]::Green
$Global:YELLOW = [System.ConsoleColor]::Yellow
$Global:RED = [System.ConsoleColor]::Red
$Global:BLUE = [System.ConsoleColor]::Blue
$Global:CYAN = [System.ConsoleColor]::Cyan

# Logging functions with log levels
# LOG_LEVEL can be: debug (default) or info
# debug: shows all messages
# info: shows only info, warn, error (hides debug messages)

function Log-Debug {
    param([string]$Message)
    # Only show debug messages if LOG_LEVEL is not set to info
    if ($env:LOG_LEVEL -ne "info") {
        $timestamp = Get-Date -Format 'HH:mm:ss'
        Write-Host "[$timestamp]" -ForegroundColor $Global:GREEN -NoNewline

        # Parse message for colored variables (pattern: variable_name: variable_value)
        if ($Message -match '^(\s+\w+):\s(.+)$') {
            $label = $matches[1]
            $value = $matches[2]
            Write-Host "$label" -NoNewline
            Write-Host ": " -NoNewline
            Write-Host $value -ForegroundColor $Global:CYAN
        } else {
            Write-Host " $Message"
        }
    }
}

function Log-Info {
    param([string]$Message)
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$timestamp]" -ForegroundColor $Global:BLUE -NoNewline
    Write-Host " $Message"
}

function Log-Success {
    param([string]$Message)
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$timestamp]" -ForegroundColor $Global:BLUE -NoNewline
    Write-Host " $Message"
}

function Log-Warn {
    param([string]$Message)
    $timestamp = Get-Date -Format 'HH:mm:ss'
    if ($env:QUIET -eq "true") {
        Write-Host "[$timestamp]" -ForegroundColor $Global:YELLOW -NoNewline
        Write-Host " WARNING: $Message"
    } else {
        Write-Host "[$timestamp]" -ForegroundColor $Global:YELLOW -NoNewline
        Write-Host " ! $Message"
    }
}

function Log-Error {
    param([string]$Message)
    $timestamp = Get-Date -Format 'HH:mm:ss'
    if ($env:QUIET -eq "true") {
        Write-Host "[$timestamp]" -ForegroundColor $Global:RED -NoNewline
        Write-Host " ERROR: $Message"
    } else {
        Write-Host "[$timestamp]" -ForegroundColor $Global:RED -NoNewline
        Write-Host " ❌ $Message"
    }
}

# Log-Debug with colored version support (matches Linux log_debug behavior)
function Log-DebugWithColor {
    param([string]$Tool, [string]$Version)
    if ($env:LOG_LEVEL -ne "info") {
        $timestamp = Get-Date -Format 'HH:mm:ss'
        Write-Host "[$timestamp]" -ForegroundColor Green -NoNewline
        Write-Host "  ${Tool}: " -NoNewline
        Write-Host $Version -ForegroundColor Cyan
    }
}

# Utility functions
function Test-Command {
    param([string]$Command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        if(Get-Command $Command){
            return $true
        }
    }
    catch {
        return $false
    }
    finally {
        $ErrorActionPreference=$oldPreference
    }
}

function Test-WingetPackage {
    param([string]$PackageName)
    try {
        $result = winget list --id $PackageName --exact 2>$null
        return $LASTEXITCODE -eq 0 -and ($result -like "*$PackageName*")
    } catch {
        return $false
    }
}

function RefreshEnvironmentPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $env:PATH = $machinePath + ";" + $userPath
}

function Show-Usage {
    Write-Host "Usage: install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Install required dependencies for HostK8s on Windows."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -h, -help    Show this help"
    Write-Host ""
    Write-Host "Required tools: kind, kubectl, helm, flux, flux-operator-mcp, yq, docker"
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
            "pre-commit" {
                try {
                    $output = pre-commit --version 2>$null
                    if ($LASTEXITCODE -eq 0 -and $output -match 'v?([0-9.]+)') {
                        $version = $matches[1]
                    }
                } catch { }
            }
            "yamllint" {
                try {
                    $output = yamllint --version 2>$null
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
            "pre-commit" {
                try {
                    $output = pre-commit --version 2>$null
                    if ($LASTEXITCODE -eq 0 -and $output -match 'v?([0-9.]+)') {
                        $version = $matches[1]
                    }
                } catch { }
            }
            "yamllint" {
                try {
                    $output = yamllint --version 2>$null
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
        Log-Debug "Installing $Tool..."
        try {
            Invoke-Expression $InstallCommand
            RefreshEnvironmentPath

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
                "pre-commit" {
                    try {
                        $output = pre-commit --version 2>$null
                        if ($LASTEXITCODE -eq 0 -and $output -match 'v?([0-9.]+)') {
                            $version = $matches[1]
                        }
                    } catch { }
                }
                "yamllint" {
                    try {
                        $output = yamllint --version 2>$null
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
        } catch {
            Log-Error "Failed to install ${Tool}: $_"
            return $false
        }
    } else {
        Log-Error "$Tool not found"
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
        @{ Name = "pre-commit"; Command = "pip install pre-commit"; WingetPackage = "" }
        @{ Name = "yamllint"; Command = "pip install yamllint"; WingetPackage = "" }
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
        @{ Name = "pre-commit"; Command = "pip install pre-commit" }
        @{ Name = "yamllint"; Command = "pip install yamllint" }
    )

    $allSuccess = $true
    foreach ($tool in $tools) {
        if (-not (Test-Tool -Tool $tool.Name -InstallCommand $tool.Command -WingetPackage "")) {
            $allSuccess = $false
        }
    }

    return $allSuccess
}

function Install-WithAPT {
    Log-Info "Tools"

    # Update package list
    Log-Debug "Updating package list..."
    sudo apt update

    $tools = @(
        @{ Name = "kind"; Command = "curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind" }
        @{ Name = "kubectl"; Command = "sudo apt install -y kubectl" }
        @{ Name = "helm"; Command = "curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null && echo 'deb [arch=`$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main' | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list && sudo apt update && sudo apt install -y helm" }
        @{ Name = "flux"; Command = "curl -s https://fluxcd.io/install.sh | sudo bash" }
        @{ Name = "flux-operator-mcp"; Command = "curl -sL https://github.com/controlplaneio-fluxcd/flux-operator-mcp/releases/latest/download/flux-operator-mcp-linux-amd64.tar.gz | tar xz && sudo mv flux-operator-mcp /usr/local/bin/" }
        @{ Name = "yq"; Command = "sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq" }
        @{ Name = "pre-commit"; Command = "pip3 install --user pre-commit || sudo apt install -y pre-commit" }
        @{ Name = "yamllint"; Command = "pip3 install --user yamllint || sudo apt install -y yamllint" }
    )

    $allSuccess = $true
    foreach ($tool in $tools) {
        if (-not (Test-Tool -Tool $tool.Name -InstallCommand $tool.Command -WingetPackage "")) {
            $allSuccess = $false
        }
    }

    return $allSuccess
}

function Install-WithAPK {
    Log-Info "Tools"

    $tools = @(
        @{ Name = "kind"; Command = "curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind" }
        @{ Name = "kubectl"; Command = "sudo apk add --no-cache kubectl" }
        @{ Name = "helm"; Command = "sudo apk add --no-cache helm" }
        @{ Name = "flux"; Command = "curl -s https://fluxcd.io/install.sh | sudo sh" }
        @{ Name = "flux-operator-mcp"; Command = "curl -sL https://github.com/controlplaneio-fluxcd/flux-operator-mcp/releases/latest/download/flux-operator-mcp-linux-amd64.tar.gz | tar xz && sudo mv flux-operator-mcp /usr/local/bin/" }
        @{ Name = "yq"; Command = "sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq" }
        @{ Name = "pre-commit"; Command = "pip3 install --user pre-commit" }
        @{ Name = "yamllint"; Command = "pip3 install --user yamllint || sudo apk add --no-cache yamllint" }
    )

    $allSuccess = $true
    foreach ($tool in $tools) {
        if (-not (Test-Tool -Tool $tool.Name -InstallCommand $tool.Command -WingetPackage "")) {
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
    Log-Info "  - yq: https://github.com/mikefarah/yq#install"
    Log-Info "  - pre-commit: https://pre-commit.com/#installation"
    Log-Info "  - yamllint: https://yamllint.readthedocs.io/en/stable/quickstart.html#installing-yamllint"

    Log-Info ""
    Log-Info "Alternatively, install a package manager:"
    Log-Info "  - Winget (recommended): Included with Windows 11, or install App Installer from Microsoft Store"
    Log-Info "  - Chocolatey: https://chocolatey.org/install"

    return $false
}

function Validate-CIEnvironment {
    param([string]$EnvName)
    Log-Debug "$EnvName environment detected - dependencies should be pre-installed"

    $tools = @("kind", "kubectl", "helm", "flux", "flux-operator-mcp", "yq")
    $missingTools = @()

    foreach ($tool in $tools) {
        if (-not (Test-Command $tool)) {
            $missingTools += $tool
        }
    }

    if ($missingTools.Length -ne 0) {
        Log-Error "Missing tools in CI environment: $($missingTools -join ', ')"
        return $false
    }

    Log-Success "All CI dependencies verified"
    return $true
}

function Install-Dependencies {
    Log-Info "[Script 💻] Running script: install.ps1"
    Log-Info "[Install] Checking dependencies..."
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
            Log-Info "Required tools: kind, kubectl, helm, flux, flux-operator-mcp, yq, docker"
            Log-Info "Installation guides:"
            Log-Info "  - kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
            Log-Info "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
            Log-Info "  - helm: https://helm.sh/docs/intro/install/"
            Log-Info "  - flux: https://fluxcd.io/flux/installation/"
            Log-Info "  - flux-operator-mcp: https://fluxcd.control-plane.io/mcp/install/"
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

    # Always check Docker separately (required on all platforms)
    if (-not (Test-Command "docker")) {
        Log-Error "Docker not available"
        Log-Info "Install Docker Desktop: https://docs.docker.com/get-docker/"
        return $false
    }

    Log-Info "------------------------"
    if ($success) {
        Log-Info "[Install] All dependencies verified ✅"
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
