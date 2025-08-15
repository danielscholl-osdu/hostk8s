# infra/scripts/flux-suspend.ps1 - Suspend/Resume Flux GitRepository sources
$ErrorActionPreference = "Stop"
$DebugPreference = "SilentlyContinue"  # Prevent secret exposure
. "$PSScriptRoot\common.ps1"

function Show-Usage {
    Write-Host "Usage: flux-suspend.ps1 [suspend|resume]"
    Write-Host ""
    Write-Host "Suspend or resume all Flux GitRepository sources."
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  suspend    Suspend all GitRepository sources (pause GitOps)"
    Write-Host "  resume     Resume all GitRepository sources (restore GitOps)"
    Write-Host "  -h, --help Show this help"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  flux-suspend.ps1 suspend     # Pause all GitOps reconciliation"
    Write-Host "  flux-suspend.ps1 resume      # Restore all GitOps reconciliation"
}

function Get-GitRepositories {
    try {
        $cmd = "flux get sources git --no-header 2>`$null"
        $output = Invoke-Expression $cmd
        if ($LASTEXITCODE -eq 0 -and $output) {
            $lines = $output -split "`n" | Where-Object { $_.Trim() }
            $repos = @()
            foreach ($line in $lines) {
                $parts = $line -split "`t"
                if ($parts.Count -gt 0) {
                    $repos += $parts[0].Trim()
                }
            }
            return $repos
        }
        return @()
    } catch {
        return @()
    }
}

function Suspend-Repositories {
    Log-Info "Suspending all GitRepository sources..."

    $gitRepos = Get-GitRepositories

    if ($gitRepos.Count -eq 0) {
        Log-Warn "No GitRepositories found"
        return $true
    }

    $failedRepos = @()
    $suspendedCount = 0

    foreach ($repo in $gitRepos) {
        Log-Info "  → Suspending repository: $repo"
        try {
            $cmd = "flux suspend source git `"$repo`" 2>`$null"
            $null = Invoke-Expression $cmd
            if ($LASTEXITCODE -eq 0) {
                $suspendedCount++
            } else {
                Log-Error "  ❌ Failed to suspend $repo"
                $failedRepos += $repo
            }
        } catch {
            Log-Error "  ❌ Failed to suspend $repo : $_"
            $failedRepos += $repo
        }
    }

    if ($failedRepos.Count -gt 0) {
        Log-Error "Failed to suspend repositories: $($failedRepos -join ', ')"
        return $false
    }

    Log-Success "Successfully suspended $suspendedCount GitRepository sources"
    Log-Info "GitOps reconciliation is now paused. Use 'make resume' to restore."
    return $true
}

function Resume-Repositories {
    Log-Info "Resuming all GitRepository sources..."

    $gitRepos = Get-GitRepositories

    if ($gitRepos.Count -eq 0) {
        Log-Warn "No GitRepositories found"
        return $true
    }

    $failedRepos = @()
    $resumedCount = 0

    foreach ($repo in $gitRepos) {
        Log-Info "  → Resuming repository: $repo"
        try {
            $cmd = "flux resume source git `"$repo`" 2>`$null"
            $null = Invoke-Expression $cmd
            if ($LASTEXITCODE -eq 0) {
                $resumedCount++
            } else {
                Log-Error "  ❌ Failed to resume $repo"
                $failedRepos += $repo
            }
        } catch {
            Log-Error "  ❌ Failed to resume $repo : $_"
            $failedRepos += $repo
        }
    }

    if ($failedRepos.Count -gt 0) {
        Log-Error "Failed to resume repositories: $($failedRepos -join ', ')"
        return $false
    }

    Log-Success "Successfully resumed $resumedCount GitRepository sources"
    Log-Info "GitOps reconciliation is now active. Use 'make sync' to force reconciliation."
    return $true
}

function Main {
    param([string[]]$Arguments)

    $action = ""

    # Parse arguments
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        switch ($Arguments[$i]) {
            "suspend" {
                $action = "suspend"
            }
            "resume" {
                $action = "resume"
            }
            "-h" { Show-Usage; return 0 }
            "--help" { Show-Usage; return 0 }
            "help" { Show-Usage; return 0 }
            default {
                Log-Error "Unknown option: $($Arguments[$i])"
                Show-Usage
                return 1
            }
        }
    }

    if ([string]::IsNullOrEmpty($action)) {
        Log-Error "Missing action: suspend or resume"
        Show-Usage
        return 1
    }

    # Check cluster connectivity
    Test-ClusterRunning

    # Check if Flux is installed
    try {
        $null = kubectl get namespace flux-system 2>$null
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Flux is not installed in this cluster"
            Log-Info "Enable Flux with: make up sample"
            return 1
        }
    } catch {
        Log-Error "Flux is not installed in this cluster"
        Log-Info "Enable Flux with: make up sample"
        return 1
    }

    # Check if Flux CLI is available
    if (-not (Test-Command "flux")) {
        Log-Error "flux CLI not available"
        Log-Info "Install with: make install"
        return 1
    }

    Log-Start "Managing GitRepository sources..."

    # Execute action
    $success = $false
    if ($action -eq "suspend") {
        $success = Suspend-Repositories
    } elseif ($action -eq "resume") {
        $success = Resume-Repositories
    }

    if ($success) {
        Log-Success "Operation complete! Run 'make status' to check results."
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
