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
HostK8s Deploy Stack Script (Python Implementation)

Deploy or remove GitOps software stack to/from existing HostK8s cluster.

Usage:
  deploy-stack.py [stack-name]         # Deploy a stack
  deploy-stack.py down [stack-name]    # Remove a stack

Examples:
  deploy-stack.py sample                # Deploy sample stack
  deploy-stack.py down sample           # Remove sample stack
  deploy-stack.py extension/my-stack    # Deploy extension stack
"""

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path
from string import Template
from typing import Optional, Dict, Any

# Import common utilities
from hostk8s_common import (
    logger, get_env, load_environment, run_kubectl, check_cluster_running
)


class StackDeployer:
    """Handles software stack deployment and removal operations."""

    def __init__(self):
        self.cluster_name = get_env('CLUSTER_NAME', 'hostk8s')
        self.kubeconfig_path = get_env('KUBECONFIG_PATH', 'data/kubeconfig/config')
        self.gitops_repo = get_env('GITOPS_REPO', 'https://community.opengroup.org/danielscholl/hostk8s')
        self.gitops_branch = get_env('GITOPS_BRANCH', 'main')
        self.components_repo = get_env('COMPONENTS_REPO', self.gitops_repo)
        self.components_branch = get_env('COMPONENTS_BRANCH', self.gitops_branch)
        self.repo_name = os.path.basename(self.gitops_repo.rstrip('.git'))

    def run_script(self, script_name: str, *args) -> bool:
        """Run a script (Python or shell) from the scripts directory."""
        script_dir = Path(__file__).parent  # Scripts directory

        # Try Python script first
        python_script = script_dir / f"{script_name}.py"
        if python_script.exists():
            logger.info(f"[Script 🐍] Running script: [cyan]{script_name}.py[/cyan]")
            env = os.environ.copy()
            env['FLUX_ENABLED'] = 'true'
            result = subprocess.run(['uv', 'run', str(python_script)] + list(args),
                                  env=env, check=False)
            return result.returncode == 0

        # Fall back to shell script
        shell_script = script_dir / f"{script_name}.sh"
        if shell_script.exists():
            logger.debug(f"Running shell script: {shell_script}")
            env = os.environ.copy()
            env['FLUX_ENABLED'] = 'true'
            result = subprocess.run([str(shell_script)] + list(args),
                                  env=env, check=False)
            return result.returncode == 0

        logger.error(f"Script not found: {script_name}")
        return False

    def cluster_exists(self) -> bool:
        """Check if the Kind cluster exists."""
        try:
            result = subprocess.run(['kind', 'get', 'clusters'],
                                  capture_output=True, text=True, check=False)
            clusters = result.stdout.strip().split('\n') if result.stdout else []
            return self.cluster_name in clusters
        except Exception:
            return False

    def setup_kubeconfig(self) -> None:
        """Set up kubeconfig if needed."""
        kubeconfig = Path(self.kubeconfig_path)
        if not kubeconfig.exists():
            logger.info("Setting up kubeconfig")
            kubeconfig.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(['kind', 'export', 'kubeconfig',
                          '--name', self.cluster_name,
                          '--kubeconfig', self.kubeconfig_path], check=True)

    def is_cluster_ready(self) -> bool:
        """Check if cluster is ready."""
        try:
            result = run_kubectl(['cluster-info'], check=False, capture_output=True)
            return result.returncode == 0
        except Exception:
            return False

    def flux_is_installed(self) -> bool:
        """Check if Flux is installed and running."""
        try:
            # Check if flux-system namespace exists
            result = run_kubectl(['get', 'namespace', 'flux-system'],
                               check=False, capture_output=True)
            if result.returncode != 0:
                return False

            # Check if Flux pods are running
            result = run_kubectl(['get', 'pods', '-n', 'flux-system',
                                '-l', 'app.kubernetes.io/part-of=flux', '--no-headers'],
                               check=False, capture_output=True)
            return 'Running' in result.stdout
        except Exception:
            return False

    def remove_stack(self, stack_name: str) -> None:
        """Remove a software stack from the cluster."""
        # Check if cluster exists
        if not self.cluster_exists():
            logger.error(f"Cluster '{self.cluster_name}' does not exist")
            sys.exit(1)

        # Set up kubeconfig if needed
        self.setup_kubeconfig()

        # Check if cluster is ready
        if not self.is_cluster_ready():
            logger.error(f"Cluster '{self.cluster_name}' is not ready")
            sys.exit(1)

        # Check if any kustomizations exist for this stack
        logger.info(f"[Stack] Checking for stack '{stack_name}' kustomizations")

        # Extract stack name from path for labeling
        stack_name_only = stack_name.split('/')[-1]
        result = run_kubectl(['get', 'kustomizations', '-n', 'flux-system',
                            '-l', f'hostk8s.stack={stack_name_only}', '--no-headers',
                            '-o', 'custom-columns=NAME:.metadata.name'],
                           check=False, capture_output=True)

        stack_kustomizations = result.stdout.strip() if result.returncode == 0 else ""

        if not stack_kustomizations:
            logger.info(f"[Stack] No kustomizations found for stack '{stack_name}'")
            logger.info("[Stack] Nothing to remove - stack is already clean")
            return

        logger.info(f"[Stack] Found kustomizations for stack '{stack_name}' - proceeding with removal")

        # Remove the bootstrap kustomization first (if it exists)
        stack_name_only = stack_name.split('/')[-1]
        result = run_kubectl(['get', 'kustomization', f'bootstrap-{stack_name_only}',
                            '-n', 'flux-system', '--no-headers'],
                           check=False, capture_output=True)
        if result.returncode == 0:
            logger.info(f"[Stack] Removing bootstrap kustomization: bootstrap-{stack_name_only}")
            run_kubectl(['delete', 'kustomization', f'bootstrap-{stack_name_only}',
                        '-n', 'flux-system'], check=False)

        # Remove all kustomizations labeled with this stack
        logger.info(f"[Stack] Removing all kustomizations for stack '{stack_name}'")
        run_kubectl(['delete', 'kustomizations', '-n', 'flux-system',
                    '-l', f'hostk8s.stack={stack_name_only}'], check=False)

        # Clean up the stack-specific GitRepository
        if stack_name.startswith('extension/'):
            logger.info("[Stack] Cleaning up extension GitRepository")
            run_kubectl(['delete', 'gitrepository', 'extension-stack-system',
                        '-n', 'flux-system'], check=False)
        else:
            logger.info(f"[Stack] Cleaning up stack-specific GitRepository: flux-system-{stack_name_only}")
            run_kubectl(['delete', 'gitrepository', f'flux-system-{stack_name_only}',
                        '-n', 'flux-system'], check=False)

            # Check if any component kustomizations remain (from any stack)
            logger.info("[Stack] Checking if flux-system GitRepository is still needed")
            result = run_kubectl(['get', 'kustomizations', '-n', 'flux-system',
                                '-l', 'hostk8s.type=component', '--no-headers'],
                               check=False, capture_output=True)

            component_count = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0

            if component_count == 0:
                logger.info("[Stack] No component kustomizations remaining, removing shared GitRepository")
                run_kubectl(['delete', 'gitrepository', 'flux-system',
                            '-n', 'flux-system'], check=False)
            else:
                logger.info(f"[Stack] Found {component_count} component kustomization(s) remaining, keeping shared GitRepository")

        logger.success(f"[Stack] Software stack '{stack_name}' removal initiated")
        logger.info("[Stack] Flux will complete the cleanup automatically (may take 1-2 minutes)")
        logger.info("[Stack] Monitor with: kubectl get all --all-namespaces | grep -v flux-system")

    def apply_stack_yaml(self, yaml_file: Path, description: str, stack_name: str) -> None:
        """Apply stack YAML files with template substitution support."""
        if not yaml_file.exists():
            logger.error(f"Stack configuration not found: {yaml_file}")
            logger.error("Available stacks:")
            stacks_dir = Path("software/stacks")
            if stacks_dir.exists():
                for stack_dir in stacks_dir.iterdir():
                    if stack_dir.is_dir():
                        logger.error(f"  {stack_dir.name}")
            sys.exit(1)

        logger.info(description)

        # Read the YAML file
        with open(yaml_file, 'r') as f:
            yaml_content = f.read()

        # Check if template processing is needed
        if 'extension/' in str(yaml_file) or '${' in yaml_content:
            logger.info("[Stack] Processing template variables for stack file")
            # Create template and substitute variables
            template = Template(yaml_content)
            # Extract stack name from path (e.g., "foundation/elastic" -> "elastic")
            stack_name_only = stack_name.split('/')[-1]
            yaml_content = template.safe_substitute(
                REPO_NAME=self.repo_name,
                GITOPS_REPO=self.gitops_repo,
                GITOPS_BRANCH=self.gitops_branch,
                SOFTWARE_STACK=stack_name_only,
                SOFTWARE_STACK_PATH=stack_name,
                COMPONENTS_REPO=self.components_repo,
                COMPONENTS_BRANCH=self.components_branch
            )

        # Apply the YAML
        try:
            process = subprocess.run(['kubectl', 'apply', '-f', '-'],
                                   input=yaml_content, text=True,
                                   capture_output=True, check=False)
            if process.returncode != 0:
                logger.warn(f"Failed to apply {description}")
                if process.stderr:
                    logger.debug(process.stderr)
        except Exception as e:
            logger.warn(f"Failed to apply {description}: {e}")

    def stack_uses_components(self, stack_name: str) -> bool:
        """Check if the stack uses components."""
        stack_yaml = Path(f"software/stacks/{stack_name}/stack.yaml")
        if stack_yaml.exists():
            with open(stack_yaml, 'r') as f:
                content = f.read()
                return "./software/components/" in content
        return False

    def wait_for_gitrepository_sync(self) -> None:
        """Wait for GitRepository to sync."""
        logger.info("[Stack] Waiting for GitRepository to sync")
        timeout = 60
        while timeout > 0:
            result = run_kubectl(['get', 'gitrepository', '-n', 'flux-system',
                                '-o', 'jsonpath={.items[*].status.conditions[?(@.type=="Ready")].status}'],
                               check=False, capture_output=True)
            if 'True' in result.stdout:
                logger.info("[Stack] GitRepository synced successfully")
                break
            time.sleep(2)
            timeout -= 2

        if timeout <= 0:
            logger.warn("GitRepository sync timed out, but continuing")

    def deploy_stack(self, stack_name: str) -> None:
        """Deploy a software stack to the cluster."""
        # Check if cluster exists
        if not self.cluster_exists():
            logger.error(f"Cluster '{self.cluster_name}' does not exist")
            logger.error("Create cluster first: make start")
            sys.exit(1)

        # Set up kubeconfig if needed
        self.setup_kubeconfig()

        # Check if cluster is ready
        if not self.is_cluster_ready():
            logger.error(f"Cluster '{self.cluster_name}' is not ready")
            sys.exit(1)

        # Check if Flux is installed, install if not
        if not self.flux_is_installed():
            logger.info("[Stack] Flux not found. Installing Flux first")
            if not self.run_script('setup-flux'):
                logger.error("Failed to install Flux")
                sys.exit(1)
        else:
            logger.info("[Stack] Flux is already installed and running")

        logger.info(f"[Stack] Deploying software stack '{stack_name}'")

        # Check if the stack uses components
        uses_components = self.stack_uses_components(stack_name)

        # Apply component GitRepository if stack uses components
        if uses_components:
            source_component = Path("software/stacks/source-component.yaml")
            if source_component.exists():
                self.apply_stack_yaml(source_component,
                                    f"[Stack] Configuring components repository for stack: {stack_name}",
                                    stack_name)

        # Always apply stack-specific GitRepository
        source_stack = Path("software/stacks/source-stack.yaml")
        if source_stack.exists():
            self.apply_stack_yaml(source_stack,
                                f"[Stack] Configuring stack repository for stack: {stack_name}",
                                stack_name)

        # Apply bootstrap kustomization - different for extension vs local stacks
        if stack_name.startswith('extension/'):
            logger.info("[Stack] Setting up GitOps bootstrap configuration for extension stack")
            # Create dynamic bootstrap for extension stack
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
  path: ./software/stacks/{stack_name}
  targetNamespace: flux-system
  prune: true
  wait: false
"""
            process = subprocess.run(['kubectl', 'apply', '-f', '-'],
                                   input=bootstrap_yaml, text=True,
                                   capture_output=True, check=False)
            if process.returncode != 0:
                logger.warn("Failed to apply bootstrap configuration")
        else:
            bootstrap_yaml = Path("software/stacks/bootstrap.yaml")
            if bootstrap_yaml.exists():
                self.apply_stack_yaml(bootstrap_yaml,
                                    "[Stack] Setting up GitOps bootstrap configuration",
                                    stack_name)

        # Wait for GitRepository to sync
        self.wait_for_gitrepository_sync()

        # Show deployment status
        logger.info(f"[Stack] Software stack '{stack_name}' deployment completed!")
        logger.success(f"[Stack] Software stack '{stack_name}' deployed successfully!")
        logger.info("Monitor deployment: make status")


