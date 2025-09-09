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
HostK8s Vault Secret Management Setup Script (Python Implementation)

Sets up Vault secret management for HostK8s cluster with:
- Idempotent Vault installation in development mode
- External Secrets Operator integration (conditional)
- ClusterSecretStore and token configuration
- Vault UI ingress setup with NGINX detection
- Comprehensive status reporting and access instructions

This replaces the shell script version with improved error handling,
better YAML operations, and more maintainable code structure.
"""

import os
import sys
import subprocess
import time
from pathlib import Path
from typing import Optional

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError, KubectlError, HelmError,
    run_kubectl, run_helm, detect_kubeconfig, get_env, load_environment
)


class VaultSetup:
    """Handles Vault secret management setup operations."""

    def __init__(self):
        self.prefix = "[Vault]"
        self.namespace = "hostk8s"
        self.vault_token = "hostk8s"
        self.vault_enabled = get_env('VAULT_ENABLED', 'false').strip().lower() == 'true'

    def log_info(self, message: str):
        """Log with Vault prefix."""
        logger.info(f"{self.prefix} {message}")

    def log_warn(self, message: str):
        """Log warning with Vault prefix."""
        logger.warn(f"{self.prefix} {message}")

    def log_error(self, message: str):
        """Log error with Vault prefix."""
        logger.error(f"{self.prefix} {message}")

    def show_vault_configuration(self) -> None:
        """Show Vault configuration summary."""
        logger.debug("─" * 60)
        logger.debug("Vault Secret Management Configuration")
        logger.debug(f"  Mode: [cyan]Development[/cyan]")
        logger.debug(f"  Token: [cyan]{self.vault_token}[/cyan]")
        logger.debug(f"  Namespace: [cyan]{self.namespace}[/cyan]")

        # Check if External Secrets Operator will be installed
        if self.vault_enabled:
            eso_status = "Enabled (External Secrets Operator)"
        else:
            eso_status = "Basic mode only"

        # Check if UI will be available via ingress
        try:
            run_kubectl(['get', 'ingressclass', 'nginx'], check=False, capture_output=True)
            ui_status = "http://localhost:8080/ui/"
        except:
            ui_status = "Port-forward required (NGINX Ingress not available)"

        logger.debug(f"  Integration: [cyan]{eso_status}[/cyan]")
        logger.debug(f"  UI Access: [cyan]{ui_status}[/cyan]")
        logger.debug("─" * 60)

    def check_prerequisites(self) -> None:
        """Check prerequisites and setup kubeconfig."""
        try:
            self.kubeconfig_path = detect_kubeconfig()
        except HostK8sError as e:
            self.log_error(str(e))
            sys.exit(1)

    def is_vault_already_installed(self) -> bool:
        """Check if Vault is already installed and running."""
        try:
            # Check if Vault is already installed via Helm
            result = run_helm(['list', '-n', self.namespace], check=False, capture_output=True)
            if result.returncode == 0 and 'vault' in result.stdout:
                self.log_info("Vault already installed via Helm")

                # Check if Vault pods are running
                result = run_kubectl(['get', 'pod', '-l', 'app.kubernetes.io/name=vault',
                                    '-n', self.namespace], check=False, capture_output=True)

                if result.returncode == 0 and 'Running' in result.stdout:
                    self.log_info("✅ Vault is already running")
                    return True

            return False

        except Exception:
            return False

    def add_hashicorp_helm_repo(self) -> None:
        """Add HashiCorp Helm repository."""
        self.log_info("Adding HashiCorp Helm repository")

        try:
            # Add repo (ignore if already exists)
            result = run_helm(['repo', 'add', 'hashicorp', 'https://helm.releases.hashicorp.com'],
                            check=False, capture_output=True)
            if result.returncode != 0 and 'already exists' not in result.stderr:
                raise HelmError(f"Failed to add HashiCorp repo: {result.stderr}")

            if 'already exists' in result.stderr:
                logger.debug("HashiCorp repo already exists")

            # Update repos
            run_helm(['repo', 'update'], capture_output=True)

        except HelmError:
            logger.error("Failed to add HashiCorp Helm repository")
            sys.exit(1)

    def install_vault(self) -> None:
        """Install Vault in development mode."""
        self.log_info("Installing Vault")
        # Note: If image pulls are slow, you can pre-pull the image with:
        # docker pull hashicorp/vault:1.20.1 && kind load docker-image hashicorp/vault:1.20.1 --name hostk8s

        max_retries = 3
        retry_count = 0

        while retry_count < max_retries:
            try:
                # Helm install command with development configuration
                helm_args = [
                    'upgrade', '--install', 'vault', 'hashicorp/vault',
                    '--namespace', self.namespace,
                    '--create-namespace',
                    '--set', 'server.dev.enabled=true',
                    '--set', f'server.dev.devRootToken={self.vault_token}',
                    '--set', 'injector.enabled=false',
                    '--set', 'server.resources.requests.memory=64Mi',
                    '--set', 'server.resources.requests.cpu=10m',
                    '--set', 'server.resources.limits.memory=128Mi',
                    '--set', 'server.resources.limits.cpu=100m',
                    '--set', 'ui.enabled=true',
                    '--set', 'ui.serviceType=ClusterIP',
                    '--wait', '--timeout', '5m'  # Increased from 2m to 5m
                ]

                # Set environment variable for increased timeout
                original_timeout = os.environ.get('HELM_HTTP_TIMEOUT')
                os.environ['HELM_HTTP_TIMEOUT'] = '600'  # 10 minutes for chart download

                try:
                    run_helm(helm_args, capture_output=True)
                    self.log_info("Vault installed successfully")
                    return  # Success, exit the function
                finally:
                    # Restore original timeout
                    if original_timeout:
                        os.environ['HELM_HTTP_TIMEOUT'] = original_timeout
                    elif 'HELM_HTTP_TIMEOUT' in os.environ:
                        del os.environ['HELM_HTTP_TIMEOUT']
            except HelmError as e:
                error_msg = str(e)
                if 'context deadline exceeded' in error_msg or 'Client.Timeout' in error_msg:
                    retry_count += 1
                    if retry_count < max_retries:
                        logger.warn(f"Helm chart download timed out, retrying ({retry_count}/{max_retries})")
                        time.sleep(5)  # Wait 5 seconds before retry
                        continue
                    else:
                        logger.error("Failed to download Vault helm chart after multiple attempts")
                        logger.error("This may be due to network issues or HashiCorp repository being slow")
                        logger.error("You can try running 'make up vault' again later")
                        sys.exit(1)
                else:
                    # Other error, don't retry
                    logger.error(f"Failed to install Vault: {error_msg}")
                    sys.exit(1)
            except Exception as e:
                retry_count += 1
                if retry_count >= max_retries:
                    logger.error(f"Failed to install Vault: {str(e)}")
                    sys.exit(1)
                logger.warn(f"Installation attempt failed, retrying ({retry_count}/{max_retries})")
                time.sleep(5)

    def wait_for_vault_ready(self) -> None:
        """Wait for Vault to be ready."""
        self.log_info("Waiting for Vault to be ready")

        # Use check=False to suppress error output
        result = run_kubectl(['wait', '--for=condition=ready', 'pod',
                            '-l', 'app.kubernetes.io/name=vault',
                            '-n', self.namespace, '--timeout=120s'],
                            check=False, capture_output=True)

        if result.returncode != 0:
            # Check pod status to provide appropriate feedback
            try:
                pod_result = run_kubectl(['get', 'pod', '-l', 'app.kubernetes.io/name=vault',
                                        '-n', self.namespace], check=False, capture_output=True)

                if 'No resources found' in pod_result.stdout:
                    logger.error("Vault pod was not created. Installation may have failed.")
                    return

                # Check if pod exists and is starting
                if 'vault-0' in pod_result.stdout:
                    if 'ContainerCreating' in pod_result.stdout or 'Pending' in pod_result.stdout:
                        # Check if pulling image
                        describe_result = run_kubectl(['describe', 'pod', '-l', 'app.kubernetes.io/name=vault',
                                                      '-n', self.namespace], check=False, capture_output=True)
                        if 'Pulling image' in describe_result.stdout:
                            self.log_info("Vault container image is being pulled. This may take several minutes on first run.")
                        else:
                            self.log_info("Vault container is being created")
                    elif 'Running' in pod_result.stdout:
                        logger.info("Vault is running but not yet ready. It should be available shortly.")
                    else:
                        # Show the actual status if it's something else
                        logger.warn("Vault pod status:")
                        print(pod_result.stdout.strip())

            except Exception:
                pass

    def install_external_secrets_operator(self) -> None:
        """Install External Secrets Operator if VAULT_ENABLED is true."""
        if not self.vault_enabled:
            return

        self.log_info("Installing External Secrets Operator")

        try:
            # Add External Secrets Helm repository
            result = run_helm(['repo', 'add', 'external-secrets',
                             'https://charts.external-secrets.io'],
                            check=False, capture_output=True)
            if result.returncode != 0 and 'already exists' not in result.stderr:
                raise HelmError(f"Failed to add External Secrets repo: {result.stderr}")

            run_helm(['repo', 'update'], capture_output=True)

            # Install External Secrets Operator
            helm_args = [
                'upgrade', '--install', 'external-secrets', 'external-secrets/external-secrets',
                '--namespace', self.namespace,
                '--set', 'installCRDs=true',
                '--set', 'webhook.port=9443',
                '--set', 'resources.requests.memory=32Mi',
                '--set', 'resources.requests.cpu=10m',
                '--set', 'resources.limits.memory=64Mi',
                '--set', 'resources.limits.cpu=50m',
                '--wait', '--timeout', '2m'
            ]

            run_helm(helm_args, capture_output=True)

        except HelmError:
            logger.warn("Failed to install External Secrets Operator")

    def create_vault_cluster_secret_store(self) -> None:
        """Create ClusterSecretStore for Vault integration."""
        if not self.vault_enabled:
            return

        self.log_info("Creating Vault ClusterSecretStore")

        cluster_secret_store_yaml = f"""apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "http://vault.{self.namespace}.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: vault-token
          key: token
          namespace: {self.namespace}
