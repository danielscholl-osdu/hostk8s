#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "pyyaml>=6.0.2",
#     "rich>=14.1.0",
#     "requests>=2.32.5"
# ]
# ///

"""
HostK8s Vault-Enhanced Secret Management Script (Python Implementation)

Reads hostk8s.secrets.yaml contracts and:
1. Populates Vault with secret values
2. Generates external-secrets.yaml for GitOps deployment

This replaces the shell script version with improved error handling,
better YAML processing, and more maintainable code structure.
"""

import argparse
import json
import sys
import uuid
from pathlib import Path
from typing import Dict, List, Any, Optional

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError,
    load_yaml_file, write_yaml_file, get_env,
    generate_password, generate_token, generate_hex,
    vault_api_call
)


class SecretManager:
    """Manages HostK8s secrets with Vault integration."""

    def __init__(self):
        self.vault_addr = get_env('VAULT_ADDR', 'http://localhost:8080')
        self.vault_token = get_env('VAULT_TOKEN', 'hostk8s')

    def check_vault_connectivity(self) -> bool:
        """Check if Vault is accessible."""
        try:
            response = vault_api_call('GET', 'sys/health',
                                    vault_addr=self.vault_addr,
                                    vault_token=self.vault_token)
            return response.status_code in [200, 429]  # 429 is also valid (sealed)
        except Exception as e:
            logger.error(f"Cannot connect to Vault at {self.vault_addr}")
            logger.error(f"Make sure Vault is running and VAULT_ADDR/VAULT_TOKEN are set correctly")
            logger.error(f"Connection error: {e}")
            return False

    def vault_secret_exists(self, path: str) -> bool:
        """Check if secret already exists in Vault."""
        try:
            response = vault_api_call('GET', f'secret/data/{path}',
                                    vault_addr=self.vault_addr,
                                    vault_token=self.vault_token)
            # Check if response contains data (secret exists)
            if response.status_code == 200:
                data = response.json()
                return 'data' in data and data['data'] is not None
            return False
        except Exception:
            return False

    def store_vault_secret(self, path: str, secret_data: Dict[str, str]) -> bool:
        """Store secret in Vault KV v2."""
        try:
            logger.debug(f"[Secrets] Storing secret in Vault: secret/{path}")

            response = vault_api_call('POST', f'secret/data/{path}',
                                    data={'data': secret_data},
                                    vault_addr=self.vault_addr,
                                    vault_token=self.vault_token)

            if response.status_code in [200, 201]:
                return True
            else:
                logger.error(f"Failed to store secret {path}: HTTP {response.status_code}")
                if response.text:
                    logger.error(f"Response: {response.text}")
                return False

        except Exception as e:
            logger.error(f"Failed to store secret {path}: {e}")
            return False

    def remove_vault_secret(self, path: str) -> bool:
        """Remove secret from Vault (both data and metadata)."""
        try:
            logger.debug(f"Removing Vault secret: secret/{path}")

            # Delete secret data
            data_response = vault_api_call('DELETE', f'secret/data/{path}',
                                         vault_addr=self.vault_addr,
                                         vault_token=self.vault_token)

            # Delete secret metadata
            metadata_response = vault_api_call('DELETE', f'secret/metadata/{path}',
                                             vault_addr=self.vault_addr,
                                             vault_token=self.vault_token)

            return True  # Don't fail on deletion errors (secret may not exist)

        except Exception as e:
            logger.debug(f"Error removing secret {path}: {e}")
            return True  # Continue anyway

    def list_vault_secrets(self, base_path: str = '') -> List[str]:
        """List secrets in Vault."""
        try:
            if base_path:
                path = f'secret/metadata/{base_path}?list=true'
            else:
                path = 'secret/metadata?list=true'

            response = vault_api_call('GET', path,
                                    vault_addr=self.vault_addr,
                                    vault_token=self.vault_token)

            if response.status_code == 200:
                data = response.json()
                return data.get('data', {}).get('keys', [])
            else:
                return []

        except Exception:
            return []

    def generate_value(self, generate_type: str, length: int = 32) -> str:
        """Generate secret value based on type."""
        if generate_type == 'password':
            return generate_password(length)
        elif generate_type == 'token':
            return generate_token(length)
        elif generate_type == 'hex':
            return generate_hex(length)
        elif generate_type == 'uuid':
            return str(uuid.uuid4()).lower()
        else:
            # Default to token for unknown types
            return generate_token(length)

    def process_secret_data(self, secret_name: str, namespace: str,
                          data_list: List[Dict[str, Any]], stack: str,
                          external_secrets_file: Path) -> bool:
        """Process a single secret from the contract."""
        vault_path = f"{stack}/{namespace}/{secret_name}"

        # Check if secret already exists in Vault (idempotency)
        if self.vault_secret_exists(vault_path):
            logger.info(f"[Secrets] Secret '{secret_name}' already exists in Vault, skipping Vault population")
        else:
            logger.info(f"[Secrets] Populating Vault with secret '{secret_name}' for namespace '{namespace}'")

            # Build secret data for Vault
            vault_data = {}

            for data_entry in data_list:
                key = data_entry['key']
                value = data_entry.get('value')
                generate_type = data_entry.get('generate')
                length = data_entry.get('length', 32)

                if value is not None:
                    # Static value
                    vault_data[key] = value
                elif generate_type:
                    # Generated value
                    vault_data[key] = self.generate_value(generate_type, length)
                else:
                    logger.warn(f"No value or generate type specified for key '{key}' in secret '{secret_name}'")
                    continue

            # Store in Vault
            if not self.store_vault_secret(vault_path, vault_data):
                logger.error("Failed to store secret in Vault")
                return False

        # Always generate ExternalSecret manifest
        logger.debug(f"[Secrets] Generating ExternalSecret manifest for '{secret_name}'")
        self.generate_external_secret_manifest(secret_name, namespace, data_list, stack, external_secrets_file)
        return True

    def generate_external_secret_manifest(self, secret_name: str, namespace: str,
                                        data_list: List[Dict[str, Any]], stack: str,
                                        external_secrets_file: Path) -> None:
        """Generate ExternalSecret manifest and append to file."""
        vault_path = f"{stack}/{namespace}/{secret_name}"

        manifest = {
            'apiVersion': 'external-secrets.io/v1',
            'kind': 'ExternalSecret',
            'metadata': {
                'name': secret_name,
                'namespace': namespace,
                'labels': {
                    'hostk8s.io/managed': 'true',
                    'hostk8s.io/contract': stack
                }
            },
            'spec': {
                'refreshInterval': '10s',
                'secretStoreRef': {
                    'name': 'vault-backend',
                    'kind': 'ClusterSecretStore'
                },
                'target': {
                    'name': secret_name,
                    'creationPolicy': 'Owner'
                },
                'data': []
            }
        }

        # Add data mappings
        for data_entry in data_list:
            key = data_entry['key']
            manifest['spec']['data'].append({
                'secretKey': key,
                'remoteRef': {
                    'key': vault_path,
                    'property': key
                }
            })

        # Append to file
        with open(external_secrets_file, 'a') as f:
            f.write('\n---\n')
            f.write('# ExternalSecret for ' + secret_name + '\n')
            import yaml
            yaml.dump(manifest, f, default_flow_style=False, sort_keys=False)


