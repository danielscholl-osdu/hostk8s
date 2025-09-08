#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "rich>=13.0.0",
#     "pyyaml>=6.0",
#     "requests>=2.28.0",
# ]
# ///

"""
HostK8s Cluster Restart Script (Python Implementation)

Quick development cycle for host-mode Kind clusters.
Stops the existing cluster and starts a fresh one.

Environment variables:
  SOFTWARE_STACK - Optional software stack to deploy (e.g., "sample")
  CLUSTER_NAME   - Cluster name (defaults to "hostk8s")
  FLUX_ENABLED   - Enable GitOps deployment (defaults based on SOFTWARE_STACK)
"""

import os
import sys
import subprocess
from pathlib import Path
from typing import Optional

# Import common utilities
from hostk8s_common import (
    logger, get_env, load_environment, run_kubectl
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


def cleanup_on_failure(cluster_name: str) -> None:
    """Cleanup function for partial failures."""
    logger.debug("Cleaning up after restart failure...")
    # If cluster-up fails, we're in an inconsistent state
    # Try to clean up but don't fail if cleanup fails
    try:
        run_command(['kind', 'delete', 'cluster', '--name', cluster_name], check=False)
    except Exception:
        pass

    try:
        config_path = Path("data/kubeconfig/config")
        if config_path.exists():
            config_path.unlink()
    except Exception:
        pass


def cluster_exists(cluster_name: str) -> bool:
    """Check if a Kind cluster exists."""
    try:
        result = run_command(['kind', 'get', 'clusters'], capture_output=True)
        clusters = result.stdout.strip().split('\n') if result.stdout else []
        return cluster_name in clusters
    except Exception:
        return False


def validate_cluster_access() -> bool:
    """Validate cluster is accessible via kubectl."""
    try:
        result = run_kubectl(['cluster-info'], check=False, capture_output=True)
        return result.returncode == 0
    except Exception:
        return False


def run_script(script_name: str) -> bool:
    """Run a script (Python or shell) from the scripts directory."""
    script_dir = Path(__file__).parent.parent  # Go up from python/ to scripts/

    # Try Python script first
    python_script = script_dir / "python" / f"{script_name}.py"
    if python_script.exists():
        logger.debug(f"Running Python script: {python_script}")
        result = run_command(['uv', 'run', str(python_script)], check=False)
        return result.returncode == 0

    # Fall back to shell script
    shell_script = script_dir / f"{script_name}.sh"
    if shell_script.exists():
        logger.debug(f"Running shell script: {shell_script}")
        result = run_command([str(shell_script)], check=False)
        return result.returncode == 0

    logger.error(f"Script not found: {script_name}")
    return False


def main():
    """Main entry point."""
    # Load environment
    load_environment()

    # Get configuration from environment
    cluster_name = get_env('CLUSTER_NAME', 'hostk8s')
    software_stack = get_env('SOFTWARE_STACK', '')
    flux_enabled = get_env('FLUX_ENABLED', 'auto')

    logger.info("Starting HostK8s cluster restart...")

    # Show configuration for debugging
    logger.debug("Cluster configuration:")
    logger.debug(f"  Cluster Name: {cluster_name}")
    if software_stack:
        logger.debug(f"  Software Stack: {software_stack}")
        logger.debug(f"  Flux Enabled: {flux_enabled}")
    else:
        logger.debug("  Software Stack: none")

    # Stop existing cluster with error handling
    logger.info("Stopping existing cluster...")
    if not run_script("cluster-down"):
        logger.error("Failed to stop cluster")
        sys.exit(1)

    # Validate cluster was actually stopped
    if cluster_exists(cluster_name):
        logger.error(f"Cluster '{cluster_name}' still exists after shutdown")
        sys.exit(1)

    # Start fresh cluster with error handling
    logger.info("Starting fresh cluster...")
    if not run_script("cluster-up"):
        logger.error("Failed to start cluster")
        cleanup_on_failure(cluster_name)
        sys.exit(1)

    # Validate cluster is actually running
    if not validate_cluster_access():
        logger.error("Cluster started but not accessible via kubectl")
        cleanup_on_failure(cluster_name)
        sys.exit(1)

    logger.success("Cluster restart complete!")
    logger.info(f"Cluster '{cluster_name}' is ready for development")

    if software_stack:
        logger.info(f"Software stack '{software_stack}' has been deployed")
        if flux_enabled == "true":
            logger.info("GitOps is enabled - changes will sync automatically")


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        logger.warn("Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        # Try cleanup on any unexpected error
        cluster_name = get_env('CLUSTER_NAME', 'hostk8s')
        cleanup_on_failure(cluster_name)
        sys.exit(1)
