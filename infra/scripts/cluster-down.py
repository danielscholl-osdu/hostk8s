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
HostK8s Cluster Down Script (Python Implementation)

Stops and removes the HostK8s Kind cluster and associated resources.
Preserves kubeconfig for 'make start' (use 'make clean' for complete removal).
"""

import sys
import subprocess
from typing import Optional

# Import common utilities
from hostk8s_common import (
    logger, get_env, load_environment
)


def run_command(cmd: list, check: bool = True, capture_output: bool = False) -> subprocess.CompletedProcess:
    """Run a command with optional output capture."""
    if capture_output:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    else:
        result = subprocess.run(cmd, check=False)

    if check and result.returncode != 0:
        raise subprocess.CalledProcessError(result.returncode, cmd)

    return result


def cluster_exists(cluster_name: str) -> bool:
    """Check if a Kind cluster exists."""
    try:
        result = run_command(['kind', 'get', 'clusters'], capture_output=True)
        clusters = result.stdout.strip().split('\n') if result.stdout else []
        return cluster_name in clusters
    except Exception:
        return False


def delete_cluster(cluster_name: str) -> None:
    """Delete the Kind cluster."""
    logger.info(f"[Cluster] Deleting Kind cluster '[cyan]{cluster_name}[/cyan]'")
    try:
        run_command(['kind', 'delete', 'cluster', '--name', cluster_name], capture_output=True)
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to delete cluster: {e}")
        sys.exit(1)


def remove_registry_container(registry_name: str = "hostk8s-registry") -> None:
    """Remove the registry container if it exists."""
    try:
        # Check if container exists
        result = run_command(['docker', 'inspect', registry_name],
                            check=False, capture_output=True)
        if result.returncode == 0:
            logger.info(f"[Cluster] Removing registry container '[cyan]{registry_name}[/cyan]'")
            run_command(['docker', 'rm', '-f', registry_name],
                       check=False, capture_output=True)
            logger.info("[Cluster] Registry container removed")
    except Exception as e:
        # Ignore errors - container might not exist
        pass


def main() -> None:
    """Main entry point."""
    # Load environment
    load_environment()

    # Get cluster name from environment
    cluster_name = get_env('CLUSTER_NAME', 'hostk8s')

    logger.info(f"[Script 🐍] Running script: [cyan]cluster-down.py[/cyan]")
    logger.info(f"[Cluster] Stopping HostK8s cluster")

    # Check if cluster exists
    if not cluster_exists(cluster_name):
        logger.warn(f"[Cluster] Cluster '[cyan]{cluster_name}[/cyan]' does not exist")
        sys.exit(0)

    # Delete the cluster
    delete_cluster(cluster_name)

    # Clean up registry container if it exists
    remove_registry_container()

    # Note: Preserving kubeconfig for 'make start' (use 'make clean' for complete removal)

    logger.success(f"[Cluster] Cluster '[cyan]{cluster_name}[/cyan]' deleted successfully")


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        logger.warn("Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)
