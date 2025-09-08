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
HostK8s Application Deployment Script (Python Implementation)

Deploy or remove applications to/from the cluster with support for:
- Helm charts (Chart.yaml)
- Kustomization apps (kustomization.yaml)
- Legacy single-file apps (app.yaml)
- Namespace management and cleanup
- Multi-format argument parsing

This replaces the shell script version with improved error handling,
better path management, and more maintainable code structure.
"""

import argparse
import shutil
import sys
from pathlib import Path
from typing import List, Optional

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError, KubectlError,
    run_kubectl, run_helm,
    list_available_apps, validate_app_exists, get_app_deployment_type
)


class AppDeployer:
    """Handles application deployment and removal operations."""

    def __init__(self):
        pass

    def check_prerequisites(self) -> None:
        """Check that cluster is running."""
        try:
            result = run_kubectl(['cluster-info'], check=False, capture_output=True)
            if result.returncode != 0:
                logger.error("Cluster not running. Run 'make start' to start the cluster.")
                sys.exit(1)
        except Exception:
            logger.error("Cannot connect to cluster")
            sys.exit(1)

    def ensure_namespace(self, namespace: str) -> None:
        """Ensure namespace exists, create if necessary."""
        if namespace == 'default':
            return  # Default namespace always exists

        try:
            run_kubectl(['get', 'namespace', namespace], check=False, capture_output=True)
            logger.debug(f"Namespace {namespace} already exists")
        except:
            logger.info(f"Creating namespace: {namespace}")
            try:
                run_kubectl(['create', 'namespace', namespace])
                # Label the namespace so we know we created it
                run_kubectl(['label', 'namespace', namespace, 'hostk8s.created=true'], check=False)
                logger.success(f"Namespace {namespace} created")
            except KubectlError:
                logger.error(f"Failed to create namespace: {namespace}")
                sys.exit(1)

    def cleanup_namespace_if_empty(self, namespace: str) -> None:
        """Clean up namespace if it's empty and we created it."""
        # Never remove default or system namespaces
        system_namespaces = [
            'default', 'kube-system', 'kube-public', 'kube-node-lease',
            'flux-system', 'metallb-system', 'ingress-nginx'
        ]

        if namespace in system_namespaces:
            return

        try:
            # Only remove namespaces we created
            result = run_kubectl(['get', 'namespace', namespace,
                                '-o', 'jsonpath={.metadata.labels.hostk8s\\.created}'],
                               check=False, capture_output=True)

            if result.returncode != 0 or result.stdout.strip() != 'true':
                logger.debug(f"Not removing namespace {namespace} (not created by HostK8s)")
                return

            # Check if namespace has any hostk8s-managed resources
            result = run_kubectl(['get', 'all,ingress,configmap,secret',
                                '-l', 'hostk8s.app', '-n', namespace, '--no-headers'],
                               check=False, capture_output=True)

            resource_count = len([line for line in result.stdout.split('\n') if line.strip()])

            if resource_count == 0:
                logger.info(f"Removing empty namespace: {namespace}")
                try:
                    run_kubectl(['delete', 'namespace', namespace])
                    logger.success(f"Namespace {namespace} removed")
                except KubectlError:
                    logger.warn(f"Failed to remove namespace: {namespace}")
            else:
                logger.debug(f"Not removing namespace {namespace} (contains {resource_count} resources)")

        except Exception as e:
            logger.debug(f"Error checking namespace {namespace}: {e}")

    def deploy_helm_app(self, app_name: str, app_dir: Path, namespace: str) -> None:
        """Deploy application using Helm."""
        # Check if Helm is available
        if not shutil.which('helm'):
            logger.error("Helm is not installed. Please install Helm to deploy chart-based apps.")
            logger.info("Run: make install (includes Helm installation)")
            sys.exit(1)

        # Build Helm command arguments
        helm_args = ['upgrade', '--install', app_name, str(app_dir),
                    '--namespace', namespace, '--create-namespace']

        # Check for values files and add them
        values_file = app_dir / 'values.yaml'
        custom_values = app_dir / 'custom_values.yaml'
        env_values = app_dir / 'values' / 'development.yaml'

        if custom_values.exists():
            helm_args.extend(['-f', str(custom_values)])
            logger.info(f"Using custom values: {custom_values}")

        if env_values.exists():
            helm_args.extend(['-f', str(env_values)])
            logger.info(f"Using development values: {env_values}")

        try:
            run_helm(helm_args[1:])  # Skip 'helm' command as run_helm adds it
            logger.success(f"{app_name} deployed successfully via Helm to {namespace}")
            logger.info(f"See software/apps/{app_name}/README.md for access details")
            logger.info(f"Use 'helm status {app_name} -n {namespace}' for deployment status")
        except HostK8sError:
            logger.error(f"Failed to deploy {app_name} via Helm to {namespace}")
            logger.info(f"Check chart syntax with: helm lint {app_dir}")
            sys.exit(1)

    def remove_helm_app(self, app_name: str, namespace: str) -> None:
        """Remove application using Helm."""
        # Check if Helm is available
        if not shutil.which('helm'):
            logger.error("Helm is not installed. Cannot remove Helm releases.")
            logger.info("Run: make install (includes Helm installation)")
            sys.exit(1)

        # First, try to find the release in the specified namespace
        try:
            result = run_helm(['list', '-q', '-n', namespace], check=False)
            if result.returncode == 0 and app_name in result.stdout.split():
                run_helm(['uninstall', app_name, '-n', namespace])
                logger.success(f"{app_name} removed successfully via Helm from {namespace}")
                return
        except Exception:
            pass

        # If not found in specified namespace, search across all namespaces
        try:
            result = run_helm(['list', '-A'], check=False)
            if result.returncode == 0:
                for line in result.stdout.split('\n')[1:]:  # Skip header
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 2 and parts[0] == app_name:
                            found_namespace = parts[1]
                            logger.info(f"Helm release {app_name} not found in {namespace}, but found in {found_namespace}")
                            run_helm(['uninstall', app_name, '-n', found_namespace])
                            logger.success(f"{app_name} removed successfully via Helm from {found_namespace}")
                            return
        except Exception:
            pass

        # If still not found, try label-based removal
        logger.info(f"Helm release {app_name} not found, trying label-based removal across namespaces...")

        resources_removed = False

        # Try with app name as label first
        try:
            result = run_kubectl(['delete', 'all,ingress,configmap,secret',
                                '-l', f'hostk8s.app={app_name}', '-A'], check=False)
            if result.returncode == 0:
                resources_removed = True
        except Exception:
            pass

        # Also try with chart name as label (for cases where labels are inconsistent)
        app_dir = Path(f'software/apps/{app_name}')
        chart_file = app_dir / 'Chart.yaml'
        if chart_file.exists():
            try:
                import yaml
                with open(chart_file) as f:
                    chart_data = yaml.safe_load(f)
                chart_name = chart_data.get('name', '')

                if chart_name and chart_name != app_name:
                    result = run_kubectl(['delete', 'all,ingress,configmap,secret',
                                        '-l', f'hostk8s.app={chart_name}', '-A'], check=False)
                    if result.returncode == 0:
                        resources_removed = True
            except Exception:
                pass

        if resources_removed:
            logger.success(f"{app_name} removed successfully (label-based)")
        else:
            logger.warn(f"No resources found for app: {app_name} (may already be removed)")

    def deploy_kustomization_app(self, app_name: str, app_dir: Path, namespace: str) -> None:
        """Deploy application using Kustomization."""
        try:
            run_kubectl(['apply', '-k', str(app_dir), '-n', namespace])
            logger.success(f"{app_name} deployed successfully via Kustomization to {namespace}")
            logger.info(f"See software/apps/{app_name}/README.md for access details")
        except KubectlError:
            logger.error(f"Failed to deploy {app_name} via Kustomization to {namespace}")
            sys.exit(1)

    def remove_kustomization_app(self, app_name: str, app_dir: Path, namespace: str) -> None:
        """Remove application using Kustomization."""
        try:
            run_kubectl(['delete', '-k', str(app_dir), '-n', namespace], check=False)
            logger.success(f"{app_name} removed successfully via Kustomization from {namespace}")
        except Exception:
            logger.warn(f"Error removing {app_name} via Kustomization (may not exist)")

    def deploy_legacy_app(self, app_name: str, app_dir: Path, namespace: str) -> None:
        """Deploy application using legacy app.yaml."""
        app_file = app_dir / 'app.yaml'
        try:
            run_kubectl(['apply', '-f', str(app_file), '-n', namespace])
            logger.success(f"{app_name} deployed successfully via app.yaml to {namespace}")
            logger.info(f"See software/apps/{app_name}/README.md for access details")
        except KubectlError:
            logger.error(f"Failed to deploy {app_name} via app.yaml to {namespace}")
            sys.exit(1)

    def remove_legacy_app(self, app_name: str, app_dir: Path, namespace: str) -> None:
        """Remove application using legacy app.yaml."""
        app_file = app_dir / 'app.yaml'
        try:
            run_kubectl(['delete', '-f', str(app_file), '-n', namespace], check=False)
            logger.success(f"{app_name} removed successfully via app.yaml from {namespace}")
        except Exception:
            logger.warn(f"Error removing {app_name} via app.yaml (may not exist)")

    def deploy_application(self, app_name: str, namespace: str) -> None:
        """Deploy an application."""
        # Validate app exists
        if not validate_app_exists(app_name):
            logger.error(f"App not found: {app_name}")
            logger.info("Available apps:")
            for app in list_available_apps():
                logger.info(f"  {app}")
            sys.exit(1)

        # Ensure namespace exists
        self.ensure_namespace(namespace)

        # Determine deployment type and deploy accordingly
        deployment_type = get_app_deployment_type(app_name)
        app_dir = Path(f'software/apps/{app_name}')

        if deployment_type == 'helm':
            logger.info(f"Deploying {app_name} via Helm to namespace: {namespace}")
            self.deploy_helm_app(app_name, app_dir, namespace)
        elif deployment_type == 'kustomization':
            logger.info(f"Deploying {app_name} via Kustomization to namespace: {namespace}")
            self.deploy_kustomization_app(app_name, app_dir, namespace)
        elif deployment_type == 'legacy':
            logger.info(f"Deploying {app_name} via app.yaml to namespace: {namespace}")
            self.deploy_legacy_app(app_name, app_dir, namespace)
        else:
            logger.error(f"Unknown deployment type for {app_name}")
            sys.exit(1)

    def remove_application(self, app_name: str, namespace: str) -> None:
        """Remove an application."""
        # Validate app exists
        if not validate_app_exists(app_name):
            logger.error(f"App not found: {app_name}")
            logger.info("Available apps:")
            for app in list_available_apps():
                logger.info(f"  {app}")
            sys.exit(1)

        # Determine deployment type and remove accordingly
        deployment_type = get_app_deployment_type(app_name)
        app_dir = Path(f'software/apps/{app_name}')

        if deployment_type == 'helm':
            logger.info(f"Removing {app_name} via Helm from namespace: {namespace}")
            self.remove_helm_app(app_name, namespace)
        elif deployment_type == 'kustomization':
            logger.info(f"Removing {app_name} via Kustomization from namespace: {namespace}")
            self.remove_kustomization_app(app_name, app_dir, namespace)
        elif deployment_type == 'legacy':
            logger.info(f"Removing {app_name} via app.yaml from namespace: {namespace}")
            self.remove_legacy_app(app_name, app_dir, namespace)
        else:
            logger.error(f"Unknown deployment type for {app_name}")
            sys.exit(1)

        # Clean up namespace if it's empty and we created it
        self.cleanup_namespace_if_empty(namespace)


