# infra/scripts/deploy-stack.ps1 - Deploy software stacks for Windows
. "$PSScriptRoot\common.ps1"

function Show-Usage {
    Write-Host "Usage: deploy-stack.ps1 <stack-name> [down]"
    Write-Host ""
    Write-Host "Deploy or remove software stacks using GitOps."
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  stack-name   Name of the stack to deploy (required)"
    Write-Host "  down         Remove the stack instead of deploying"
}

function Deploy-Stack {
    param(
        [string]$StackName,
        [bool]$Remove = $false
    )
    
    $stackPath = Join-Path "software" "stacks" $StackName
    
    if (-not (Test-Path $stackPath)) {
        Log-Error "Stack '$StackName' not found at $stackPath"
        Log-Info "Available stacks:"
        $stacks = Get-ChildItem "software/stacks" -Directory -ErrorAction SilentlyContinue
        if ($stacks) {
            $stacks | ForEach-Object { Log-Info "  $($_.Name)" }
        } else {
            Log-Info "  No stacks found"
        }
        return $false
    }
    
    if ($Remove) {
        Log-Info "Removing stack '$StackName'..."
        try {
            # Remove stack resources
            kubectl delete -k $stackPath 2>$null
            Log-Success "Stack '$StackName' removed successfully"
            return $true
        } catch {
            Log-Error "Failed to remove stack '$StackName': $_"
            return $false
        }
    } else {
        Log-Info "Deploying stack '$StackName'..."
        try {
            # Deploy stack
            kubectl apply -k $stackPath
            
            if ($LASTEXITCODE -eq 0) {
                Log-Success "Stack '$StackName' deployment initiated"
                Log-Info "Use 'make status' to monitor deployment progress"
                return $true
            } else {
                Log-Error "Failed to deploy stack '$StackName'"
                return $false
            }
        } catch {
            Log-Error "Failed to deploy stack '$StackName': $_"
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
    
    $stackName = $Arguments[0]
    $remove = ($Arguments.Count -gt 1 -and $Arguments[1] -eq "down") -or ($Arguments -contains "down")
    
    # Check cluster connectivity
    Test-ClusterRunning
    
    if (Deploy-Stack -StackName $stackName -Remove $remove) {
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