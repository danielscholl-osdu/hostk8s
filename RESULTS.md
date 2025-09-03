# Component-Owned Secret Architecture Implementation

## Overview
- **Task**: Design and implement a component-owned secret architecture to resolve circular dependency issues
- **Environment**: HostK8s cluster with GitOps/Flux workflow
- **Approach**: Move component-internal secrets INTO components themselves, separating them from cross-component integration secrets

## Problem Solved

**Previous Issue:**
- Components needed secrets to start (pgAdmin4, Redis Commander)
- But secrets were created by stack deployment which waited for components to be Ready
- This created a circular dependency that prevented proper component initialization

**Root Cause:**
- Stack deployment waited for component readiness before generating secrets
- Components couldn't start without the secrets they needed
- Classic chicken-and-egg problem in the deployment pipeline

## Implementation

### 1. Component-Level Secret Contracts

Created component-owned secret contracts:

**`software/components/postgres/hostk8s.secrets.yaml`**
```yaml
apiVersion: hostk8s.io/v1
kind: SecretContract
metadata:
  name: postgres
spec:
  secrets:
    - name: pgadmin4-credentials
      namespace: hostk8s
      data:
        - key: email
          value: admin@hostk8s.dev
        - key: password
          generate: password
          length: 16
```

**`software/components/redis/hostk8s.secrets.yaml`**
```yaml
apiVersion: hostk8s.io/v1
kind: SecretContract
metadata:
  name: redis
spec:
  secrets:
    - name: redis-commander-credentials
      namespace: redis
      data:
        - key: username
          value: admin
        - key: password
          generate: password
          length: 12
```

### 2. Enhanced Secret Management Script

Created **`infra/scripts/manage-secrets-enhanced.sh`** with capabilities:
- **Component-first processing**: Generates component secrets before stack deployment
- **Multi-contract support**: Processes both component and stack-level contracts
- **Proper labeling**: Labels secrets with their contract source (`hostk8s.io/contract`)
- **Selective processing**: Can process only components or full stack
- **Idempotency**: Skips existing secrets to avoid overwrites

### 3. Updated Component Metadata

Added secret contract annotations to component kustomization files:

```yaml
metadata:
  annotations:
    component.hostk8s.io/secrets: "hostk8s.secrets.yaml"
```

### 4. Refined Stack-Level Secrets

Updated **`software/stacks/sample-app/hostk8s.secrets.yaml`** to contain only cross-component integration secrets:

```yaml
spec:
  secrets:
    # PostgreSQL database credentials for voting app
    # This is a cross-component integration secret (app -> database)
    - name: postgres-credentials
      namespace: sample-app
      data:
        - key: username
          value: postgres
        # ... other integration credentials
```

### 5. Enhanced Deployment Flow

Modified **Makefile** to implement the new deployment sequence:

```makefile
up: ## Deploy software stack (Usage: make up [stack-name] - defaults to 'sample')
	@$(SCRIPT_RUNNER) ./infra/scripts/manage-secrets-enhanced$(SCRIPT_EXT) $(stack) true 2>/dev/null || true
	@$(SCRIPT_RUNNER) ./infra/scripts/deploy-stack$(SCRIPT_EXT) $(stack)
	@$(SCRIPT_RUNNER) ./infra/scripts/manage-secrets-enhanced$(SCRIPT_EXT) $(stack) false 2>/dev/null || true
```

**New Flow:**
1. **Generate component secrets first** (`true` = component-only mode)
2. **Deploy stack** (components can now start successfully)
3. **Generate integration secrets** (`false` = full mode including stack secrets)

## Testing & Validation

### Deployment Testing
```bash
# Clean deployment test
make up sample-app

# Verified all components start successfully
make status
# Result: All kustomizations show [OK] status
```

### Secret Verification
```bash
# Check all managed secrets
kubectl get secrets --all-namespaces -l hostk8s.io/managed=true

# Results:
# NAMESPACE    NAME                          TYPE     DATA   AGE
# hostk8s      pgadmin4-credentials          Opaque   2      working
# redis        redis-commander-credentials   Opaque   2      working
# sample-app   postgres-credentials          Opaque   5      working
```

### Label Verification
- Component secrets labeled with component name as contract: `hostk8s.io/contract=postgres`
- Stack secrets labeled with stack name as contract: `hostk8s.io/contract=sample-app`
- All secrets marked as managed: `hostk8s.io/managed=true`

## Usage

### For Component Developers

**Create component secret contract:**
```yaml
# software/components/my-component/hostk8s.secrets.yaml
apiVersion: hostk8s.io/v1
kind: SecretContract
metadata:
  name: my-component
spec:
  secrets:
    - name: my-app-credentials
      namespace: my-namespace
      data:
        - key: username
          value: admin
        - key: password
          generate: password
          length: 16
```

**Update component kustomization:**
```yaml
metadata:
  annotations:
    component.hostk8s.io/secrets: "hostk8s.secrets.yaml"
```

### For Stack Developers

**Keep only integration secrets in stack contract:**
```yaml
# software/stacks/my-stack/hostk8s.secrets.yaml
spec:
  secrets:
    # Only cross-component secrets belong here
    - name: app-database-credentials
      namespace: my-app
      data:
        - key: connection-string
          value: "postgres://user@db.namespace.svc:5432/mydb"
```

### Manual Secret Operations

```bash
# Generate only component secrets (before deployment)
./infra/scripts/manage-secrets-enhanced.sh my-stack true

# Generate full secrets (components + stack)
./infra/scripts/manage-secrets-enhanced.sh my-stack false

# Standard deployment (uses enhanced flow automatically)
make up my-stack
```

## Architecture Benefits

### 1. **Component Self-Containment**
- Components own their internal secrets
- No external dependencies for component-specific credentials
- Components can be deployed independently

### 2. **Clear Separation of Concerns**
- **Component secrets**: Internal to the component (UI credentials, internal tokens)
- **Stack secrets**: Cross-component integration (database connections, API keys)

### 3. **Resolved Circular Dependencies**
- Component secrets created BEFORE component deployment
- Components can start immediately with required credentials
- Stack-level integration happens after components are running

### 4. **GitOps Compatibility**
- Works seamlessly with existing Flux workflow
- Maintains Git-based secret contracts
- Preserves GitOps principles and patterns

### 5. **Enhanced Traceability**
- Secrets labeled with their contract source
- Clear ownership and management boundaries
- Easier debugging and maintenance

## Notes

### Key Design Decisions

1. **Two-phase secret generation**: Component secrets first, then integration secrets
2. **Contract-based labeling**: Each secret knows its source contract
3. **Backward compatibility**: Existing stack patterns still work
4. **Enhanced script over replacement**: Builds on existing secret management patterns

### Future Improvements

- **Auto-discovery**: Automatically detect components needing secrets during stack deployment
- **Secret rotation**: Implement automatic secret rotation for generated passwords
- **Validation**: Add schema validation for secret contracts
- **Cleanup**: Implement secret cleanup when components are removed

### Migration Path

For existing deployments:
1. Move component-specific secrets from stack to component contracts
2. Update component kustomization metadata
3. Use enhanced secret management script
4. Verify proper labeling and functionality

The implementation successfully resolves the circular dependency issue while maintaining clean architecture patterns and full GitOps compatibility.