def add_secrets(stack: str) -> None:
    """Add secrets from contract (enhanced for Vault)."""
    if not stack:
        logger.error("Stack name required. Usage: manage-secrets.py add <stack-name>")
        sys.exit(1)

    sm = SecretManager()

    # Check Vault connectivity
    if not sm.check_vault_connectivity():
        sys.exit(1)

    contract_file = Path(f"software/stacks/{stack}/hostk8s.secrets.yaml")
    external_secrets_file = Path(f"software/stacks/{stack}/manifests/external-secrets.yaml")

    if not contract_file.exists():
        logger.info(f"[Secrets] No secret contract found for stack '{stack}'")
        return

    logger.info(f"[Secrets] Processing secrets for stack '{stack}' (Vault + ExternalSecrets)")

    try:
        # Load secret contract
        contract = load_yaml_file(contract_file)

        # Ensure manifests directory exists
        external_secrets_file.parent.mkdir(parents=True, exist_ok=True)

        # Create external-secrets.yaml file with header
        header = f"""# Generated ExternalSecret manifests from hostk8s.secrets.yaml
# This file is auto-generated by manage-secrets.py - safe to commit to Git
# Contains no sensitive data - only Vault path references
# To regenerate: make up {stack}
"""
        with open(external_secrets_file, 'w') as f:
            f.write(header)

        # Process each secret in the contract
        secrets = contract.get('spec', {}).get('secrets', [])

        success_count = 0
        for secret in secrets:
            name = secret['name']
            namespace = secret['namespace']
            data = secret['data']

            if sm.process_secret_data(name, namespace, data, stack, external_secrets_file):
                success_count += 1
            else:
                logger.error(f"Failed to process secret '{name}'")

        if success_count == len(secrets):
            logger.success(f"[Secrets] Secrets processed successfully for stack '{stack}'")
            logger.info("[Secrets] ✅ Vault populated with secret values")
            logger.info(f"[Secrets] ✅ ExternalSecret manifests generated: {external_secrets_file}")
            logger.info("[Secrets] ✅ Ready for GitOps deployment via Flux")
        else:
            logger.error(f"Only {success_count}/{len(secrets)} secrets processed successfully")
            sys.exit(1)

    except Exception as e:
        logger.error(f"Error processing secrets: {e}")
        sys.exit(1)


