# ADR-015: Unified Python Script Architecture

## Status
**Accepted** - 2025-09-09

## Context

HostK8s previously used a dual shell script architecture (.sh/.ps1 pairs) to provide cross-platform support while maintaining native platform integration. While this approach was successful, it created a significant **dual maintenance burden** where every script enhancement required implementation in both bash and PowerShell, with ongoing functional parity verification and synchronization risks.

The need for a more maintainable solution led to evaluating alternatives that could:
1. Eliminate dual maintenance entirely
2. Preserve cross-platform functionality
3. Maintain the established Make interface patterns
4. Enhance developer experience with modern tooling

## Decision

Migrate to a **unified Python script architecture** using PEP 723 headers for dependency management and `uv` for cross-platform execution. Each operation is implemented once as a Python script that runs identically across all platforms, eliminating the dual maintenance burden while enhancing functionality.

## Rationale

1. **Eliminated Dual Maintenance**: Single implementation per operation removes the complexity and synchronization risks of maintaining script pairs
2. **Native Cross-Platform**: Python's platform abstraction provides consistent behavior without platform-specific code paths
3. **Enhanced Developer Experience**: Rich terminal output, structured error handling, and comprehensive logging improve usability
4. **Modern Dependency Management**: PEP 723 headers make scripts self-contained with explicit dependency declarations
5. **Universal Execution**: `uv run` provides consistent script execution environment across all platforms
6. **Architecture Preservation**: Maintains the successful Make interface layer while simplifying the implementation layer

## Architecture Design

### Simplified Three-Layer Abstraction
```
Make Interface (Argument Parsing & Routing)
    ↓
uv Execution Layer (Universal Python Runtime)
    ↓
Python Script Implementation (Cross-Platform)
```

### Script Structure (PEP 723)
```python
#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "pyyaml>=6.0",
#     "rich>=13.0.0",
#     "requests>=2.28.0"
# ]
# ///

"""
Script Description with detailed functionality explanation.
"""

import sys
from pathlib import Path

# Import shared utilities
from hostk8s_common import (
    logger, HostK8sError, KubectlError,
    run_kubectl, detect_kubeconfig, get_env
)

def main():
    """Main entry point with structured error handling."""
    try:
        # Implementation
        perform_operation()
    except HostK8sError as e:
        logger.error(str(e))
        sys.exit(1)
    except KeyboardInterrupt:
        logger.warn("Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
```

### Make Interface Integration
```makefile
# Unified Python script execution
define SCRIPT_RUNNER_FUNC
uv run ./infra/scripts/$(1).py
endef

# Make handles interface and routing
start: ## Start cluster (cross-platform)
	@$(call SCRIPT_RUNNER_FUNC,cluster-up)
```

### Shared Utilities Module
`hostk8s_common.py` provides unified cross-platform utilities:
- **Logging**: Rich-formatted output with colors, emojis, and timestamp formatting
- **Error Handling**: Structured exception classes (`HostK8sError`, `KubectlError`, `FluxError`)
- **Command Execution**: Cross-platform `kubectl`, `flux`, and system command wrappers
- **Environment Management**: `.env` file processing and environment variable handling
- **Validation**: kubeconfig detection, cluster connectivity, and prerequisite checking

## Implementation Features

### Self-Contained Dependencies
Each script declares its own requirements via PEP 723 headers:
- No global Python environment dependencies
- Automatic dependency resolution and installation
- Version pinning ensures consistent behavior
- Scripts remain executable in isolation

### Enhanced User Experience
- **Rich Terminal Output**: Colors, emojis, and progress indicators
- **Structured Logging**: Consistent formatting with LOG_LEVEL environment variable support
- **Comprehensive Error Messages**: Detailed errors with recovery suggestions
- **Help Documentation**: Argparse-based help systems with usage examples

### Cross-Platform Design Patterns
- **Path Handling**: `pathlib.Path` for cross-platform file operations
- **Environment Variables**: Unified environment detection and processing
- **Command Execution**: Platform-agnostic subprocess management
- **Error Handling**: Consistent exception patterns across all scripts

## Script Organization

### Current Python Implementation (19 scripts)
- `hostk8s_common.py` - Shared cross-platform utilities
- `cluster-*.py` - Cluster lifecycle management (up, down, status, restart)
- `setup-*.py` - Infrastructure component setup (flux, ingress, metallb, etc.)
- `deploy-*.py` - Application and stack deployment
- `flux-*.py` - GitOps workflow management
- `build.py` - Container image build and registry operations
- `prepare.py` - Development environment setup
- `manage-secrets.py` - Secret management operations
- `worktree-setup.py` - Git worktree development environments

### Remaining Platform-Specific Scripts
Only installation scripts remain platform-specific due to package manager differences:
- `install.sh` - Unix/Linux/Mac dependency installation (brew, apt, yum)
- `install.ps1` - Windows dependency installation (winget, chocolatey)

