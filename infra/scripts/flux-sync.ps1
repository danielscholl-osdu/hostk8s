# infra/scripts/flux-sync.ps1 - Force Flux reconciliation for Windows
. "$PSScriptRoot\common.ps1"

function Show-Usage {
    Write-Host "Usage: flux-sync.ps1 [--repo <name>] [--kustomization <name>]"
    Write-Host ""
    Write-Host "Force Flux reconciliation of GitOps resources."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --repo <name>           Force reconcile specific git repository"
    Write-Host "  --kustomization <name>  Force reconcile specific kustomization"
    Write-Host "  (no options)            Force reconcile all resources"
}

function Sync-FluxResources {
    param(
        [string]$RepoName = "",
        [string]$KustomizationName = ""
    )
    
    # Check if Flux is available
    if (-not (Test-Command "flux")) {
        Log-Error "Flux CLI not available. Install with: winget install fluxcd.flux2"
        return $false
    }
    
    # Check if Flux is installed in cluster
    try {
        $null = kubectl get namespace flux-system 2>$null
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Flux not installed in cluster. Run 'make start' with FLUX_ENABLED=true"
            return $false
        }
    } catch {
        Log-Error "Unable to check Flux installation: $_"
        return $false
    }
    
    try {
        if ($RepoName) {
            Log-Info "Force reconciling git repository '$RepoName'..."
            flux reconcile source git $RepoName
        } elseif ($KustomizationName) {
            Log-Info "Force reconciling kustomization '$KustomizationName'..."
            flux reconcile kustomization $KustomizationName
        } else {
            Log-Info "Force reconciling all Flux resources..."
            
            # Get all git repositories and reconcile them
            $gitRepos = flux get sources git --no-header 2>$null
            if ($LASTEXITCODE -eq 0 -and $gitRepos) {
                $lines = $gitRepos -split "`n" | Where-Object { $_.Trim() }
                foreach ($line in $lines) {
                    $parts = $line -split "`t"
                    if ($parts.Count -gt 0) {
                        $repoName = $parts[0].Trim()
                        Log-Debug "Reconciling git repository: $repoName"
                        flux reconcile source git $repoName 2>$null
                    }
                }
            }
            
            # Get all kustomizations and reconcile them
            $kustomizations = flux get kustomizations --no-header 2>$null
            if ($LASTEXITCODE -eq 0 -and $kustomizations) {
                $lines = $kustomizations -split "`n" | Where-Object { $_.Trim() }
                foreach ($line in $lines) {
                    $parts = $line -split "`t"
                    if ($parts.Count -gt 0) {
                        $kustomizationName = $parts[0].Trim()
                        Log-Debug "Reconciling kustomization: $kustomizationName"
                        flux reconcile kustomization $kustomizationName 2>$null
                    }
                }
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            Log-Success "Flux reconciliation completed"
            Log-Info "Use 'make status' to check deployment status"
            return $true
        } else {
            Log-Error "Flux reconciliation failed"
            return $false
        }
    } catch {
        Log-Error "Failed to reconcile Flux resources: $_"
        return $false
    }
}

function Main {
    param([string[]]$Arguments)
    
    $repoName = ""
    $kustomizationName = ""
    
    # Parse arguments
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        switch ($Arguments[$i]) {
            "--repo" {
                if ($i + 1 -lt $Arguments.Count) {
                    $repoName = $Arguments[$i + 1]
                    $i++
                } else {
                    Log-Error "Missing repository name after --repo"
                    Show-Usage
                    return 1
                }
            }
            "--kustomization" {
                if ($i + 1 -lt $Arguments.Count) {
                    $kustomizationName = $Arguments[$i + 1]
                    $i++
                } else {
                    Log-Error "Missing kustomization name after --kustomization"
                    Show-Usage
                    return 1
                }
            }
            "-h" { Show-Usage; return 0 }
            "--help" { Show-Usage; return 0 }
            default {
                Log-Error "Unknown option: $($Arguments[$i])"
                Show-Usage
                return 1
            }
        }
    }
    
    # Check cluster connectivity
    Test-ClusterRunning
    
    if (Sync-FluxResources -RepoName $repoName -KustomizationName $kustomizationName) {
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