def show_usage() -> None:
    """Show usage information."""
    print("Usage: deploy-app.py [remove] [APP_NAME] [NAMESPACE]")
    print("")
    print("Deploy or remove an application to/from the cluster.")
    print("")
    print("Arguments:")
    print("  remove      Remove mode - removes the application")
    print("  APP_NAME    Application to deploy/remove (default: simple)")
    print("  NAMESPACE   Target namespace (default: default)")
    print("")

    apps = list_available_apps()
    if apps:
        print("Available applications:")
        for app in apps:
            print(f"  {app}")
    else:
        print("Available applications:")
        print("  No apps found")

    print("")
    print("Examples:")
    print("  deploy-app.py                     # Deploy default app (simple)")
    print("  deploy-app.py simple             # Deploy simple app to default namespace")
    print("  deploy-app.py advanced test      # Deploy advanced app to test namespace")
    print("  deploy-app.py remove simple      # Remove simple app from default namespace")
    print("  deploy-app.py remove voting-app test  # Remove voting-app from test namespace")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description='Deploy/remove applications', add_help=False)
    parser.add_argument('args', nargs='*', help='Arguments: [remove] [app_name] [namespace]')
    parser.add_argument('-h', '--help', action='store_true', help='Show help')

    args = parser.parse_args()

    if args.help:
        show_usage()
        return

    # Parse arguments similar to shell script
    operation = 'deploy'
    app_name = 'simple'
    namespace = 'default'

    if args.args:
        if args.args[0] == 'remove':
            operation = 'remove'
            app_name = args.args[1] if len(args.args) > 1 else 'simple'
            namespace = args.args[2] if len(args.args) > 2 else 'default'
        else:
            # Deploy mode
            app_name = args.args[0]
            namespace = args.args[1] if len(args.args) > 1 else 'default'

    deployer = AppDeployer()

    try:
        # Check prerequisites
        deployer.check_prerequisites()

        # Execute operation
        if operation == 'remove':
            deployer.remove_application(app_name, namespace)
        else:
            deployer.deploy_application(app_name, namespace)

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
