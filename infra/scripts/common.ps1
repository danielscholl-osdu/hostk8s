# HostK8s Common PowerShell Script for Windows
# Handles all Windows-specific Make target operations

param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(Position=1)]
    [string]$Arg1,

    [Parameter(Position=2)]
    [string]$Arg2
)

function Show-Help {
    Write-Host 'HostK8s - Host-Mode Kubernetes Development Platform' -ForegroundColor White
    Write-Host ''
    Write-Host 'Usage:'
    Write-Host '  make <target>'
    Write-Host ''
    Write-Host 'Available targets:' -ForegroundColor White

    Get-Content Makefile | ForEach-Object {
        if ($_ -match '^##@\s*(.*)') {
            $section = $Matches[1]
            Write-Host "`n$section" -ForegroundColor White
        }
        elseif ($_ -match '^([a-zA-Z_-]+):.*?##\s*(.*)') {
            $target = $Matches[1]
            $desc = $Matches[2]
            Write-Host ("  {0,-15} {1}" -f $target, $desc) -ForegroundColor Cyan
        }
    }
}

function Clean-Data {
    if (Test-Path 'data') {
        $time = Get-Date -Format 'HH:mm:ss'
        Write-Host "[$time] [Clean] Removing data directory and persistent volumes..."
        Remove-Item -Recurse -Force data -ErrorAction SilentlyContinue
        $time2 = Get-Date -Format 'HH:mm:ss'
        Write-Host "[$time2] [Clean] Data cleanup completed"
    } else {
        $time = Get-Date -Format 'HH:mm:ss'
        Write-Host "[$time] [Clean] No data directory found - already clean"
    }
}

function Auto-Deploy {
    param(
        [string]$StackName,
        [string]$BuildTarget
    )

    $stackName = $StackName.Trim()
    Write-Host "[Cluster] SOFTWARE_STACK detected: $stackName"

    $buildTarget = if ($BuildTarget) { $BuildTarget.Trim() } else { $stackName }

    if ($buildTarget -and (Test-Path "src\$buildTarget")) {
        Write-Host "[Cluster] Auto-building: src\$buildTarget"
        & make build "src\$buildTarget"
    }

    Write-Host "[Cluster] Auto-deploying stack..."
    & make up $stackName
}

# Main dispatch logic
switch ($Command) {
    'help' {
        Show-Help
    }
    'clean-data' {
        Clean-Data
    }
    'auto-deploy' {
        Auto-Deploy -StackName $Arg1 -BuildTarget $Arg2
    }
    default {
        Write-Error "Unknown command: $Command"
        exit 1
    }
}
