# infra/scripts/cluster-status.ps1 - Show cluster health and running services for Windows
. "$PSScriptRoot\common.ps1"

function Show-KubeconfigInfo {
    Log-Debug "export KUBECONFIG=$(Get-Location)\data\kubeconfig\config"
    Write-Host ""
}

function Test-FluxCLI {
    return (Test-Command "flux")
}

function Test-Flux {
    try {
        $null = kubectl get namespace flux-system 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Show-GitOpsResources {
    if (-not (Test-Flux)) {
        return
    }
    
    # Only show this section if there are actual GitOps resources configured
    $hasGitRepos = 0
    $hasKustomizations = 0
    
    if (Test-FluxCLI) {
        try {
            $gitOutput = flux get sources git 2>$null
            if ($LASTEXITCODE -eq 0 -and $gitOutput -match "^NAME") {
                $hasGitRepos = ($gitOutput -split "`n" | Where-Object { $_ -notmatch "^NAME" -and $_.Trim() }).Count
            }
            
            $kustomizationOutput = flux get kustomizations 2>$null
            if ($LASTEXITCODE -eq 0 -and $kustomizationOutput -match "^NAME") {
                $hasKustomizations = ($kustomizationOutput -split "`n" | Where-Object { $_ -notmatch "^NAME" -and $_.Trim() }).Count
            }
        } catch { }
    }
    
    if ($hasGitRepos -gt 0 -or $hasKustomizations -gt 0) {
        Log-Info "GitOps Resources"
        Show-GitRepositories
        Show-Kustomizations
    }
}

function Show-GitRepositories {
    if (Test-FluxCLI) {
        try {
            $gitOutput = flux get sources git 2>$null
            if ($LASTEXITCODE -ne 0 -or -not ($gitOutput -match "^NAME")) {
                Write-Host "📁 No GitRepositories configured"
                Write-Host "   Run 'make restart sample' to configure a software stack"
                Write-Host ""
                return
            }
            
            $lines = $gitOutput -split "`n" | Where-Object { $_ -notmatch "^NAME" -and $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "`t"
                if ($parts.Count -ge 4) {
                    $name = $parts[0].Trim()
                    $revision = $parts[1].Trim()
                    $suspended = $parts[2].Trim()
                    $ready = $parts[3].Trim()
                    $message = if ($parts.Count -gt 4) { $parts[4].Trim() } else { "" }
                    
                    $repoUrl = "unknown"
                    $branch = "unknown"
                    
                    try {
                        $repoUrl = kubectl get gitrepository.source.toolkit.fluxcd.io $name -n flux-system -o jsonpath='{.spec.url}' 2>$null
                        $branch = kubectl get gitrepository.source.toolkit.fluxcd.io $name -n flux-system -o jsonpath='{.spec.ref.branch}' 2>$null
                    } catch { }
                    
                    Write-Host "📁 Repository: $name"
                    Write-Host "   URL: $repoUrl"
                    Write-Host "   Branch: $branch"
                    Write-Host "   Revision: $revision"
                    Write-Host "   Ready: $ready"
                    Write-Host "   Suspended: $suspended"
                    if ($message -and $message -ne "-") {
                        Write-Host "   Message: $message"
                    }
                    Write-Host ""
                }
            }
        } catch {
            Write-Host "Error retrieving git repositories: $_"
        }
    } else {
        Write-Host "flux CLI not available - showing basic repository status:"
        try {
            $repos = kubectl get gitrepositories.source.toolkit.fluxcd.io -A --no-headers 2>$null
            if ($LASTEXITCODE -ne 0 -or -not $repos) {
                Write-Host "No GitRepositories configured"
                return
            }
            
            $lines = $repos -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Count -ge 3) {
                    $ns = $parts[0]
                    $name = $parts[1]
                    $ready = $parts[2]
                    
                    $repoUrl = "unknown"
                    try {
                        $repoUrl = kubectl get gitrepository.source.toolkit.fluxcd.io $name -n $ns -o jsonpath='{.spec.url}' 2>$null
                    } catch { }
                    
                    Write-Host "Repository: $name ($repoUrl)"
                    Write-Host "Ready: $ready"
                }
            }
        } catch { }
    }
}

