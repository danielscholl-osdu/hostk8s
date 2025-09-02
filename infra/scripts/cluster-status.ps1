# infra/scripts/cluster-status.ps1 - Show cluster health and running services for Windows
. "$PSScriptRoot\common.ps1"

function Show-KubeconfigInfo {
    Log-Debug "`$env:KUBECONFIG = `"$(Get-Location)\data\kubeconfig\config`""
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
        Write-Host "🌐 Ingress Controller: ingress-nginx ($status !)"
    }
    Write-Host ""
}


function Test-Metrics {
    try {
        $cmd = "kubectl get deployment metrics-server -n kube-system 2>`$null"
        Invoke-Expression $cmd >$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Show-DockerServices {
    Log-Info "Docker Services"

    $dockerServicesFound = $false

    # Check for hostk8s-registry container
    try {
        $null = docker inspect hostk8s-registry 2>$null
        if ($LASTEXITCODE -eq 0) {
            $containerStatus = docker inspect -f '{{.State.Status}}' hostk8s-registry 2>$null
            $portInfo = docker port hostk8s-registry 2>$null
            $portInfo = if ($portInfo) { ($portInfo -split "`n")[0] -split " " | Select-Object -Last 1 } else { "localhost:5002" }

            if ($containerStatus -eq "running") {
                Write-Host "📦 Registry Container: Ready"
                Write-Host "   Status: Running on $portInfo"
                Write-Host "   Network: Connected to Kind cluster"
            } else {
                Write-Host "📦 Registry Container: $containerStatus"
            }
            $dockerServicesFound = $true
        }
    } catch { }

    # Check for other hostk8s-* containers (future extensions, excluding Kind cluster nodes)
    try {
        $otherContainers = docker ps -a --filter "name=hostk8s-*" --format "{{.Names}}" 2>$null
        if ($LASTEXITCODE -eq 0 -and $otherContainers) {
            $containers = $otherContainers -split "`n" | Where-Object {
                $_ -and $_ -notmatch "hostk8s-registry" -and $_ -notmatch "hostk8s-control-plane" -and $_ -notmatch "hostk8s-worker"
            }
            foreach ($container in $containers) {
                if ($container.Trim()) {
                    $status = docker inspect -f '{{.State.Status}}' $container.Trim() 2>$null
                    Write-Host "🔧 $($container.Trim()): $status"
                    $dockerServicesFound = $true
                }
            }
        }
    } catch { }

    if (-not $dockerServicesFound) {
        Write-Host "   No Docker services running"
    }
    Write-Host ""
}

function Show-AddonStatus {
    Log-Info "Cluster Services"

    # Show cluster nodes
    Show-ClusterNodes

    # Metrics Server status (core cluster infrastructure)
    if ($env:METRICS_DISABLED -ne "true") {
        $metricsStatus = "NotReady"
        $metricsMessage = ""

        if (Test-Metrics) {
            # Check if metrics API is available
            try {
                $cmd = "kubectl top nodes 2>`$null"
                Invoke-Expression $cmd >$null
                if ($LASTEXITCODE -eq 0) {
                    $metricsStatus = "Ready"
                    $metricsMessage = "Resource metrics available (kubectl top)"
                } else {
                    $metricsStatus = "Starting"
                    $metricsMessage = "Metrics API not yet available"
                }
            } catch {
                $metricsStatus = "Starting"
                $metricsMessage = "Metrics API not yet available"
            }
        } else {
            $metricsStatus = "NotReady"
            $metricsMessage = "Deployment not found in kube-system namespace"
        }

        Write-Host "📊 Metrics Server: $metricsStatus"
        if ($metricsMessage) { Write-Host "   Status: $metricsMessage" }
    }

    # Show Flux status if installed
    if (Test-Flux) {
        $fluxStatus = "NotReady"
        $fluxMessage = ""
        $fluxVersion = Get-FluxVersion

        # Check if Flux controllers are running
        try {
            $fluxPods = kubectl get pods -n flux-system --no-headers 2>$null
            if ($LASTEXITCODE -eq 0 -and $fluxPods) {
                $podStates = ($fluxPods -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { ($_ -split "\s+")[2] })
                $runningCount = ($podStates | Where-Object { $_ -eq "Running" }).Count
                $totalCount = $podStates.Count

                if ($runningCount -eq $totalCount -and $totalCount -gt 0) {
                    $fluxStatus = "Ready"
                    $fluxMessage = "GitOps automation available ($fluxVersion)"
                } else {
                    $fluxStatus = "Pending"
                    $fluxMessage = "$runningCount/$totalCount controllers running"
                }
            }
        } catch {
            $fluxStatus = "NotReady"
            $fluxMessage = "Controllers not running"
        }

        Write-Host "🔄 Flux (GitOps): $fluxStatus"
        if ($fluxMessage) { Write-Host "   Status: $fluxMessage" }

        # Show suspended sources count if any
        if (Test-Command "flux") {
            $suspendedCount = 0
            try {
                $cmd = "flux get sources git --no-header 2>`$null"
                $gitOutput = Invoke-Expression $cmd
                if ($LASTEXITCODE -eq 0 -and $gitOutput) {
                    $lines = $gitOutput -split "`n" | Where-Object { $_.Trim() }
                    foreach ($line in $lines) {
                        $parts = $line -split "`t"
                        if ($parts.Count -ge 3 -and $parts[2].Trim() -eq "True") {
                            $suspendedCount++
                        }
                    }
                }
            } catch { }
            if ($suspendedCount -gt 0) {
                Write-Host "   Sources: $suspendedCount suspended ⏸️"
            }
        }
    }

    # Show MetalLB status if installed
    if (Test-MetalLB) {
        $metallbStatus = "NotReady"
        $metallbMessage = ""

        try {
            $metallbPods = kubectl get pods -n metallb-system -l app=metallb --no-headers 2>$null
            if ($LASTEXITCODE -eq 0 -and $metallbPods) {
                $podStates = ($metallbPods -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { ($_ -split "\s+")[2] })
                $runningCount = ($podStates | Where-Object { $_ -eq "Running" }).Count
                $totalCount = $podStates.Count

                if ($runningCount -eq $totalCount -and $totalCount -gt 0) {
                    $metallbStatus = "Ready"
                    $metallbMessage = "LoadBalancer support available"
                } else {
                    $metallbStatus = "Pending"
                    $metallbMessage = "$runningCount/$totalCount pods running"
                }
            }
        } catch {
            $metallbMessage = "Pods not running"
        }

        Write-Host "🔗 MetalLB (LoadBalancer): $metallbStatus"
        if ($metallbMessage) { Write-Host "   Status: $metallbMessage" }
    }

    # Show Ingress status if installed
    if (Test-Ingress) {
        $ingressStatus = "NotReady"
        $ingressMessage = ""

        try {
            $deployment = kubectl get deployment ingress-nginx-controller -n ingress-nginx --no-headers 2>$null
            if ($LASTEXITCODE -eq 0 -and $deployment) {
                $parts = $deployment -split "\s+"
                if ($parts.Count -ge 2) {
                    $ready = $parts[1]
                    $readyParts = $ready -split "/"
                    if ($readyParts.Count -eq 2 -and $readyParts[0] -eq $readyParts[1] -and [int]$readyParts[0] -gt 0) {
                        $ingressStatus = "Ready"
                        $ingressMessage = "HTTP/HTTPS ingress available at localhost:8080/8443"
                    } else {
                        $ingressStatus = "Pending"
                        $ingressMessage = "Controller deployment $ready ready"
                    }
                }
            } else {
                $ingressMessage = "Controller deployment not found"
            }
        } catch {
            $ingressMessage = "Controller deployment not found"
        }

        Write-Host "🌐 NGINX Ingress: $ingressStatus"
        if ($ingressMessage) { Write-Host "   Status: $ingressMessage" }
    }

    # Show Registry status if installed (hybrid Docker/K8s)
    if (Test-Registry) {
        $registryStatus = "NotReady"
        $registryMessage = ""

        # Check Docker registry first (preferred)
        if (Test-RegistryDocker) {
            # Check if Kubernetes registry UI is also running
            $cmd = "kubectl get deployment registry-ui -n hostk8s --no-headers 2>`$null"
            $registryUi = Invoke-Expression $cmd
            if ($LASTEXITCODE -eq 0 -and $registryUi) {
                $parts = $registryUi -split "\s+"
                if ($parts.Count -ge 2) {
                    $ready = $parts[1]
                    $readyParts = $ready -split "/"
                    if ($readyParts.Count -eq 2 -and $readyParts[0] -eq $readyParts[1] -and [int]$readyParts[0] -gt 0) {
                        $registryStatus = "Ready"
                        $registryMessage = "Docker registry with Web UI at http://localhost:8080/registry"
                    } else {
                        $registryStatus = "Ready"
                        $registryMessage = "Docker registry API at http://localhost:5002 (UI not deployed)"
                    }
                } else {
                    $registryStatus = "Ready"
                    $registryMessage = "Docker registry API at http://localhost:5002 (UI not deployed)"
                }
            } else {
                $registryStatus = "Ready"
                $registryMessage = "Docker registry API at http://localhost:5002 (UI not deployed)"
            }
        } elseif (Test-RegistryK8s) {
            # Fallback to Kubernetes registry
            $cmd = "kubectl get deployment registry-core -n hostk8s --no-headers 2>`$null"
            $registryCore = Invoke-Expression $cmd
            if ($LASTEXITCODE -eq 0 -and $registryCore) {
                $parts = $registryCore -split "\s+"
                if ($parts.Count -ge 2) {
                    $ready = $parts[1]
                    $readyParts = $ready -split "/"
                    if ($readyParts.Count -eq 2 -and $readyParts[0] -eq $readyParts[1] -and [int]$readyParts[0] -gt 0) {
                        $registryStatus = "Ready"
                        $registryMessage = "Kubernetes registry at http://localhost:5001"

                        # Check if registry UI is also running
                        $cmd = "kubectl get deployment registry-ui -n hostk8s --no-headers 2>`$null"
                        $registryUi = Invoke-Expression $cmd
                        if ($LASTEXITCODE -eq 0 -and $registryUi) {
                            $uiParts = $registryUi -split "\s+"
                            if ($uiParts.Count -ge 2) {
                                $uiReady = $uiParts[1]
                                $uiReadyParts = $uiReady -split "/"
                                if ($uiReadyParts.Count -eq 2 -and $uiReadyParts[0] -eq $uiReadyParts[1] -and [int]$uiReadyParts[0] -gt 0) {
                                    $registryMessage = "$registryMessage, Web UI: Available at http://localhost:8080/registry/"
                                }
                            }
                        }
                    } else {
                        $registryStatus = "Pending"
                        $registryMessage = "Registry deployment $ready ready"
                    }
                }
            } else {
                $registryStatus = "NotReady"
                $registryMessage = "Registry deployment not found"
            }
        } else {
            $registryStatus = "NotReady"
            $registryMessage = "No registry found (Docker or Kubernetes)"
        }

        Write-Host "📦 Registry: $registryStatus"
        if ($registryMessage) { Write-Host "   Status: $registryMessage" }
    }

    Write-Host ""
}

function Show-ClusterNodes {
    # Get all nodes info
    try {
        $cmd = "kubectl get nodes --no-headers 2>`$null"
        $allNodes = Invoke-Expression $cmd
        if ($LASTEXITCODE -ne 0 -or -not $allNodes) {
            Write-Host "🕹️ Cluster Nodes: NotFound"
            Write-Host "   Status: No nodes found"
            return
        }

        # Count total nodes and check if multi-node
        $nodeLines = $allNodes -split "`n" | Where-Object { $_.Trim() }
        $nodeCount = $nodeLines.Count
        $isMultinode = $nodeCount -gt 1

        # Process each node
        foreach ($line in $nodeLines) {
            $parts = $line -split "\s+"
            if ($parts.Count -ge 5) {
                $name = $parts[0]
                $status = $parts[1]
                $roles = $parts[2]
                $age = $parts[3]
                $k8sVersion = $parts[4]

                $nodeType = "Node"
                $nodeIcon = "🖥️ "

                # Determine node type and icon based on roles
                if ($roles -match "control-plane") {
                    $nodeType = "Control Plane"
                    $nodeIcon = "🕹️ "
                } elseif ($roles -match "worker") {
                    $nodeType = "Worker"
                    $nodeIcon = "🚜 "
                } elseif ($roles -match "agent") {
                    $nodeType = "Agent"
                    $nodeIcon = "🤖 "
                } elseif ($roles -eq "<none>") {
                    $nodeType = "Worker"
                    $nodeIcon = "🚜 "
                }

                # Show node status
                Write-Host "${nodeIcon}${nodeType}: $status"
                if ($status -eq "Ready") {
                    Write-Host "   Status: Kubernetes $k8sVersion (up $age)"
                } else {
                    Write-Host "   Status: Node status: $status"
                }

                # Add node name for multi-node clusters
                if ($isMultinode) {
                    Write-Host "   Node: $name"
                }
            }
        }
    } catch {
        Write-Host "🕹️ Cluster Nodes: Error retrieving node information"
    }
}

function Get-FluxVersion {
    try {
        $version = flux version --client 2>$null
        if ($LASTEXITCODE -eq 0 -and $version -match 'v([0-9.]+)') {
            return $matches[1]
        }
        return "unknown"
    } catch {
        return "unknown"
    }
}

function Test-MetalLB {
    try {
        $null = kubectl get namespace metallb-system 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Test-Ingress {
    try {
        $null = kubectl get namespace ingress-nginx 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Show-GitOpsApplications {
    try {
        $gitopsDeployments = kubectl get deployments -l hostk8s.application --all-namespaces --no-headers 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $gitopsDeployments) {
            return
        }

        Log-Info "GitOps Applications"
        Show-IngressControllerStatus

        $lines = $gitopsDeployments -split "`n" | Where-Object { $_.Trim() }
        foreach ($line in $lines) {
            $parts = $line -split "\s+"
            if ($parts.Count -ge 6) {
                $ns = $parts[0]
                $deploymentName = $parts[1]
                $ready = $parts[2]

                # Use deployment name as primary identifier with namespace qualification
                $displayName = if ($ns -eq "default") { $deploymentName } else { "$ns.$deploymentName" }

                # Get the hostk8s.application label for services/ingress lookup
                $appLabel = kubectl get deployment $deploymentName -n $ns -o jsonpath="{.metadata.labels.hostk8s\.application}" 2>$null

                Write-Host "📱 $displayName"
                Write-Host "   Deployment: $deploymentName ($ready ready)"

                # Show services and ingress for this app
                if ($appLabel) {
                    Show-AppServices $appLabel "application" $ns
                    Show-AppIngress $appLabel "application" $ns
                }
                Write-Host ""
            }
        }
    } catch { }
}

function Show-ManualDeployedApps {
    try {
        $deployedDeployments = kubectl get deployments -l hostk8s.app --all-namespaces --no-headers 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $deployedDeployments) {
            return
        }

        Log-Info "Manual Deployed Apps"

        # Get unique app identifiers using two-tier grouping strategy
        $uniqueApps = @()
        $lines = $deployedDeployments -split "`n" | Where-Object { $_.Trim() }
        foreach ($line in $lines) {
            $parts = $line -split "\s+"
            if ($parts.Count -ge 6) {
                $ns = $parts[0]
                $deploymentName = $parts[1]

                # Check if this is a Helm-managed app
                $managedBy = kubectl get deployment $deploymentName -n $ns -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>$null

                if ($managedBy -eq "Helm") {
                    # For Helm apps: use app.kubernetes.io/instance + namespace
                    $instance = kubectl get deployment $deploymentName -n $ns -o jsonpath='{.metadata.labels.app\.kubernetes\.io/instance}' 2>$null
                    if ($instance) {
                        $appId = if ($ns -eq "default") { "helm:$instance" } else { "helm:$ns.$instance" }
                        if ($uniqueApps -notcontains $appId) { $uniqueApps += $appId }
                    }
                } else {
                    # For non-Helm apps: use hostk8s.app + namespace
                    $appLabel = kubectl get deployment $deploymentName -n $ns -o jsonpath='{.metadata.labels.hostk8s\.app}' 2>$null
                    if ($appLabel) {
                        $appId = if ($ns -eq "default") { "app:$appLabel" } else { "app:$ns.$appLabel" }
                        if ($uniqueApps -notcontains $appId) { $uniqueApps += $appId }
                    }
                }
            }
        }

        if (-not $uniqueApps) { return }

        foreach ($appIdentifier in ($uniqueApps | Sort-Object)) {
            $appType, $appKey = $appIdentifier -split ":", 2

            if ($appType -eq "helm") {
                # Handle Helm app
                Write-Host "📱 $appKey"
                Show-HelmChartInfo $appKey
                Show-HelmAppResources $appKey
            } else {
                # Handle non-Helm app
                Write-Host "📱 $appKey"

                # Extract actual app name (remove namespace prefix if present)
                $actualAppName = if ($appKey -match '\.') { $appKey -replace '^[^.]*\.', '' } else { $appKey }

                Show-AppDeployments $actualAppName "app"
                Show-AppServices $actualAppName "app"
                Show-AppIngress $actualAppName "app"
            }
            Write-Host ""
        }
    } catch { }
}

function Test-GitOpsHealth {
    $gitopsIssuesFound = $false

    if (-not (Test-FluxCLI)) {
        return $false
    }

    try {
        # Check Kustomization status for GitOps stacks
        $kustomizationOutput = flux get kustomizations 2>$null
        if ($LASTEXITCODE -eq 0 -and $kustomizationOutput -match "^NAME") {
            $lines = $kustomizationOutput -split "`n" | Where-Object { $_ -notmatch "^NAME" -and $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "`t"
                if ($parts.Count -ge 4) {
                    $name = $parts[0].Trim()
                    $revision = $parts[1].Trim()
                    $suspended = $parts[2].Trim()
                    $ready = $parts[3].Trim()
                    $message = if ($parts.Count -gt 4) { $parts[4].Trim() } else { "" }

                    # Skip if suspended (paused by design)
                    if ($suspended -eq "True") {
                        continue
                    }

                    # Check if not ready
                    if ($ready -eq "False") {
                        Log-Warn "GitOps Kustomization $name not ready: $message"
                        $gitopsIssuesFound = $true
                    }
                }
            }
        }
    } catch {
        $gitopsIssuesFound = $true
    }

    return $gitopsIssuesFound
}

function Test-ManualAppsHealth {
    $manualIssuesFound = $false

    try {
        # Check if any manual apps exist
        $allApps = kubectl get all -l hostk8s.app --all-namespaces 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }

        # Check LoadBalancer services
        $services = kubectl get services -l hostk8s.app --all-namespaces --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $services) {
            $lines = $services -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Count -ge 5) {
                    $ns = $parts[0]
                    $name = $parts[1]
                    $type = $parts[2]
                    $externalIp = $parts[4]

                    if ($type -eq "LoadBalancer" -and $externalIp -eq "<pending>") {
                        Log-Warn "LoadBalancer $name is pending (MetalLB not installed?)"
                        $manualIssuesFound = $true
                    }
                }
            }
        }

        # Check deployments
        $deployments = kubectl get deployments -l hostk8s.app --all-namespaces --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $deployments) {
            $lines = $deployments -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Count -ge 3) {
                    $ns = $parts[0]
                    $name = $parts[1]
                    $ready = $parts[2]

                    $readyParts = $ready -split "/"
                    if ($readyParts.Count -eq 2 -and $readyParts[0] -ne $readyParts[1]) {
                        Log-Warn "Deployment $name not fully ready ($ready)"
                        $manualIssuesFound = $true
                    }
                }
            }
        }

        # Check pods
        $pods = kubectl get pods -l hostk8s.app --all-namespaces --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $pods) {
            $lines = $pods -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Count -ge 4) {
                    $ns = $parts[0]
                    $name = $parts[1]
                    $ready = $parts[2]
                    $status = $parts[3]

                    if ($status -ne "Running" -and $status -ne "Completed") {
                        Log-Warn "Pod $name in $status state"
                        $manualIssuesFound = $true
                    }
                }
            }
        }
    } catch {
        $manualIssuesFound = $true
    }

    return $manualIssuesFound
}

