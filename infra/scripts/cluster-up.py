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
HostK8s Cluster Up Script (Python Implementation)

Starts a new HostK8s Kind cluster with optional addons.
Handles cluster creation, registry setup, and addon deployment.
"""

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional, Dict, Any, List

# Import common utilities
from hostk8s_common import (
    logger, get_env, load_environment, run_kubectl
)


class ClusterSetup:
    """Handles Kind cluster creation and setup."""

    def __init__(self):
        # Load environment
        load_environment()

        # Configuration from environment
        self.cluster_name = get_env('CLUSTER_NAME', 'hostk8s')
        self.k8s_version = get_env('K8S_VERSION', 'v1.34.0')
        self.kubeconfig_path = Path(get_env('KUBECONFIG_PATH', 'data/kubeconfig/config'))
        self.kind_config = get_env('KIND_CONFIG', '')
        self.kind_config_file = None  # Will be set in determine_kind_config

        # Addon flags (strip spaces from env values to handle .env formatting)
        # Support both ENABLE_* and *_ENABLED formats for backward compatibility
        self.metallb_enabled = (get_env('METALLB_ENABLED', 'false').strip().lower() == 'true' or
                               get_env('ENABLE_METALLB', 'false').strip().lower() == 'true')
        # Ingress is enabled by default, check for INGRESS_DISABLED to turn it off
        self.ingress_enabled = not (get_env('INGRESS_DISABLED', 'false').strip().lower() == 'true')
        self.registry_enabled = (get_env('REGISTRY_ENABLED', 'false').strip().lower() == 'true' or
                                get_env('ENABLE_REGISTRY', 'false').strip().lower() == 'true')
        self.metrics_disabled = get_env('METRICS_DISABLED', 'false').strip().lower() == 'true'
        self.vault_enabled = (get_env('VAULT_ENABLED', 'false').strip().lower() == 'true' or
                             get_env('ENABLE_VAULT', 'false').strip().lower() == 'true')
        self.flux_enabled = (get_env('FLUX_ENABLED', 'false').strip().lower() == 'true' or
                            get_env('ENABLE_FLUX', 'false').strip().lower() == 'true')

        # Registry configuration
        self.registry_name = "hostk8s-registry"
        self.registry_port = get_env('REGISTRY_PORT', '5002')  # Use 5002 to avoid conflict with Kind NodePort on 5001

        # Paths
        self.script_dir = Path(__file__).parent  # infra/scripts directory
        self.project_root = self.script_dir.parent.parent

    def check_dependencies(self) -> None:
        """Validate required tools are installed."""
        missing_tools = []

        for tool in ['kind', 'kubectl', 'helm', 'docker']:
            if not shutil.which(tool):
                missing_tools.append(tool)

        if missing_tools:
            logger.error(f"Missing required tools: {', '.join(missing_tools)}")
            logger.error("Run 'make install' to install missing dependencies")
            sys.exit(1)

        # Check if Docker is running
        try:
            subprocess.run(['docker', 'info'], capture_output=True, check=True)
        except subprocess.CalledProcessError:
            logger.error("Docker is not running. Please start Docker Desktop first.")
            sys.exit(1)

    def validate_docker_resources(self) -> None:
        """Validate Docker resource allocation."""
        logger.debug("[Cluster] Checking Docker resource allocation")

        try:
            # Get Docker system info
            result = subprocess.run(['docker', 'system', 'info', '--format', 'json'],
                                  capture_output=True, text=True, check=True)
            docker_info = json.loads(result.stdout)

            # Check memory
            memory_bytes = docker_info.get('MemTotal', 0)
            memory_gb = memory_bytes / (1024 ** 3)

            # Check CPUs
            cpus = docker_info.get('NCPU', 0)

            logger.debug(f"[Cluster] Docker resources: [cyan]{memory_gb:.1f}GB[/cyan] memory, [cyan]{cpus}[/cyan] CPUs")

            # Validate minimum requirements
            if memory_gb < 4:
                logger.warn(f"Docker has only {memory_gb:.1f}GB memory allocated. Recommend 4GB+ for better performance")
                logger.warn("Increase in Docker Desktop -> Settings -> Resources -> Memory")

            if cpus < 2:
                logger.warn(f"Docker has only {cpus} CPUs allocated. Recommend 2+ for better performance")
                logger.warn("Increase in Docker Desktop -> Settings -> Resources -> CPUs")

            # Check available disk space
            stat = shutil.disk_usage(os.getcwd())
            available_gb = stat.free / (1024 ** 3)

            if available_gb < 10:
                logger.warn(f"Low disk space: {available_gb:.1f}GB available. Recommend 10GB+ free space")

        except Exception as e:
            logger.warn("Could not retrieve Docker system information")
            logger.debug(f"Error: {e}")

    def cluster_exists(self) -> bool:
        """Check if the Kind cluster already exists."""
        try:
            result = subprocess.run(['kind', 'get', 'clusters'],
                                  capture_output=True, text=True, check=True)
            return self.cluster_name in result.stdout.strip().split('\n')
        except subprocess.CalledProcessError:
            return False

    def determine_kind_config(self, config_arg: Optional[str] = None) -> Optional[Path]:
        """Determine which Kind configuration file to use."""
        # 1. Check for argument-provided config
        if config_arg:
            # Check for extension config
            extension_config = self.project_root / 'infra' / 'kubernetes' / 'extension' / f'kind-{config_arg}.yaml'
            if extension_config.exists():
                self.kind_config_file = f"extension/kind-{config_arg}.yaml"
                logger.info(f"Using extension config: kind-{config_arg}.yaml")
                return extension_config

            # Check for standard config
            standard_config = self.project_root / 'infra' / 'kubernetes' / f'kind-{config_arg}.yaml'
            if standard_config.exists():
                self.kind_config_file = f"kind-{config_arg}.yaml"
                logger.info(f"Using config: kind-{config_arg}.yaml")
                return standard_config

            logger.warn(f"Config 'kind-{config_arg}.yaml' not found")

        # 2. Check KIND_CONFIG environment variable
        if self.kind_config:
            # Handle different KIND_CONFIG formats
            if self.kind_config.startswith('extension/'):
                # Extension config (format: extension/name)
                extension_name = self.kind_config.replace('extension/', '')
                config_path = self.project_root / 'infra' / 'kubernetes' / f'extension/kind-{extension_name}.yaml'
                self.kind_config_file = f"extension/kind-{extension_name}.yaml"
            elif self.kind_config.endswith('.yaml'):
                # Direct filename
                config_path = self.project_root / 'infra' / 'kubernetes' / self.kind_config
                self.kind_config_file = self.kind_config
            else:
                # Named config (e.g., "default", "minimal", "custom")
                config_path = self.project_root / 'infra' / 'kubernetes' / f'kind-{self.kind_config}.yaml'
                self.kind_config_file = f"kind-{self.kind_config}.yaml"

            if config_path.exists():
                logger.info(f"Using config from KIND_CONFIG: {self.kind_config}")
                return config_path
            else:
                logger.error(f"Kind config '{self.kind_config}' not found (expected: kind-{self.kind_config}.yaml)")
                logger.error("Available configurations:")
                # List available configs
                for conf in sorted((self.project_root / 'infra' / 'kubernetes').glob('kind-*.yaml')):
                    config_name = conf.stem.replace('kind-', '')
                    logger.error(f"  {config_name} ({conf.name})")
                sys.exit(1)

        # 3. Default to kind-config.yaml if it exists
        default_config = self.project_root / 'infra' / 'kubernetes' / 'kind-config.yaml'
        if default_config.exists():
            self.kind_config_file = "kind-config.yaml"
            logger.info("Using default config: kind-config.yaml")
            return default_config

        # 4. Fall back to kind-custom.yaml (matching shell script behavior)
        custom_config = self.project_root / 'infra' / 'kubernetes' / 'kind-custom.yaml'
        if custom_config.exists():
            self.kind_config_file = "kind-custom.yaml"
            return custom_config

        # 5. No config found
        self.kind_config_file = "Kind defaults"
        logger.info("No Kind config file found, using Kind defaults")
        return None

    def create_cluster(self, config_path: Optional[Path] = None) -> None:
        """Create the Kind cluster."""
        logger.info(f"[Cluster] Creating Kind cluster '[cyan]{self.cluster_name}[/cyan]'")

        cmd = ['kind', 'create', 'cluster', '--name', self.cluster_name, '--quiet']

        if config_path:
            cmd.extend(['--config', str(config_path)])

        # Add Kubernetes version
        cmd.extend(['--image', f'kindest/node:{self.k8s_version}'])

        # Add kubeconfig path
        cmd.extend(['--kubeconfig', str(self.kubeconfig_path)])

        try:
            # Create kubeconfig directory if needed
            self.kubeconfig_path.parent.mkdir(parents=True, exist_ok=True)

            # Create cluster
            subprocess.run(cmd, check=True)

        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to create Kind cluster: {e}")
            sys.exit(1)

    def create_persistent_volume(self) -> None:
        """Create Docker volume for universal persistent storage."""
        volume_name = "hostk8s-pv-data"

        try:
            # Check if volume already exists
            result = subprocess.run(['docker', 'volume', 'inspect', volume_name],
                                  capture_output=True, check=False)

            if result.returncode == 0:
                logger.debug(f"[Cluster] Docker volume '{volume_name}' already exists")
            else:
                # Create the volume
                subprocess.run(['docker', 'volume', 'create', volume_name],
                             check=True, capture_output=True)
                logger.info(f"[Cluster] Created Docker volume '{volume_name}'")

            # Set up component directories with proper permissions
            self.setup_component_directories()

        except subprocess.CalledProcessError as e:
            logger.error(f"[Cluster] Failed to create Docker volume: {e}")
            raise RuntimeError(f"Failed to create Docker volume '{volume_name}'")

    def setup_component_directories(self) -> None:
        """Set up universal storage mount point in the Kind cluster."""
        try:
            # Wait for Kind cluster to be ready before setting up directories
            if not hasattr(self, 'cluster_name'):
                return

            cluster_container = f"{self.cluster_name}-control-plane"

            # Check if the Kind cluster container is running
            result = subprocess.run(['docker', 'inspect', cluster_container],
                                  capture_output=True, check=False)
            if result.returncode != 0:
                logger.debug("[Cluster] Kind cluster not ready yet, skipping directory setup")
                return

            # Set up universal storage mount point
            # Storage contracts will handle component-specific directories
            storage_setup = [
                'mkdir -p /mnt/pv',
                'chmod 755 /mnt/pv'  # Standard permissions, components manage their own subdirs
            ]

            for cmd in storage_setup:
                subprocess.run(['docker', 'exec', cluster_container, 'sh', '-c', cmd],
                             capture_output=True, check=False)

            logger.debug("[Cluster] Universal storage mount point configured")

        except Exception as e:
            logger.debug(f"[Cluster] Storage setup warning: {e}")
            # Don't fail cluster startup if storage setup has issues


    def create_registry_config(self) -> Path:
        """Create registry configuration file with CORS settings."""
        config_file = self.project_root / 'data' / 'registry-config.yml'

        if not config_file.exists():
            logger.debug("[Cluster] Creating registry configuration file")
            config_file.parent.mkdir(parents=True, exist_ok=True)

            config_content = """version: 0.1
