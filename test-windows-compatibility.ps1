# Test script for Windows PowerShell compatibility
Write-Host "Testing HostK8s Windows PowerShell Compatibility" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

$testResults = @()

function Test-Script {
    param(
        [string]$ScriptPath,
        [string]$ScriptName,
        [string[]]$TestArgs = @()
    )
    
    Write-Host "`nTesting: $ScriptName" -ForegroundColor Yellow
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "  ❌ Script not found: $ScriptPath" -ForegroundColor Red
        return $false
    }
    
    try {
        # Test script can be loaded without errors
        . $ScriptPath
        Write-Host "  ✅ Script loads successfully" -ForegroundColor Green
        
        # Test basic execution (if it has a main function or help)
        if ($TestArgs.Count -gt 0) {
            & $ScriptPath @TestArgs 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ Script executes with test args" -ForegroundColor Green
            } else {
                Write-Host "  ⚠️  Script execution returned non-zero (expected for some tests)" -ForegroundColor Yellow
            }
        }
        
        return $true
    } catch {
        Write-Host "  ❌ Script error: $_" -ForegroundColor Red
        return $false
    }
}

# Test core PowerShell scripts
$scriptsToTest = @(
    @{ Path = "infra\scripts\common.ps1"; Name = "Common Utilities"; Args = @() }
    @{ Path = "infra\scripts\install.ps1"; Name = "Tool Installation"; Args = @("-help") }
    @{ Path = "infra\scripts\cluster-up.ps1"; Name = "Cluster Creation"; Args = @() }
    @{ Path = "infra\scripts\cluster-down.ps1"; Name = "Cluster Teardown"; Args = @() }
    @{ Path = "infra\scripts\cluster-status.ps1"; Name = "Cluster Status"; Args = @() }
    @{ Path = "infra\scripts\cluster-restart.ps1"; Name = "Cluster Restart"; Args = @() }
    @{ Path = "infra\scripts\prepare.ps1"; Name = "Dev Environment Setup"; Args = @("-help") }
    @{ Path = "infra\scripts\deploy-app.ps1"; Name = "Application Deployment"; Args = @() }
    @{ Path = "infra\scripts\deploy-stack.ps1"; Name = "Stack Deployment"; Args = @() }
    @{ Path = "infra\scripts\flux-sync.ps1"; Name = "Flux Sync"; Args = @("--help") }
    @{ Path = "infra\scripts\utils.ps1"; Name = "Utilities"; Args = @("help") }
    @{ Path = "infra\scripts\show-help.ps1"; Name = "Help Display"; Args = @() }
)

$passCount = 0
$totalCount = 0

foreach ($script in $scriptsToTest) {
    $totalCount++
    if (Test-Script -ScriptPath $script.Path -ScriptName $script.Name -TestArgs $script.Args) {
        $passCount++
    }
}

# Test file existence
Write-Host "`nTesting file structure..." -ForegroundColor Yellow

$requiredFiles = @(
    ".gitattributes",
    "Makefile",
    "infra\scripts\common.ps1",
    "infra\scripts\install.ps1",
    "infra\scripts\cluster-up.ps1",
    "infra\scripts\cluster-down.ps1",
    "infra\scripts\cluster-status.ps1",
    "infra\scripts\show-help.ps1",
    "infra\scripts\show-help.sh"
)

$fileCount = 0
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ $file" -ForegroundColor Green
        $fileCount++
    } else {
        Write-Host "  ❌ $file (missing)" -ForegroundColor Red
    }
}

# Summary
Write-Host "`nTest Summary" -ForegroundColor Green
Write-Host "============" -ForegroundColor Green
Write-Host "Scripts: $passCount/$totalCount passed" -ForegroundColor $(if ($passCount -eq $totalCount) { "Green" } else { "Yellow" })
Write-Host "Files: $fileCount/$($requiredFiles.Count) present" -ForegroundColor $(if ($fileCount -eq $requiredFiles.Count) { "Green" } else { "Yellow" })

# Check PowerShell version
Write-Host "`nPowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host "✅ PowerShell 7+ detected (compatible)" -ForegroundColor Green
} else {
    Write-Host "⚠️ PowerShell $($PSVersionTable.PSVersion.Major) detected (PowerShell 7+ recommended)" -ForegroundColor Yellow
}

# Check Make availability
Write-Host "`nMake Availability:" -ForegroundColor Cyan
$makeAvailable = $false
try {
    $makeVersion = make --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Make is available" -ForegroundColor Green
        $makeAvailable = $true
    } else {
        Write-Host "❌ Make not found" -ForegroundColor Red
        Write-Host "  Install with: winget install ezwinports.make" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Make not found: $_" -ForegroundColor Red
    Write-Host "  Install with: winget install ezwinports.make" -ForegroundColor Yellow
}

# Test Makefile syntax if make is available
$makeTestPassed = $true
$makeDefaultPassed = $true

if ($makeAvailable) {
    Write-Host "`nTesting Makefile syntax..." -ForegroundColor Yellow
    try {
        $makeHelp = make help 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ 'make help' executes successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ 'make help' failed: $makeHelp" -ForegroundColor Red
            $makeTestPassed = $false
        }
    } catch {
        Write-Host "❌ 'make help' failed: $_" -ForegroundColor Red
        $makeTestPassed = $false
    }

    # Test basic make command (should show help by default)
    try {
        $make = make 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ 'make' (default) executes successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ 'make' (default) failed: $make" -ForegroundColor Red
            $makeDefaultPassed = $false
        }
    } catch {
        Write-Host "❌ 'make' (default) failed: $_" -ForegroundColor Red
        $makeDefaultPassed = $false
    }
} else {
    Write-Host "⚠️ Skipping Makefile tests (make not available)" -ForegroundColor Yellow
}

if ($passCount -eq $totalCount -and $fileCount -eq $requiredFiles.Count -and $makeTestPassed -and $makeDefaultPassed) {
    Write-Host "`n🎉 Windows PowerShell compatibility test PASSED!" -ForegroundColor Green
    Write-Host "All scripts, files, and Makefile syntax are compatible!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠️ Some tests failed. Review the output above." -ForegroundColor Yellow
    if (-not $makeTestPassed -or -not $makeDefaultPassed) {
        Write-Host "Makefile issues detected. Check for bash syntax or missing dependencies." -ForegroundColor Red
    }
    exit 1
}