function Test-GitOpsAppsHealth {
    $gitopsAppIssuesFound = $false

    try {
        # Check if any GitOps apps exist
        $allApps = kubectl get all -l hostk8s.application --all-namespaces 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }

        # Check LoadBalancer services
        $services = kubectl get services -l hostk8s.application --all-namespaces --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $services) {
            $lines = $services -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Count -ge 5) {
                    $ns = $parts[0]
                    $name = $parts[1]
                    $type = $parts[2]
                    $externalIp = $parts[4]

                    if ($type -eq "LoadBalancer" -and $externalIp -eq "<pending>") {
                        Log-Warn "LoadBalancer $name is pending (MetalLB not installed?)"
                        $gitopsAppIssuesFound = $true
                    }
                }
            }
        }

        # Check deployments
        $deployments = kubectl get deployments -l hostk8s.application --all-namespaces --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $deployments) {
            $lines = $deployments -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Count -ge 3) {
                    $ns = $parts[0]
                    $name = $parts[1]
                    $ready = $parts[2]

                    $readyParts = $ready -split "/"
                    if ($readyParts.Count -eq 2 -and $readyParts[0] -ne $readyParts[1]) {
                        Log-Warn "Deployment $name not fully ready ($ready)"
                        $gitopsAppIssuesFound = $true
                    }
                }
            }
        }

        # Check pods
        $pods = kubectl get pods -l hostk8s.application --all-namespaces --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $pods) {
            $lines = $pods -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Count -ge 4) {
                    $ns = $parts[0]
                    $name = $parts[1]
                    $ready = $parts[2]
                    $status = $parts[3]

                    if ($status -ne "Running" -and $status -ne "Completed") {
                        Log-Warn "Pod $name in $status state"
                        $gitopsAppIssuesFound = $true
                    }
                }
            }
        }
    } catch {
        $gitopsAppIssuesFound = $true
    }

    return $gitopsAppIssuesFound
}

