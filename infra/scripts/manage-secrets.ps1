#######################################
# HostK8s Secret Generation Script
# Generates ephemeral secrets from hostk8s.secrets.yaml contract files
#######################################

param(
    [Parameter(Position = 0)]
    [string]$Stack = ""
)

# Source common utilities
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptDir\common.ps1"

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
# Wait for namespace to be ready
#######################################
function Wait-ForNamespace {
    param(
        [string]$Namespace,
        [int]$TimeoutSeconds = 60
    )

    Write-Info "Waiting for namespace '$Namespace' to be ready..."

    $count = 0
    while ((kubectl get namespace $Namespace 2>&1 | Out-String) -match "NotFound|Error") {
        if ($count -ge $TimeoutSeconds) {
            Write-Error "Timeout waiting for namespace '$Namespace' to be created"
            Write-Error "Run 'kubectl get namespace $Namespace' to check status"
            return $false
        }

        Start-Sleep -Seconds 2
        $count += 2
        Write-Host "." -NoNewline
    }

    Write-Host ""
    Write-Success "Namespace '$Namespace' is ready"
    return $true
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
                    $value = [guid]::NewGuid().ToString().ToLower()
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

#######################################
# Generate secrets from contract
#######################################
function Generate-Secrets {
    if ([string]::IsNullOrEmpty($Stack)) {
        Write-Error "Stack name required. Usage: manage-secrets.ps1 <stack-name>"
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

    # Get unique namespaces first and wait for them to be ready
    $namespaces = $contract.spec.secrets | ForEach-Object { $_.namespace } | Select-Object -Unique
    foreach ($namespace in $namespaces) {
        if (-not (Wait-ForNamespace -Namespace $namespace)) {
            exit 1
        }
    }

    # Process each secret in the contract
    $secretCount = $contract.spec.secrets.Count

    for ($i = 0; $i -lt $secretCount; $i++) {
        $secret = $contract.spec.secrets[$i]
        $name = $secret.name
        $namespace = $secret.namespace

        # Skip if secret already exists (idempotency)
        if (Test-SecretExists -Name $name -Namespace $namespace) {
            Write-Info "Secret '$name' already exists in namespace '$namespace', skipping"
            continue
        }

        Write-Info "Generating secret '$name'"

        # Use generic data format
        $secretYaml = Generate-SecretFromData -SecretName $name -Namespace $namespace -Data $secret.data
        Add-Content -Path $tempFile -Value $secretYaml -Encoding UTF8
    }

    # Apply generated secrets to cluster
    if ((Get-Item $tempFile).Length -gt 0) {
        Write-Info "Applying generated secrets to cluster"
        kubectl apply -f $tempFile

        # Save a copy for reference (but it's gitignored)
        Copy-Item $tempFile "$SecretsDir/generated.yaml" -Force
        Remove-Item $tempFile

        Write-Success "Secrets generated and applied successfully"
    } else {
        Write-Info "No new secrets to generate"
    }
}

#######################################
# Main execution
#######################################
Generate-Secrets
