#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "pyyaml>=6.0",
#     "rich>=13.0.0",
#     "requests>=2.28.0"
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

import sys
import time
from pathlib import Path

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError, KubectlError,
    run_kubectl, load_environment, get_env
)


class MetricsSetup:
    """Handles Metrics Server setup operations."""

    def __init__(self):
        self.prefix = "[Metrics]"

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
        """Check if metrics-server is already installed."""
        try:
            result = run_kubectl(['get', 'deployment', 'metrics-server', '-n', 'kube-system'],
                                check=False, capture_output=True)
            if result.returncode == 0:
                self.log_info("✅ Metrics Server already installed")
                return True
            return False
        except Exception:
            return False

    def install_metrics_server(self) -> None:
        """Install Metrics Server from local manifest."""
        self.log_info("Installing Metrics Server")

        manifest_path = Path("infra/manifests/metrics-server.yaml")
        if not manifest_path.exists():
            self.log_error(f"Manifest not found: {manifest_path}")
            sys.exit(1)

        try:
            run_kubectl(['apply', '-f', str(manifest_path)])
        except KubectlError:
            self.log_error("Failed to apply Metrics Server manifest")
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


def main():
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
