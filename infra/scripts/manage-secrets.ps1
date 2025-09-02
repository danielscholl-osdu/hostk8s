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

Usage: make secrets <action> [STACK=stack-name]

Actions:
  generate    Generate secrets from contract for a stack
  show        Display current secrets for a stack
  clean       Remove secrets for a stack from cluster
  help        Show this help message

Examples:
  make secrets generate STACK=sample-app
  make secrets show STACK=sample-app
  make secrets clean STACK=sample-app

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
# Generate PostgreSQL secret
#######################################
function Generate-PostgreSQLSecret {
    param(
        [string]$SecretName,
        [string]$Namespace,
        [string]$Username = "postgres",
        [string]$Database = "postgres",
        [string]$Cluster = "postgres"
    )

    $password = Generate-Password -Length 32
    $host = "$Cluster-rw.$Namespace.svc.cluster.local"
    $port = "5432"
    $url = "postgresql://${Username}:${password}@${host}:${port}/${Database}"

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
    hostk8s.io/type: "postgresql"
type: kubernetes.io/basic-auth
stringData:
  username: "$Username"
  password: "$password"
  database: "$Database"
  host: "$host"
  port: "$port"
  url: "$url"
"@
}

#######################################
# Generate Redis secret
#######################################
function Generate-RedisSecret {
    param(
        [string]$SecretName,
        [string]$Namespace,
        [string]$Service = "redis"
    )

    $password = Generate-Password -Length 32
    $host = "$Service.$Namespace.svc.cluster.local"
    $port = "6379"

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
    hostk8s.io/type: "redis"
type: Opaque
stringData:
  password: "$password"
  host: "$host"
  port: "$port"
"@
}

#######################################
# Generate generic secret
#######################################
function Generate-GenericSecret {
    param(
        [string]$SecretName,
        [string]$Namespace,
        [hashtable]$Fields
    )

    $stringData = ""
    foreach ($field in $Fields.Keys) {
        $fieldDef = $Fields[$field]
        $value = ""

        switch ($fieldDef.generate) {
            "password" { $value = Generate-Password -Length $fieldDef.length }
            "token" { $value = Generate-Token -Length $fieldDef.length }
            "hex" { $value = Generate-Hex -Length $fieldDef.length }
            "static" { $value = $fieldDef.value }
            default { $value = Generate-Token -Length $fieldDef.length }
        }

        $stringData += "  $field: `"$value`"`n"
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
    hostk8s.io/type: "generic"
type: Opaque
stringData:
$stringData"@
}

#######################################
# Generate API key secret
#######################################
function Generate-APIKeySecret {
    param(
        [string]$SecretName,
        [string]$Namespace,
        [string]$Prefix = "",
        [int]$Length = 32
    )

    $key = "$Prefix$(Generate-Token -Length $Length)"

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
    hostk8s.io/type: "apikey"
type: Opaque
stringData:
  key: "$key"
"@
}

#######################################
# Parse and generate secrets from contract
#######################################
function Invoke-GenerateSecrets {
    if ([string]::IsNullOrEmpty($Stack)) {
        Write-Error "Stack name required. Use: make secrets generate STACK=<name>"
        exit 1
    }

    $ContractFile = "software/stacks/$Stack/secrets.contract.yaml"
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

        Write-Info "Generating secret '$name' of type '$type'"

        $secretYaml = ""

        switch ($type) {
            "postgresql" {
                $username = if ($secret.spec.username) { $secret.spec.username } else { "postgres" }
                $database = $secret.spec.database
                $cluster = $secret.spec.cluster
                $secretYaml = Generate-PostgreSQLSecret -SecretName $name -Namespace $namespace `
                    -Username $username -Database $database -Cluster $cluster
            }

            "redis" {
                $service = if ($secret.spec.service) { $secret.spec.service } else { "redis" }
                $secretYaml = Generate-RedisSecret -SecretName $name -Namespace $namespace -Service $service
            }

            "apikey" {
                $prefix = if ($secret.spec.prefix) { $secret.spec.prefix } else { "" }
                $length = if ($secret.spec.length) { $secret.spec.length } else { 32 }
                $secretYaml = Generate-APIKeySecret -SecretName $name -Namespace $namespace `
                    -Prefix $prefix -Length $length
            }

            "generic" {
                $fields = @{}
                foreach ($field in $secret.spec.fields) {
                    $fields[$field.name] = @{
                        generate = if ($field.generate) { $field.generate } else { "token" }
                        length = if ($field.length) { $field.length } else { 32 }
                        value = $field.value
                    }
                }
                $secretYaml = Generate-GenericSecret -SecretName $name -Namespace $namespace -Fields $fields
            }

            default {
                Write-Warning "Unknown secret type '$type' for secret '$name', skipping"
            }
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
        Write-Error "Stack name required. Use: make secrets show STACK=<name>"
        exit 1
    }

    Write-Info "Showing secrets for stack '$Stack'"

    # Get the namespace from the contract
    $ContractFile = "software/stacks/$Stack/secrets.contract.yaml"
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
        Write-Error "Stack name required. Use: make secrets clean STACK=<name>"
        exit 1
    }

    Write-Warning "Removing secrets for stack '$Stack'"

    # Get the namespace from the contract
    $ContractFile = "software/stacks/$Stack/secrets.contract.yaml"
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
