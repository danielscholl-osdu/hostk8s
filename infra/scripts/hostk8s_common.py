#!/usr/bin/env -S uv run
# -*- coding: utf-8 -*-
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "pyyaml>=6.0.2",
#     "rich>=14.1.0",
#     "requests>=2.32.5"
# ]
# ///

"""
HostK8s Python Common Module
Replaces the functionality of common.sh and common.ps1 with unified Python implementation.
"""

import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, Any, List, Union

import requests
import yaml
from rich.console import Console
from rich.text import Text


class HostK8sLogger:
    """
    Logging system matching the shell script output format with colors and timestamps.
    Handles LOG_LEVEL and QUIET environment variables just like the shell versions.
    """

    def __init__(self):
        # Use Rich's modern Windows console handling for proper Unicode support
        # This works cross-platform - Rich handles the differences internally
        self.console = Console(legacy_windows=False)
        self.console_err = Console(stderr=True, legacy_windows=False)
        self.log_level = os.getenv('LOG_LEVEL', 'debug').lower()
        self.quiet = os.getenv('QUIET', 'false').lower() == 'true'

    def _get_timestamp(self) -> str:
        """Get formatted timestamp matching shell script format."""
        return datetime.now().strftime('%H:%M:%S')

    def debug(self, message: str):
        """Log debug message (only shown if LOG_LEVEL != 'info')."""
        if self.log_level != 'info':
            timestamp = self._get_timestamp()
            self.console.print(f"[green][{timestamp}][/green] {message}")

    def info(self, message: str):
        """Log info message."""
        timestamp = self._get_timestamp()
        self.console.print(f"[blue][{timestamp}][/blue] {message}")

    def success(self, message: str):
        """Log success message (same as info but semantically different)."""
        timestamp = self._get_timestamp()
        self.console.print(f"[blue][{timestamp}][/blue] {message}")

    def warn(self, message: str):
        """Log warning message."""
        timestamp = self._get_timestamp()
        if self.quiet:
            self.console.print(f"[yellow][{timestamp}] WARNING:[/yellow] {message}")
        else:
            self.console.print(f"[yellow][{timestamp}] ![/yellow] {message}")

    def error(self, message: str):
        """Log error message to stderr."""
        timestamp = self._get_timestamp()
        if self.quiet:
            self.console_err.print(f"[red][{timestamp}] ERROR:[/red] {message}")
        else:
            self.console_err.print(f"[red][{timestamp}] ❌[/red] {message}")

    def section_start(self):
        """Log section separator."""
        self.console.print("─" * 60, style="dim")

    def status(self, label: str, value: str):
        """Log status with label and value (matching shell script format)."""
        self.console.print(f"  {label}: ", end="")
        self.console.print(value, style="cyan")


# Global logger instance
logger = HostK8sLogger()


class HostK8sError(Exception):
    """Base exception for HostK8s operations."""
    pass


class KubectlError(HostK8sError):
    """Exception raised when kubectl operations fail."""
    pass


class FluxError(HostK8sError):
    """Exception raised when flux operations fail."""
    pass


class HelmError(HostK8sError):
    """Exception raised when helm operations fail."""
    pass


def detect_kubeconfig() -> str:
    """
    Detect kubeconfig path following HostK8s conventions.
    Matches the logic from common.sh detect_kubeconfig function.
    """
    # Check KUBECONFIG environment variable first
    if kubeconfig := os.getenv('KUBECONFIG'):
        return kubeconfig

    # Check for container mode
    container_path = Path('/kubeconfig/config')
    if container_path.exists():
        logger.info(f"Using container kubeconfig: {container_path}")
        return str(container_path)

    # Check for host mode
    host_path = Path(os.getcwd()) / 'data' / 'kubeconfig' / 'config'
    if host_path.exists():
        logger.info(f"Using host-mode kubeconfig: {host_path}")
        return str(host_path)

    raise HostK8sError("No kubeconfig found. Ensure cluster is running.")


def run_kubectl(args: List[str], check: bool = True, capture_output: bool = True) -> subprocess.CompletedProcess:
    """
    Run kubectl command with proper error handling and KUBECONFIG setup.

    Args:
        args: kubectl command arguments (without 'kubectl')
        check: Whether to raise exception on non-zero exit code
        capture_output: Whether to capture stdout/stderr

    Returns:
        CompletedProcess result

    Raises:
        KubectlError: If command fails and check=True
    """
    kubeconfig = detect_kubeconfig()
    env = os.environ.copy()
    env['KUBECONFIG'] = kubeconfig

    cmd = ['kubectl'] + args

    try:
        result = subprocess.run(
            cmd,
            env=env,
            capture_output=capture_output,
            text=True,
            check=False  # We handle errors manually for better messages
        )

        if check and result.returncode != 0:
            logger.error(f"kubectl command failed: {' '.join(cmd)}")
            if result.stderr:
                logger.error(f"Error output: {result.stderr.strip()}")
            raise KubectlError(f"kubectl failed with exit code {result.returncode}")

        return result

    except FileNotFoundError:
        raise KubectlError("kubectl not found. Install kubectl first with 'make install'")


