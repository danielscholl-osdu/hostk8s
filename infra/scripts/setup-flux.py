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
HostK8s Flux GitOps Setup Script (Python Implementation)

Sets up Flux GitOps controllers for HostK8s cluster with:
- Flux CLI verification and version checking
- Flux controller installation with custom components
- GitOps repository and kustomization configuration
- Template variable substitution support
- Extension stack handling

This replaces the shell script version with improved error handling,
better template processing, and more maintainable code structure.
"""

import os
import subprocess
import sys
from pathlib import Path
from string import Template
from typing import Optional

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError, KubectlError, FluxError,
    run_kubectl, run_flux, detect_kubeconfig, get_env, load_environment
)


class FluxSetup:
    """Handles Flux GitOps setup operations."""

    def __init__(self):
        self.prefix = "[Flux]"
        self.kubeconfig_path = None
        self.gitops_repo = get_env('GITOPS_REPO', 'https://community.opengroup.org/danielscholl/hostk8s')
        self.gitops_branch = get_env('GITOPS_BRANCH', 'main')
        self.software_stack = get_env('SOFTWARE_STACK', '')
        self.flux_version = None

    def log_info(self, message: str):
        """Log with Flux prefix."""
        logger.info(f"{self.prefix} {message}")

    def log_warn(self, message: str):
        """Log warning with Flux prefix."""
        logger.warn(f"{self.prefix} {message}")

    def log_error(self, message: str):
        """Log error with Flux prefix."""
        logger.error(f"{self.prefix} {message}")

    def check_prerequisites(self) -> None:
        """Check prerequisites and setup kubeconfig."""
        try:
            self.kubeconfig_path = detect_kubeconfig()
            # Store kubeconfig - will be shown in config block
        except HostK8sError as e:
            self.log_error(str(e))
            sys.exit(1)

    def check_flux_cli(self) -> None:
        """Check if flux CLI is available and working."""
        try:
            # Check if flux CLI exists
            result = subprocess.run(['flux', 'version', '--client'],
                                  capture_output=True, text=True, check=False)
            if result.returncode != 0:
                self.log_error("Flux CLI not found. Install it first with 'make install' or manually: https://fluxcd.io/flux/installation/")
                sys.exit(1)

            # Extract version info (remove 'flux: ' prefix if present)
            raw_version = result.stdout.split('\n')[0] if result.stdout else "version unknown"
            self.flux_version = raw_version.replace('flux: ', '').strip()

        except FileNotFoundError:
            self.log_error("Flux CLI not found. Install it first with 'make install' or manually: https://fluxcd.io/flux/installation/")
            sys.exit(1)

    def show_flux_configuration(self) -> None:
        """Show Flux configuration."""
        logger.info("─" * 60)
        logger.info("Flux GitOps Configuration")
        logger.info(f"  Repository: [cyan]{self.gitops_repo}[/cyan]")
        logger.info(f"  Branch: [cyan]{self.gitops_branch}[/cyan]")
        if self.software_stack:
            logger.info(f"  Stack: [cyan]{self.software_stack}[/cyan]")
        if hasattr(self, 'flux_version') and self.flux_version:
            logger.info(f"  Version: [cyan]{self.flux_version}[/cyan]")
        logger.info("─" * 60)

    def is_flux_already_installed(self) -> bool:
        """Check if Flux is already installed and running."""
        try:
            # Check if flux-system namespace exists
            result = run_kubectl(['get', 'namespace', 'flux-system'], check=False, capture_output=True)
            if result.returncode != 0:
                return False

            logger.info("Flux namespace already exists, checking if installation is complete...")

            # Check if Flux pods are running
            result = run_kubectl(['get', 'pods', '-n', 'flux-system',
                                '-l', 'app.kubernetes.io/part-of=flux'],
                               check=False, capture_output=True)

            if result.returncode == 0 and 'Running' in result.stdout:
                logger.info("Flux appears to already be running")
                return True

            return False

        except Exception:
            return False

    def install_flux(self) -> None:
        """Install Flux controllers."""
        self.log_info("Installing Flux controllers")

        # Set KUBECONFIG for flux CLI
        env = os.environ.copy()
        env['KUBECONFIG'] = self.kubeconfig_path

        try:
            # Install Flux with minimal components for development
            cmd = [
                'flux', 'install',
                '--components-extra=image-reflector-controller,image-automation-controller',
                '--network-policy=false',
                '--watch-all-namespaces=true'
            ]

            result = subprocess.run(cmd, env=env, capture_output=True, text=True, check=False)

            if result.returncode != 0:
                logger.error("Failed to install Flux")
                if result.stderr:
                    logger.error(f"Error: {result.stderr}")
                sys.exit(1)

        except Exception as e:
            logger.error(f"Failed to install Flux: {e}")
            sys.exit(1)

    def wait_for_flux_controllers(self) -> None:
        """Wait for Flux controllers to be ready."""
        self.log_info("Waiting for Flux controllers to be ready")

        try:
            run_kubectl(['wait', '--for=condition=available', 'deployment',
                        '-l', 'app.kubernetes.io/part-of=flux', '-n', 'flux-system',
                        '--timeout=600s'])
        except KubectlError:
            logger.warn("Flux controllers still initializing, continuing setup...")

    def substitute_template_variables(self, content: str) -> str:
        """Substitute environment variables in template content."""
        # Get repository name from URL
        repo_name = Path(self.gitops_repo.rstrip('.git')).name

        # Create template variables
        variables = {
            'REPO_NAME': repo_name,
            'GITOPS_REPO': self.gitops_repo,
            'GITOPS_BRANCH': self.gitops_branch,
            'SOFTWARE_STACK': self.software_stack
        }

        # Add all environment variables as well
        variables.update(os.environ)

        try:
            template = Template(content)
            return template.safe_substitute(variables)
        except Exception as e:
            logger.debug(f"Template substitution error: {e}")
            return content

    def apply_stamp_yaml(self, yaml_file: str, description: str) -> None:
        """Apply YAML files with template substitution support."""
        file_path = Path(yaml_file)

        if not file_path.exists():
            logger.info(f"WARNING: YAML file not found: {yaml_file}")
            return

        logger.info(description)

        try:
            with open(file_path, 'r') as f:
                content = f.read()

            # Check if this file needs template processing
            needs_template = ('extension/' in yaml_file) or ('${' in content)

            if needs_template:
                logger.debug("Processing template variables for stack file")
                content = self.substitute_template_variables(content)

            # Apply the YAML
            process = subprocess.run(['kubectl', 'apply', '-f', '-'],
                                   input=content, text=True,
                                   env={'KUBECONFIG': self.kubeconfig_path},
                                   capture_output=True)

            if process.returncode != 0:
                logger.info(f"WARNING: Failed to apply {description}")
                if process.stderr:
                    logger.debug(f"Error: {process.stderr}")

        except Exception as e:
            logger.info(f"WARNING: Failed to apply {description}: {e}")

    def create_extension_bootstrap(self) -> None:
        """Create dynamic bootstrap configuration for extension stack."""
        logger.info("Setting up GitOps bootstrap configuration for extension stack")

        bootstrap_yaml = f"""apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: bootstrap-stack
  namespace: flux-system
