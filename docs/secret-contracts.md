# Secret Contract Specification

## Overview

Secret contracts provide a declarative interface for managing sensitive data in Kubernetes without storing secrets in version control. Applications declare their secret requirements through `SecretContract` resources, and HostK8s generates, stores, and syncs the secrets automatically using HashiCorp Vault and External Secrets Operator.

Secret Contracts implement the [Vault-integrated secret management architecture](adr/014-vault-integrated-secret-management-architecture.md) established in HostK8s.

## Terminology

To clarify the relationship between contract fields and Kubernetes resources:

| SecretContract Term | Kubernetes Equivalent | Description |
|---------------------|----------------------|-------------|
| `spec.secrets[].name` | `Secret.metadata.name` | The name of the Kubernetes Secret that will be created |
| `spec.secrets[].namespace` | `Secret.metadata.namespace` | The namespace where the Kubernetes Secret will be created |
| `spec.secrets[].data[].key` | `Secret.data.{key}` | A data key within the Kubernetes Secret |
| `spec.secrets[].data[].value` | `Secret.data.{key}` | The stored secret value (base64-encoded in Kubernetes) |

**Example mapping:**
```yaml
# SecretContract declares this:
secrets:
  - name: postgres-credentials    # → Creates Kubernetes Secret named "postgres-credentials"
    data:
      - key: password            # → Creates data key "password" in that Secret
        generate: password       # → With a generated value
```

## Schema Definition

### Contract Structure

```yaml
apiVersion: hostk8s.io/v1
kind: SecretContract
metadata:
  name: {stack-name}
spec:
  secrets:
    - name: {secret-name}
      namespace: {namespace}
      data:
        - key: {key-name}
          value: {value}
          # OR
          generate: {type}
          length: {length}
```

### Field Specification

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `apiVersion` | string | ✅ | Must be `hostk8s.io/v1` |
| `kind` | string | ✅ | Must be `SecretContract` |
| `metadata.name` | string | ✅ | Stack name (must match the deploying stack) |
| `spec.secrets` | array | ✅ | List of Kubernetes Secrets to create |
| `spec.secrets[].name` | string | ✅ | Name of the Kubernetes Secret to create |
| `spec.secrets[].namespace` | string | ✅ | Namespace where the Kubernetes Secret will be created |
| `spec.secrets[].data` | array | ✅ | Data keys to include in the Kubernetes Secret (minimum 1) |
| `spec.secrets[].data[].key` | string | ✅ | Data key name within the Kubernetes Secret |
| `spec.secrets[].data[].value` | string | ⚠️ | The stored secret value (mutually exclusive with `generate`) |
| `spec.secrets[].data[].generate` | enum | ⚠️ | Auto-generate value for this data key (mutually exclusive with `value`) |
| `spec.secrets[].data[].length` | integer | ❌ | Optional; overrides default length (ignored for UUID) |

## Processing Model

When HostK8s processes a `SecretContract`, the following sequence occurs:

1. **Contract Parsing**: HostK8s validates the contract against the schema requirements
2. **Secret Generation**: Static values are used as provided; generated values are created using cryptographically secure randomness
3. **Vault Storage**: All secrets are stored in HashiCorp Vault at path `secret/{stack}/{namespace}/{secret-name}`
4. **Manifest Generation**: `ExternalSecret` resources are generated for GitOps deployment
5. **Kubernetes Sync**: External Secrets Operator syncs Vault secrets to Kubernetes `Secret` resources
6. **Application Access**: Applications reference secrets using standard `secretKeyRef` patterns

## Data Key Types

Each data key can specify its value in one of two ways:

**`value`**: Provide the exact value to store (usernames, hostnames, ports)

**`generate`**: Automatically create a secure value based on the specified type

| Generate Type | Character Set | Default Length | Use Case |
|---------------|---------------|----------------|----------|
| `password` | A-Z, a-z, 0-9, `!@#$%^&*` | 32 | Database passwords, authentication credentials |
| `token` | A-Z, a-z, 0-9 | 32 | API tokens, session keys, safe identifiers |
| `hex` | a-f, 0-9 | 32 | Encryption keys, hash values, hexadecimal IDs |
| `uuid` | UUID v4 format | 36 | Correlation IDs, unique identifiers (RFC 4122) |
```yaml
data:
  # Static values
  - key: username
    value: postgres
  - key: host
    value: database.namespace.svc.cluster.local
  - key: port
    value: "5432"

  # Generated values
  - key: password
    generate: password
  - key: api_token
    generate: token
    length: 64
  - key: session_key
    generate: hex
  - key: correlation_id
    generate: uuid
```

## Validation Rules

### Contract Requirements
- Contract `name` must match the deploying stack name
- At least one secret must be defined in `spec.secrets`
- Each secret must have at least one data key

### Data Key Constraints
- Each data key must specify either `value` OR `generate` (mutually exclusive)
- Secret and key names must follow Kubernetes naming conventions (DNS-1123 subdomain)
- Maximum key name length is 63 characters (Kubernetes limit)
- Generated password minimum length is 8 characters
- UUID generation ignores `length` parameter (always 36 characters)

## Lifecycle

When you run `make up {stack-name}`, HostK8s automatically processes any `hostk8s.secrets.yaml` file:

1. **Contract Parsing**: Validates the SecretContract against schema requirements
2. **Value Generation**: Creates secure values for `generate` fields, uses provided `value` fields directly
3. **Vault Storage**: Stores all secrets in HashiCorp Vault for secure backend storage
4. **Manifest Generation**: Creates ExternalSecret resources for GitOps deployment
5. **Kubernetes Sync**: External Secrets Operator syncs Vault data to Kubernetes Secret resources
6. **Application Access**: Applications reference secrets using standard `secretKeyRef` patterns

## Using Secrets in Applications

Once your secret contract is processed, the secrets become available as standard Kubernetes Secret resources that applications can reference:

```yaml
env:
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-credentials  # From contract: secrets[].name
        key: password              # From contract: data[].key
```

The secret name and key names in your application manifests must match exactly what you declared in your SecretContract.


## Examples

### Basic Contract
```yaml
apiVersion: hostk8s.io/v1
kind: SecretContract
metadata:
  name: simple-app
spec:
  secrets:
    - name: basic-auth          # → Creates Kubernetes Secret "basic-auth"
      namespace: simple-app
      data:
        - key: password         # → Secret will have data key "password"
          generate: password    # → With auto-generated secure password
```

### Advanced Contract
```yaml
apiVersion: hostk8s.io/v1
kind: SecretContract
metadata:
  name: database-app
spec:
  secrets:
    - name: postgres-credentials
      namespace: database-app
      data:
        - key: username
          value: postgres       # Static value
        - key: password
          generate: password    # Generated password
        - key: host
          value: postgres.database-app.svc.cluster.local
        - key: port
          value: "5432"

    - name: app-secrets
      namespace: database-app
      data:
        - key: jwt_secret
          generate: token       # Generated token (alphanumeric)
          length: 64
        - key: api_key
          generate: hex         # Generated hex string
        - key: correlation_id
          generate: uuid        # Generated UUID
        - key: environment
          value: production
```
