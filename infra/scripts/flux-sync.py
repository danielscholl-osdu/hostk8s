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
HostK8s Flux Sync Script (Python Implementation)

Force Flux reconciliation of GitOps resources with support for:
- Syncing all repositories and kustomizations
- Syncing specific stack (source + kustomization)
- Syncing specific GitRepository
- Syncing specific Kustomization

This replaces the shell script version with improved argument parsing,
better error handling, and more maintainable code structure.
"""

import argparse
import sys
from typing import List, Optional

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError, FluxError, KubectlError,
    run_kubectl, run_flux, has_flux, has_flux_cli
)


class FluxSyncer:
    """Handles Flux synchronization operations."""

    def check_prerequisites(self) -> None:
        """Check that cluster is running and Flux is installed."""
        # Check cluster connectivity
        try:
            result = run_kubectl(['cluster-info'], check=False, capture_output=True)
            if result.returncode != 0:
                logger.error("Cluster not running. Run 'make start' to start the cluster.")
                sys.exit(1)
        except Exception:
            logger.error("Cannot connect to cluster")
            sys.exit(1)

        # Check if Flux is installed
        if not has_flux():
            logger.error("Flux is not installed in this cluster")
            logger.info("Enable Flux with: make up sample")
            sys.exit(1)

        # Check if flux CLI is available
        if not has_flux_cli():
            logger.error("flux CLI not available")
            logger.info("Install with: make install")
            sys.exit(1)

    def sync_repository(self, repo_name: str) -> bool:
        """Sync a specific GitRepository."""
        logger.info(f"Syncing GitRepository: {repo_name}")

        try:
            run_flux(['reconcile', 'source', 'git', repo_name])
            logger.success(f"Successfully synced {repo_name}")
            return True
        except FluxError:
            logger.error(f"Failed to sync {repo_name}")
            return False

    def sync_kustomization(self, kust_name: str, with_source: bool = False) -> bool:
        """Sync a specific Kustomization."""
        logger.info(f"Syncing Kustomization: {kust_name}")

        try:
            cmd = ['reconcile', 'kustomization', kust_name]
            if with_source:
                cmd.append('--with-source')

            run_flux(cmd)
            logger.success(f"Successfully synced {kust_name}")
            return True
        except FluxError:
            logger.error(f"Failed to sync {kust_name}")
            return False

    def sync_stack(self, stack_name: str) -> bool:
        """Sync a specific stack (flux-system source + bootstrap kustomization)."""
        logger.info(f"Syncing stack: {stack_name}")

        # First sync the git source
        logger.info("  → Syncing flux-system repository")
        try:
            run_flux(['reconcile', 'source', 'git', 'flux-system'])
        except FluxError:
            logger.error("Failed to sync flux-system repository")
            return False

        # Then sync the bootstrap stack kustomization with source
        bootstrap_kust = "bootstrap-stack"
        logger.info(f"  → Syncing {bootstrap_kust} kustomization")
        try:
            run_flux(['reconcile', 'kustomization', bootstrap_kust, '--with-source'])
            logger.success(f"Successfully synced stack: {stack_name}")
            return True
        except FluxError:
            logger.error(f"Failed to sync stack: {stack_name}")
            return False

    def get_git_repositories(self) -> List[str]:
        """Get list of GitRepository names."""
        try:
            result = run_flux(['get', 'sources', 'git', '--no-header'], check=False)
            if result.returncode != 0 or not result.stdout.strip():
                return []

            repos = []
            for line in result.stdout.strip().split('\n'):
                if line.strip():
                    # First column is the name
                    repos.append(line.split()[0])
            return repos
        except Exception:
            return []

    def get_stack_kustomizations(self) -> List[str]:
        """Get list of stack-related Kustomization names."""
        try:
            result = run_flux(['get', 'kustomizations', '--no-header'], check=False)
            if result.returncode != 0 or not result.stdout.strip():
                return []

            kustomizations = []
            for line in result.stdout.strip().split('\n'):
                if line.strip():
                    name = line.split()[0]
                    # Include bootstrap-stack and anything ending with 'stack'
                    if name == 'bootstrap-stack' or name.endswith('stack'):
                        kustomizations.append(name)
            return kustomizations
        except Exception:
            return []

    def sync_all_repositories(self) -> bool:
        """Sync all GitRepositories and stack kustomizations."""
        logger.info("Syncing all GitRepositories and stack kustomizations...")

        # Get all repositories
        git_repos = self.get_git_repositories()
        if not git_repos:
            logger.warn("No GitRepositories found")
            return True

        # Sync all repositories
        failed_repos = []
        for repo in git_repos:
            print(f"  → Syncing repository: {repo}")
            try:
                run_flux(['reconcile', 'source', 'git', repo])
            except FluxError:
                print(f"  ❌ Failed to sync {repo}")
                failed_repos.append(repo)

        # Get and sync stack kustomizations
        stack_kustomizations = self.get_stack_kustomizations()
        failed_kustomizations = []
        for kust in stack_kustomizations:
            print(f"  → Syncing stack kustomization: {kust}")
            try:
                run_flux(['reconcile', 'kustomization', kust, '--with-source'])
            except FluxError:
                print(f"  ❌ Failed to sync {kust}")
                failed_kustomizations.append(kust)

        # Report results
        if failed_repos or failed_kustomizations:
            if failed_repos:
                logger.error(f"Failed to sync repositories: {', '.join(failed_repos)}")
            if failed_kustomizations:
                logger.error(f"Failed to sync kustomizations: {', '.join(failed_kustomizations)}")
            return False

        logger.success("All repositories and stack kustomizations synced successfully")
        return True


def show_usage() -> None:
    """Show usage information."""
    print("Usage: flux-sync.py [OPTIONS]")
    print("")
    print("Force Flux reconciliation of GitOps resources.")
    print("")
    print("Options:")
    print("  --stack STACK_NAME         Sync specific stack (source + kustomization)")
    print("  --repo REPO_NAME           Sync specific GitRepository")
    print("  --kustomization KUST_NAME  Sync specific Kustomization")
    print("  -h, --help                 Show this help")
    print("")
    print("Examples:")
    print("  flux-sync.py                              # Sync all sources and stacks")
    print("  flux-sync.py --stack sample               # Sync source + sample stack")
    print("  flux-sync.py --repo my-repo              # Sync specific repository")
    print("  flux-sync.py --kustomization my-kust     # Sync specific kustomization")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description='Force Flux reconciliation', add_help=False)
    parser.add_argument('--stack', help='Sync specific stack (source + kustomization)')
    parser.add_argument('--repo', help='Sync specific GitRepository')
    parser.add_argument('--kustomization', help='Sync specific Kustomization')
    parser.add_argument('-h', '--help', action='store_true', help='Show help')

    args = parser.parse_args()

    if args.help:
        show_usage()
        return

    syncer = FluxSyncer()

    try:
        # Check prerequisites
        syncer.check_prerequisites()

        logger.info("Forcing Flux reconciliation...")

        # Sync based on arguments
        success = False
        if args.stack:
            success = syncer.sync_stack(args.stack)
        elif args.repo:
            success = syncer.sync_repository(args.repo)
        elif args.kustomization:
            success = syncer.sync_kustomization(args.kustomization)
        else:
            success = syncer.sync_all_repositories()

        if success:
            logger.success("Sync complete! Run 'make status' to check results.")
        else:
            logger.error("Sync completed with errors")
            sys.exit(1)

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
