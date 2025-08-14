# infra/scripts/common.ps1 - Shared utilities for HostK8s PowerShell scripts
# Source this file from other scripts: . "$PSScriptRoot\common.ps1"

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

# Convenience aliases for semantic actions
function Log-Start {
    param([string]$Message)
    Log-Info $Message
}

function Log-Clean {
    param([string]$Message)
    Log-Info $Message
}

function Log-Deploy {
    param([string]$Message)
    Log-Info $Message
}

# Winget package verification - more reliable than PATH-based checking
function Test-WingetPackage {
    param([string]$PackageName)
    try {
        $result = winget list $PackageName 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Refresh environment variables to pick up newly installed tools
function RefreshEnvironmentPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $env:PATH = $machinePath + ";" + $userPath
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

function Log-Section-Start {
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$timestamp] ------------------------" -ForegroundColor $Global:GREEN
}

function Log-Status {
    param([string]$Message)
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$timestamp] $Message" -ForegroundColor $Global:GREEN
}

function Log-Section-End {
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$timestamp] ------------------------" -ForegroundColor $Global:GREEN
}

# Environment setup - load .env if exists
function Load-Environment {
    # Clear environment variables that could be set from .env to prevent persistence
    if (Test-Path ".env") {
        # First pass: identify all variables that could be set from .env (including commented ones)
        Get-Content ".env" | ForEach-Object {
            if ($_ -match '^#?([^#=]+)=(.*)$') {
                $varName = $matches[1].Trim()
                if ($varName -and $varName.Length -gt 0) {
                    [Environment]::SetEnvironmentVariable($varName, $null, "Process")
                }
            }
        }

        # Second pass: load only uncommented variables
        Get-Content ".env" | ForEach-Object {
            if ($_ -match '^([^#=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()

                # Remove inline comments (everything after first # including the #)
                if ($value -match '^([^#]*?)(\s*#.*)?$') {
                    $value = $matches[1].Trim()
                }

                # Remove quotes if present
                $value = $value -replace '^"(.*)"$', '$1'
                $value = $value -replace "^'(.*)'$", '$1'
                [Environment]::SetEnvironmentVariable($name, $value, "Process")
            }
        }
    }

    # Set defaults
    if (-not $env:CLUSTER_NAME) { $env:CLUSTER_NAME = "hostk8s" }
    if (-not $env:K8S_VERSION) { $env:K8S_VERSION = "v1.33.2" }
    if (-not $env:KIND_CONFIG) { $env:KIND_CONFIG = "" }
    if (-not $env:METALLB_ENABLED) { $env:METALLB_ENABLED = "false" }
    if (-not $env:INGRESS_ENABLED) { $env:INGRESS_ENABLED = "false" }
    if (-not $env:FLUX_ENABLED) { $env:FLUX_ENABLED = "false" }
    if (-not $env:PACKAGE_MANAGER) { $env:PACKAGE_MANAGER = "" }

    # Set KUBECONFIG paths using PowerShell path joining
    $kubeconfigDir = Join-Path (Get-Location) "data\kubeconfig"
    $env:KUBECONFIG_PATH = Join-Path $kubeconfigDir "config"
    $env:KUBECONFIG = $env:KUBECONFIG_PATH
}

