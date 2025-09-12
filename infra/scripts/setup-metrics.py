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
HostK8s Metrics Server Setup Script (Python Implementation)

Sets up Metrics Server add-on for the HostK8s cluster with:
- Environment variable configuration support
- Idempotent installation (skip if already installed)
- Wait for deployment ready with timeout
- Metrics API availability verification

This replaces the shell script version with improved error handling,
structured retry logic, and more maintainable code.
"""

# Default versions - update these for new releases
DEFAULT_METRICS_SERVER_CHART_VERSION = "3.13.0"
DEFAULT_METRICS_SERVER_APP_VERSION = "0.8.0"

import sys
import time
from pathlib import Path

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError, KubectlError, HelmError,
    run_kubectl, run_helm, load_environment, get_env
)


class MetricsSetup:
    """Handles Metrics Server setup operations."""

    def __init__(self):
        self.prefix = "[Metrics]"

    def get_chart_version(self) -> str:
        """Get metrics server chart version from environment or default."""
        return get_env('METRICS_VERSION', DEFAULT_METRICS_SERVER_CHART_VERSION)

    def log_info(self, message: str):
        """Log with Metrics prefix."""
        logger.info(f"{self.prefix} {message}")

    def log_warn(self, message: str):
        """Log warning with Metrics prefix."""
        logger.warn(f"{self.prefix} {message}")

    def log_error(self, message: str):
        """Log error with Metrics prefix."""
        logger.error(f"{self.prefix} {message}")

    def check_prerequisites(self) -> None:
        """Check that cluster is running."""
        self.log_info("Validating cluster is ready")
        try:
            run_kubectl(['cluster-info'], check=False, capture_output=True)
        except Exception:
            self.log_error("Cluster is not ready. Ensure cluster is started first.")
            sys.exit(1)

    def check_if_disabled(self) -> bool:
        """Check if metrics server should be disabled."""
        if get_env('METRICS_DISABLED', 'false').strip().lower() == 'true':
            self.log_info("⏭️  Metrics Server disabled by METRICS_DISABLED=true")
            return True
        return False

    def check_if_already_installed(self) -> bool:
        """Check if metrics-server is already installed via Helm."""
        try:
            # Check if Helm release exists
            result = run_helm(['list', '-n', 'kube-system', '-q'], check=False, capture_output=True)
            if result.returncode == 0 and 'metrics-server' in result.stdout:
                self.log_info("✅ Metrics Server already installed via Helm")
                return True

            # Fallback: check for deployment (in case it was manually installed)
            kubectl_result = run_kubectl(['get', 'deployment', 'metrics-server', '-n', 'kube-system'],
                                        check=False, capture_output=True)
            if kubectl_result.returncode == 0:
                self.log_info("ℹ️  Metrics Server found (not managed by Helm)")
                return True

            return False
        except Exception:
            return False

    def install_metrics_server(self) -> None:
        """Install Metrics Server via Helm."""
        chart_version = self.get_chart_version()
        self.log_info(f"Installing Metrics Server via Helm (chart version: {chart_version})")

        try:
            # Add metrics-server repo if not present
            self.log_info("Adding metrics-server Helm repository")
            run_helm(['repo', 'add', 'metrics-server',
                     'https://kubernetes-sigs.github.io/metrics-server/'], check=False)

            # Update repo to get latest charts
            run_helm(['repo', 'update'], check=False)

            # Install metrics-server with HostK8s customizations
            helm_args = [
                'upgrade', '--install', 'metrics-server', 'metrics-server/metrics-server',
                '--namespace', 'kube-system',
                '--version', chart_version,
                '--set', 'commonLabels.hostk8s\\.addon=metrics-server',
                '--set', 'commonLabels.app\\.kubernetes\\.io/managed-by=hostk8s',
                '--set', 'args={--kubelet-insecure-tls}'
            ]

            run_helm(helm_args)

        except HelmError as e:
            self.log_error(f"Failed to install Metrics Server via Helm: {e}")
            sys.exit(1)

    def wait_for_deployment_ready(self, timeout_seconds: int = 120) -> None:
        """Wait for metrics-server deployment to be ready."""
        self.log_info("Waiting for Metrics Server to be ready")

        try:
            run_kubectl(['wait', '--namespace', 'kube-system',
                        '--for=condition=available', 'deployment/metrics-server',
                        f'--timeout={timeout_seconds}s'])
        except KubectlError:
            self.log_warn("Metrics Server deployment not ready within 2 minutes")
            sys.exit(1)

    def wait_for_metrics_api(self, max_attempts: int = 20, sleep_seconds: int = 3) -> None:
        """Wait for metrics-server API to be available."""
        self.log_info("Waiting for Metrics API to be available")

        for attempt in range(1, max_attempts + 1):
            try:
                result = run_kubectl(['top', 'nodes'], check=False, capture_output=True)
                if result.returncode == 0:
                    break
            except Exception:
                pass

            if attempt == max_attempts:
                self.log_warn(f"Metrics API not available after {max_attempts} attempts")
                break

            time.sleep(sleep_seconds)

    def setup_metrics_server(self) -> None:
        """Main setup process for Metrics Server."""
        self.log_info("Setting up Metrics Server add-on")

        # Load environment configuration
        load_environment()

        # Check prerequisites
        self.check_prerequisites()

        # Check if disabled
        if self.check_if_disabled():
            sys.exit(0)

        # Check if already installed
        if self.check_if_already_installed():
            sys.exit(0)

        # Install Metrics Server
        self.install_metrics_server()

        # Wait for deployment to be ready
        self.wait_for_deployment_ready()

        # Wait for API to be available
        self.wait_for_metrics_api()

        # Success
        logger.info("[Cluster] Metrics Server addon ready ✅")


def main() -> None:
    """Main entry point."""
    setup = MetricsSetup()

    try:
        setup.setup_metrics_server()

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
