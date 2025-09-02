#######################################
# HostK8s Secret Management Script
# Handles ephemeral secret generation from contracts
#######################################

param(
    [Parameter(Position = 0)]
    [string]$Action = "help",

    [Parameter(Position = 1)]
    [string]$Stack = ""
)

# Source common utilities
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptDir\common.ps1"

# Variables
$ContractFile = ""
$SecretsDir = ""
$Namespace = ""

#######################################
# Show help message
#######################################
function Show-Help {
    Write-Host @"
HostK8s Secret Management

Usage: make secrets-<action> <stack-name>

Actions:
  generate    Generate secrets from contract for a stack
  show        Display current secrets for a stack
  clean       Remove secrets for a stack from cluster
  help        Show this help message

Examples:
  make secrets-generate sample-app
  make secrets-show sample-app
  make secrets-clean sample-app

"@
}

#######################################
# Generate random password
#######################################
function Generate-Password {
    param(
        [int]$Length = 32
    )

    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*'
    -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

#######################################
# Generate alphanumeric token
#######################################
function Generate-Token {
    param(
        [int]$Length = 32
    )

    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

#######################################
# Generate hex string
#######################################
function Generate-Hex {
    param(
        [int]$Length = 32
    )

    $chars = 'abcdef0123456789'
    -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

#######################################
# Check if secret exists in cluster
#######################################
function Test-SecretExists {
    param(
        [string]$Name,
        [string]$Namespace
    )

    $result = kubectl get secret $Name -n $Namespace 2>&1
    return $LASTEXITCODE -eq 0
}

#######################################
# Generate secret from generic data format
#######################################
function Generate-SecretFromData {
    param(
        [string]$SecretName,
        [string]$Namespace,
        [array]$Data
    )

    $stringData = ""

    foreach ($item in $Data) {
        $key = $item.key

        if ($item.value) {
            # Static value
            $stringData += "  $key: `"$($item.value)`"`n"
        }
        elseif ($item.generate) {
            # Generated value
            $length = if ($item.length) { $item.length } else { 32 }

            switch ($item.generate) {
                "password" {
                    $value = Generate-Password -Length $length
                    $stringData += "  $key: `"$value`"`n"
                }
                "token" {
                    $value = Generate-Token -Length $length
                    $stringData += "  $key: `"$value`"`n"
                }
                "hex" {
                    $value = Generate-Hex -Length $length
                    $stringData += "  $key: `"$value`"`n"
                }
                "uuid" {
                    $value = [guid]::NewGuid().ToString()
                    $stringData += "  $key: `"$value`"`n"
                }
                default {
                    $value = Generate-Token -Length $length
                    $stringData += "  $key: `"$value`"`n"
                }
            }
        }
    }

    @"
---
apiVersion: v1
kind: Secret
metadata:
  name: $SecretName
  namespace: $Namespace
  labels:
    hostk8s.io/managed: "true"
    hostk8s.io/contract: "$Stack"
type: Opaque
stringData:
$stringData"@
}

# Legacy type-specific generators removed - using generic data format

#######################################
# Parse and generate secrets from contract
#######################################
function Invoke-GenerateSecrets {
    if ([string]::IsNullOrEmpty($Stack)) {
        Write-Error "Stack name required. Use: make secrets-generate <name>"
        exit 1
    }

    $ContractFile = "software/stacks/$Stack/hostk8s.secrets.yaml"
    $SecretsDir = "data/secrets/$Stack"

    if (-not (Test-Path $ContractFile)) {
        Write-Info "No secret contract found for stack '$Stack'"
        return
    }

    Write-Info "Generating secrets for stack '$Stack'"

    # Create secrets directory
    New-Item -ItemType Directory -Force -Path $SecretsDir | Out-Null

    # Temporary file for generated secrets
    $tempFile = "$SecretsDir/generated.tmp.yaml"
    "" | Out-File -FilePath $tempFile -Encoding UTF8

    # Check for yq
    if (-not (Get-Command yq -ErrorAction SilentlyContinue)) {
        Write-Error "yq is required for parsing YAML contracts"
        Write-Error "Install from: https://github.com/mikefarah/yq"
        exit 1
    }

    # Parse contract
    $contract = Get-Content $ContractFile -Raw | yq eval -o=json | ConvertFrom-Json

    foreach ($secret in $contract.spec.secrets) {
        $name = $secret.name
        $namespace = $secret.namespace
        $type = $secret.type

        # Skip if secret already exists
        if (Test-SecretExists -Name $name -Namespace $namespace) {
            Write-Info "Secret '$name' already exists in namespace '$namespace', skipping"
            continue
        }

        Write-Info "Generating secret '$name'"

        $secretYaml = ""

        # Check if secret uses new data format
        if ($secret.data) {
            # New generic data format
            $secretYaml = Generate-SecretFromData -SecretName $name -Namespace $namespace -Data $secret.data
        }
        elseif ($type) {
            # Legacy type-based format (for backwards compatibility)
            switch ($type) {
                "postgresql" {
                    $username = if ($secret.spec.username) { $secret.spec.username } else { "postgres" }
                    $database = $secret.spec.database
                    $cluster = $secret.spec.cluster

                    # Convert to new format internally
                    $data = @(
                        @{key = "username"; value = $username},
                        @{key = "password"; generate = "password"; length = 32},
                        @{key = "database"; value = $database},
                        @{key = "host"; value = "$cluster-rw.$namespace.svc.cluster.local"},
                        @{key = "port"; value = "5432"}
                    )
                    $secretYaml = Generate-SecretFromData -SecretName $name -Namespace $namespace -Data $data
                }
                default {
                    Write-Warning "Unknown secret type '$type' for secret '$name', skipping"
                }
            }
        }
        else {
            Write-Warning "Secret '$name' has no data or type definition, skipping"
        }

        if ($secretYaml) {
            Add-Content -Path $tempFile -Value $secretYaml -Encoding UTF8
        }
    }

    # Apply generated secrets to cluster
    if ((Get-Item $tempFile).Length -gt 0) {
        Write-Info "Applying generated secrets to cluster"
        kubectl apply -f $tempFile

        # Save a copy for reference
        Copy-Item $tempFile "$SecretsDir/generated.yaml" -Force
        Remove-Item $tempFile

        Write-Success "Secrets generated and applied successfully"
    } else {
        Write-Info "No new secrets to generate"
    }
}

#######################################
# Show secrets for a stack
#######################################
function Show-Secrets {
    if ([string]::IsNullOrEmpty($Stack)) {
        Write-Error "Stack name required. Use: make secrets-show <name>"
        exit 1
    }

    Write-Info "Showing secrets for stack '$Stack'"

    # Get the namespace from the contract
    $ContractFile = "software/stacks/$Stack/hostk8s.secrets.yaml"
    if (-not (Test-Path $ContractFile)) {
        Write-Error "No secret contract found for stack '$Stack'"
        exit 1
    }

    # Get unique namespaces from contract
    $contract = Get-Content $ContractFile -Raw | yq eval -o=json | ConvertFrom-Json
    $namespaces = $contract.spec.secrets | ForEach-Object { $_.namespace } | Select-Object -Unique

    foreach ($namespace in $namespaces) {
        Write-Host ""
        Write-Info "Secrets in namespace '$namespace':"
        kubectl get secrets -n $namespace -l "hostk8s.io/contract=$Stack" `
            -o custom-columns=NAME:.metadata.name,TYPE:.metadata.labels.'hostk8s\.io/type',AGE:.metadata.creationTimestamp
    }
}

#######################################
# Clean secrets for a stack
#######################################
function Invoke-CleanSecrets {
    if ([string]::IsNullOrEmpty($Stack)) {
        Write-Error "Stack name required. Use: make secrets-clean <name>"
        exit 1
    }

    Write-Warning "Removing secrets for stack '$Stack'"

    # Get the namespace from the contract
    $ContractFile = "software/stacks/$Stack/hostk8s.secrets.yaml"
    if (-not (Test-Path $ContractFile)) {
        Write-Error "No secret contract found for stack '$Stack'"
        exit 1
    }

    # Get unique namespaces from contract
    $contract = Get-Content $ContractFile -Raw | yq eval -o=json | ConvertFrom-Json
    $namespaces = $contract.spec.secrets | ForEach-Object { $_.namespace } | Select-Object -Unique

    foreach ($namespace in $namespaces) {
        Write-Info "Cleaning secrets in namespace '$namespace'"
        kubectl delete secrets -n $namespace -l "hostk8s.io/contract=$Stack" --ignore-not-found=true
    }

    # Clean local cache
    $SecretsDir = "data/secrets/$Stack"
    if (Test-Path $SecretsDir) {
        Remove-Item -Recurse -Force $SecretsDir
        Write-Info "Cleaned local secret cache"
    }

    Write-Success "Secrets cleaned successfully"
}

#######################################
# Main execution
#######################################
switch ($Action) {
    "generate" { Invoke-GenerateSecrets }
    "show" { Show-Secrets }
    "clean" { Invoke-CleanSecrets }
    default { Show-Help }
}