# Validation functions
function Test-Cluster {
    if (-not (Test-Path $env:KUBECONFIG_PATH)) {
        return $false
    }

    try {
        $null = kubectl cluster-info 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Test-ClusterRunning {
    if (-not (Test-Cluster)) {
        Log-Error "Cluster not found or not running. Run 'make start' first."
        exit 1
    }
}

# Cross-platform path operations
function Join-PathSafe {
    param([string[]]$Paths)
    $result = $Paths[0]
    for ($i = 1; $i -lt $Paths.Count; $i++) {
        $result = Join-Path $result $Paths[$i]
    }
    return $result
}

# Cross-platform sed operations equivalent
function Edit-FileInPlace {
    param(
        [string]$Pattern,
        [string]$Replacement,
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Log-Error "File does not exist: $FilePath"
        return $false
    }

    if (-not (Test-Path $FilePath -PathType Leaf)) {
        Log-Error "Path is not a file: $FilePath"
        return $false
    }

    try {
        $content = Get-Content $FilePath -Raw
        $newContent = $content -replace $Pattern, $Replacement
        Set-Content -Path $FilePath -Value $newContent -NoNewline
        return $true
    } catch {
        Log-Error "Failed to edit file $FilePath`: $_"
        return $false
    }
}

# Helper function to set cluster name in .env
function Set-ClusterNameInEnv {
    param([string]$ClusterName, [string]$EnvFile = ".env")

    if (-not (Test-Path $EnvFile)) {
        Log-Error "Environment file does not exist: $EnvFile"
        return $false
    }

    # Update or add CLUSTER_NAME
    $updated = $false
    $lines = Get-Content $EnvFile
    $newLines = @()

    foreach ($line in $lines) {
        if ($line -match '^#?\s*CLUSTER_NAME\s*=') {
            $newLines += "CLUSTER_NAME=$ClusterName"
            $updated = $true
        } else {
            $newLines += $line
        }
    }

    if (-not $updated) {
        $newLines += "CLUSTER_NAME=$ClusterName"
    }

    try {
        Set-Content -Path $EnvFile -Value $newLines
        return $true
    } catch {
        Log-Error "Failed to update $EnvFile`: $_"
        return $false
    }
}

# Helper function to set git branch in .env
function Set-GitOpsBranchInEnv {
    param(
        [string]$GitUser,
        [string]$WorktreeName,
        [string]$EnvFile = ".env"
    )

    if (-not (Test-Path $EnvFile)) {
        Log-Error "Environment file does not exist: $EnvFile"
        return $false
    }

    $branchName = "user/$GitUser/$WorktreeName"

    # Update or add GITOPS_BRANCH
    $updated = $false
    $lines = Get-Content $EnvFile
    $newLines = @()

    foreach ($line in $lines) {
        if ($line -match '^#?\s*GITOPS_BRANCH\s*=') {
            $newLines += "GITOPS_BRANCH=$branchName"
            $updated = $true
        } else {
            $newLines += $line
        }
    }

    if (-not $updated) {
        $newLines += "GITOPS_BRANCH=$branchName"
    }

    try {
        Set-Content -Path $EnvFile -Value $newLines
        return $true
    } catch {
        Log-Error "Failed to update $EnvFile`: $_"
        return $false
    }
}

# Helper function to enable Flux in .env
function Enable-FluxInEnv {
    param([string]$EnvFile = ".env")

    if (-not (Test-Path $EnvFile)) {
        Log-Error "Environment file does not exist: $EnvFile"
        return $false
    }

    # Update or add FLUX_ENABLED
    $updated = $false
    $lines = Get-Content $EnvFile
    $newLines = @()

    foreach ($line in $lines) {
        if ($line -match '^#?\s*FLUX_ENABLED\s*=') {
            $newLines += "FLUX_ENABLED=true"
            $updated = $true
        } else {
            $newLines += $line
        }
    }

    if (-not $updated) {
        $newLines += "FLUX_ENABLED=true"
    }

    try {
        Set-Content -Path $EnvFile -Value $newLines
        return $true
    } catch {
        Log-Error "Failed to update $EnvFile`: $_"
        return $false
    }
}

# Test if a command exists (equivalent to 'command -v')
function Test-Command {
    param([string]$Command)

    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Wait for condition with timeout
function Wait-ForCondition {
    param(
        [scriptblock]$Condition,
        [int]$TimeoutSeconds = 300,
        [int]$IntervalSeconds = 5,
        [string]$Description = "condition"
    )

    $elapsed = 0
    Log-Debug "Waiting for $Description (timeout: ${TimeoutSeconds}s)"

    while ($elapsed -lt $TimeoutSeconds) {
        if (& $Condition) {
            Log-Debug "✅ $Description met after ${elapsed}s"
            return $true
        }

        Start-Sleep -Seconds $IntervalSeconds
        $elapsed += $IntervalSeconds
        Log-Debug "⏳ Still waiting for $Description (${elapsed}s/${TimeoutSeconds}s)"
    }

    Log-Error "❌ Timeout waiting for $Description after ${TimeoutSeconds}s"
    return $false
}

# Get pod count in namespace
function Get-PodCountInNamespace {
    param([string]$Namespace)

    try {
        $output = kubectl get pods -n $Namespace --no-headers 2>$null
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Failed to get pods in namespace $Namespace"
            return 0
        }

        $runningPods = $output | Where-Object { $_ -match "Running" }
        return $runningPods.Count
    } catch {
        Log-Error "Failed to get pod count in namespace $Namespace`: $_"
        return 0
    }
}

# Extract arguments from Make-style input (equivalent to bash argument parsing)
function Get-MakeArguments {
    param([string[]]$Arguments)

    $result = @{}
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $result["arg$($i + 1)"] = $Arguments[$i]
    }
    return $result
}

# Initialize environment on script load
Load-Environment
