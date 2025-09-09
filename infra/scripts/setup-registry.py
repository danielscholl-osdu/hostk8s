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
HostK8s Container Registry Setup Script (Python Implementation)

Sets up Container Registry add-on for HostK8s cluster with:
- Docker container registry deployment
- containerd configuration on Kind nodes
- Registry UI deployment (conditional on NGINX)
- Registry health checks and configuration

This replaces the shell script version with improved error handling,
better Docker integration, and more maintainable code.
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import List

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError, KubectlError,
    run_kubectl, get_env
)


class RegistrySetup:
    """Handles Container Registry setup operations."""

    def __init__(self):
        self.prefix = "[Registry]"
        self.registry_name = 'hostk8s-registry'
        self.registry_port = '5002'  # Use 5002 to avoid conflict with Kind NodePort on 5001
        self.registry_internal_port = '5000'
        self.cluster_name = get_env('CLUSTER_NAME', 'hostk8s')

    def log_info(self, message: str):
        """Log with Registry prefix."""
        logger.info(f"{self.prefix} {message}")

    def log_warn(self, message: str):
        """Log warning with Registry prefix."""
        logger.warn(f"{self.prefix} {message}")

    def log_error(self, message: str):
        """Log error with Registry prefix."""
        logger.error(f"{self.prefix} {message}")

    def check_docker_running(self) -> None:
        """Check if Docker is running."""
        try:
            result = subprocess.run(['docker', 'info'], capture_output=True, check=False)
            if result.returncode != 0:
                self.log_error("❌ Docker is not running. Please start Docker first.")
                sys.exit(1)
        except FileNotFoundError:
            self.log_error("❌ Docker not found. Please install Docker first.")
            sys.exit(1)

    def check_cluster_running(self) -> None:
        """Check that cluster is running."""
        try:
            run_kubectl(['cluster-info'], check=False, capture_output=True)
        except Exception:
            self.log_error("❌ Cluster is not ready. Ensure cluster is started first.")
            sys.exit(1)

    def create_registry_directories(self) -> None:
        """Create host directories for registry storage."""
        registry_data_dir = Path("data/registry")

        if not registry_data_dir.exists():
            self.log_info("Creating registry storage directory")
            registry_data_dir.mkdir(parents=True)

        # Ensure registry docker subdirectory exists
        docker_dir = registry_data_dir / 'docker'
        if not docker_dir.exists():
            self.log_info("Creating registry docker storage subdirectory")
            docker_dir.mkdir(parents=True)

    def create_registry_config(self) -> None:
        """Create registry configuration file."""
        config_file = Path("data/registry-config.yml")

        if config_file.exists():
            return

        self.log_info("Creating registry configuration file")

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

        with open(config_file, 'w') as f:
            f.write(config_content)

    def run_docker(self, args: List[str], check: bool = True) -> subprocess.CompletedProcess:
        """Run docker command with error handling."""
        cmd = ['docker'] + args

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=False)

            if check and result.returncode != 0:
                self.log_error(f"Docker command failed: {' '.join(cmd)}")
                if result.stderr:
                    self.log_error(f"Error: {result.stderr.strip()}")
                raise HostK8sError(f"Docker command failed with exit code {result.returncode}")

            return result
        except FileNotFoundError:
            raise HostK8sError("docker not found")

    def setup_containerd_config(self, node: str) -> None:
        """Setup containerd configuration on Kind node."""
        self.log_info(f"Configuring containerd on node: {node}")

        # Create containerd registry config directory
        self.run_docker(['exec', node, 'mkdir', '-p',
                        f'/etc/containerd/certs.d/localhost:{self.registry_internal_port}'])

        # Create hosts.toml configuration
        hosts_config = f"""server = "http://{self.registry_name}:{self.registry_internal_port}"

[host."http://{self.registry_name}:{self.registry_internal_port}"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
"""

        # Write config using docker exec with shell command
        config_path = f'/etc/containerd/certs.d/localhost:{self.registry_internal_port}/hosts.toml'
        # Use proper heredoc format with actual newlines
        cmd = f'''cat > {config_path} << 'EOF'
{hosts_config}EOF'''

        self.run_docker(['exec', node, 'sh', '-c', cmd])

        # Check if config_path is already configured (silent check)
        result = self.run_docker(['exec', node, 'grep', '-q', 'config_path.*certs.d',
                                '/etc/containerd/config.toml'], check=False)
        # Note: No logging needed - this is internal containerd configuration detail

    def get_registry_status(self) -> tuple[bool, str]:
        """Get registry container status."""
        try:
            result = self.run_docker(['inspect', self.registry_name], check=False)
            if result.returncode == 0:
                container_info = json.loads(result.stdout)[0]
                status = container_info['State']['Status']
                return True, status
            return False, ''
        except Exception:
            return False, ''

    def is_registry_connected_to_kind(self) -> bool:
        """Check if registry is connected to Kind network."""
        try:
            result = self.run_docker(['network', 'inspect', 'kind'])
            network_info = json.loads(result.stdout)[0]

            for container_id, container_info in network_info.get('Containers', {}).items():
                if container_info.get('Name') == self.registry_name:
                    return True
            return False
        except Exception:
            return False

    def connect_registry_to_kind(self) -> None:
        """Connect registry container to Kind network."""
        self.log_info("Connecting registry to Kind network")
        self.run_docker(['network', 'connect', 'kind', self.registry_name])

    def create_registry_container(self) -> None:
        """Create registry Docker container."""
        self.log_info("Creating Container Registry container")

        # Get absolute paths
        registry_data_dir = Path("data/registry").absolute()
        registry_config_file = Path("data/registry-config.yml").absolute()

        cmd = [
            'run', '-d', '--restart=always',
            '-p', f'127.0.0.1:{self.registry_port}:{self.registry_internal_port}',
            '-v', f'{registry_data_dir}:/var/lib/registry',
            '-v', f'{registry_config_file}:/etc/docker/registry/config.yml',
            '--name', self.registry_name,
            'registry:2'
        ]

        self.run_docker(cmd)

        # Connect to Kind network
        self.connect_registry_to_kind()

    def get_kind_nodes(self) -> List[str]:
        """Get list of Kind cluster nodes."""
        try:
            result = subprocess.run(['kind', 'get', 'nodes', '--name', self.cluster_name],
                                  capture_output=True, text=True, check=True)
            return [node.strip() for node in result.stdout.strip().split('\n') if node.strip()]
        except Exception as e:
            self.log_error(f"Failed to get Kind nodes: {e}")
            return []

    def configure_containerd_on_nodes(self) -> None:
        """Configure containerd on all Kind nodes."""
        self.log_info("Configuring containerd on Kind cluster nodes")

        nodes = self.get_kind_nodes()
        for node in nodes:
            self.setup_containerd_config(node)

    def ensure_namespace(self) -> None:
        """Ensure the hostk8s namespace exists."""
        try:
            # Check if namespace exists
            result = run_kubectl(['get', 'namespace', 'hostk8s'], check=False, capture_output=True)
            if result.returncode != 0:
                # Create namespace
                self.log_info("Creating namespace 'hostk8s'")
                run_kubectl(['create', 'namespace', 'hostk8s'])
                self.log_info("Namespace 'hostk8s' created")
        except KubectlError as e:
            self.log_error(f"Failed to ensure namespace: {e}")
            sys.exit(1)

    def deploy_registry_ui(self) -> bool:
        """Deploy registry UI if NGINX ingress is available."""
        # Check if NGINX ingress is available
        try:
            run_kubectl(['get', 'ingressclass', 'nginx'], check=False, capture_output=True)
        except Exception:
            self.log_info("NGINX Ingress not available - Registry UI skipped")
            return False

        self.log_info("Installing Registry UI")

        # Ensure namespace exists first
        self.ensure_namespace()

        manifest_path = Path("infra/manifests/registry-ui.yaml")
        if not manifest_path.exists():
            self.log_warn(f"Registry UI manifest not found: {manifest_path}")
            return False

        try:
            run_kubectl(['apply', '-f', str(manifest_path)])

            # Wait for registry UI to be ready
            self.log_info("Waiting for Container Registry UI to be ready")
            try:
                run_kubectl(['wait', '--namespace', 'hostk8s', '--for=condition=ready',
                           'pod', '--selector=app=registry-ui', '--timeout=120s'])
            except KubectlError:
                # Don't fail if wait times out
                pass

            return True

        except KubectlError:
            self.log_warn("Failed to deploy Registry UI")
            return False

    def test_registry_health(self, max_attempts: int = 10, sleep_seconds: int = 3) -> None:
        """Test registry connectivity."""
        self.log_info("Testing registry connectivity")

        for attempt in range(1, max_attempts + 1):
            try:
                import requests
                response = requests.get(f'http://localhost:{self.registry_port}/v2/', timeout=5)
                if response.status_code == 200:
                    break
            except Exception:
                pass

            if attempt == max_attempts:
                self.log_error("❌ Registry health check failed")
                sys.exit(1)

            time.sleep(sleep_seconds)

    def create_local_registry_configmap(self) -> None:
        """Create local registry hosting ConfigMap (Kubernetes standard)."""
        configmap_yaml = f"""apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:{self.registry_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
"""

        try:
            process = subprocess.run(['kubectl', 'apply', '-f', '-'],
                                   input=configmap_yaml, text=True, check=False, capture_output=True)
        except Exception:
            pass  # Don't fail if ConfigMap creation fails

    def show_registry_configuration(self) -> None:
        """Show Container Registry configuration summary."""
        logger.debug("─" * 60)
        logger.debug("Container Registry Configuration")
        logger.debug(f"  Registry Mode: [cyan]Docker Container[/cyan]")
        logger.debug(f"  Registry API: [cyan]http://localhost:{self.registry_port}[/cyan]")
        logger.debug(f"  Docker Usage: [cyan]localhost:{self.registry_port}/image:tag[/cyan]")
        logger.debug(f"  Storage Path: [cyan]{Path('data/registry').absolute()}[/cyan]")

        # Check if UI will be available
        try:
            run_kubectl(['get', 'ingressclass', 'nginx'], check=False, capture_output=True)
            ui_status = "http://localhost:8080/registry/"
        except:
            ui_status = "Not available (NGINX Ingress required)"

        logger.debug(f"  Web UI: [cyan]{ui_status}[/cyan]")
        logger.debug("─" * 60)

    def setup_registry(self) -> None:
        """Main setup process for Container Registry."""
        self.log_info("Setting up Container Registry add-on (Docker container)")

        # Check prerequisites
        self.check_docker_running()
        self.check_cluster_running()

        # Show configuration summary
        self.show_registry_configuration()

        # Create directories and config
        self.create_registry_directories()
        self.create_registry_config()

        # Check if registry already exists
        exists, status = self.get_registry_status()
        skip_container_creation = False

        if exists:
            if status == 'running':
                self.log_info("Container Registry already running")

                # Verify network connectivity
                if self.is_registry_connected_to_kind():
                    self.log_info("Registry container connected to Kind network")
                else:
                    self.connect_registry_to_kind()

                skip_container_creation = True
            else:
                self.log_info(f"Registry container exists but not running ({status})")
                self.log_info("Removing old container")
                self.run_docker(['rm', '-f', self.registry_name], check=False)

        # Create registry container if needed
        if not skip_container_creation:
            self.create_registry_container()

        # Configure containerd on Kind nodes
        self.configure_containerd_on_nodes()

        # Deploy registry UI
        registry_ui_deployed = self.deploy_registry_ui()

        # Test registry health
        self.test_registry_health()

        # Create local registry ConfigMap
        self.create_local_registry_configmap()

        # Success
        logger.info("[Cluster] Container Registry addon ready ✅")


def main() -> None:
    """Main entry point."""
    setup = RegistrySetup()

    try:
        setup.setup_registry()

    except KeyboardInterrupt:
        logger.warn("Operation cancelled by user")
        sys.exit(1)
    except HostK8sError as e:
        logger.error(str(e))
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