def remove_secrets(stack: str) -> None:
    """Remove secrets for a stack from Vault."""
    if not stack:
        logger.error("Stack name required. Usage: manage-secrets.py remove <stack-name>")
        sys.exit(1)

    sm = SecretManager()

    # Check Vault connectivity
    if not sm.check_vault_connectivity():
        sys.exit(1)

    logger.info(f"[Secrets] Removing secrets for stack '{stack}' from Vault...")

    contract_file = Path(f"software/stacks/{stack}/hostk8s.secrets.yaml")
    external_secrets_file = Path(f"software/stacks/{stack}/manifests/external-secrets.yaml")

    if not contract_file.exists():
        logger.warn(f"[Secrets] No secret contract found for stack '{stack}'")
        logger.info("[Secrets] Attempting to remove any existing secrets anyway...")

        # Try to remove by pattern: secret/metadata/STACK/*
        namespaces = sm.list_vault_secrets(stack)
        for namespace in namespaces:
            secrets = sm.list_vault_secrets(f"{stack}/{namespace}")
            for secret_name in secrets:
                vault_path = f"{stack}/{namespace}/{secret_name}"
                sm.remove_vault_secret(vault_path)
    else:
        # Process each secret in the contract for removal
        try:
            contract = load_yaml_file(contract_file)
            secrets = contract.get('spec', {}).get('secrets', [])

            for secret in secrets:
                name = secret['name']
                namespace = secret['namespace']
                vault_path = f"{stack}/{namespace}/{name}"

                logger.info(f"[Secrets] Removing secret '{name}' from Vault path: secret/{vault_path}")
                sm.remove_vault_secret(vault_path)

        except Exception as e:
            logger.error(f"Error processing contract file: {e}")

    # Remove external-secrets.yaml file
    if external_secrets_file.exists():
        logger.info(f"[Secrets] Removing ExternalSecret manifests: {external_secrets_file}")
        external_secrets_file.unlink()

    logger.success(f"[Secrets] Secret removal completed for stack '{stack}'")


def list_secrets(stack: Optional[str] = None) -> None:
    """List secrets in Vault."""
    sm = SecretManager()

    # Check Vault connectivity
    if not sm.check_vault_connectivity():
        sys.exit(1)

    logger.info("Listing secrets in Vault...")

    if stack:
        logger.info(f"Filtering for stack: {stack}")
        secrets = sm.list_vault_secrets(stack)
        if not secrets:
            logger.info(f"No secrets found for stack '{stack}'")
            return

        for secret_key in secrets:
            logger.success(f"  {stack}/{secret_key}")
    else:
        secrets = sm.list_vault_secrets()
        if not secrets:
            logger.info("No secrets found in Vault")
            return

        for secret_key in secrets:
            logger.success(f"  {secret_key}")


def show_usage() -> None:
    """Show usage information."""
    print("Usage: manage-secrets.py [COMMAND] <stack-name>")
    print("")
    print("Commands:")
    print("  add <stack>     Add/update secrets in Vault and generate manifests (default)")
    print("  remove <stack>  Remove all secrets for stack from Vault")
    print("  list [stack]    List secrets in Vault (all stacks or specific stack)")
    print("")
    print("Examples:")
    print("  manage-secrets.py add sample-app       # Populate Vault + generate manifests")
    print("  manage-secrets.py remove sample-app    # Clean up Vault secrets")
    print("  manage-secrets.py list                 # List all secrets")
    print("  manage-secrets.py list sample-app      # List secrets for specific stack")


def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(description='HostK8s Secret Management', add_help=False)
    parser.add_argument('command', nargs='?', help='Command: add, remove, list')
    parser.add_argument('stack', nargs='?', help='Stack name')
    parser.add_argument('-h', '--help', action='store_true', help='Show help')

    args = parser.parse_args()

    if args.help or (not args.command):
        show_usage()
        return

    # Handle legacy format: manage-secrets.py <stack> (defaults to add)
    if args.command and args.command not in ['add', 'remove', 'list']:
        # First argument is actually the stack name, command defaults to 'add'
        stack = args.command
        command = 'add'
    else:
        command = args.command
        stack = args.stack

    # Special case for list command without stack
    if command == 'list' and not stack:
        list_secrets()
        return

    # Log script execution
    script_name = Path(__file__).name
    if command == 'add':
        logger.info(f"[Script 🐍] Running script: [cyan]{script_name}[/cyan] [green]add {stack}[/green]")
    elif command == 'remove':
        logger.info(f"[Script 🐍] Running script: [cyan]{script_name}[/cyan] [yellow]remove {stack}[/yellow]")
    else:
        logger.info(f"[Script 🐍] Running script: [cyan]{script_name}[/cyan] [blue]{command} {stack or ''}[/blue]")

    # Execute command
    try:
        if command == 'add':
            add_secrets(stack)
        elif command == 'remove':
            remove_secrets(stack)
        elif command == 'list':
            list_secrets(stack)
        else:
            logger.error(f"Unknown command: {command}")
            show_usage()
            sys.exit(1)

    except KeyboardInterrupt:
        logger.warn("Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
