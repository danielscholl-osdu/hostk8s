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
HostK8s Gateway API Setup Script

Installs Kubernetes Gateway API CRDs as foundational infrastructure.
Gateway API is the modern standard for ingress and traffic management,
replacing traditional Ingress resources with more powerful capabilities.

This runs automatically during cluster creation and is not shown as an
addon since Gateway API is considered foundational Kubernetes infrastructure.
"""

import os
import sys
from pathlib import Path

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError, KubectlError,
    run_kubectl, detect_kubeconfig
)


class GatewayApiSetup:
    """Handles Gateway API CRD installation."""

    def __init__(self):
        self.prefix = "[Gateway API]"
        self.gateway_api_version = "v1.3.0"
        self.gateway_api_url = f"https://github.com/kubernetes-sigs/gateway-api/releases/download/{self.gateway_api_version}/standard-install.yaml"

    def log_info(self, message: str):
        """Log with Gateway API prefix."""
        logger.info(f"{self.prefix} {message}")

    def log_error(self, message: str):
        """Log error with Gateway API prefix."""
        logger.error(f"{self.prefix} {message}")

    def check_prerequisites(self) -> None:
        """Check that cluster is running."""
        try:
            self.kubeconfig = detect_kubeconfig()
        except Exception:
            self.log_error("No kubeconfig found. Ensure cluster is running.")
            sys.exit(1)

    def is_gateway_api_installed(self) -> bool:
        """Check if Gateway API CRDs are already installed."""
        try:
            result = run_kubectl(['get', 'crd', 'gateways.gateway.networking.k8s.io'],
                                check=False, capture_output=True)
            if result.returncode == 0:
                self.log_info("Gateway API CRDs already installed")
                return True
            return False
        except Exception:
            return False

    def install_gateway_api_crds(self) -> None:
        """Install Gateway API CRDs from upstream."""
        self.log_info(f"Installing Gateway API {self.gateway_api_version} CRDs (foundational infrastructure)")

        try:
            # Apply Gateway API CRDs directly from upstream
            run_kubectl(['apply', '-f', self.gateway_api_url])
            self.log_info("Gateway API CRDs installed successfully")

        except KubectlError as e:
            self.log_error(f"Failed to install Gateway API CRDs: {e}")
            sys.exit(1)

    def verify_installation(self) -> None:
        """Verify Gateway API CRDs are ready."""
        try:
            # Check for main Gateway API CRDs
            crds_to_check = [
                'gateways.gateway.networking.k8s.io',
                'httproutes.gateway.networking.k8s.io',
                'gatewayclasses.gateway.networking.k8s.io'
            ]

            for crd in crds_to_check:
                result = run_kubectl(['get', 'crd', crd], check=False, capture_output=True)
                if result.returncode != 0:
                    self.log_error(f"Gateway API CRD not found: {crd}")
                    return False

            self.log_info("Gateway API CRDs verified successfully")
            return True

        except Exception as e:
            self.log_error(f"Error verifying Gateway API installation: {e}")
            return False

    def setup_gateway_api(self) -> None:
        """Main setup process for Gateway API CRDs."""
        self.log_info("Setting up Gateway API infrastructure")

        # Check prerequisites
        self.check_prerequisites()

        # Check if already installed
        if self.is_gateway_api_installed():
            self.verify_installation()
            return

        # Install Gateway API CRDs
        self.install_gateway_api_crds()

        # Verify installation
        if not self.verify_installation():
            sys.exit(1)

        logger.info("[Cluster] Gateway API infrastructure ready ✅")


def main() -> None:
    """Main entry point."""
    setup = GatewayApiSetup()

    try:
        setup.setup_gateway_api()

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
