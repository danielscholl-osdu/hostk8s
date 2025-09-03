# manage-secrets.ps1 - PowerShell version of Vault-Enhanced Secret Management Script
# Command-based interface for Vault + External Secrets management

$ErrorActionPreference = "Stop"

# Source common utilities
. "$PSScriptRoot\common.ps1"

# Command line parsing
$COMMAND = ""
$STACK = ""

# Parse arguments - support both old and new formats
if ($args.Count -eq 1) {
    # Could be either legacy format or list command
    if ($args[0] -eq "list") {
        $COMMAND = "list"
        $STACK = ""
    } else {
        # Legacy format: manage-secrets.ps1 <stack>
        $COMMAND = "add"
        $STACK = $args[0]
    }
} elseif ($args.Count -eq 2) {
    # New format: manage-secrets.ps1 <command> <stack>
    $COMMAND = $args[0]
    $STACK = $args[1]
} else {
    $COMMAND = ""
    $STACK = ""
}

# Variables
$VAULT_ADDR = if ($env:VAULT_ADDR) { $env:VAULT_ADDR } else { "http://localhost:8080" }
$VAULT_TOKEN = if ($env:VAULT_TOKEN) { $env:VAULT_TOKEN } else { "hostk8s" }

#######################################
# Generate random password
#######################################
function Generate-Password {
    param([int]$Length = 32)

    # Use .NET RNGCryptoServiceProvider for secure random generation
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $bytes = New-Object byte[] $Length
    $rng.GetBytes($bytes)
    $result = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $result += $chars[$bytes[$i] % $chars.Length]
    }
    $rng.Dispose()
    return $result
}

#######################################
# Generate alphanumeric token
#######################################
function Generate-Token {
    param([int]$Length = 32)

    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $bytes = New-Object byte[] $Length
    $rng.GetBytes($bytes)
    $result = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $result += $chars[$bytes[$i] % $chars.Length]
    }
    $rng.Dispose()
    return $result
}

#######################################
# Generate hex string
#######################################
function Generate-Hex {
    param([int]$Length = 32)

    $chars = "abcdef0123456789"
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $bytes = New-Object byte[] $Length
    $rng.GetBytes($bytes)
    $result = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $result += $chars[$bytes[$i] % $chars.Length]
    }
    $rng.Dispose()
    return $result
}

#######################################
# Show usage information
#######################################
function Show-Usage {
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) [COMMAND] <stack-name>"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  add <stack>     Add/update secrets in Vault and generate manifests (default)"
    Write-Host "  remove <stack>  Remove all secrets for stack from Vault"
    Write-Host "  list [stack]    List secrets in Vault (all stacks or specific stack)"
    Write-Host ""
    Write-Host "Legacy format (defaults to 'add'):"
    Write-Host "  $($MyInvocation.MyCommand.Name) <stack>      Same as: $($MyInvocation.MyCommand.Name) add <stack>"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  $($MyInvocation.MyCommand.Name) add sample-app       # Populate Vault + generate manifests"
    Write-Host "  $($MyInvocation.MyCommand.Name) remove sample-app    # Clean up Vault secrets"
    Write-Host "  $($MyInvocation.MyCommand.Name) list                 # List all secrets"
    Write-Host "  $($MyInvocation.MyCommand.Name) list sample-app      # List secrets for specific stack"
    Write-Host "  $($MyInvocation.MyCommand.Name) sample-app           # Legacy format (same as add)"
}

#######################################
# Check Vault connectivity
#######################################
function Test-VaultConnectivity {
    try {
        $headers = @{ "X-Vault-Token" = $VAULT_TOKEN }
        Invoke-RestMethod -Uri "$VAULT_ADDR/v1/sys/health" -Headers $headers -Method Get | Out-Null
        return $true
    } catch {
        Log-Error "Cannot connect to Vault at $VAULT_ADDR"
        Log-Error "Make sure Vault is running and VAULT_ADDR/VAULT_TOKEN are set correctly"
        return $false
    }
}