def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Deploy or remove GitOps software stack',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s sample                # Deploy sample stack
  %(prog)s down sample           # Remove sample stack
  %(prog)s extension/my-stack    # Deploy extension stack
        """
    )

    parser.add_argument('operation', nargs='?',
                       help='Operation: stack name to deploy, or "down" to remove')
    parser.add_argument('stack_name', nargs='?',
                       help='Stack name (required when operation is "down")')

    args = parser.parse_args()

    # Load environment
    load_environment()

    # Determine operation and stack name
    if args.operation == 'down':
        if not args.stack_name:
            # Check environment variable
            stack_name = get_env('SOFTWARE_STACK', '')
            if not stack_name:
                logger.error("Stack name must be specified for down operation")
                parser.print_help()
                sys.exit(1)
        else:
            stack_name = args.stack_name
        operation = 'down'
    else:
        # Legacy mode - first argument is the stack name
        stack_name = args.operation or get_env('SOFTWARE_STACK', '')
        if not stack_name:
            logger.error("SOFTWARE_STACK must be specified")
            parser.print_help()
            sys.exit(1)
        operation = 'deploy'

    # Log script execution
    script_name = Path(__file__).name
    if operation == 'down':
        logger.info(f"[Script 🐍] Running script: [cyan]{script_name}[/cyan] [yellow]down {stack_name}[/yellow]")
    else:
        logger.info(f"[Script 🐍] Running script: [cyan]{script_name}[/cyan] [green]{stack_name}[/green]")

    # Create deployer instance
    deployer = StackDeployer()

    try:
        if operation == 'down':
            logger.info(f"[Stack] Removing software stack '{stack_name}'")
            deployer.remove_stack(stack_name)
        else:
            logger.info(f"[Stack] Deploying software stack '{stack_name}'")
            deployer.deploy_stack(stack_name)
    except KeyboardInterrupt:
        logger.warn("Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