function Show-HealthCheck {
    try {
        # Check if there are any deployed resources to check
        $hasManualApps = $false
        $hasGitOpsApps = $false
        $hasGitOpsStacks = $false

        # Check for manual apps
        $manualApps = kubectl get all -l hostk8s.app --all-namespaces 2>$null
        if ($LASTEXITCODE -eq 0) {
            $hasManualApps = $true
        }

        # Check for GitOps applications
        $gitopsApps = kubectl get all -l hostk8s.application --all-namespaces 2>$null
        if ($LASTEXITCODE -eq 0) {
            $hasGitOpsApps = $true
        }

        # Check for GitOps stacks (Flux Kustomizations)
        if (Test-FluxCLI) {
            $kustomizationOutput = flux get kustomizations 2>$null
            if ($LASTEXITCODE -eq 0 -and $kustomizationOutput -match "^NAME") {
                $hasGitOpsStacks = $true
            }
        }

        # If nothing is deployed, skip health check
        if (-not $hasManualApps -and -not $hasGitOpsApps -and -not $hasGitOpsStacks) {
            return
        }

        Log-Info "Health Check"
        $totalIssuesFound = $false

        # Check GitOps stack reconciliation status first (most important for stacks)
        if ($hasGitOpsStacks) {
            if (Test-GitOpsHealth) {
                $totalIssuesFound = $true
            }
        }

        # Check GitOps application resources
        if ($hasGitOpsApps) {
            if (Test-GitOpsAppsHealth) {
                $totalIssuesFound = $true
            }
        }

        # Check manual application resources
        if ($hasManualApps) {
            if (Test-ManualAppsHealth) {
                $totalIssuesFound = $true
            }
        }

        if (-not $totalIssuesFound) {
            Log-Success "All deployed apps are healthy"
        }
    } catch { }
}

