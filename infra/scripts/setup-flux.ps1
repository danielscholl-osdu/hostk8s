# infra/scripts/setup-flux.ps1 - Setup Flux GitOps for Windows
. "$PSScriptRoot\common.ps1"

Log-Info "Setting up Flux GitOps..."
Log-Warn "Flux setup for Windows PowerShell is not yet fully implemented"
Log-Info "Please refer to the bash version for complete functionality"
Log-Info "You can run the bash version in WSL if needed"

# Basic Flux installation check
if (-not (Test-Command "flux")) {
    Log-Error "Flux CLI not available. Install with: winget install fluxcd.flux2"
    exit 1
}

# TODO: Implement full Flux bootstrap functionality
Log-Info "Use 'flux bootstrap' manually or run the bash version in WSL"
exit 0