log:
  fields:
    service: registry
storage:
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    Access-Control-Allow-Origin: ['*']
    Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    Access-Control-Allow-Headers: ['Authorization', 'Accept']
    Access-Control-Max-Age: [1728000]
    Access-Control-Allow-Credentials: [true]
"""
            config_file.write_text(config_content)

        return config_file

    def setup_registry(self) -> None:
        """Setup Docker registry if enabled."""
        if not self.registry_enabled:
            return

        logger.info("[Cluster] Setting up local container registry")

        # Create data directory for registry storage
        registry_data_dir = self.project_root / 'data' / 'registry' / 'docker'
        registry_data_dir.mkdir(parents=True, exist_ok=True)

        # Create Docker volume for universal persistent storage
        self.create_persistent_volume()

        # Create registry config file
        config_file = self.create_registry_config()

        # Check if registry already exists
        try:
            result = subprocess.run(['docker', 'inspect', self.registry_name],
                                  capture_output=True, check=False)
            if result.returncode == 0:
                # Check if it's running
                status_result = subprocess.run(
                    ['docker', 'inspect', '-f', '{{.State.Status}}', self.registry_name],
                    capture_output=True, text=True, check=False
                )
                if status_result.returncode == 0 and status_result.stdout.strip() == 'running':
                    logger.info(f"[Cluster] Registry '{self.registry_name}' already running")
                    self.connect_registry_to_kind()
                    return
                else:
                    logger.info(f"[Cluster] Registry exists but not running, removing")
                    subprocess.run(['docker', 'rm', '-f', self.registry_name],
                                 capture_output=True, check=False)
        except Exception:
            pass

        # Create registry with proper mounts and configuration
        try:
            subprocess.run([
                'docker', 'run', '-d', '--restart=always',
                '-p', f'{self.registry_port}:5000',
                '-v', f'{registry_data_dir}:/var/lib/registry',
                '-v', f'{config_file}:/etc/docker/registry/config.yml',
                '--name', self.registry_name,
                'registry:2'
            ], check=True, capture_output=True)
            logger.info("[Cluster] Registry container created")

            # Connect to kind network
            self.connect_registry_to_kind()

        except subprocess.CalledProcessError as e:
            logger.error(f"[Cluster] Failed to create registry: {e}")

    def connect_registry_to_kind(self) -> None:
        """Connect registry to Kind network."""
        try:
            # Get kind network name
            result = subprocess.run(['docker', 'network', 'ls', '--format', 'json'],
                                  capture_output=True, text=True, check=True)

            kind_network = None
            for line in result.stdout.strip().split('\n'):
                if line:
                    network = json.loads(line)
                    if 'kind' in network.get('Name', ''):
                        kind_network = network['Name']
                        break

            if kind_network:
                logger.info(f"[Cluster] Connecting registry to network: {kind_network}")
                subprocess.run(['docker', 'network', 'connect', kind_network, self.registry_name],
                             capture_output=True, check=False)
                logger.info("[Cluster] Registry connected to Kind network")
        except Exception as e:
            logger.warn(f"[Cluster] Could not connect registry to Kind network: {e}")

    def wait_for_nodes_ready(self) -> None:
        """Wait for cluster nodes to be ready."""
        logger.info("[Cluster] Waiting for cluster nodes to be ready")

        max_attempts = 30
        for attempt in range(1, max_attempts + 1):
            logger.debug(f"[Cluster] Attempt {attempt}: Waiting for nodes to be ready")

            try:
                # Preserve existing environment and add KUBECONFIG
                env = os.environ.copy()
                env['KUBECONFIG'] = str(self.kubeconfig_path)
                result = subprocess.run([
                    'kubectl', 'wait', '--for=condition=Ready',
                    'nodes', '--all', '--timeout=10s'
                ], capture_output=True, text=True, env=env)

                if result.returncode == 0:
                    logger.info("[Cluster] All nodes are ready ✅")

                    # Show cluster status
                    try:
                        env = os.environ.copy()
                        env['KUBECONFIG'] = str(self.kubeconfig_path)
                        result = subprocess.run(['kubectl', 'get', 'nodes'],
                                              capture_output=True, text=True,
                                              env=env)
                        if result.returncode == 0:
                            if get_env('LOG_LEVEL', 'info').lower() == 'debug':
                                print(result.stdout)
                    except FileNotFoundError:
                        pass
                    return

            except FileNotFoundError:
                logger.warn("kubectl not found in PATH. Skipping node readiness check.")
                return
            except Exception:
                pass

            if attempt < max_attempts:
                time.sleep(10)

        logger.error(f"Nodes not ready after {max_attempts} attempts")
        sys.exit(1)

    def setup_core_namespace(self) -> None:
        """Setup core hostk8s namespace."""
        logger.info("[Cluster] Setting up core hostk8s namespace")

        namespace_manifest = self.project_root / 'infra' / 'manifests' / 'namespace.yaml'

        try:
            env = os.environ.copy()
            env['KUBECONFIG'] = str(self.kubeconfig_path)
            if namespace_manifest.exists():
                subprocess.run(['kubectl', 'apply', '-f', str(namespace_manifest)],
                             check=True, capture_output=True, env=env)
            else:
                # Create namespace directly
                subprocess.run([
                    'kubectl', 'create', 'namespace', 'hostk8s'
                ], capture_output=True, check=True, env=env)

            logger.info("[Cluster] HostK8s namespace ready")


        except FileNotFoundError:
            logger.warn("kubectl not found in PATH. Namespace will be created by addon scripts.")
        except subprocess.CalledProcessError as e:
            # Check if namespace already exists
            if 'AlreadyExists' in str(e):
                logger.success("HostK8s namespace already exists")
            else:
                logger.warn(f"Could not create namespace: {e}")

    def run_addon_script(self, script_name: str) -> bool:
        """Run an addon setup script (Python-only for OS independence)."""
        # Python scripts handle all OS-specific logic internally
        python_script = self.script_dir / f'{script_name}.py'
        if python_script.exists() and shutil.which('uv'):
            logger.info(f"[Script 🐍] Running script: [cyan]{script_name}.py[/cyan]")
            try:
                env = os.environ.copy()
                env['KUBECONFIG'] = str(self.kubeconfig_path)
                # Python scripts are OS-agnostic, handling platform differences internally
                result = subprocess.run(['uv', 'run', str(python_script)],
                                      env=env, check=False)
                return result.returncode == 0
            except Exception as e:
                logger.debug(f"Error running Python script: {e}")
                return False

        # Only log warning if Python script doesn't exist
        # No shell script fallback - Python handles everything
        logger.warn(f"{script_name}.py script not found, skipping")
        return False

    def setup_addons(self) -> None:
        """Setup enabled addons."""
        # Setup Gateway API CRDs first (foundational Kubernetes infrastructure)
        if not self.run_addon_script('setup-gateway-api'):
            logger.warn("[Cluster] Gateway API setup failed, continuing")

        # Setup Metrics Server (core Kubernetes API extension)
        if not self.metrics_disabled:
            if not self.run_addon_script('setup-metrics'):
                logger.warn("[Cluster] Metrics Server setup failed, continuing")

        if self.metallb_enabled:
            if not self.run_addon_script('setup-metallb'):
                logger.warn("[Cluster] MetalLB setup failed, continuing")

        if self.ingress_enabled:
            if not self.run_addon_script('setup-ingress'):
                logger.warn("[Cluster] Ingress setup failed, continuing")

        if self.registry_enabled:
            if not self.run_addon_script('setup-registry'):
                logger.warn("[Cluster] Registry setup failed, continuing")

        if self.vault_enabled:
            if not self.run_addon_script('setup-vault'):
                logger.warn("[Cluster] Vault setup failed, continuing")

        if self.flux_enabled:
            if not self.run_addon_script('setup-flux'):
                logger.warn("[Cluster] Flux setup failed, continuing")

    def setup_cluster(self, config_arg: Optional[str] = None) -> None:
        """Main cluster setup process."""
        logger.info("[Script 🐍] Running script: [cyan]cluster-up.py[/cyan]")
        logger.info("[Cluster] Starting HostK8s cluster setup")

        # Validate dependencies
        self.check_dependencies()

        # Validate Docker resources
        self.validate_docker_resources()

        # Check if cluster already exists
        if self.cluster_exists():
            logger.warn(f"[Cluster] Cluster '{self.cluster_name}' already exists. Use 'make restart' to recreate it.")
            sys.exit(1)

        # Determine Kind configuration
        config_path = self.determine_kind_config(config_arg)

        # Show cluster configuration (only in debug mode, matching shell script)
        if get_env('LOG_LEVEL', 'debug').lower() == 'debug':
            logger.debug("─" * 60)
            logger.debug("Kind Cluster Configuration:")
            logger.debug(f"  Cluster Name: [cyan]{self.cluster_name}[/cyan]")
            logger.debug(f"  Kubernetes Version: [cyan]{self.k8s_version}[/cyan]")
            logger.debug(f"  Configuration File: [cyan]{self.kind_config_file}[/cyan]")
            logger.debug(f"  Kubeconfig: [cyan]{self.kubeconfig_path}[/cyan]")
            logger.debug("─" * 60)

        # Setup registry if enabled (before cluster for docker network)
        if self.registry_enabled:
            self.setup_registry()

        # Create cluster
        self.create_cluster(config_path)

        # Setup kubeconfig
        logger.info("[Cluster] Setting up kubeconfig")
        os.environ['KUBECONFIG'] = str(self.kubeconfig_path)
        try:
            env = os.environ.copy()
            env['KUBECONFIG'] = str(self.kubeconfig_path)
            subprocess.run(['kubectl', 'config', 'use-context', f'kind-{self.cluster_name}'],
                          capture_output=True, check=False, env=env)
        except FileNotFoundError:
            logger.debug("kubectl not in PATH, skipping context switch")

        # Wait for nodes to be ready
        self.wait_for_nodes_ready()

        # Setup core namespace
        self.setup_core_namespace()

        # Setup addons
        self.setup_addons()

        logger.info(f"[Cluster] Kind cluster '{self.cluster_name}' is ready!")


def main() -> None:
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Start a new HostK8s Kind cluster',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Environment variables:
  CLUSTER_NAME       Cluster name (default: hostk8s)
  KIND_CONFIG        Kind config file to use
  METALLB_ENABLED    Enable MetalLB LoadBalancer (or ENABLE_METALLB)
  INGRESS_DISABLED   Disable NGINX Ingress (enabled by default)
  REGISTRY_ENABLED   Enable local Docker registry (or ENABLE_REGISTRY)
  METRICS_DISABLED   Disable metrics server
  VAULT_ENABLED      Enable Vault secret management (or ENABLE_VAULT)
  FLUX_ENABLED       Enable Flux GitOps (or ENABLE_FLUX)

Examples:
  %(prog)s                    # Start with defaults
  %(prog)s dev                # Use kind-dev.yaml config
  %(prog)s extension/custom   # Use extension config
        """
    )

    parser.add_argument('config', nargs='?',
                       help='Kind config name (looks for kind-NAME.yaml)')

    args = parser.parse_args()

    # Create setup instance
    setup = ClusterSetup()

    try:
        # Run setup
        setup.setup_cluster(args.config)

    except KeyboardInterrupt:
        logger.warn("Setup cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