def run_flux(args: List[str], check: bool = True, capture_output: bool = True) -> subprocess.CompletedProcess:
    """
    Run flux command with proper error handling and KUBECONFIG setup.

    Args:
        args: flux command arguments (without 'flux')
        check: Whether to raise exception on non-zero exit code
        capture_output: Whether to capture stdout/stderr

    Returns:
        CompletedProcess result

    Raises:
        FluxError: If command fails and check=True
    """
    kubeconfig = detect_kubeconfig()
    env = os.environ.copy()
    env['KUBECONFIG'] = kubeconfig

    cmd = ['flux'] + args

    try:
        result = subprocess.run(
            cmd,
            env=env,
            capture_output=capture_output,
            text=True,
            check=False  # We handle errors manually for better messages
        )

        if check and result.returncode != 0:
            logger.error(f"flux command failed: {' '.join(cmd)}")
            if result.stderr:
                logger.error(f"Error output: {result.stderr.strip()}")
            raise FluxError(f"flux failed with exit code {result.returncode}")

        return result

    except FileNotFoundError:
        raise FluxError("flux CLI not found. Install flux first with 'make install'")


def has_flux() -> bool:
    """Check if Flux is installed in the cluster (matches shell script logic)."""
    try:
        result = run_kubectl(['get', 'deployment', '-n', 'flux-system', 'source-controller'],
                           check=False, capture_output=True)
        return result.returncode == 0
    except (KubectlError, HostK8sError):
        return False


def has_flux_cli() -> bool:
    """Check if flux CLI is available."""
    try:
        result = subprocess.run(['flux', 'version', '--client'],
                              capture_output=True, check=False)
        return result.returncode == 0
    except FileNotFoundError:
        return False


def has_ingress_controller() -> bool:
    """Check if NGINX Ingress Controller is installed in the cluster."""
    try:
        result = run_kubectl(['get', 'deployment', '-n', 'hostk8s',
                            '-l', 'app.kubernetes.io/name=ingress-nginx'],
                           check=False, capture_output=True)
        return result.returncode == 0 and result.stdout.strip() != ''
    except (KubectlError, HostK8sError):
        return False


def load_env_file(env_file: str = '.env') -> Dict[str, str]:
    """
    Load environment variables from .env file (similar to shell script logic).

    Args:
        env_file: Path to environment file

    Returns:
        Dictionary of environment variables
    """
    env_vars = {}
    env_path = Path(env_file)

    if env_path.exists():
        with open(env_path, 'r') as f:
            for line in f:
                line = line.strip()
                # Skip comments and empty lines
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()  # Strip whitespace from key
                    # Remove inline comments (everything after #)
                    if '#' in value:
                        value = value.split('#', 1)[0]
                    # Strip whitespace and remove quotes if present
                    value = value.strip().strip('\'"')
                    env_vars[key] = value
                    # Only set if not already in environment (preserve Make exports)
                    if key not in os.environ:
                        os.environ[key] = value

    return env_vars


def get_env(key: str, default: str = '') -> str:
    """Get environment variable with default value."""
    return os.environ.get(key, default)


def load_environment() -> None:
    """Load environment configuration from .env file (convenience function)."""
    # Find project root (3 levels up from this file)
    script_path = Path(__file__)
    project_root = script_path.parent.parent.parent
    env_file = project_root / '.env'

    # Load from project root .env file
    if env_file.exists():
        load_env_file(str(env_file))
    else:
        # Fallback to current directory if project structure is different
        load_env_file('.env')


def write_yaml_file(data: Dict[str, Any], file_path: Union[str, Path]) -> None:
    """
    Write data to YAML file with proper formatting.

    Args:
        data: Data to write
        file_path: Path to output file
    """
    path = Path(file_path)
    path.parent.mkdir(parents=True, exist_ok=True)

    with open(path, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)


def load_yaml_file(file_path: Union[str, Path]) -> Dict[str, Any]:
    """
    Load YAML file and return parsed data.

    Args:
        file_path: Path to YAML file

    Returns:
        Parsed YAML data

    Raises:
        FileNotFoundError: If file doesn't exist
        yaml.YAMLError: If YAML is invalid
    """
    with open(file_path, 'r') as f:
        return yaml.safe_load(f)


def generate_password(length: int = 32) -> str:
    """
    Generate a random password (matches shell script logic).

    Args:
        length: Password length

    Returns:
        Generated password
    """
    import secrets
    import string

    # Use same character set as shell script
    chars = string.ascii_letters + string.digits + "!@#$%^&*"
    return ''.join(secrets.choice(chars) for _ in range(length))


def generate_token(length: int = 32) -> str:
    """
    Generate an alphanumeric token (matches shell script logic).

    Args:
        length: Token length

    Returns:
        Generated token
    """
    import secrets
    import string

    # Alphanumeric only
    chars = string.ascii_letters + string.digits
    return ''.join(secrets.choice(chars) for _ in range(length))


