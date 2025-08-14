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

function Get-AppDeploymentType {
    param([string]$AppName)

    $appPath = Join-Path "software" "apps" $AppName

    if (Test-Path (Join-Path $appPath "Chart.yaml")) {
        return "helm"
    } elseif (Test-Path (Join-Path $appPath "kustomization.yaml")) {
        return "kustomization"
    } elseif (Test-Path (Join-Path $appPath "app.yaml")) {
        return "legacy"
    } else {
        return "none"
    }
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

    # Determine deployment type
    $deploymentType = Get-AppDeploymentType $AppName

    if ($Remove) {
        switch ($deploymentType) {
            "helm" {
                Log-Info "Removing $AppName via Helm from namespace: $Namespace"
                try {
                    helm uninstall $AppName -n $Namespace
                    if ($LASTEXITCODE -eq 0) {
                        Log-Success "$AppName removed successfully via Helm from $Namespace"
                        return $true
                    } else {
                        Log-Error "Failed to remove $AppName via Helm from $Namespace"
                        return $false
                    }
                } catch {
                    Log-Error "Failed to remove Helm application '$AppName': $_"
                    return $false
                }
            }
            "kustomization" {
                Log-Info "Removing $AppName via Kustomization from namespace: $Namespace"
                try {
                    $output = kubectl delete -k $appPath --namespace=$Namespace
                    $output | ForEach-Object { Write-Host $_ }

                    if ($LASTEXITCODE -eq 0) {
                        Log-Success "$AppName removed successfully via Kustomization from $Namespace"
                        return $true
                    } else {
                        Log-Error "Failed to remove $AppName via Kustomization from $Namespace"
                        return $false
                    }
                } catch {
                    Log-Error "Failed to remove application '$AppName': $_"
                    return $false
                }
            }
            default {
                Log-Error "Unknown deployment type '$deploymentType' for $AppName"
                return $false
            }
        }
    } else {
        switch ($deploymentType) {
            "helm" {
                Log-Info "Deploying $AppName via Helm to namespace: $Namespace"
                try {
                    # Ensure namespace exists
                    kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - 2>$null

                    # Deploy with Helm
                    helm upgrade --install $AppName $appPath --namespace $Namespace --create-namespace

                    if ($LASTEXITCODE -eq 0) {
                        Log-Success "$AppName deployed successfully via Helm to $Namespace"
                        Log-Info "See software/apps/$AppName/README.md for access details"
                        return $true
                    } else {
                        Log-Error "Failed to deploy $AppName via Helm to $Namespace"
                        return $false
                    }
                } catch {
                    Log-Error "Failed to deploy Helm application '$AppName': $_"
                    return $false
                }
            }
            "kustomization" {
                Log-Info "Deploying $AppName via Kustomization to namespace: $Namespace"
                try {
                    # Ensure namespace exists
                    kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - 2>$null

                    # Deploy application - let kubectl output show the created resources
                    $output = kubectl apply -k $appPath --namespace=$Namespace
                    $output | ForEach-Object { Write-Host $_ }

                    if ($LASTEXITCODE -eq 0) {
                        Log-Success "$AppName deployed successfully via Kustomization to $Namespace"
                        Log-Info "See software/apps/$AppName/README.md for access details"
                        return $true
                    } else {
                        Log-Error "Failed to deploy $AppName via Kustomization to $Namespace"
                        return $false
                    }
                } catch {
                    Log-Error "Failed to deploy application '$AppName': $_"
                    return $false
                }
            }
            default {
                Log-Error "Unknown deployment type '$deploymentType' for $AppName"
                return $false
            }
        }
    }
}

function Main {
    param([string[]]$Arguments)

    # Show help if no arguments or help requested
    if ($Arguments.Count -eq 0 -or $Arguments[0] -in @("-h", "--help", "help")) {
        Show-Usage
        return 1
    }

    $operation = $Arguments[0]
    $appName = ""
    $namespace = "default"
    $remove = $false

    # Handle different argument patterns like Linux script
    if ($operation -eq "remove") {
        # Remove mode: remove [app_name] [namespace]
        $remove = $true
        $appName = if ($Arguments.Count -gt 1 -and $Arguments[1] -ne "") { $Arguments[1] } else { "simple" }
        $namespace = if ($Arguments.Count -gt 2 -and $Arguments[2] -ne "") { $Arguments[2] } else { "default" }
    } else {
        # Deploy mode: [app_name] [namespace]
        $appName = if ($operation -and $operation -ne "") { $operation } else { "simple" }
        $namespace = if ($Arguments.Count -gt 1 -and $Arguments[1] -ne "") { $Arguments[1] } else { "default" }
    }

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