# Helper functions for app details
function Show-AppDeployments {
    param($appName, $appType)

    try {
        $deployments = kubectl get deployments -l "hostk8s.$appType=$appName" --all-namespaces --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $deployments) {
            $lines = $deployments -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Count -ge 6) {
                    $ns = $parts[0]
                    $name = $parts[1]
                    $ready = $parts[2]
                    Write-Host "   Deployment: $name ($ready ready)"
                }
            }
        }
    } catch { }
}

function Show-AppServices {
    param($appName, $appType, $ns = $null)

    try {
        $labelSelector = "hostk8s.$appType=$appName"
        $namespaceFlag = if ($ns) { "-n $ns" } else { "--all-namespaces" }

        $cmd = "kubectl get services -l `"$labelSelector`" $namespaceFlag --no-headers 2>`$null"
        $services = Invoke-Expression $cmd
        if ($LASTEXITCODE -eq 0 -and $services) {
            $lines = $services -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                # Different field count based on namespace flag
                $minParts = if ($ns) { 5 } else { 6 }
                if ($parts.Count -ge $minParts) {
                    $svcNs = if ($ns) { $ns } else { $parts[0] }
                    $name = if ($ns) { $parts[0] } else { $parts[1] }
                    $type = if ($ns) { $parts[1] } else { $parts[2] }
                    $ports = if ($ns) { $parts[4] } else { $parts[5] }

                    if ($type -eq "NodePort") {
                        # Extract NodePort from ports (format like "80:30081/TCP")
                        if ($ports -match ":(\d+)/") {
                            $nodePort = $matches[1]
                            Write-Host "   Service: $name (NodePort $nodePort)"
                        } else {
                            Write-Host "   Service: $name (NodePort)"
                        }
                    } elseif ($type -eq "LoadBalancer") {
                        Write-Host "   Service: $name ($type)"
                    } else {
                        Write-Host "   Service: $name ($type)"
                    }
                }
            }
        }
    } catch { }
}

