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
HostK8s MetalLB LoadBalancer Setup Script (Python Implementation)

Sets up MetalLB LoadBalancer for HostK8s cluster with:
- Idempotent MetalLB installation
- Docker network subnet detection and IP pool configuration
- L2Advertisement setup for Kind networking
- LoadBalancer functionality testing with connectivity verification
- Automatic cleanup of test resources

This replaces the shell script version with improved error handling,
better JSON processing for Docker network inspection, and more maintainable code structure.
"""

# Default versions - update these for new releases
DEFAULT_METALLB_CHART_VERSION = "0.15.2"
DEFAULT_METALLB_APP_VERSION = "v0.15.2"

import json
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional, Dict, Any

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError, KubectlError, HelmError,
    run_kubectl, run_helm, detect_kubeconfig, get_env
)


class MetalLBSetup:
    """Handles MetalLB LoadBalancer setup operations."""

    def __init__(self):
        self.prefix = "[MetalLB]"
        self.namespace = "hostk8s"
        self.default_subnet = "172.18.0.0/16"

    def get_chart_version(self) -> str:
        """Get MetalLB chart version from environment or default."""
        return get_env('METALLB_VERSION', DEFAULT_METALLB_CHART_VERSION)

    def log_info(self, message: str):
        """Log with MetalLB prefix."""
        logger.info(f"{self.prefix} {message}")

    def log_warn(self, message: str):
        """Log warning with MetalLB prefix."""
        logger.warn(f"{self.prefix} {message}")

    def log_error(self, message: str):
        """Log error with MetalLB prefix."""
        logger.error(f"{self.prefix} {message}")

    def check_prerequisites(self) -> None:
        """Check that cluster is running."""
        try:
            kubeconfig = detect_kubeconfig()
            self.log_info(f"Using kubeconfig: {kubeconfig}")
        except Exception:
            self.log_error("No kubeconfig found. Ensure cluster is running.")
            sys.exit(1)

    def is_metallb_already_installed(self) -> bool:
        """Check if MetalLB is already installed via Helm."""
        try:
            # Check if Helm release exists
            result = run_helm(['list', '-n', self.namespace, '-q'], check=False, capture_output=True)
            if result.returncode == 0 and 'metallb' in result.stdout:
                self.log_info("✅ MetalLB already installed via Helm")
                return True

            # Fallback: check for deployment (in case it was manually installed)
            kubectl_result = run_kubectl(['get', 'deployment', 'metallb-controller', '-n', self.namespace],
                                        check=False, capture_output=True)
            if kubectl_result.returncode == 0:
                self.log_info("ℹ️  MetalLB found (not managed by Helm)")
                return True

            return False
        except Exception:
            return False

    def install_metallb(self) -> None:
        """Install MetalLB LoadBalancer via Helm."""
        chart_version = self.get_chart_version()
        self.log_info(f"Installing MetalLB via Helm (chart version: {chart_version})")

        try:
            # Add MetalLB repo if not present
            self.log_info("Adding MetalLB Helm repository")
            run_helm(['repo', 'add', 'metallb',
                     'https://metallb.github.io/metallb'], check=False)

            # Update repo to get latest charts
            run_helm(['repo', 'update'], check=False)

            # Install MetalLB with HostK8s customizations
            helm_args = [
                'upgrade', '--install', 'metallb', 'metallb/metallb',
                '--namespace', self.namespace,
                '--create-namespace',
                '--version', chart_version
            ]

            run_helm(helm_args)

        except HelmError as e:
            self.log_error(f"Failed to install MetalLB via Helm: {e}")
            sys.exit(1)

    def wait_for_metallb_ready(self) -> None:
        """Wait for MetalLB pods to be ready."""
        self.log_info("Waiting for MetalLB pods to be ready")

        try:
            run_kubectl(['wait', '--for=condition=ready', 'pod',
                        '-l', 'app.kubernetes.io/name=metallb', '-n', self.namespace,
                        '--timeout=300s'])
        except KubectlError:
            self.log_error("MetalLB pods failed to become ready")
            sys.exit(1)

    def detect_docker_subnet(self) -> str:
        """Detect Docker network subnet for MetalLB IP pool."""
        self.log_info("Detecting Docker network subnet")

        try:
            # Inspect Docker Kind network
            result = subprocess.run(['docker', 'network', 'inspect', 'kind'],
                                  capture_output=True, text=True, check=True)

            # Parse JSON response
            network_info = json.loads(result.stdout)

            # Look for IPv4 subnet
            if network_info and len(network_info) > 0:
                ipam_config = network_info[0].get('IPAM', {}).get('Config', [])

                for config in ipam_config:
                    subnet = config.get('Subnet', '')
                    if subnet and '.' in subnet:  # IPv4 check
                        self.log_info(f"Using Docker subnet: [cyan]{subnet}[/cyan]")
                        return subnet

            # Fallback to default
            self.log_info(f"Could not detect IPv4 subnet, using default: [cyan]{self.default_subnet}[/cyan]")
            return self.default_subnet

        except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError):
            self.log_info(f"Could not detect IPv4 subnet, using default: [cyan]{self.default_subnet}[/cyan]")
            return self.default_subnet

    def create_metallb_ip_pool(self, subnet: str) -> None:
        """Create MetalLB IP address pool configuration."""
        # Extract network prefix and create IP pool range
        network_prefix = '.'.join(subnet.split('/')[0].split('.')[:2])
        ip_pool_start = f"{network_prefix}.200.200"
        ip_pool_end = f"{network_prefix}.200.250"

        self.log_info(f"Configuring MetalLB IP pool: [cyan]{ip_pool_start}-{ip_pool_end}[/cyan]")

        ip_pool_yaml = f"""apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: {self.namespace}
