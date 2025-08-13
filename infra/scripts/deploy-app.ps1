# infra/scripts/deploy-app.ps1 - Deploy applications for Windows
. "$PSScriptRoot\common.ps1"

function Show-Usage {
    Write-Host "Usage: deploy-app.ps1 <app-name> [namespace] [remove]"
    Write-Host ""
    Write-Host "Deploy or remove applications in the cluster."
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  app-name     Name of the application to deploy (required)"
    Write-Host "  namespace    Target namespace (optional, defaults to 'default')"
    Write-Host "  remove       Remove the application instead of deploying"
}

function Deploy-Application {
    param(
        [string]$AppName,
        [string]$Namespace = "default",
        [bool]$Remove = $false
    )
    
    $appPath = Join-Path "software" "apps" $AppName
    
    if (-not (Test-Path $appPath)) {
        Log-Error "Application '$AppName' not found at $appPath"
        Log-Info "Available applications:"
        $apps = Get-ChildItem "software/apps" -Directory -ErrorAction SilentlyContinue
        if ($apps) {
            $apps | ForEach-Object { Log-Info "  $($_.Name)" }
        } else {
            Log-Info "  No applications found"
        }
        return $false
    }
    
    if ($Remove) {
        Log-Info "Removing application '$AppName' from namespace '$Namespace'..."
        try {
            kubectl delete -k $appPath --namespace=$Namespace 2>$null
            Log-Success "Application '$AppName' removed successfully"
            return $true
        } catch {
            Log-Error "Failed to remove application '$AppName': $_"
            return $false
        }
    } else {
        Log-Info "Deploying application '$AppName' to namespace '$Namespace'..."
        try {
            # Ensure namespace exists
            kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - 2>$null
            
            # Deploy application
            kubectl apply -k $appPath --namespace=$Namespace
            
            if ($LASTEXITCODE -eq 0) {
                Log-Success "Application '$AppName' deployed successfully"
                return $true
            } else {
                Log-Error "Failed to deploy application '$AppName'"
                return $false
            }
        } catch {
            Log-Error "Failed to deploy application '$AppName': $_"
            return $false
        }
    }
}

function Main {
    param([string[]]$Arguments)
    
    if ($Arguments.Count -eq 0) {
        Show-Usage
        return 1
    }
    
    $appName = $Arguments[0]
    $namespace = if ($Arguments.Count -gt 1) { $Arguments[1] } else { "default" }
    $remove = $Arguments -contains "remove"
    
    # Check cluster connectivity
    Test-ClusterRunning
    
    if (Deploy-Application -AppName $appName -Namespace $namespace -Remove $remove) {
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