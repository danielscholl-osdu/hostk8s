# infra/scripts/utils.ps1 - Utility functions for Windows
. "$PSScriptRoot\common.ps1"

function Show-Usage {
    Write-Host "Usage: utils.ps1 <command> [arguments]"
    Write-Host ""
    Write-Host "Available commands:"
    Write-Host "  logs [pod-name]    Show cluster events and pod logs"
    Write-Host "  help               Show this help"
}

function Show-Logs {
    param([string]$PodName = "")

    if ($PodName) {
        Log-Info "Showing logs for pod: $PodName"
        kubectl logs $PodName --tail=100 --follow
    } else {
        Log-Info "Showing recent cluster events..."
        kubectl get events --sort-by=.metadata.creationTimestamp --all-namespaces

        Write-Host ""
        Log-Info "Showing pod status..."
        kubectl get pods --all-namespaces
    }
}

function Main {
    param([string[]]$Arguments)

    if ($Arguments.Count -eq 0) {
        Show-Usage
        return 1
    }

    $command = $Arguments[0]
    $remainingArgs = $Arguments[1..($Arguments.Count-1)]

    switch ($command) {
        "logs" {
            Test-ClusterRunning
            $podName = if ($remainingArgs.Count -gt 0) { $remainingArgs[0] } else { "" }
            Show-Logs -PodName $podName
            return 0
        }
        "help" {
            Show-Usage
            return 0
        }
        default {
            Log-Error "Unknown command: $command"
            Show-Usage
            return 1
        }
    }
}

# Run if called directly
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Main -Arguments $args
    exit $exitCode
}
