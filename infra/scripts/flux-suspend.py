#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "rich>=13.0.0",
#     "pyyaml>=6.0",
#     "requests>=2.28.0",
# ]
# ///

"""
HostK8s Flux Suspend/Resume Script (Python Implementation)

Suspend or resume all Flux GitRepository sources.
This allows pausing and restoring GitOps reconciliation.

Commands:
  suspend    Suspend all GitRepository sources (pause GitOps)
  resume     Resume all GitRepository sources (restore GitOps)

Examples:
  flux-suspend.py suspend     # Pause all GitOps reconciliation
  flux-suspend.py resume      # Restore all GitOps reconciliation
"""

import sys
import argparse
import subprocess
from typing import List, Tuple

# Import common utilities
from hostk8s_common import (
    logger, load_environment, check_cluster_running, has_flux, has_flux_cli
)


def run_flux_command(args: list, check: bool = True, capture_output: bool = True) -> subprocess.CompletedProcess:
    """Run a flux CLI command."""
    cmd = ['flux'] + args
    result = subprocess.run(cmd, capture_output=capture_output, text=True, check=False)

    if check and result.returncode != 0:
        raise subprocess.CalledProcessError(result.returncode, cmd, result.stdout, result.stderr)

    return result


def get_git_repositories() -> List[str]:
    """Get list of all GitRepository sources."""
    try:
        result = run_flux_command(['get', 'sources', 'git', '--no-header'], check=False)
        if result.returncode != 0 or not result.stdout:
            return []

        # Parse the output to get repository names (first column)
        repos = []
        for line in result.stdout.strip().split('\n'):
            if line:
                parts = line.split()
                if parts:
                    repos.append(parts[0])
        return repos
    except Exception as e:
        logger.debug(f"Error getting repositories: {e}")
        return []


def suspend_repositories() -> Tuple[int, List[str]]:
    """
    Suspend all GitRepository sources.
    Returns (success_count, failed_repos).
    """
    logger.info("Suspending all GitRepository sources...")

    git_repos = get_git_repositories()

    if not git_repos:
        logger.warn("No GitRepositories found")
        return (0, [])

    failed_repos = []
    suspended_count = 0

    for repo in git_repos:
        logger.info(f"  → Suspending repository: {repo}")
        try:
            result = run_flux_command(['suspend', 'source', 'git', repo], check=False)
            if result.returncode == 0:
                suspended_count += 1
            else:
                logger.error(f"  ❌ Failed to suspend {repo}")
                failed_repos.append(repo)
        except Exception as e:
            logger.error(f"  ❌ Failed to suspend {repo}: {e}")
            failed_repos.append(repo)

    if failed_repos:
        logger.error(f"Failed to suspend repositories: {', '.join(failed_repos)}")
        return (suspended_count, failed_repos)

    logger.success(f"Successfully suspended {suspended_count} GitRepository sources")
    logger.info("GitOps reconciliation is now paused. Use 'make resume' to restore.")
    return (suspended_count, [])


def resume_repositories() -> Tuple[int, List[str]]:
    """
    Resume all GitRepository sources.
    Returns (success_count, failed_repos).
    """
    logger.info("Resuming all GitRepository sources...")

    git_repos = get_git_repositories()

    if not git_repos:
        logger.warn("No GitRepositories found")
        return (0, [])

    failed_repos = []
    resumed_count = 0

    for repo in git_repos:
        logger.info(f"  → Resuming repository: {repo}")
        try:
            result = run_flux_command(['resume', 'source', 'git', repo], check=False)
            if result.returncode == 0:
                resumed_count += 1
            else:
                logger.error(f"  ❌ Failed to resume {repo}")
                failed_repos.append(repo)
        except Exception as e:
            logger.error(f"  ❌ Failed to resume {repo}: {e}")
            failed_repos.append(repo)

    if failed_repos:
        logger.error(f"Failed to resume repositories: {', '.join(failed_repos)}")
        return (resumed_count, failed_repos)

    logger.success(f"Successfully resumed {resumed_count} GitRepository sources")
    logger.info("GitOps reconciliation is now active. Use 'make sync' to force reconciliation.")
    return (resumed_count, [])


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Suspend or resume Flux GitRepository sources',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s suspend     # Pause all GitOps reconciliation
  %(prog)s resume      # Restore all GitOps reconciliation
        """
    )

    parser.add_argument(
        'action',
        choices=['suspend', 'resume'],
        help='Action to perform'
    )

    args = parser.parse_args()

    # Load environment
    load_environment()

    # Ensure cluster exists and is running
    try:
        check_cluster_running()
    except Exception as e:
        logger.error(str(e))
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

    logger.info("Managing GitRepository sources...")

    # Execute action
    if args.action == 'suspend':
        success_count, failed_repos = suspend_repositories()
        if failed_repos:
            sys.exit(1)
    elif args.action == 'resume':
        success_count, failed_repos = resume_repositories()
        if failed_repos:
            sys.exit(1)

    logger.success("Operation complete! Run 'make status' to check results.")


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        logger.warn("Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)