---
apiVersion: v1
kind: Secret
metadata:
  name: vault-token
  namespace: {self.namespace}
type: Opaque
stringData:
  token: "{self.vault_token}"
"""

        try:
            process = subprocess.run(['kubectl', 'apply', '-f', '-'],
                                   input=cluster_secret_store_yaml, text=True,
                                   capture_output=True)

            if process.returncode != 0:
                logger.warn("Failed to create ClusterSecretStore")
                if process.stderr:
                    logger.debug(f"Error: {process.stderr}")

        except Exception:
            logger.warn("Failed to create ClusterSecretStore")

    def is_nginx_ingress_available(self) -> bool:
        """Check if NGINX Ingress controller is available and ready."""
        try:
            # Check if deployment exists
            result = run_kubectl(['get', 'deployment', '-n', self.namespace,
                                'ingress-nginx-controller'], check=False, capture_output=True)
            if result.returncode != 0:
                return False

            # Check if deployment is ready
            result = run_kubectl(['wait', '--for=condition=available',
                                'deployment/ingress-nginx-controller',
                                '-n', self.namespace, '--timeout=30s'],
                               check=False, capture_output=True)
            return result.returncode == 0

        except Exception:
            return False

    def setup_vault_ui_ingress(self) -> None:
        """Setup Vault UI ingress if NGINX is available."""
        if not self.is_nginx_ingress_available():
            logger.warn("NGINX Ingress not available, skipping Vault UI ingress setup")
            logger.warn("You can manually apply: kubectl apply -f infra/manifests/vault-ingress.yaml")
            return

        self.log_info("Installing Vault UI ingress")

        ingress_manifest = Path("infra/manifests/vault-ingress.yaml")
        if not ingress_manifest.exists():
            logger.warn(f"Ingress manifest not found: {ingress_manifest}")
            return

        try:
            run_kubectl(['apply', '-f', str(ingress_manifest)], capture_output=True)
        except KubectlError:
            logger.warn("Failed to configure Vault UI ingress")

    def show_vault_status(self) -> None:
        """Show Vault addon status."""
        logger.debug("Vault addon status:")
        try:
            result = run_kubectl(['get', 'pods', '-n', self.namespace,
                                '-l', 'app.kubernetes.io/name=vault'], check=False)
            if result.returncode == 0:
                print(result.stdout)
        except Exception:
            pass

    def show_completion_message(self) -> None:
        """Show simple completion message."""
        logger.info("[Cluster] Vault addon ready ✅")

    def setup_vault_secret_management(self) -> None:
        """Main setup process for Vault secret management."""
        # Load environment
        load_environment()

        # Update configuration from environment (in case .env changed values)
        self.vault_enabled = get_env('VAULT_ENABLED', 'false').strip().lower() == 'true'

        # Check prerequisites
        self.check_prerequisites()

        self.log_info("Setting up Vault secret management addon")

        # Show configuration summary
        self.show_vault_configuration()

        # Check if already installed
        if self.is_vault_already_installed():
            # Still configure External Secrets Operator and ingress if needed
            self.install_external_secrets_operator()
            self.create_vault_cluster_secret_store()
            self.setup_vault_ui_ingress()
            self.show_completion_message()
            return

        # Add HashiCorp Helm repository
        self.add_hashicorp_helm_repo()

        # Install Vault
        self.install_vault()

        # Wait for Vault to be ready
        self.wait_for_vault_ready()

        # Install External Secrets Operator (conditional)
        self.install_external_secrets_operator()

        # Create ClusterSecretStore
        self.create_vault_cluster_secret_store()

        # Setup Vault UI ingress
        self.setup_vault_ui_ingress()

        # Show completion
        self.show_completion_message()


def main():
    """Main entry point."""
    setup = VaultSetup()

    try:
        setup.setup_vault_secret_management()

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