## Alternatives Considered

### 1. Continue Dual Shell Script Maintenance
- **Pros**: Established pattern, native platform integration
- **Cons**: Ongoing dual maintenance burden, synchronization risks, complexity
- **Decision**: Rejected due to maintenance costs outweighing benefits

### 2. Cross-Platform PowerShell (PowerShell Core)
- **Pros**: Single language, object-based, modern syntax
- **Cons**: Additional dependency on Unix systems, less familiar to Unix developers
- **Decision**: Rejected due to mixed developer experience

### 3. Docker-Based Script Execution
- **Pros**: Completely isolated environment, no host dependencies
- **Cons**: Performance overhead, Docker-in-Docker complications, complexity for simple operations
- **Decision**: Rejected due to performance and complexity concerns

### 4. Node.js/JavaScript Tooling
- **Pros**: Cross-platform, rich npm ecosystem, familiar to many developers
- **Cons**: Runtime dependency, domain mismatch for infrastructure scripting
- **Decision**: Rejected due to runtime requirements and tool ecosystem mismatch

## Migration Results

### Eliminated Complexity
- **17 Script Pairs → 19 Single Scripts**: No more dual maintenance
- **Functional Parity Testing**: No longer required - single implementation guarantees consistency
- **OS Detection Logic**: Eliminated from Makefile - `uv` handles execution uniformly
- **Platform-Specific Bugs**: Eliminated through unified implementation

### Enhanced Capabilities
- **Rich Output**: Enhanced terminal experience with colors and progress indicators
- **Better Error Handling**: Structured exceptions with detailed recovery information
- **Improved Logging**: Consistent formatting with configurable log levels
- **Modern Tooling**: Type hints, proper documentation, structured code organization

### Maintained Benefits
- **Make Interface**: Preserved existing user experience and command patterns
- **Cross-Platform Support**: All platforms supported with better consistency
- **Independent Execution**: Scripts can still be run in isolation for debugging
- **Environment Management**: KUBECONFIG and environment variable handling preserved

## Consequences

**Positive:**
- **Eliminated Dual Maintenance**: Single implementation per operation dramatically reduces maintenance burden
- **Enhanced Developer Experience**: Rich terminal output, better error messages, comprehensive logging
- **Improved Consistency**: Single implementation guarantees identical behavior across platforms
- **Modern Dependency Management**: PEP 723 headers provide explicit, self-contained dependencies
- **Better Debugging**: Python's exception handling and logging provide superior debugging experience
- **Simplified Testing**: Single implementation reduces testing complexity and CI/CD requirements
- **Future-Proof**: Python ecosystem provides long-term viability and enhancement opportunities

**Negative:**
- **Runtime Dependency**: Requires Python 3.8+ and `uv` tool (manageable via install scripts)
- **Paradigm Shift**: Developers accustomed to shell scripting need to adapt to Python patterns
- **Initial Migration Effort**: One-time cost to convert existing shell scripts (already completed)

## Success Criteria

- ✅ **Unified Implementation**: Single script per operation eliminates dual maintenance
- ✅ **Cross-Platform Consistency**: Identical behavior across all platforms without platform-specific code
- ✅ **Enhanced User Experience**: Rich terminal output and comprehensive error handling
- ✅ **Preserved Interface**: Make commands work identically to previous implementation
- ✅ **Independent Execution**: Scripts can be run in isolation for debugging via `uv run`
- ✅ **Self-Contained**: Scripts manage their own dependencies via PEP 723 headers
- ✅ **Maintainable Architecture**: Clear patterns and shared utilities enable easy extension

## Future Considerations

### Quality Enhancements
- **Standardized Help Text**: Ensure all scripts provide comprehensive `--help` documentation
- **Type Safety**: Complete type hint coverage across all scripts
- **Testing Framework**: Consider automated testing patterns for Python script validation
- **Documentation Generation**: Automated help documentation from script metadata

### Extension Opportunities
- **Configuration Validation**: Enhanced YAML/JSON validation with detailed error reporting
- **Interactive Mode**: Rich CLI prompts for complex operations
- **Performance Monitoring**: Built-in timing and resource usage reporting
- **Plugin Architecture**: Framework for custom script extensions

## Implementation Status

**Completed:**
- All 19 operational scripts migrated to Python with PEP 723 headers
- Shared utilities module (`hostk8s_common.py`) provides comprehensive cross-platform support
- Make interface updated to use unified `uv run` execution pattern
- Documentation updated to reflect Python architecture
- All functionality verified across Mac, Linux, and Windows platforms

**Remaining:**
- Install scripts remain platform-specific (necessary for package manager integration)
- Deprecated shell script folder ready for removal
- Minor standardization improvements (help text consistency)

The Python script architecture represents a significant improvement over the previous dual shell script approach, eliminating maintenance complexity while enhancing functionality and developer experience.
