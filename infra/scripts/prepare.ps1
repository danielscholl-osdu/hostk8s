# infra/scripts/prepare.ps1 - Setup development environment for Windows
. "$PSScriptRoot\common.ps1"

function Show-Usage {
    Write-Host "Usage: prepare.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Setup HostK8s development environment (pre-commit, yamllint, hooks)."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -h, -help    Show this help"
    Write-Host ""
    Write-Host "Tools installed:"
    Write-Host "  - pre-commit (code quality hooks)"
    Write-Host "  - yamllint (YAML validation)"
    Write-Host "  - pre-commit hooks (configured in .pre-commit-config.yaml)"
}

function Install-PreCommit {
    if (Test-Command "pre-commit") {
        Log-Info "pre-commit already installed"
        return $true
    }
    
    Log-Info "Installing pre-commit..."
    
    # Try different installation methods in order of preference
    if (Test-Command "pipx") {
        try {
            pipx install pre-commit
            if ($LASTEXITCODE -eq 0) {
                Log-Success "pre-commit installed via pipx"
                return $true
            }
        } catch { }
    }
    
    if (Test-Command "winget") {
        try {
            winget install pre-commit --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Log-Success "pre-commit installed via winget"
                return $true
            }
        } catch { }
    }
    
    if (Test-Command "choco") {
        try {
            choco install pre-commit -y
            if ($LASTEXITCODE -eq 0) {
                Log-Success "pre-commit installed via chocolatey"
                return $true
            }
        } catch { }
    }
    
    if (Test-Command "pip3") {
        try {
            pip3 install --user pre-commit
            if ($LASTEXITCODE -eq 0) {
                Log-Success "pre-commit installed via pip3"
                return $true
            }
        } catch { }
    }
    
    if (Test-Command "pip") {
        try {
            pip install pre-commit
            if ($LASTEXITCODE -eq 0) {
                Log-Success "pre-commit installed via pip"
                return $true
            }
        } catch { }
    }
    
    Log-Error "Could not install pre-commit. Please install manually:"
    Log-Info "   pipx install pre-commit (recommended)"
    Log-Info "   # or"
    Log-Info "   winget install pre-commit"
    Log-Info "   # or"
    Log-Info "   choco install pre-commit"
    Log-Info "   # or"
    Log-Info "   pip3 install --user pre-commit"
    return $false
}

function Install-YamlLint {
    if (Test-Command "yamllint") {
        Log-Info "yamllint already installed"
        return $true
    }
    
    Log-Info "Installing yamllint..."
    
    # Try different installation methods
    if (Test-Command "pipx") {
        try {
            pipx install yamllint
            if ($LASTEXITCODE -eq 0) {
                Log-Success "yamllint installed via pipx"
                return $true
            }
        } catch { }
    }
    
    if (Test-Command "pip3") {
        try {
            pip3 install --user yamllint
            if ($LASTEXITCODE -eq 0) {
                Log-Success "yamllint installed via pip3"
                return $true
            }
        } catch { }
    }
    
    if (Test-Command "pip") {
        try {
            pip install yamllint
            if ($LASTEXITCODE -eq 0) {
                Log-Success "yamllint installed via pip"
                return $true
            }
        } catch { }
    }
    
    Log-Error "Could not install yamllint. Please install manually:"
    Log-Info "   pipx install yamllint (recommended)"
    Log-Info "   # or"
    Log-Info "   pip3 install --user yamllint"
    return $false
}

function Install-PreCommitHooks {
    if (-not (Test-Path ".pre-commit-config.yaml")) {
        Log-Warn ".pre-commit-config.yaml not found, skipping hook installation"
        return $true
    }
    
    Log-Info "Installing pre-commit hooks..."
    
    try {
        pre-commit install
        if ($LASTEXITCODE -eq 0) {
            Log-Success "pre-commit hooks installed"
            return $true
        } else {
            Log-Error "Failed to install pre-commit hooks"
            return $false
        }
    } catch {
        Log-Error "Failed to install pre-commit hooks: $_"
        return $false
    }
}

function Test-DevelopmentTools {
    Log-Info "Checking development tools..."
    
    $tools = @("git", "make", "docker")
    $missing = @()
    
    foreach ($tool in $tools) {
        if (Test-Command $tool) {
            Log-Debug "✅ $tool: available"
        } else {
            $missing += $tool
            Log-Warn "❌ $tool: not found"
        }
    }
    
    if ($missing.Count -gt 0) {
        Log-Error "Missing development tools: $($missing -join ', ')"
        Log-Info "Install missing tools:"
        foreach ($tool in $missing) {
            switch ($tool) {
                "git" { Log-Info "  winget install Git.Git" }
                "make" { Log-Info "  winget install ezwinports.make" }
                "docker" { Log-Info "  winget install Docker.DockerDesktop" }
            }
        }
        return $false
    }
    
    return $true
}

function Main {
    param([string[]]$Arguments)
    
    # Parse arguments
    foreach ($arg in $Arguments) {
        switch ($arg.ToLower()) {
            "-h" { Show-Usage; return 0 }
            "-help" { Show-Usage; return 0 }
            "help" { Show-Usage; return 0 }
            default {
                Log-Error "Unknown option: $arg"
                Show-Usage
                return 1
            }
        }
    }
    
    Log-Info "Setting up HostK8s development environment..."
    
    # Check basic development tools
    if (-not (Test-DevelopmentTools)) {
        Log-Error "Please install missing development tools first"
        return 1
    }
    
    # Install development quality tools
    $success = $true
    
    if (-not (Install-PreCommit)) {
        $success = $false
    }
    
    if (-not (Install-YamlLint)) {
        $success = $false
    }
    
    if (-not (Install-PreCommitHooks)) {
        $success = $false
    }
    
    if ($success) {
        Log-Success "Development environment setup completed!"
        Log-Info "You can now use 'make start' to create your first cluster"
        return 0
    } else {
        Log-Error "Development environment setup had some failures"
        return 1
    }
}

# Run if called directly
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Main -Arguments $args
    exit $exitCode
}