#######################################
# List secrets in Vault
#######################################
function Invoke-ListSecrets {
    param([string]$FilterStack = "")

    Log-Info "Listing secrets in Vault..."

    if (-not (Test-VaultConnectivity)) {
        exit 1
    }

    if ($FilterStack) {
        Log-Info "Filtering for stack: $FilterStack"
        $vaultPath = "secret/metadata/$FilterStack"
    } else {
        $vaultPath = "secret/metadata"
    }

    Log-Debug "Querying Vault path: $vaultPath"

    try {
        $headers = @{ "X-Vault-Token" = $VAULT_TOKEN }
        $response = Invoke-RestMethod -Uri "$VAULT_ADDR/v1/$vaultPath" -Headers $headers -Method Get -Body @{list = "true"}

        if ($response.data.keys) {
            foreach ($key in $response.data.keys) {
                if ($FilterStack) {
                    Log-Success "  $FilterStack/$key"
                } else {
                    Log-Success "  $key"
                }
            }
        } else {
            if ($FilterStack) {
                Log-Info "No secrets found for stack '$FilterStack'"
            } else {
                Log-Info "No secrets found in Vault"
            }
        }
    } catch {
        if ($FilterStack) {
            Log-Info "No secrets found for stack '$FilterStack'"
        } else {
            Log-Info "No secrets found in Vault"
        }
    }
}

#######################################
# Remove a single secret from Vault
#######################################
function Remove-VaultSecret {
    param([string]$VaultPath)

    Log-Debug "Removing Vault secret: secret/$VaultPath"

    try {
        $headers = @{ "X-Vault-Token" = $VAULT_TOKEN }

        # Delete secret data
        Invoke-RestMethod -Uri "$VAULT_ADDR/v1/secret/data/$VaultPath" -Headers $headers -Method Delete | Out-Null

        # Delete secret metadata
        Invoke-RestMethod -Uri "$VAULT_ADDR/v1/secret/metadata/$VaultPath" -Headers $headers -Method Delete | Out-Null

        return $true
    } catch {
        return $false
    }
}

#######################################
# Remove secrets for a stack from Vault
#######################################
function Invoke-RemoveSecrets {
    if (-not $STACK) {
        Log-Error "Stack name required. Usage: manage-secrets.ps1 remove <stack-name>"
        exit 1
    }

    Log-Info "Removing secrets for stack '$STACK' from Vault..."

    if (-not (Test-VaultConnectivity)) {
        exit 1
    }

    $CONTRACT_FILE = "software/stacks/$STACK/hostk8s.secrets.yaml"
    $EXTERNAL_SECRETS_FILE = "software/stacks/$STACK/manifests/external-secrets.yaml"

    if (-not (Test-Path $CONTRACT_FILE)) {
        Log-Warn "No secret contract found for stack '$STACK'"
        Log-Info "Attempting to remove any existing secrets anyway..."

        # Try to remove by pattern: secret/metadata/STACK/*
        try {
            $headers = @{ "X-Vault-Token" = $VAULT_TOKEN }
            $response = Invoke-RestMethod -Uri "$VAULT_ADDR/v1/secret/metadata/$STACK" -Headers $headers -Method Get -Body @{list = "true"}

            if ($response.data.keys) {
                foreach ($namespace in $response.data.keys) {
                    $namespacePath = "$STACK/$namespace"
                    try {
                        $nsResponse = Invoke-RestMethod -Uri "$VAULT_ADDR/v1/secret/metadata/$namespacePath" -Headers $headers -Method Get -Body @{list = "true"}
                        if ($nsResponse.data.keys) {
                            foreach ($secretName in $nsResponse.data.keys) {
                                Remove-VaultSecret "$namespacePath/$secretName" | Out-Null
                            }
                        }
                    } catch {
                        # Continue with other namespaces
                    }
                }
            }
        } catch {
            Log-Info "No secrets found for stack '$STACK'"
        }

        # Remove external-secrets.yaml if it exists
        if (Test-Path $EXTERNAL_SECRETS_FILE) {
            Log-Info "Removing ExternalSecret manifests: $EXTERNAL_SECRETS_FILE"
            Remove-Item $EXTERNAL_SECRETS_FILE -Force
        }

        Log-Success "Secret removal completed for stack '$STACK'"
        return
    }

    Log-Info "Reading secret contract: $CONTRACT_FILE"

    # Check if yq is available
    try {
        yq --version | Out-Null
    } catch {
        Log-Error "yq is required for parsing YAML contracts"
        Log-Error "Install from: https://github.com/mikefarah/yq"
        exit 1
    }

    # Process each secret in the contract for removal
    try {
        $secretCountOutput = yq eval '.spec.secrets | length' $CONTRACT_FILE
        $secretCount = [int]$secretCountOutput.Trim()

        for ($i = 0; $i -lt $secretCount; $i++) {
            $name = (yq eval ".spec.secrets[$i].name" $CONTRACT_FILE).Trim()
            $namespace = (yq eval ".spec.secrets[$i].namespace" $CONTRACT_FILE).Trim()
            $vaultPath = "$STACK/$namespace/$name"

            Log-Info "Removing secret '$name' from Vault path: secret/$vaultPath"

            if (-not (Remove-VaultSecret $vaultPath)) {
                Log-Warn "Failed to remove secret: $vaultPath"
            }
        }
    } catch {
        Log-Error "Failed to process secrets contract: $($_.Exception.Message)"
        exit 1
    }

    # Remove external-secrets.yaml file
    if (Test-Path $EXTERNAL_SECRETS_FILE) {
        Log-Info "Removing ExternalSecret manifests: $EXTERNAL_SECRETS_FILE"
        Remove-Item $EXTERNAL_SECRETS_FILE -Force
    }

    Log-Success "Secret removal completed for stack '$STACK'"
}