def generate_hex(length: int = 32) -> str:
    """
    Generate a hex string (matches shell script logic).

    Args:
        length: Hex string length

    Returns:
        Generated hex string
    """
    import secrets

    return secrets.token_hex(length // 2)


def vault_api_call(method: str, path: str, data: Optional[Dict] = None,
                  vault_addr: str = None, vault_token: str = None) -> requests.Response:
    """
    Make API call to Vault server.

    Args:
        method: HTTP method (GET, POST, etc.)
        path: API path (without /v1/ prefix)
        data: Request data for POST/PUT
        vault_addr: Vault address (defaults to env var or localhost:8080)
        vault_token: Vault token (defaults to env var or 'hostk8s')

    Returns:
        Response object
    """
    vault_addr = vault_addr or get_env('VAULT_ADDR', 'http://localhost:8080')
    vault_token = vault_token or get_env('VAULT_TOKEN', 'hostk8s')

    url = f"{vault_addr}/v1/{path}"
    headers = {'X-Vault-Token': vault_token}

    if method.upper() in ['POST', 'PUT'] and data:
        headers['Content-Type'] = 'application/json'
        response = requests.request(method, url, headers=headers, json=data)
    else:
        response = requests.request(method, url, headers=headers)

    return response


def list_available_apps() -> List[str]:
    """List available applications in software/apps/."""
    apps = set()
    apps_dir = Path('software/apps')

    if not apps_dir.exists():
        return []

    # Find Helm charts
    for chart_file in apps_dir.rglob('Chart.yaml'):
        app_name = chart_file.parent.name
        apps.add(app_name)

    # Find Kustomization apps
    for kust_file in apps_dir.rglob('kustomization.yaml'):
        app_name = kust_file.parent.name
        apps.add(app_name)

    # Find Legacy app.yaml apps
    for app_file in apps_dir.rglob('app.yaml'):
        app_name = app_file.parent.name
        apps.add(app_name)

    return sorted(list(apps))


def validate_app_exists(app_name: str) -> bool:
    """Validate that an application exists."""
    app_dir = Path(f'software/apps/{app_name}')

    if not app_dir.exists():
        return False

    # Check for Helm chart
    if (app_dir / 'Chart.yaml').exists():
        return True

    # Check for Kustomization app
    if (app_dir / 'kustomization.yaml').exists():
        return True

    # Check for Legacy app.yaml
    if (app_dir / 'app.yaml').exists():
        return True

    return False


def get_app_deployment_type(app_name: str) -> str:
    """Get deployment type for an application."""
    app_dir = Path(f'software/apps/{app_name}')

    if (app_dir / 'Chart.yaml').exists():
        return 'helm'
    elif (app_dir / 'kustomization.yaml').exists():
        return 'kustomization'
    elif (app_dir / 'app.yaml').exists():
        return 'legacy'
    else:
        return 'none'


def run_helm(args: List[str], check: bool = True, capture_output: bool = True) -> subprocess.CompletedProcess:
    """
    Run helm command with proper error handling.

    Args:
        args: helm command arguments (without 'helm')
        check: Whether to raise exception on non-zero exit code
        capture_output: Whether to capture stdout/stderr

    Returns:
        CompletedProcess result

    Raises:
        HostK8sError: If command fails and check=True
    """
    cmd = ['helm'] + args

    try:
        result = subprocess.run(
            cmd,
            capture_output=capture_output,
            text=True,
            check=False  # We handle errors manually for better messages
        )

        if check and result.returncode != 0:
            logger.error(f"helm command failed: {' '.join(cmd)}")
            if result.stderr:
                logger.error(f"Error output: {result.stderr.strip()}")
            raise HostK8sError(f"helm failed with exit code {result.returncode}")

        return result

    except FileNotFoundError:
        raise HostK8sError("helm not found. Install helm first with 'make install'")


def check_cluster_running() -> None:
    """Check if cluster is running and accessible.

    Raises:
        HostK8sError: If cluster is not accessible
    """
    try:
        # Try to get cluster info to verify cluster is running
        result = subprocess.run(['kubectl', 'cluster-info'],
                              capture_output=True, text=True, check=False)
        if result.returncode != 0:
            raise HostK8sError("Cluster not running. Run 'make start' to start the cluster.")
    except FileNotFoundError:
        raise HostK8sError("kubectl command not found. Ensure kubectl is installed and in PATH.")


# Export commonly used items
__all__ = [
    'logger', 'HostK8sError', 'KubectlError', 'FluxError', 'HelmError',
    'detect_kubeconfig', 'run_kubectl', 'run_flux', 'run_helm',
    'has_flux', 'has_flux_cli',
    'load_env_file', 'load_environment', 'get_env',
    'write_yaml_file', 'load_yaml_file',
    'generate_password', 'generate_token', 'generate_hex',
    'vault_api_call',
    'list_available_apps', 'validate_app_exists', 'get_app_deployment_type',
    'check_cluster_running'
]
