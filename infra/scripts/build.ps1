# infra/scripts/build.ps1 - Build applications for Windows
. "$PSScriptRoot\common.ps1"

function Show-Usage {
    Write-Host "Usage: build.ps1 <app-path>"
    Write-Host ""
    Write-Host "Build and containerize applications from source code."
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  app-path    Path to application source (e.g., src/my-app)"
}

function Show-AvailableApps {
    Log-Info "Available applications:"
    $foundApps = $false
    $shownDirs = @()

    # Look for bake files first (preferred)
    Get-ChildItem "src" -Recurse -Filter "docker-bake.hcl" -ErrorAction SilentlyContinue | ForEach-Object {
        $appDir = $_.Directory.FullName.Replace($PWD.Path + [System.IO.Path]::DirectorySeparatorChar, "")
        Log-Info "  $appDir (docker-bake.hcl)"
        $shownDirs += $appDir
        $foundApps = $true
    }

    # Then look for docker-compose files, but skip if bake file already exists
    Get-ChildItem "src" -Recurse -Filter "docker-compose.yml" -ErrorAction SilentlyContinue | ForEach-Object {
        $appDir = $_.Directory.FullName.Replace($PWD.Path + [System.IO.Path]::DirectorySeparatorChar, "")
        if ($appDir -notin $shownDirs) {
            Log-Info "  $appDir (docker-compose.yml)"
            $foundApps = $true
        }
    }

    if (-not $foundApps) {
        Log-Info "  No applications found in src/"
    }
}

function Build-Application {
    param([string]$AppPath)

    if (-not (Test-Path $AppPath)) {
        Log-Error "Application path not found: $AppPath"
        Show-AvailableApps
        return $false
    }

    # Check for bake file first (preferred), then docker-compose.yml
    $dockerBakePath = Join-Path $AppPath "docker-bake.hcl"
    $dockerComposePath = Join-Path $AppPath "docker-compose.yml"

    if (-not (Test-Path $dockerBakePath) -and -not (Test-Path $dockerComposePath)) {
        Log-Error "No docker-bake.hcl or docker-compose.yml found in $AppPath"
        Log-Info "Expected: $AppPath/docker-bake.hcl or $AppPath/docker-compose.yml"
        return $false
    }

    Log-Start "Building application: $AppPath"

    # Set build metadata
    $buildDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $buildVersion = "1.0.0"

    Log-Info "Build date: $buildDate"
    Log-Info "Version: $buildVersion"

    try {
        Push-Location $AppPath

        # Determine build method and build the application
        if (Test-Path "docker-bake.hcl") {
            Log-Info "Using docker-bake.hcl for build and push..."
            Log-Info "Building and pushing Docker images..."

            # Use docker buildx bake with push for detailed output
            docker buildx bake --push

            if ($LASTEXITCODE -eq 0) {
                Log-Success "Build and push complete"
                return $true
            } else {
                Log-Error "Docker bake build and push failed"
                return $false
            }
        } elseif (Test-Path "docker-compose.yml") {
            Log-Info "Using docker-compose.yml for build and push..."

            # Build the application
            Log-Info "Building Docker images..."
            docker compose build

            if ($LASTEXITCODE -ne 0) {
                Log-Error "Docker build failed"
                return $false
            }

            # Push to registry
            Log-Info "Pushing to registry..."
            docker compose push

            if ($LASTEXITCODE -eq 0) {
                Log-Success "Build and push complete"
                return $true
            } else {
                Log-Error "Docker push failed"
                return $false
            }
        } else {
            Log-Error "No build configuration found"
            return $false
        }
    } catch {
        Log-Error "Build failed: $_"
        return $false
    } finally {
        Pop-Location
    }
}

function Main {
    param([string[]]$Arguments)

    if ($Arguments.Count -eq 0) {
        Show-Usage
        return 1
    }

    $appPath = $Arguments[0]

    if (Build-Application -AppPath $appPath) {
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
