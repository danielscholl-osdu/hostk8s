# Extension Kubernetes Configurations

This directory contains custom Kubernetes cluster configurations for extending HostK8s functionality.

## Adding Custom Configurations

1. Add your Kind configuration: `extension/kind-your-name.yaml`
2. Use with: `make up extension/your-name`

## Structure

```
extension/
├── .gitignore          # Ignore all except documented files
├── README.md           # This file
└── kind-sample.yaml    # Sample extension config
```

## Configuration Requirements

Your `kind-your-name.yaml` must:
- Set `name: hostk8s` (required for compatibility)
- Include standard port mappings if needed (8080, 8443, etc.)
- Follow Kind cluster configuration format

## Example Usage

```bash
# Use custom cluster configuration
make up extension/sample          # Uses extension/kind-sample.yaml
make deploy extension/sample      # Deploy custom app
make status                       # Check status
```

## Git Integration

The `.gitignore` file allows you to:
- Add custom configurations directly to this directory
- Keep configurations private (not committed to main repo)
- Share specific configurations by whitelisting them in `.gitignore`