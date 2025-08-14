# infra/scripts/flux-sync.ps1 - Force Flux reconciliation for Windows
. "$PSScriptRoot\common.ps1"

function Show-Usage {
    Write-Host "Usage: flux-sync.ps1 [--stack <name>] [--repo <name>] [--kustomization <name>]"
    Write-Host ""
    Write-Host "Force Flux reconciliation of GitOps resources."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --stack <name>          Sync specific stack (source + kustomization)"
    Write-Host "  --repo <name>           Sync specific GitRepository"
    Write-Host "  --kustomization <name>  Sync specific Kustomization"
    Write-Host "  -h, --help              Show this help"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  flux-sync.ps1                    # Sync all sources and stacks"
    Write-Host "  flux-sync.ps1 --stack sample     # Sync source + sample stack"
    Write-Host "  flux-sync.ps1 --repo my-repo     # Sync specific repository"
    Write-Host "  flux-sync.ps1 --kustomization my-kust  # Sync specific kustomization"
}

function Sync-Stack {
    param([string]$StackName)

    Log-Info "Syncing stack: $StackName"

    # First sync the git source
    Log-Info "  → Syncing flux-system repository"
    $cmd = "flux reconcile source git flux-system 2>`$null"
    $null = Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to sync flux-system repository"
        return $false
    }

    # Then sync the bootstrap stack kustomization with source
    $bootstrapKust = "bootstrap-stack"
    Log-Info "  → Syncing $bootstrapKust kustomization"
    $cmd = "flux reconcile kustomization `"$bootstrapKust`" --with-source 2>`$null"
    $null = Invoke-Expression $cmd
    if ($LASTEXITCODE -eq 0) {
        Log-Success "Successfully synced stack: $StackName"
        return $true
    } else {
        Log-Error "Failed to sync stack: $StackName"
        return $false
    }
}

function Sync-FluxResources {
    param(
        [string]$StackName = "",
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
        if ($StackName) {
            return Sync-Stack -StackName $StackName
        } elseif ($RepoName) {
            Log-Info "Force reconciling git repository '$RepoName'..."
            flux reconcile source git $RepoName
        } elseif ($KustomizationName) {
            Log-Info "Force reconciling kustomization '$KustomizationName'..."
            flux reconcile kustomization $KustomizationName
        } else {
            Log-Info "Syncing all GitRepositories and stack kustomizations..."

            # Get all git repositories and reconcile them
            $gitRepos = flux get sources git --no-header 2>$null
            if ($LASTEXITCODE -eq 0 -and $gitRepos) {
                $lines = $gitRepos -split "`n" | Where-Object { $_.Trim() }
                foreach ($line in $lines) {
                    $parts = $line -split "`t"
                    if ($parts.Count -gt 0) {
                        $repoName = $parts[0].Trim()
                        Write-Host "  → Syncing repository: $repoName"
                        flux reconcile source git $repoName 2>$null
                    }
                }
            }

            # Sync stack kustomizations (bootstrap-stack and any others)
            $cmd = "flux get kustomizations --no-header 2>`$null | Select-String -Pattern `"bootstrap-stack|stack$`""
            $stackKustomizations = Invoke-Expression $cmd
            if ($stackKustomizations) {
                $lines = $stackKustomizations -split "`n" | Where-Object { $_.Trim() }
                foreach ($line in $lines) {
                    $parts = $line -split "`t"
                    if ($parts.Count -gt 0) {
                        $kustomizationName = $parts[0].Trim()
                        Write-Host "  → Syncing stack kustomization: $kustomizationName"
                        $cmd = "flux reconcile kustomization `"$kustomizationName`" --with-source 2>`$null"
                        Invoke-Expression $cmd
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

    $stackName = ""
    $repoName = ""
    $kustomizationName = ""

    # Parse arguments
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        switch ($Arguments[$i]) {
            "--stack" {
                if ($i + 1 -lt $Arguments.Count) {
                    $stackName = $Arguments[$i + 1]
                    $i++
                } else {
                    Log-Error "Missing stack name after --stack"
                    Show-Usage
                    return 1
                }
            }
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

    if (Sync-FluxResources -StackName $stackName -RepoName $repoName -KustomizationName $kustomizationName) {
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