spec:
  interval: 1m
  retryInterval: 30s
  timeout: 5m
  sourceRef:
    kind: GitRepository
    name: extension-stack-system
  path: ./software/stacks/{self.software_stack}
  targetNamespace: flux-system
  prune: true
  wait: false
"""

        try:
            process = subprocess.run(['kubectl', 'apply', '-f', '-'],
                                   input=bootstrap_yaml, text=True,
                                   env={'KUBECONFIG': self.kubeconfig_path},
                                   capture_output=True)

            if process.returncode != 0:
                logger.warn("Failed to create extension bootstrap configuration")
                if process.stderr:
                    logger.debug(f"Error: {process.stderr}")
        except Exception as e:
            logger.warn(f"Failed to create extension bootstrap configuration: {e}")

    def configure_gitops(self) -> None:
        """Configure GitOps repository and kustomization if stack is specified."""
        if not self.software_stack:
            self.log_info("No stack specified - Flux installed without GitOps configuration")
            return

        self.log_info("Stack configuration will be handled by make up command")

    def show_flux_status(self) -> None:
        """Show Flux installation status."""
        self.log_info("Flux installation completed! ✅")

    def show_completion_summary(self) -> None:
        """Show completion summary with configuration details."""
        logger.info("[Cluster] Flux addon ready ✅")

    def setup_flux(self) -> None:
        """Main setup process for Flux GitOps."""
        # Load environment
        load_environment()

        # Update configuration from environment (in case .env changed values)
        self.gitops_repo = get_env('GITOPS_REPO', self.gitops_repo)
        self.gitops_branch = get_env('GITOPS_BRANCH', self.gitops_branch)
        self.software_stack = get_env('SOFTWARE_STACK', self.software_stack)

        # Check prerequisites
        self.check_prerequisites()

        # Check Flux CLI
        self.check_flux_cli()

        # Show configuration
        self.show_flux_configuration()

        # Check if already installed
        if self.is_flux_already_installed():
            return

        # Install Flux
        self.install_flux()

        # Wait for controllers
        self.wait_for_flux_controllers()

        # Configure GitOps
        self.configure_gitops()

        # Show status
        self.show_flux_status()

        # Show completion summary
        self.show_completion_summary()


def main() -> None:
    """Main entry point."""
    setup = FluxSetup()

    try:
        setup.setup_flux()

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