function Show-AppIngress {
    param($appName, $appType, $ns = $null)

    try {
        $labelSelector = "hostk8s.$appType=$appName"
        $namespaceFlag = if ($ns) { "-n $ns" } else { "--all-namespaces" }

        $cmd = "kubectl get ingress -l `"$labelSelector`" $namespaceFlag --no-headers 2>`$null"
        $ingresses = Invoke-Expression $cmd
        if ($LASTEXITCODE -eq 0 -and $ingresses) {
            $lines = $ingresses -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Count -ge 4) {
                    $ingressNs = if ($ns) { $ns } else { $parts[0] }
                    $name = if ($ns) { $parts[0] } else { $parts[1] }

                    # Check if ingress controller is ready
                    if (Test-IngressControllerReady) {
                        if ($appType -eq "application") {
                            # Get detailed ingress info to show paths for GitOps applications
                            $path = kubectl get ingress $name -n $ingressNs -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>$null
                            $hasTls = kubectl get ingress $name -n $ingressNs -o jsonpath='{.spec.tls}' 2>$null
                            if ($LASTEXITCODE -eq 0 -and $path) {
                                if ($path -eq "/") {
                                    if ($hasTls -and $hasTls -ne "null" -and $hasTls.Trim() -ne "") {
                                        Write-Host "   Access: http://localhost:8080/, https://localhost:8443/ ($name ingress)"
                                    } else {
                                        Write-Host "   Access: http://localhost:8080/ ($name ingress)"
                                    }
                                } else {
                                    if ($hasTls -and $hasTls -ne "null" -and $hasTls.Trim() -ne "") {
                                        Write-Host "   Access: http://localhost:8080$path, https://localhost:8443$path ($name ingress)"
                                    } else {
                                        Write-Host "   Access: http://localhost:8080$path ($name ingress)"
                                    }
                                }
                            } else {
                                if ($hasTls -and $hasTls -ne "null" -and $hasTls.Trim() -ne "") {
                                    Write-Host "   Access: http://localhost:8080/, https://localhost:8443/ ($name ingress)"
                                } else {
                                    Write-Host "   Access: http://localhost:8080/ ($name ingress)"
                                }
                            }
                        } else {
                            # For non-GitOps applications, use simpler format
                            $path = kubectl get ingress $name -n $ingressNs -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>$null
                            $hasTls = kubectl get ingress $name -n $ingressNs -o jsonpath='{.spec.tls}' 2>$null
                            if ($LASTEXITCODE -eq 0 -and $path -and $path -ne "/") {
                                if ($hasTls -and $hasTls -ne "null" -and $hasTls.Trim() -ne "") {
                                    Write-Host "   Ingress: $name -> http://localhost:8080$path, https://localhost:8443$path"
                                } else {
                                    Write-Host "   Ingress: $name -> http://localhost:8080$path"
                                }
                            } else {
                                if ($hasTls -and $hasTls -ne "null" -and $hasTls.Trim() -ne "") {
                                    Write-Host "   Ingress: $name -> http://localhost:8080/, https://localhost:8443/"
                                } else {
                                    Write-Host "   Ingress: $name -> http://localhost:8080/"
                                }
                            }
                        }
                    } else {
                        Write-Host "   Ingress: $name (configured but controller not ready)"
                        Write-Host "   Enable with: export INGRESS_ENABLED=true && make restart"
                    }
                }
            }
        }
    } catch { }
}