function Show-Kustomizations {
    if (-not (Test-FluxCLI)) {
        return
    }
    
    try {
        $kustomizationOutput = flux get kustomizations 2>$null
        if ($LASTEXITCODE -ne 0 -or -not ($kustomizationOutput -match "^NAME")) {
            Write-Host "🔧 No Kustomizations configured"
            Write-Host "   GitOps resources will appear here after configuring a stack"
            Write-Host ""
            return
        }
        
        $lines = $kustomizationOutput -split "`n" | Where-Object { $_ -notmatch "^NAME" -and $_.Trim() }
        foreach ($line in $lines) {
            $parts = $line -split "`t"
            if ($parts.Count -ge 4) {
                $name = $parts[0].Trim()
                $revision = $parts[1].Trim()
                $suspended = $parts[2].Trim()
                $ready = $parts[3].Trim()
                $message = if ($parts.Count -gt 4) { $parts[4].Trim() } else { "" }
                
                $sourceRef = "unknown"
                try {
                    $sourceRef = kubectl get kustomization.kustomize.toolkit.fluxcd.io $name -n flux-system -o jsonpath='{.spec.sourceRef.name}' 2>$null
                } catch { }
                
                $statusIcon = "[...]"
                if ($suspended -eq "True") {
                    $statusIcon = "[PAUSED]"
                } elseif ($ready -eq "True") {
                    $statusIcon = "[OK]"
                } elseif ($ready -eq "False") {
                    if ($message -match "dependency.*is not ready") {
                        $statusIcon = "[WAITING]"
                    } else {
                        $statusIcon = "[FAIL]"
                    }
                }
                
                Write-Host "$statusIcon Kustomization: $name"
                Write-Host "   Source: $sourceRef"
                Write-Host "   Revision: $revision"
                Write-Host "   Ready: $ready"
                Write-Host "   Suspended: $suspended"
                if ($message -and $message -ne "-") {
                    Write-Host "   Message: $message"
                }
                Write-Host ""
            }
        }
    } catch {
        Write-Host "Error retrieving kustomizations: $_"
    }
}

function Test-IngressControllerReady {
    try {
        $deployment = kubectl get deployment ingress-nginx-controller -n ingress-nginx --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $deployment) {
            $parts = $deployment -split "\s+"
            if ($parts.Count -ge 2) {
                $ready = $parts[1]
                $readyParts = $ready -split "/"
                if ($readyParts.Count -eq 2 -and $readyParts[0] -eq $readyParts[1] -and [int]$readyParts[0] -gt 0) {
                    return $true
                }
            }
        }
        return $false
    } catch {
        return $false
    }
}

function Show-IngressControllerStatus {
    if (Test-IngressControllerReady) {
        Write-Host "🌐 Ingress Controller: ingress-nginx (Ready ✅)"
        Write-Host "   Access: http://localhost:8080, https://localhost:8443"
    } else {
        $status = "not found"
        try {
            $deployment = kubectl get deployment ingress-nginx-controller -n ingress-nginx --no-headers 2>$null
            if ($LASTEXITCODE -eq 0) {
                $status = "not ready"
            }
        } catch { }
        Write-Host "🌐 Ingress Controller: ingress-nginx ($status ⚠️)"
    }
    Write-Host ""
}

function Show-ClusterInfo {
    Log-Info "Cluster Information"
    
    try {
        # Check if cluster exists
        $clusters = kind get clusters 2>$null
        if ($LASTEXITCODE -ne 0 -or $clusters -notcontains $env:CLUSTER_NAME) {
            Write-Host "❌ Cluster '$($env:CLUSTER_NAME)' not found"
            Write-Host "   Run 'make start' to create the cluster"
            return
        }
        
        Write-Host "✅ Cluster: $($env:CLUSTER_NAME)"
        
        # Check kubectl connectivity
        try {
            $null = kubectl cluster-info 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ kubectl: Connected"
            } else {
                Write-Host "❌ kubectl: Not connected"
                Write-Host "   Check KUBECONFIG: $env:KUBECONFIG"
                return
            }
        } catch {
            Write-Host "❌ kubectl: Not available"
            return
        }
        
        # Show node status
        try {
            $nodes = kubectl get nodes --no-headers 2>$null
            if ($LASTEXITCODE -eq 0 -and $nodes) {
                $nodeLines = $nodes -split "`n" | Where-Object { $_.Trim() }
                $readyNodes = 0
                $totalNodes = 0
                
                foreach ($line in $nodeLines) {
                    $parts = $line -split "\s+"
                    if ($parts.Count -ge 2) {
                        $totalNodes++
                        if ($parts[1] -eq "Ready") {
                            $readyNodes++
                        }
                    }
                }
                
                if ($readyNodes -eq $totalNodes) {
                    Write-Host "✅ Nodes: $readyNodes/$totalNodes ready"
                } else {
                    Write-Host "⚠️ Nodes: $readyNodes/$totalNodes ready"
                }
            }
        } catch { }
        
        Write-Host ""
    } catch {
        Write-Host "❌ Error checking cluster status: $_"
        Write-Host ""
    }
}

function Show-BasicApps {
    try {
        $deployments = kubectl get deployments --all-namespaces --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $deployments) {
            Log-Info "Applications"
            
            $lines = $deployments -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Count -ge 4) {
                    $namespace = $parts[0]
                    $name = $parts[1]
                    $ready = $parts[2]
                    
                    $displayName = if ($namespace -eq "default") { $name } else { "$namespace.$name" }
                    Write-Host "📱 $displayName ($ready ready)"
                }
            }
            Write-Host ""
        }
    } catch { }
}

# Main status check
try {
    Test-ClusterRunning
    
    Show-ClusterInfo
    Show-GitOpsResources
    Show-IngressControllerStatus
    Show-BasicApps
    Show-KubeconfigInfo
    
    Log-Success "Cluster status check completed"
    
} catch {
    Log-Error "Status check failed: $_"
    exit 1
}