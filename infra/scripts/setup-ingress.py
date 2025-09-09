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
HostK8s NGINX Ingress Controller Setup Script (Python Implementation)

Sets up NGINX Ingress Controller for HostK8s cluster with:
- Idempotent installation (skip if already installed)
- MetalLB LoadBalancer integration (if available)
- NodePort configuration for Kind port mapping
- Admission webhook setup and verification
- Comprehensive wait logic with CI environment support

This replaces the shell script version with improved error handling,
better JSON operations, and more maintainable code structure.
"""

import json
import os
import sys
import time
from pathlib import Path
from typing import Dict, Any, Optional

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError, KubectlError,
    run_kubectl, detect_kubeconfig, get_env
)


class IngressSetup:
    """Handles NGINX Ingress Controller setup operations."""

    def __init__(self):
        self.prefix = "[Ingress]"
        self.namespace = "hostk8s"

    def log_info(self, message: str):
        """Log with Ingress prefix."""
        logger.info(f"{self.prefix} {message}")

    def log_warn(self, message: str):
        """Log warning with Ingress prefix."""
        logger.warn(f"{self.prefix} {message}")

    def log_error(self, message: str):
        """Log error with Ingress prefix."""
        logger.error(f"{self.prefix} {message}")

    def check_prerequisites(self) -> None:
        """Check that cluster is running."""
        try:
            self.kubeconfig = detect_kubeconfig()
        except Exception:
            self.log_error("No kubeconfig found. Ensure cluster is running.")
            sys.exit(1)

    def ensure_namespace(self) -> None:
        """Ensure the hostk8s namespace exists."""
        try:
            # Check if namespace exists
            result = run_kubectl(['get', 'namespace', self.namespace], check=False, capture_output=True)
            if result.returncode != 0:
                # Create namespace
                self.log_info(f"Creating namespace '{self.namespace}'")
                run_kubectl(['create', 'namespace', self.namespace])
                self.log_info(f"Namespace '{self.namespace}' created")
        except KubectlError as e:
            self.log_error(f"Failed to ensure namespace: {e}")
            sys.exit(1)

    def is_ingress_already_installed(self) -> bool:
        """Check if NGINX Ingress is already installed and running."""
        try:
            # Check if namespace exists
            result = run_kubectl(['get', 'namespace', self.namespace], check=False, capture_output=True)
            if result.returncode != 0:
                return False

            # Check if deployment exists
            result = run_kubectl(['get', 'deployment', 'ingress-nginx-controller', '-n', self.namespace],
                               check=False, capture_output=True)
            if result.returncode != 0:
                return False

            # Check if pods are running
            result = run_kubectl(['get', 'pods', '-n', self.namespace,
                                '-l', 'app.kubernetes.io/name=ingress-nginx'],
                               check=False, capture_output=True)

            if result.returncode == 0 and 'Running' in result.stdout:
                self.log_info("NGINX Ingress already installed and running")
                return True

            return False

        except Exception:
            return False

    def install_nginx_ingress(self) -> None:
        """Install NGINX Ingress Controller."""
        self.log_info("Installing NGINX Ingress Controller")

        manifest_path = Path("infra/manifests/nginx-ingress.yaml")
        if not manifest_path.exists():
            self.log_error(f"Manifest not found: {manifest_path}")
            sys.exit(1)

        try:
            run_kubectl(['apply', '-f', str(manifest_path)])
        except KubectlError:
            self.log_error("Failed to install NGINX Ingress Controller")
            sys.exit(1)

    def is_metallb_installed(self) -> bool:
        """Check if MetalLB is installed."""
        try:
            result = run_kubectl(['get', 'deployment', 'speaker', '-n', self.namespace],
                               check=False, capture_output=True)
            return result.returncode == 0
        except Exception:
            return False

    def wait_for_service_creation(self, service_name: str, timeout_seconds: int = 60) -> bool:
        """Wait for service to be created."""
        try:
            run_kubectl(['wait', '--for=jsonpath={.metadata.name}',
                        f'service/{service_name}', '-n', self.namespace,
                        f'--timeout={timeout_seconds}s'])
            return True
        except KubectlError:
            self.log_warn(f"Service {service_name} not found within timeout")
            return False

    def patch_service_for_metallb(self) -> None:
        """Configure ingress service for MetalLB LoadBalancer integration."""
        self.log_info("MetalLB detected, configuring NGINX Ingress for LoadBalancer integration")

        # Wait for service to be created
        if not self.wait_for_service_creation('ingress-nginx-controller'):
            return

        patch_data = {
            "spec": {
                "type": "LoadBalancer",
                "ports": [
                    {"name": "http", "port": 80, "protocol": "TCP", "targetPort": "http", "nodePort": 30080},
                    {"name": "https", "port": 443, "protocol": "TCP", "targetPort": "https", "nodePort": 30443}
                ]
            }
        }

        try:
            patch_json = json.dumps(patch_data)
            run_kubectl(['patch', 'service', 'ingress-nginx-controller', '-n', self.namespace,
                        '-p', patch_json])
            self.log_info("Ingress controller configured for MetalLB LoadBalancer")
        except KubectlError:
            self.log_warn("Failed to patch ingress service for LoadBalancer")

    def patch_service_for_nodeport(self) -> None:
        """Configure ingress service for Kind NodePort mapping."""
        self.log_info("MetalLB not detected, configuring NodePort for Kind port mapping")

        # Wait for service to be created
        if not self.wait_for_service_creation('ingress-nginx-controller'):
            return

        patch_data = {
            "spec": {
                "type": "NodePort",
                "ports": [
                    {"name": "http", "port": 80, "protocol": "TCP", "targetPort": "http", "nodePort": 30080},
                    {"name": "https", "port": 443, "protocol": "TCP", "targetPort": "https", "nodePort": 30443}
                ]
            }
        }

        try:
            patch_json = json.dumps(patch_data)
            run_kubectl(['patch', 'service', 'ingress-nginx-controller', '-n', self.namespace,
                        '-p', patch_json])
        except KubectlError:
            self.log_warn("Failed to patch ingress service for NodePort")

    def get_ingress_timeout(self) -> str:
        """Get ingress timeout based on environment."""
        # Increase timeout for CI environments
        if get_env('CI') or get_env('GITHUB_ACTIONS'):
            self.log_info("CI environment detected, increasing timeout to 600s for Ingress readiness")
            return '600s'
        return '300s'

    def wait_for_ingress_deployment(self, timeout: str) -> None:
        """Wait for NGINX Ingress deployment to be ready."""
        self.log_info("Waiting for NGINX Ingress Controller to be ready")

        try:
            run_kubectl(['wait', '--namespace', self.namespace,
                        '--for=condition=available', 'deployment/ingress-nginx-controller',
                        f'--timeout={timeout}'])
        except KubectlError:
            self.log_warn("Ingress deployment not ready, checking pod status")
            try:
                # Get pods info for debugging
                result = run_kubectl(['get', 'pods', '-n', self.namespace], check=False)
                if result.returncode == 0:
                    print(result.stdout)

                # Get pod descriptions for debugging
                run_kubectl(['describe', 'pods', '-n', self.namespace], check=False)
            except Exception:
                pass

    def wait_for_ingress_pods(self, timeout: str) -> None:
        """Wait for NGINX Ingress pods to be ready."""
        try:
            run_kubectl(['wait', '--namespace', self.namespace,
                        '--for=condition=ready', 'pod',
                        '--selector=app.kubernetes.io/component=controller',
                        f'--timeout={timeout}'])
        except KubectlError:
            self.log_warn(f"NGINX Ingress Controller failed to become ready within {timeout}")
            self.log_info("Checking ingress controller status")

            try:
                # Get pods status
                result = run_kubectl(['get', 'pods', '-n', self.namespace], check=False)
                if result.returncode == 0:
                    print(result.stdout)

                # Get logs for debugging
                run_kubectl(['logs', '-n', self.namespace,
                           '-l', 'app.kubernetes.io/component=controller',
                           '--tail=50'], check=False)
            except Exception:
                pass

            self.log_info("Continuing without waiting for ingress readiness")

    def wait_for_admission_webhook(self) -> None:
        """Wait for admission webhook jobs to complete."""
        self.log_info("Waiting for admission webhook setup jobs to complete")

        try:
            run_kubectl(['wait', '--namespace', self.namespace,
                        '--for=condition=complete', 'job',
                        '--selector=app.kubernetes.io/component=admission-webhook',
                        '--timeout=120s'])
        except KubectlError:
            self.log_warn("Admission webhook jobs did not complete in time, continuing")

    def verify_admission_webhook(self) -> None:
        """Verify admission webhook configuration."""
        self.log_info("Verifying admission webhook configuration")

        try:
            result = run_kubectl(['get', 'validatingwebhookconfiguration', 'ingress-nginx-admission'],
                                check=False, capture_output=True)
            if result.returncode == 0:
                self.log_info("Admission webhook successfully configured")
            else:
                self.log_warn("Admission webhook configuration not found")
        except Exception:
            self.log_warn("Error checking admission webhook configuration")

    def show_ingress_configuration(self) -> None:
        """Show NGINX Ingress configuration summary."""
        logger.debug("─" * 60)
        logger.debug("NGINX Ingress Controller Configuration")

        # Detect service type and configuration
        if self.is_metallb_installed():
            service_type = "LoadBalancer (MetalLB)"
            port_mapping = "80, 443 (via LoadBalancer IP)"
            access_urls = "http://localhost, https://localhost"
        else:
            service_type = "NodePort (Kind cluster)"
            port_mapping = "30080->8080, 30443->8443 (Kind port mapping)"
            access_urls = "http://localhost, https://localhost"

        logger.debug(f"  Service Type: [cyan]{service_type}[/cyan]")
        logger.debug(f"  Port Mapping: [cyan]{port_mapping}[/cyan]")
        logger.debug(f"  Access URLs: [cyan]{access_urls}[/cyan]")
        logger.debug(f"  Namespace: [cyan]{self.namespace}[/cyan]")
        logger.debug("─" * 60)

    def setup_ingress_controller(self) -> None:
        """Main setup process for NGINX Ingress Controller."""
        self.log_info("Setting up NGINX Ingress Controller")

        # Check prerequisites
        self.check_prerequisites()

        # Show configuration summary
        self.show_ingress_configuration()

        # Ensure namespace exists
        self.ensure_namespace()

        # Check if already installed
        skip_installation = self.is_ingress_already_installed()

        # Install NGINX Ingress if needed
        if not skip_installation:
            self.install_nginx_ingress()

        # Configure service based on MetalLB availability
        if self.is_metallb_installed():
            self.patch_service_for_metallb()
        else:
            self.patch_service_for_nodeport()

        # Wait for components to be ready
        timeout = self.get_ingress_timeout()
        self.wait_for_ingress_deployment(timeout)
        self.wait_for_ingress_pods(timeout)
        self.wait_for_admission_webhook()
        self.verify_admission_webhook()

        # Success
        logger.info("[Cluster] Ingress Controller addon ready ✅")


def main() -> None:
    """Main entry point."""
    setup = IngressSetup()

    try:
        setup.setup_ingress_controller()

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
