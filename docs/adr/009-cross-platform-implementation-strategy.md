# ADR-009: Cross-Platform Implementation Strategy

## Status
**Accepted** - 2025-01-15

## Context
HostK8s was originally designed for Unix/Linux/Mac environments using bash scripts. With growing Windows developer adoption and Docker Desktop's native Windows support, there was demand for native Windows PowerShell support while maintaining the existing three-layer abstraction architecture and user experience consistency.

The core challenge was extending platform support without compromising the established Make interface patterns, operational reliability, or developer experience that made HostK8s successful.

## Decision
Implement **dual script architecture** with functional parity between platform-native scripts (.sh for Unix/Linux/Mac, .ps1 for Windows PowerShell) rather than adopting cross-platform scripting solutions. Enhance the Make interface with automatic OS detection and script selection while preserving identical user experience across all platforms.

## Rationale
1. **Platform Optimization**: Native tooling integration (winget/chocolatey vs brew/apt) provides better user experience than lowest-common-denominator solutions
2. **Developer Familiarity**: Platform-specific scripting conventions align with developer expectations (PowerShell idioms on Windows, bash patterns on Unix)
3. **Tool Ecosystem Integration**: Direct integration with platform package managers and native utilities
4. **Performance**: No abstraction layer overhead; scripts execute in optimal platform environments
5. **Maintainability**: Clear separation enables platform-specific optimization without cross-platform compromises
6. **Architecture Preservation**: Maintains the successful three-layer abstraction while extending platform support

## Architecture Design

### Enhanced Three-Layer Abstraction
```
Make Interface (Cross-Platform Detection)
    ↓
OS Detection & Script Selection Layer
    ↓
Platform-Native Script Execution (.sh/.ps1)
```

### Cross-Platform Make Interface
```makefile
# OS Detection for cross-platform script execution
ifeq ($(OS),Windows_NT)
    SCRIPT_EXT := .ps1
    SCRIPT_RUNNER := pwsh -ExecutionPolicy Bypass -NoProfile -File
else
    SCRIPT_EXT := .sh
    SCRIPT_RUNNER :=
endif

# Unified command routing
start: ## Start cluster (cross-platform)
	@$(SCRIPT_RUNNER) ./infra/scripts/cluster-up$(SCRIPT_EXT)
```

### Functional Parity Requirements
- **Identical Command Interface**: `make start`, `make deploy`, etc. work identically across platforms
- **Consistent Output**: Same logging format, status indicators, and error messages
- **Environment Compatibility**: KUBECONFIG, environment variables handled consistently
- **Feature Completeness**: All functionality available on all supported platforms

### Platform-Specific Implementations

**Unix/Linux/Mac (.sh scripts)**:
- Bash scripting conventions and best practices
- Integration with brew, apt, yum package managers
- Standard Unix path handling and environment management
- POSIX-compliant utilities and commands

**Windows (.ps1 scripts)**:
- PowerShell 7+ scripting conventions and best practices
- Integration with winget (preferred) and chocolatey package managers
- Windows-native path handling and environment management
- PowerShell-specific utilities and cmdlets

## Alternatives Considered

### 1. PowerShell Core (Cross-Platform PowerShell)
- **Pros**: Single scripting language, modern syntax, object-based
- **Cons**: Additional dependency on Unix systems, less familiar to Unix developers
- **Decision**: Rejected due to Unix developer experience concerns

### 2. Python-Based Scripts
- **Pros**: True cross-platform, rich ecosystem, widely known
- **Cons**: Additional runtime dependency, deviation from shell scripting conventions
- **Decision**: Rejected due to additional dependency requirements

### 3. Node.js/JavaScript-Based Tooling
- **Pros**: Cross-platform, npm ecosystem, modern async patterns
- **Cons**: Requires Node.js runtime, unfamiliar for infrastructure scripting
- **Decision**: Rejected due to runtime dependency and domain mismatch

### 4. Docker-Based Script Execution
- **Pros**: Consistent environment, no platform dependencies
- **Cons**: Performance overhead, complexity for simple operations, Docker-in-Docker issues
- **Decision**: Rejected due to performance and complexity concerns

### 5. Lowest-Common-Denominator Shell Scripts
- **Pros**: Single implementation, minimal maintenance
- **Cons**: Suboptimal platform integration, limited tooling support, poor developer experience
- **Decision**: Rejected due to platform optimization benefits

## Implementation Benefits

### Developer Experience Consistency
```bash
# Identical commands across all platforms
make start        # Works on Mac, Linux, Windows
make deploy       # Same interface everywhere
make status       # Consistent output format
```

### Platform Optimization Examples
```bash
# Unix/Linux/Mac - brew integration
brew install kind kubectl helm

# Windows - winget integration
winget install Kubernetes.kind Kubernetes.kubectl Helm.Helm
```

### Functional Parity Verification
- All 17 script pairs provide identical functionality
- Cross-platform testing ensures behavioral consistency
- Common operations (cluster management, app deployment) work identically

## Consequences

**Positive:**
- **Native Platform Integration**: Optimal tooling and package manager integration on each platform
- **Developer Familiarity**: Scripts follow platform-specific conventions developers expect
- **Performance**: No abstraction layer overhead; optimal execution on each platform
- **Architecture Preservation**: Maintains successful three-layer abstraction design
- **Feature Parity**: Complete HostK8s functionality available on all platforms
- **User Experience Consistency**: Identical interface and behavior across platforms

**Negative:**
- **Dual Maintenance Burden**: Every script enhancement requires implementation in both .sh and .ps1
- **Functional Parity Verification**: Changes must be tested across platforms to ensure consistency
- **Documentation Complexity**: Platform-specific implementation details require comprehensive documentation
- **Testing Requirements**: CI/CD must validate both script implementations
- **Synchronization Risk**: Platform implementations may drift without proper governance

## Implementation Results

### Script Architecture
- **17 Script Pairs**: Complete functional parity between .sh and .ps1 implementations
- **Common Utilities**: Platform-specific common.sh/common.ps1 with identical interfaces
- **Make Integration**: Transparent OS detection and script selection

### Platform Support Matrix
| Platform | Script Type | Package Manager | Status |
|----------|-------------|----------------|---------|
| macOS | .sh | brew | ✅ Fully Supported |
| Linux | .sh | apt/yum/native | ✅ Fully Supported |
| WSL2 | .sh | apt/native | ✅ Fully Supported |
| Windows PowerShell | .ps1 | winget/chocolatey | ✅ Fully Supported |

### Operational Validation
- All core operations (cluster management, application deployment, GitOps workflows) validated across platforms
- Cross-platform CI/CD testing ensures functional parity maintenance
- Documentation updated to reflect cross-platform capabilities

## Success Criteria
- Identical user experience across Unix/Linux/Mac/Windows platforms
- No functional limitations on any supported platform
- Platform-native tooling integration provides optimal developer experience
- Three-layer abstraction architecture preserved and enhanced
- Dual maintenance overhead remains manageable through proper tooling and processes

## Future Considerations
- **CI/CD Enhancement**: Automated functional parity testing across platforms
- **Script Generation**: Consider tooling to automatically generate script pairs from common specifications
- **Documentation Automation**: Automated cross-platform documentation generation
- **Community Contributions**: Clear guidelines for maintaining functional parity in community contributions