function Show-HelmChartInfo {
    param($appKey)

    # Extract namespace and instance name
    $namespace = "default"
    $instance = $appKey
    if ($appKey -match '\.') {
        $parts = $appKey -split '\.', 2
        $namespace = $parts[0]
        $instance = $parts[1]
    }

    # Get chart info from any deployment with this instance label in the namespace
    try {
        $firstDeployment = kubectl get deployments -l "app.kubernetes.io/instance=$instance" -n $namespace --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $firstDeployment) {
            $deploymentName = ($firstDeployment -split "`n")[0] -split "\s+"
            if ($deploymentName.Count -gt 0) {
                $chartInfo = kubectl get deployment $deploymentName[0] -n $namespace -o jsonpath='{.metadata.labels.helm\.sh/chart}' 2>$null
                if ($LASTEXITCODE -eq 0 -and $chartInfo) {
                    Write-Host "   Chart: $chartInfo"
                }
            }
        }
    } catch { }
}

function Show-HelmAppResources {
    param($appKey)

    # Extract namespace and instance name
    $namespace = "default"
    $instance = $appKey
    if ($appKey -match '\.') {
        $parts = $appKey -split '\.', 2
        $namespace = $parts[0]
        $instance = $parts[1]
    }

    try {
        # Show deployments for this Helm instance
        $deployments = kubectl get deployments -l "app.kubernetes.io/instance=$instance" -n $namespace --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $deployments) {
            $lines = $deployments -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Count -ge 2) {
                    $name = $parts[0]
                    $ready = $parts[1]
                    Write-Host "   Deployment: $name ($ready ready)"
                }
            }
        }

        # Show services for this Helm instance
        $services = kubectl get services -l "app.kubernetes.io/instance=$instance" -n $namespace --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $services) {
            $lines = $services -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Count -ge 5) {
                    $name = $parts[0]
                    $type = $parts[1]
                    $ports = $parts[4]

                    if ($type -eq "NodePort") {
                        # Extract NodePort from ports (format like "80:30081/TCP")
                        if ($ports -match ":(\d+)/") {
                            $nodePort = $matches[1]
                            Write-Host "   Service: $name (NodePort $nodePort)"
                        } else {
                            Write-Host "   Service: $name (NodePort)"
                        }
                    } elseif ($type -eq "LoadBalancer") {
                        Write-Host "   Service: $name ($type)"
                    } else {
                        Write-Host "   Service: $name ($type)"
                    }
                }
            }
        }

        # Show ingress for this Helm instance
        $ingresses = kubectl get ingress -l "app.kubernetes.io/instance=$instance" -n $namespace --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $ingresses) {
            $lines = $ingresses -split "`n" | Where-Object { $_.Trim() }
            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Count -ge 2) {
                    $name = $parts[0]
                    $hosts = if ($parts.Count -ge 3) { $parts[2] } else { "*" }

                    if ($hosts -eq "localhost" -or $hosts -eq "*") {
                        if (Test-IngressControllerReady) {
                            $path = kubectl get ingress $name -n $namespace -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>$null
                            if ($LASTEXITCODE -eq 0 -and $path -and $path -ne "/") {
                                Write-Host "   Ingress: $name -> http://localhost:8080$path"
                            } else {
                                Write-Host "   Ingress: $name -> http://localhost:8080/"
                            }
                        } else {
                            Write-Host "   Ingress: $name (configured but controller not ready)"
                            Write-Host "   Enable with: export INGRESS_ENABLED=true && make restart"
                        }
                    } else {
                        # Handle namespace-based hostnames (e.g., test.localhost)
                        if (Test-IngressControllerReady) {
                            if ($hosts -match "\.localhost$") {
                                $path = kubectl get ingress $name -n $namespace -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>$null
                                if ($LASTEXITCODE -eq 0 -and $path -and $path -ne "/") {
                                    Write-Host "   Ingress: $name -> http://${hosts}:8080$path"
                                } else {
                                    Write-Host "   Ingress: $name -> http://${hosts}:8080/"
                                }
                            } else {
                                Write-Host "   Ingress: $name (hosts: $hosts)"
                            }
                        } else {
                            Write-Host "   Ingress: $name (configured but controller not ready)"
                        }
                    }
                }
            }
        }
    } catch { }
}

# Main function
function Main {
    # Set kubeconfig path
    $kubeconfigPath = "$PWD/data/kubeconfig/config"

    # Check if cluster exists (but allow status to show when not running)
    if (-not (Test-Path $kubeconfigPath)) {
        Log-Warn "No cluster found. Run 'make start' to start a cluster."
        return
    }

    # Check if cluster is running
    try {
        $cmd = "kubectl cluster-info 2>`$null"
        Invoke-Expression $cmd >$null
        if ($LASTEXITCODE -ne 0) {
            Log-Warn "Cluster not running. Run 'make start' to start the cluster."
            return
        }
    } catch {
        Log-Warn "Cluster not running. Run 'make start' to start the cluster."
        return
    }

    Show-KubeconfigInfo
    Show-DockerServices
    Show-AddonStatus
    Show-GitOpsResources
    Show-GitOpsApplications
    Show-ManualDeployedApps
    Show-HealthCheck
}

# Run main function
Main
