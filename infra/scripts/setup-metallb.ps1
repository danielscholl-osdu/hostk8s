# infra/scripts/setup-metallb.ps1 - Setup MetalLB for Windows
. "$PSScriptRoot\common.ps1"

Log-Info "Setting up MetalLB LoadBalancer..."

# Basic MetalLB installation using kubectl
try {
    # Install MetalLB
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

    if ($LASTEXITCODE -eq 0) {
        Log-Success "MetalLB deployment initiated"
        Log-Info "Waiting for MetalLB to be ready..."
        kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=300s
        Log-Success "MetalLB is ready"

        # Configure IP address pool for Kind cluster
        Log-Info "Configuring MetalLB IP pool..."

        # Get Docker network subnet for MetalLB IP pool
        $dockerSubnet = ""
        try {
            $dockerInfo = docker network inspect kind | ConvertFrom-Json
            $ipamConfig = $dockerInfo[0].IPAM.Config
            foreach ($config in $ipamConfig) {
                if ($config.Subnet -and $config.Subnet -match "\d+\.\d+\.\d+\.\d+/\d+") {
                    $dockerSubnet = $config.Subnet
                    break
                }
            }
        } catch {
            Log-Warn "Could not detect Docker subnet, using default"
        }

        if (-not $dockerSubnet) {
            $dockerSubnet = "172.18.0.0/16"
            Log-Debug "Using default Docker subnet: $dockerSubnet"
        } else {
            Log-Debug "Using Docker subnet: $dockerSubnet"
        }

        # Extract network prefix and create IP pool range
        $networkPrefix = ($dockerSubnet -split '/')[0] -replace '\.\d+$', ''
        $ipPoolStart = "$networkPrefix.255.200"
        $ipPoolEnd = "$networkPrefix.255.250"

        Log-Info "Creating IP pool: $ipPoolStart-$ipPoolEnd"

        # Create MetalLB configuration
        $metallbConfig = @"
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: metallb-system
spec:
  addresses:
  - $ipPoolStart-$ipPoolEnd
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kind-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - kind-pool
"@

        $metallbConfig | kubectl apply -f -
        if ($LASTEXITCODE -eq 0) {
            Log-Success "MetalLB IP pool configured successfully"
        } else {
            Log-Error "Failed to configure MetalLB IP pool"
        }
    } else {
        Log-Error "Failed to deploy MetalLB"
        exit 1
    }
} catch {
    Log-Error "Failed to setup MetalLB: $_"
    exit 1
}
