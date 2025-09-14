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
| `spec.secrets[].data[].value` | `Secret.data.{key}` | Static secret value (stored base64-encoded in Kubernetes) |

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
| `apiVersion` | string | Required | Must be `hostk8s.io/v1` |
| `kind` | string | Required | Must be `SecretContract` |
| `metadata.name` | string | Required | Stack name (must match the deploying stack) |
| `spec.secrets` | array | Required | List of Kubernetes Secrets to create |
| `spec.secrets[].name` | string | Required | Name of the Kubernetes Secret to create |
| `spec.secrets[].namespace` | string | Required | Namespace where the Kubernetes Secret will be created |
| `spec.secrets[].data` | array | Required | Data keys to include in the Kubernetes Secret (minimum 1) |
| `spec.secrets[].data[].key` | string | Required | Data key name within the Kubernetes Secret |
| `spec.secrets[].data[].value` | string | Optional | Optional; static value (mutually exclusive with `generate`) |
| `spec.secrets[].data[].generate` | enum | Optional | Optional; generator type (mutually exclusive with `value`) |
| `spec.secrets[].data[].length` | integer | Optional | Overrides default length (ignored for UUID) |

## Validation Rules

### Contract Requirements
- Contract `metadata.name` must match the deploying stack name (used for Vault path prefixing)
- At least one secret must be defined in `spec.secrets`
- Each secret must have at least one data key
- Each `spec.secrets[].namespace` must correspond to a Kubernetes namespace provisioned before ExternalSecrets are applied

### Data Key Constraints
- Each data key must specify exactly one of `value` OR `generate` (mutually exclusive)
- Secret and key names must follow Kubernetes naming conventions (DNS-1123 subdomain)
- Maximum key name length is 63 characters (Kubernetes limit)
- Generated password minimum length is 8 characters
- UUID generation ignores `length` parameter (always 36 characters)

## Data Key Types

Each data key can specify its value in one of two ways:

• **Use `value`**: Provide the exact value to store (usernames, hostnames, ports)

• **Use `generate`**: Automatically create a secure value based on the specified type

### Supported Generators

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

## Lifecycle

When you run `make up {stack-name}`, HostK8s automatically processes any `hostk8s.secrets.yaml` file:

1. **Contract parsing** → schema validation
2. **Value resolution** → assign static values or generate new values
3. **Vault storage** → persisted at `secret/{stack}/{namespace}/{secret-name}`
4. **Manifest generation** → ExternalSecret resources produced
5. **Kubernetes sync** → ESO reconciles Vault data to Kubernetes Secrets
6. **Application access** → secrets available via `secretKeyRef`

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

## Example

```yaml
apiVersion: hostk8s.io/v1
kind: SecretContract
metadata:
  name: my-app
spec:
  secrets:
    - name: database-credentials   # PostgreSQL database secret
      namespace: my-app
      data:
        - key: username
          value: postgres           # Static value
        - key: password
          generate: password        # Generated password (default length: 32)
        - key: host
          value: db.my-app.svc.cluster.local
        - key: port
          value: "5432"

    - name: app-secrets            # Application-specific secrets
      namespace: my-app
      data:
        - key: jwt_secret
          generate: token           # Generated token
          length: 64
        - key: api_key
          generate: hex             # Generated hex string
        - key: correlation_id
          generate: uuid            # Generated UUID
        - key: environment
          value: production
```