spec:
  addresses:
  - {ip_pool_start}-{ip_pool_end}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kind-l2
  namespace: {self.namespace}
spec:
  ipAddressPools:
  - kind-pool
"""

        try:
            process = subprocess.run(['kubectl', 'apply', '-f', '-'],
                                   input=ip_pool_yaml, text=True,
                                   capture_output=True)

            if process.returncode != 0:
                self.log_error("Failed to configure MetalLB IP pool")
                if process.stderr:
                    logger.error(f"Error: {process.stderr}")
                sys.exit(1)

        except Exception as e:
            self.log_error(f"Failed to configure MetalLB IP pool: {e}")
            sys.exit(1)

    def create_test_service(self) -> None:
        """Create test service to verify MetalLB functionality."""
        self.log_info("Testing MetalLB with a test service")

        test_service_yaml = """apiVersion: apps/v1
kind: Deployment
metadata:
  name: metallb-test
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: metallb-test
  template:
    metadata:
      labels:
        app: metallb-test
    spec:
      containers:
      - name: nginx
        image: mcr.microsoft.com/azurelinux/base/nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: metallb-test
  namespace: default
spec:
  selector:
    app: metallb-test
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
"""

        try:
            process = subprocess.run(['kubectl', 'apply', '-f', '-'],
                                   input=test_service_yaml, text=True,
                                   capture_output=True)

            if process.returncode != 0:
                self.log_warn("Failed to create test service")
                if process.stderr:
                    logger.debug(f"Error: {process.stderr}")

        except Exception:
            self.log_warn("Failed to create test service")

    def test_loadbalancer_ip(self) -> Optional[str]:
        """Wait for and test LoadBalancer IP assignment."""
        self.log_info("Waiting for LoadBalancer IP assignment")

        external_ip = None

        for attempt in range(1, 31):
            try:
                result = run_kubectl(['get', 'svc', 'metallb-test',
                                    '-o', 'jsonpath={.status.loadBalancer.ingress[0].ip}'],
                                   check=False, capture_output=True)

                if result.returncode == 0 and result.stdout and result.stdout != 'null':
                    external_ip = result.stdout.strip()
                    self.log_info(f"LoadBalancer IP assigned: [cyan]{external_ip}[/cyan]")

                    # Test connectivity
                    self.log_info(f"Testing connectivity to [cyan]{external_ip}[/cyan]")
                    try:
                        curl_result = subprocess.run(['curl', '-s', '--connect-timeout', '5',
                                                    f'http://{external_ip}'],
                                                   capture_output=True, timeout=10)
                        if curl_result.returncode == 0:
                            self.log_info("MetalLB test successful!")
                        else:
                            self.log_warn("Could not connect to LoadBalancer IP, but IP was assigned")
                    except (subprocess.TimeoutExpired, FileNotFoundError):
                        self.log_warn("Could not test connectivity (curl not available or timeout)")

                    break

            except Exception:
                pass

            self.log_info(f"Waiting for LoadBalancer IP (attempt {attempt}/30)")
            time.sleep(5)

        if not external_ip:
            self.log_warn("No LoadBalancer IP was assigned after 150 seconds")
        else:
            self.log_info("MetalLB setup completed successfully")

        return external_ip

    def cleanup_test_service(self) -> None:
        """Clean up test service."""
        self.log_info("Cleaning up test service")

        try:
            run_kubectl(['delete', 'deployment,service', 'metallb-test',
                        '--ignore-not-found=true'], check=False)
        except Exception:
            pass

    def setup_metallb_loadbalancer(self) -> None:
        """Main setup process for MetalLB LoadBalancer."""
        self.log_info("Setting up MetalLB LoadBalancer")

        # Check prerequisites
        self.check_prerequisites()

        # Check if already installed
        skip_installation = self.is_metallb_already_installed()

        # Install MetalLB if needed
        if not skip_installation:
            self.install_metallb()

        # Wait for MetalLB to be ready
        if not skip_installation:
            self.wait_for_metallb_ready()

        # Detect Docker subnet and configure IP pool
        subnet = self.detect_docker_subnet()
        self.create_metallb_ip_pool(subnet)

        # Test MetalLB functionality
        self.create_test_service()
        self.test_loadbalancer_ip()
        self.cleanup_test_service()

        self.log_info("MetalLB setup complete")


def main() -> None:
    """Main entry point."""
    setup = MetalLBSetup()

    try:
        setup.setup_metallb_loadbalancer()

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
