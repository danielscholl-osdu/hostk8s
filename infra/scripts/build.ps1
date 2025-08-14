# infra/scripts/build.ps1 - Build applications for Windows
. "$PSScriptRoot\common.ps1"

function Show-Usage {
    Write-Host "Usage: build.ps1 <app-path>"
    Write-Host ""
    Write-Host "Build and containerize applications from source code."
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  app-path    Path to application source (e.g., src/my-app)"
}

function Build-Application {
    param([string]$AppPath)
    
    if (-not (Test-Path $AppPath)) {
        Log-Error "Application path not found: $AppPath"
        Log-Info "Available applications:"
        $apps = Get-ChildItem "src" -Directory -ErrorAction SilentlyContinue
        if ($apps) {
            $apps | ForEach-Object { Log-Info "  src/$($_.Name)" }
        } else {
            Log-Info "  No applications found in src/"
        }
        return $false
    }
    
    $dockerComposePath = Join-Path $AppPath "docker-compose.yml"
    if (-not (Test-Path $dockerComposePath)) {
        Log-Error "docker-compose.yml not found in $AppPath"
        Log-Info "Build system requires docker-compose.yml for consistent builds"
        return $false
    }
    
    Log-Info "Building application at $AppPath..."
    
    try {
        Push-Location $AppPath
        
        # Build using docker-compose
        docker-compose build
        
        if ($LASTEXITCODE -eq 0) {
            Log-Success "Application built successfully"
            
            # TODO: Tag and push to local registry (localhost:5000)
            Log-Info "Registry push not yet implemented in PowerShell version"
            Log-Info "Use the bash version for complete functionality"
            return $true
        } else {
            Log-Error "Build failed"
            return $false
        }
    } catch {
        Log-Error "Build failed: $_"
        return $false
    } finally {
        Pop-Location
    }
}

function Main {
    param([string[]]$Arguments)
    
    if ($Arguments.Count -eq 0) {
        Show-Usage
        return 1
    }
    
    $appPath = $Arguments[0]
    
    if (Build-Application -AppPath $appPath) {
        return 0
    } else {
        return 1
    }
}

# Run if called directly
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Main -Arguments $args
    exit $exitCode
}