#######################################
# Store/Update secret in Vault
#######################################
function Set-VaultSecret {
    param(
        [string]$Path,
        [hashtable]$Data
    )

    Log-Debug "Storing secret in Vault: secret/$Path"

    try {
        $headers = @{
            "X-Vault-Token" = $VAULT_TOKEN
            "Content-Type" = "application/json"
        }
        $payload = @{ data = $Data } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Uri "$VAULT_ADDR/v1/secret/data/$Path" -Headers $headers -Method Post -Body $payload | Out-Null
        return $true
    } catch {
        Log-Error "Failed to store secret $Path`: $($_.Exception.Message)"
        return $false
    }
}

#######################################
# Check if secret exists in Vault
#######################################
function Test-VaultSecret {
    param([string]$Path)

    try {
        $headers = @{ "X-Vault-Token" = $VAULT_TOKEN }
        Invoke-RestMethod -Uri "$VAULT_ADDR/v1/secret/data/$Path" -Headers $headers -Method Get | Out-Null
        return $true
    } catch {
        return $false
    }
}

#######################################
# Add secrets from contract
#######################################
function Invoke-AddSecrets {
    if (-not $STACK) {
        Log-Error "Stack name required. Usage: manage-secrets.ps1 add <stack-name>"
        exit 1
    }

    if (-not (Test-VaultConnectivity)) {
        exit 1
    }

    $CONTRACT_FILE = "software/stacks/$STACK/hostk8s.secrets.yaml"
    $EXTERNAL_SECRETS_FILE = "software/stacks/$STACK/manifests/external-secrets.yaml"

    if (-not (Test-Path $CONTRACT_FILE)) {
        Log-Info "No secret contract found for stack '$STACK'"
        return
    }

    Log-Info "Processing secrets for stack '$STACK' (Vault + ExternalSecrets)"

    # Check if yq is available
    try {
        yq --version | Out-Null
    } catch {
        Log-Error "yq is required for parsing YAML contracts"
        Log-Error "Install from: https://github.com/mikefarah/yq"
        exit 1
    }

    # Ensure manifests directory exists
    $manifestsDir = "software/stacks/$STACK/manifests"
    if (-not (Test-Path $manifestsDir)) {
        New-Item -ItemType Directory -Path $manifestsDir -Force | Out-Null
    }

    # Create external-secrets.yaml file with header
    $header = @"
# Generated ExternalSecret manifests from hostk8s.secrets.yaml
# This file is auto-generated by manage-secrets.ps1 - safe to commit to Git
# Contains no sensitive data - only Vault path references
# To regenerate: make up $STACK
"@
    $header | Set-Content -Path $EXTERNAL_SECRETS_FILE -Encoding UTF8

    # Process each secret in the contract
    try {
        $secretCountOutput = yq eval '.spec.secrets | length' $CONTRACT_FILE
        $secretCount = [int]$secretCountOutput.Trim()

        for ($i = 0; $i -lt $secretCount; $i++) {
            $name = (yq eval ".spec.secrets[$i].name" $CONTRACT_FILE).Trim()
            $namespace = (yq eval ".spec.secrets[$i].namespace" $CONTRACT_FILE).Trim()

            # Get data as JSON and convert to PowerShell object
            $dataJsonString = yq eval ".spec.secrets[$i].data" $CONTRACT_FILE -o=json
            $dataJson = $dataJsonString | ConvertFrom-Json

            # Create Vault path: stack/namespace/secret-name
            $vaultPath = "$STACK/$namespace/$name"

            # Check if secret already exists in Vault (idempotency)
            if (Test-VaultSecret $vaultPath) {
                Log-Info "Secret '$name' already exists in Vault, skipping Vault population"
            } else {
                Log-Info "Populating Vault with secret '$name' for namespace '$namespace'"

                # Build hashtable for Vault storage
                $vaultData = @{}

                foreach ($item in $dataJson) {
                    $key = $item.key
                    $value = $item.value
                    $generateType = $item.generate
                    $length = if ($item.length) { [int]$item.length } else { 32 }

                    if ($value -and $value -ne "null") {
                        # Static value
                        $vaultData[$key] = $value
                    } elseif ($generateType -and $generateType -ne "null") {
                        # Generated value
                        $generatedValue = switch ($generateType) {
                            "password" { Generate-Password $length }
                            "token" { Generate-Token $length }
                            "hex" { Generate-Hex $length }
                            "uuid" { [System.Guid]::NewGuid().ToString().ToLower() }
                            default { Generate-Token $length }
                        }
                        $vaultData[$key] = $generatedValue
                    }
                }

                # Store in Vault
                if (-not (Set-VaultSecret $vaultPath $vaultData)) {
                    Log-Error "Failed to store secret in Vault"
                    exit 1
                }
            }

            # Always generate ExternalSecret manifest
            Log-Debug "Generating ExternalSecret manifest for '$name'"

            $manifest = @"
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: $name
  namespace: $namespace
  labels:
    hostk8s.io/managed: "true"
    hostk8s.io/contract: "$STACK"
spec:
  refreshInterval: 10s
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: $name
    creationPolicy: Owner
  data:
"@

            foreach ($item in $dataJson) {
                $key = $item.key
                $manifest += @"

  - secretKey: $key
    remoteRef:
      key: $vaultPath
      property: $key
"@
            }

            $manifest | Add-Content -Path $EXTERNAL_SECRETS_FILE -Encoding UTF8
        }
    } catch {
        Log-Error "Failed to process secrets contract: $($_.Exception.Message)"
        exit 1
    }

    Log-Success "Secrets processed successfully for stack '$STACK'"
    Log-Info "✅ Vault populated with secret values"
    Log-Info "✅ ExternalSecret manifests generated: $EXTERNAL_SECRETS_FILE"
    Log-Info "✅ Ready for GitOps deployment via Flux"
}

#######################################
# Main execution
#######################################

# Validate command and execute
switch ($COMMAND) {
    "add" {
        Invoke-AddSecrets
    }
    "remove" {
        Invoke-RemoveSecrets
    }
    "list" {
        Invoke-ListSecrets $STACK
    }
    default {
        if (-not $COMMAND) {
            Show-Usage
            exit 1
        } else {
            Log-Error "Unknown command: $COMMAND"
            Write-Host ""
            Show-Usage
            exit 1
        }
    }
}
