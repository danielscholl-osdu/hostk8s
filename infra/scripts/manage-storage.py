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
HostK8s Storage Contract Management

Processes storage contracts to create and manage persistent storage for stacks.
Similar to manage-secrets.py but for storage resources.

Usage:
  python manage-storage.py setup <stack-name>    # Create storage for stack
  python manage-storage.py cleanup <stack-name>  # Remove storage for stack
  python manage-storage.py list [stack-name]     # List storage contracts
"""

import sys
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Optional

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError,
    load_yaml_file, write_yaml_file, get_env
)


class StorageManager:
    """Manages storage contracts and Kubernetes storage resources."""

    def __init__(self):
        self.project_root = Path(__file__).parent.parent.parent

    def setup_storage(self, stack: str) -> None:
        """Set up storage for a stack based on its storage contract."""
        if not stack:
            logger.error("Stack name required. Usage: manage-storage.py setup <stack-name>")
            sys.exit(1)

        # Check if stack has a storage contract
        contract_file = Path(f"software/stacks/{stack}/hostk8s.storage.yaml")

        if not contract_file.exists():
            logger.debug(f"[Storage] No storage contract found for stack '{stack}' - skipping storage management")
            return

        logger.info(f"[Storage] Processing storage contract for stack '{stack}'")

        try:
            # Load storage contract
            contract = load_yaml_file(contract_file)

            # Validate contract
            if not self.validate_contract(contract, stack):
                sys.exit(1)

            # Process directories in the contract
            directories = contract.get('spec', {}).get('directories', [])

            # Create StorageClasses first
            if not self.create_storage_classes(directories):
                logger.error("Failed to create StorageClasses")
                sys.exit(1)

            success_count = 0
            for directory in directories:
                if self.process_directory(directory, stack):
                    success_count += 1
                else:
                    logger.error(f"Failed to process directory '{directory.get('name', 'unknown')}'")

            if success_count == len(directories):
                logger.success(f"[Storage] Storage setup completed for stack '{stack}'")
                logger.info(f"[Storage] ✅ {success_count} storage directories configured")
                logger.info("[Storage] ✅ Ready for component deployment")
            else:
                logger.error(f"Only {success_count}/{len(directories)} directories processed successfully")
                sys.exit(1)

        except Exception as e:
            logger.error(f"Error processing storage contract: {e}")
            sys.exit(1)

    def validate_contract(self, contract: Dict[str, Any], stack: str) -> bool:
        """Validate storage contract format."""
        try:
            # Check basic structure
            if contract.get('apiVersion') != 'hostk8s.io/v1':
                logger.error("Storage contract must have apiVersion: hostk8s.io/v1")
                return False

            if contract.get('kind') != 'StorageContract':
                logger.error("Storage contract must have kind: StorageContract")
                return False

            metadata = contract.get('metadata', {})
            if metadata.get('name') != stack:
                logger.error(f"Storage contract metadata.name must match stack name '{stack}'")
                return False

            # Check directories
            directories = contract.get('spec', {}).get('directories', [])
            if not directories:
                logger.error("Storage contract must define at least one directory")
                return False

            # Validate each directory
            directory_names = set()
            for i, directory in enumerate(directories):
                if not self.validate_directory(directory, i, directory_names):
                    return False
                directory_names.add(directory['name'])

            return True

        except Exception as e:
            logger.error(f"Error validating storage contract: {e}")
            return False

    def validate_directory(self, directory: Dict[str, Any], index: int, existing_names: set) -> bool:
        """Validate a single directory specification."""
        required_fields = ['name', 'path', 'size', 'accessModes', 'storageClass']

        for field in required_fields:
            if field not in directory:
                logger.error(f"Directory {index}: missing required field '{field}'")
                return False

        # Set defaults for optional fields
        if 'owner' not in directory:
            directory['owner'] = '1000:1000'
        if 'permissions' not in directory:
            directory['permissions'] = '755'

        # Check for duplicate names
        if directory['name'] in existing_names:
            logger.error(f"Directory {index}: duplicate name '{directory['name']}'")
            return False

        # Validate path format
        path = directory['path']
        if not path.startswith('/mnt/pv/'):
            logger.error(f"Directory {index}: path must start with '/mnt/pv/', got '{path}'")
            return False

        # Validate owner format (UID:GID)
        owner = directory['owner']
        if ':' not in owner:
            logger.error(f"Directory {index}: owner must be in 'UID:GID' format, got '{owner}'")
            return False

        try:
            uid, gid = owner.split(':')
            int(uid)
            int(gid)
        except ValueError:
            logger.error(f"Directory {index}: owner must be numeric 'UID:GID', got '{owner}'")
            return False

        # Validate permissions
        permissions = directory['permissions']
        if not permissions.isdigit() or len(permissions) != 3:
            logger.error(f"Directory {index}: permissions must be 3-digit octal, got '{permissions}'")
            return False

        return True

    def create_storage_classes(self, directories: list) -> bool:
        """Create StorageClasses for unique storageClass names in the contract."""
        # Extract unique storage class names
        storage_classes = set()
        for directory in directories:
            storage_classes.add(directory['storageClass'])

        success_count = 0
        for storage_class_name in storage_classes:
            if self.create_storage_class(storage_class_name):
                success_count += 1
            else:
                logger.error(f"Failed to create StorageClass '{storage_class_name}'")

        logger.info(f"[Storage] ✅ {success_count} StorageClasses created")
        return success_count == len(storage_classes)

    def create_storage_class(self, storage_class_name: str) -> bool:
        """Create a single StorageClass."""
        # Check if StorageClass already exists
        result = subprocess.run(['kubectl', 'get', 'storageclass', storage_class_name],
                              capture_output=True, check=False)

        if result.returncode == 0:
            logger.debug(f"[Storage] StorageClass '{storage_class_name}' already exists")
            return True

        # Create StorageClass manifest
        sc_manifest = {
            'apiVersion': 'storage.k8s.io/v1',
            'kind': 'StorageClass',
            'metadata': {
                'name': storage_class_name
            },
            'provisioner': 'kubernetes.io/no-provisioner',
            'reclaimPolicy': 'Retain',
            'volumeBindingMode': 'WaitForFirstConsumer',
            'allowVolumeExpansion': False
        }

        # Apply StorageClass
        import yaml
        process = subprocess.run(['kubectl', 'apply', '-f', '-'],
                               input=yaml.dump(sc_manifest), text=True,
                               capture_output=True, check=False)

        if process.returncode != 0:
            logger.error(f"Failed to create StorageClass '{storage_class_name}': {process.stderr}")
            return False

        logger.debug(f"[Storage] Created StorageClass '{storage_class_name}'")
        return True

    def process_directory(self, directory: Dict[str, Any], stack: str) -> bool:
        """Process a single directory from the storage contract."""
        name = directory['name']
        path = directory['path']

        try:
            # Create PersistentVolume
            if not self.create_persistent_volume(directory, stack):
                return False

            # Set up directory in cluster
            if not self.setup_directory_in_cluster(directory):
                return False

            logger.info(f"[Storage] ✅ Directory '{name}' configured at '{path}'")
            return True

        except Exception as e:
            logger.error(f"[Storage] Failed to process directory '{name}': {e}")
            return False

    def create_persistent_volume(self, directory: Dict[str, Any], stack: str) -> bool:
        """Create PersistentVolume for a directory."""
        name = directory['name']
        path = directory['path']
        size = directory['size']
        access_modes = directory['accessModes']
        storage_class = directory['storageClass']

        # Generate PV name
        pv_name = f"hostk8s-{stack}-{name}-pv"

        # Check if PV already exists
        result = subprocess.run(['kubectl', 'get', 'pv', pv_name],
                              capture_output=True, check=False)

        if result.returncode == 0:
            logger.debug(f"[Storage] PersistentVolume '{pv_name}' already exists")
            return True

        # Create PV manifest
        pv_manifest = {
            'apiVersion': 'v1',
            'kind': 'PersistentVolume',
            'metadata': {
                'name': pv_name,
                'labels': {
                    'hostk8s.stack': stack,
                    'hostk8s.storage.name': name
                }
            },
            'spec': {
                'capacity': {
                    'storage': size
                },
                'accessModes': access_modes,
                'persistentVolumeReclaimPolicy': 'Retain',
                'storageClassName': storage_class,
                'hostPath': {
                    'path': path,
                    'type': 'DirectoryOrCreate'
                }
            }
        }

        # Apply PV
        import yaml
        process = subprocess.run(['kubectl', 'apply', '-f', '-'],
                               input=yaml.dump(pv_manifest), text=True,
                               capture_output=True, check=False)

        if process.returncode != 0:
            logger.error(f"Failed to create PersistentVolume '{pv_name}': {process.stderr}")
            return False

        logger.debug(f"[Storage] Created PersistentVolume '{pv_name}'")
        return True

    def setup_directory_in_cluster(self, directory: Dict[str, Any]) -> bool:
        """Set up directory with proper permissions in the Kind cluster."""
        name = directory['name']
        path = directory['path']
        owner = directory['owner']
        permissions = directory['permissions']

        try:
            cluster_container = "hostk8s-control-plane"

            # Check if Kind cluster is running
            result = subprocess.run(['docker', 'inspect', cluster_container],
                                  capture_output=True, check=False)
            if result.returncode != 0:
                logger.debug(f"[Storage] Kind cluster not ready, skipping directory setup for '{name}'")
                return True

            # Set up directory with proper permissions
            setup_commands = [
                f'mkdir -p {path}',
                f'chown {owner} {path} || true',
                f'chmod {permissions} {path}'
            ]

            for cmd in setup_commands:
                result = subprocess.run(['docker', 'exec', cluster_container, 'sh', '-c', cmd],
                                      capture_output=True, check=False)
                if result.returncode != 0:
                    logger.debug(f"[Storage] Command failed: {cmd} - {result.stderr.decode()}")

            logger.debug(f"[Storage] Directory permissions configured for '{name}': {owner} {permissions}")
            return True

        except Exception as e:
            logger.error(f"[Storage] Failed to setup directory '{name}': {e}")
            return False

    def cleanup_storage(self, stack: str) -> None:
        """Clean up storage for a stack."""
        if not stack:
            logger.error("Stack name required. Usage: manage-storage.py cleanup <stack-name>")
            sys.exit(1)

        logger.info(f"[Storage] Cleaning up storage for stack '{stack}'")

        try:
            # Remove PersistentVolumes for this stack
            result = subprocess.run(['kubectl', 'get', 'pv', '-l', f'hostk8s.stack={stack}', '-o', 'name'],
                                  capture_output=True, text=True, check=False)

            if result.returncode == 0 and result.stdout.strip():
                pv_names = result.stdout.strip().split('\n')
                for pv_name in pv_names:
                    subprocess.run(['kubectl', 'delete', pv_name], check=False)
                logger.info(f"[Storage] Removed {len(pv_names)} PersistentVolumes")

            # Clean up directories in cluster (optional - data is preserved)
            self.cleanup_directories_in_cluster(stack)

            logger.success(f"[Storage] Storage cleanup completed for stack '{stack}'")

        except Exception as e:
            logger.error(f"Error cleaning up storage: {e}")
            sys.exit(1)

    def cleanup_directories_in_cluster(self, stack: str) -> None:
        """Clean up directories in the Kind cluster (preserves data)."""
        try:
            # Load storage contract to find directories
            contract_file = Path(f"software/stacks/{stack}/hostk8s.storage.yaml")
            if not contract_file.exists():
                return

            contract = load_yaml_file(contract_file)
            directories = contract.get('spec', {}).get('directories', [])

            cluster_container = "hostk8s-control-plane"

            for directory in directories:
                path = directory['path']
                # Note: We don't actually delete the data, just clean up permissions
                # Data preservation is important for stack redeployment
                logger.debug(f"[Storage] Directory preserved: {path}")

        except Exception as e:
            logger.debug(f"[Storage] Directory cleanup warning: {e}")

    def list_storage(self, stack: Optional[str] = None) -> None:
        """List storage contracts and resources."""
        logger.info("[Storage] Storage Contract Summary")

        if stack:
            stacks = [stack]
        else:
            # Find all stacks with storage contracts
            stacks = []
            stacks_dir = Path("software/stacks")
            if stacks_dir.exists():
                for stack_dir in stacks_dir.iterdir():
                    if stack_dir.is_dir() and (stack_dir / "hostk8s.storage.yaml").exists():
                        stacks.append(stack_dir.name)

        for stack_name in stacks:
            self.list_stack_storage(stack_name)

    def list_stack_storage(self, stack: str) -> None:
        """List storage for a specific stack."""
        try:
            contract_file = Path(f"software/stacks/{stack}/hostk8s.storage.yaml")
            if not contract_file.exists():
                logger.info(f"[Storage] Stack '{stack}': No storage contract")
                return

            contract = load_yaml_file(contract_file)
            directories = contract.get('spec', {}).get('directories', [])

            logger.info(f"[Storage] Stack '{stack}': {len(directories)} directories")

            for directory in directories:
                name = directory['name']
                size = directory['size']
                path = directory['path']

                # Check if PV exists
                pv_name = f"hostk8s-{stack}-{name}-pv"
                result = subprocess.run(['kubectl', 'get', 'pv', pv_name],
                                      capture_output=True, check=False)
                status = "✅ Ready" if result.returncode == 0 else "❌ Missing"

                logger.info(f"  {name}: {size} at {path} - {status}")

        except Exception as e:
            logger.error(f"Error listing storage for stack '{stack}': {e}")


def main():
    """Main entry point for storage management."""
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    command = sys.argv[1]
    sm = StorageManager()

    if command == "setup":
        if len(sys.argv) < 3:
            logger.error("Stack name required for setup command")
            sys.exit(1)
        sm.setup_storage(sys.argv[2])

    elif command == "cleanup":
        if len(sys.argv) < 3:
            logger.error("Stack name required for cleanup command")
            sys.exit(1)
        sm.cleanup_storage(sys.argv[2])

    elif command == "list":
        stack = sys.argv[2] if len(sys.argv) > 2 else None
        sm.list_storage(stack)

    else:
        logger.error(f"Unknown command: {command}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
