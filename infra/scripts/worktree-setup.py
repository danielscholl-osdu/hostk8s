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
HostK8s Worktree Setup Automation Script (Python Implementation)

Creates isolated development environments using git worktrees.
Each worktree gets its own cluster with unique ports and GitOps configuration.

Usage:
  worktree-setup.py           # Creates 'dev' worktree
  worktree-setup.py auth      # Creates 'auth' worktree
  worktree-setup.py 3         # Creates dev1, dev2, dev3 worktrees
"""

import hashlib
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional, Tuple, List

import yaml

# Import common utilities
from hostk8s_common import (
    logger, get_env, load_environment
)


class WorktreeSetup:
    """Handles worktree creation and configuration."""

    # Base ports for Kind cluster
    BASE_API_PORT = 6443
    BASE_HTTP_PORT = 8080
    BASE_HTTPS_PORT = 8443
    BASE_REGISTRY_PORT = 5001

    def __init__(self):
        self.script_dir = Path(__file__).parent  # Scripts directory
        self.project_root = self.script_dir.parent.parent  # Go up to project root
        self.git_user = self.get_git_user()
        self.current_worktree_dir = None

    def get_git_user(self) -> str:
        """Get normalized git username."""
        try:
            result = subprocess.run(['git', 'config', 'user.name'],
                                  capture_output=True, text=True, check=False)
            user_name = result.stdout.strip() if result.returncode == 0 else "user"
        except Exception:
            user_name = "user"

        # Normalize: lowercase and replace spaces with hyphens
        git_user = user_name.lower().replace(' ', '-')
        logger.debug(f"Normalized git user: {git_user}")
        return git_user

    def validate_prerequisites(self) -> None:
        """Validate that we're in the right environment."""
        # Check if we're in a git repository
        try:
            subprocess.run(['git', 'rev-parse', '--git-dir'],
                         capture_output=True, check=True)
        except subprocess.CalledProcessError:
            logger.error("Not in a git repository")
            sys.exit(1)

        # Check if we're in the project root
        if not (self.project_root / "Makefile").exists() or \
           not (self.project_root / "infra").exists():
            logger.error("Must be run from HostK8s project root")
            sys.exit(1)

        # Check for required tools
        for tool in ['git', 'make']:
            if not shutil.which(tool):
                logger.error(f"Missing required tool: {tool}")
                sys.exit(1)

    def calculate_ports(self, name: str) -> int:
        """Calculate unique port offset for a worktree."""
        # Predefined offsets for common names
        predefined = {
            "dev": 0, "dev1": 1, "dev2": 2, "dev3": 3, "dev4": 4, "dev5": 5,
            "auth": 10, "backend": 11, "frontend": 12, "api": 13, "database": 14
        }

        if name in predefined:
            return predefined[name]

        # Calculate based on name hash for unknown names
        name_hash = hashlib.md5(name.encode()).hexdigest()
        offset = (int(name_hash[:8], 16) % 50) + 20
        return offset

    def create_kind_config(self, name: str, worktree_dir: Path) -> None:
        """Create custom Kind config with unique ports."""
        offset = self.calculate_ports(name)

        api_port = self.BASE_API_PORT + offset
        http_port = self.BASE_HTTP_PORT + offset
        https_port = self.BASE_HTTPS_PORT + offset
        registry_port = self.BASE_REGISTRY_PORT + offset

        logger.debug(f"Allocating ports for {name}: API={api_port}, HTTP={http_port}, "
                    f"HTTPS={https_port}, Registry={registry_port}")

        # Create extension directory
        extension_dir = worktree_dir / "infra" / "kubernetes" / "extension"
        extension_dir.mkdir(parents=True, exist_ok=True)

        # Read base config
        base_config_path = self.project_root / "infra" / "kubernetes" / "kind-config.yaml"
        with open(base_config_path, 'r') as f:
            config = yaml.safe_load(f)

        # Update configuration
        config['name'] = name

        # Update port mappings
        if 'nodes' in config:
            for node in config['nodes']:
                if 'extraPortMappings' in node:
                    for mapping in node['extraPortMappings']:
                        if mapping.get('hostPort') == 8080:
                            mapping['hostPort'] = http_port
                        elif mapping.get('hostPort') == 8443:
                            mapping['hostPort'] = https_port

        # Write custom config
        custom_config_path = extension_dir / f"kind-{name}.yaml"
        with open(custom_config_path, 'w') as f:
            yaml.dump(config, f, default_flow_style=False, sort_keys=False)

        logger.debug(f"Created custom Kind config: infra/kubernetes/extension/kind-{name}.yaml")

    def configure_environment(self, name: str, worktree_dir: Path) -> None:
        """Configure environment for a worktree."""
        logger.debug(f"Configuring environment for worktree: {name}")

        # Copy environment template
        env_example = self.project_root / ".env.example"
        env_file = worktree_dir / ".env"

        if env_example.exists():
            shutil.copy(env_example, env_file)
        else:
            # Create minimal .env if example doesn't exist
            env_file.touch()

        # Read and update environment file
        env_content = []
        if env_file.exists():
            with open(env_file, 'r') as f:
                env_content = f.readlines()

        # Update or add configuration values
        env_vars = {
            'CLUSTER_NAME': name,
            'KIND_CONFIG': f'extension/kind-{name}',
            'GITOPS_BRANCH': f'user/{self.git_user}/{name}',
            'SOFTWARE_STACK': 'sample',
            'FLUX_ENABLED': 'true'
        }

        # Update existing or append new
        updated_lines = []
        updated_keys = set()

        for line in env_content:
            if '=' in line and not line.strip().startswith('#'):
                key = line.split('=')[0].strip()
                if key in env_vars:
                    updated_lines.append(f"{key}={env_vars[key]}\n")
                    updated_keys.add(key)
                else:
                    updated_lines.append(line)
            else:
                updated_lines.append(line)

        # Add missing keys
        for key, value in env_vars.items():
            if key not in updated_keys:
                updated_lines.append(f"{key}={value}\n")

        # Write updated configuration
        with open(env_file, 'w') as f:
            f.writelines(updated_lines)

        logger.success(f"Environment configured for {name}")

    def retry_with_backoff(self, description: str, func, *args, **kwargs) -> bool:
        """Retry a function with exponential backoff."""
        max_attempts = 3
        delay = 2

        for attempt in range(1, max_attempts + 1):
            logger.debug(f"Attempt {attempt}: {description}")
            try:
                result = func(*args, **kwargs)
                if result:
                    return True
            except Exception as e:
                if attempt == max_attempts:
                    logger.error(f"Failed after {max_attempts} attempts: {description}")
                    logger.debug(f"Error: {e}")
                    return False
                logger.warn(f"Attempt {attempt} failed, retrying in {delay}s...")
                time.sleep(delay)
                delay *= 2

        return False

    def run_git_command(self, args: List[str], cwd: Optional[Path] = None) -> bool:
        """Run a git command and return success status."""
        try:
            result = subprocess.run(['git'] + args,
                                  capture_output=True, text=True,
                                  cwd=cwd, check=False)
            return result.returncode == 0
        except Exception:
            return False

    def create_worktree(self, name: str) -> None:
        """Create a single worktree."""
        worktree_dir = self.project_root / "trees" / name
        branch_name = f"user/{self.git_user}/{name}"

        logger.info(f"Creating worktree: {name}")

        # Set for cleanup purposes
        self.current_worktree_dir = worktree_dir

        # Create trees directory if it doesn't exist
        (self.project_root / "trees").mkdir(parents=True, exist_ok=True)

        # Check if branch exists
        branch_exists = self.run_git_command(['show-ref', '--verify', '--quiet',
                                             f'refs/heads/{branch_name}'])

        # Create worktree
        if branch_exists:
            logger.debug(f"Branch {branch_name} already exists, using existing branch")
            if not self.retry_with_backoff("Adding worktree from existing branch",
                                          self.run_git_command,
                                          ['worktree', 'add', str(worktree_dir), branch_name]):
                logger.error("Failed to create worktree from existing branch")
                sys.exit(1)
        else:
            logger.debug(f"Creating new branch: {branch_name}")
            if not self.retry_with_backoff("Adding worktree with new branch",
                                          self.run_git_command,
                                          ['worktree', 'add', '-b', branch_name, str(worktree_dir)]):
                logger.error("Failed to create worktree with new branch")
                sys.exit(1)

        # Configure environment
        self.configure_environment(name, worktree_dir)

        # Create custom Kind config
        self.create_kind_config(name, worktree_dir)

        # Check if branch exists on remote
        remote_exists = self.run_git_command(['ls-remote', '--exit-code', '--heads',
                                             'origin', branch_name])

        if not remote_exists:
            logger.debug("Pushing new branch to remote")

            # Add files to git
            files_to_add = []
            env_file = worktree_dir / ".env"
            if env_file.exists():
                files_to_add.append(".env")

            kind_config = worktree_dir / "infra" / "kubernetes" / "extension" / f"kind-{name}.yaml"
            if kind_config.exists():
                files_to_add.append(f"infra/kubernetes/extension/kind-{name}.yaml")

            if files_to_add:
                logger.debug(f"Adding files to git: {files_to_add}")
                for file in files_to_add:
                    self.run_git_command(['add', file], cwd=worktree_dir)

            # Commit changes
            commit_message = f"""Initialize {name} development branch

- Environment configured for {name} cluster
- Custom Kind config with unique ports
- GitOps enabled for branch {branch_name}"""

            # Check if there are changes to commit
            has_changes = not self.run_git_command(['diff', '--staged', '--quiet'],
                                                  cwd=worktree_dir)

            if has_changes:
                self.run_git_command(['commit', '-m', commit_message], cwd=worktree_dir)
            else:
                # Create empty commit if no changes
                self.run_git_command(['commit', '--allow-empty', '-m', commit_message],
                                   cwd=worktree_dir)

            # Push to remote
            if not self.retry_with_backoff("Pushing branch to remote",
                                          self.run_git_command,
                                          ['push', '-u', 'origin', branch_name],
                                          cwd=worktree_dir):
                logger.error("Failed to push branch after multiple attempts")
                sys.exit(1)

        # Start cluster
        logger.info(f"Starting cluster: {name}")
        os.chdir(worktree_dir)
        subprocess.run(['make', 'start'], check=False)
        os.chdir(self.project_root)

        # Clear the current worktree directory since creation was successful
        self.current_worktree_dir = None

        logger.success(f"Worktree {name} created and cluster started")

    def create_numbered_worktrees(self, count: int) -> None:
        """Create multiple numbered worktrees."""
        logger.info(f"Creating {count} numbered worktrees")

        for i in range(1, count + 1):
            name = f"dev{i}"
            self.create_worktree(name)

        logger.success(f"All {count} worktrees created and clusters started")

    def cleanup_on_failure(self) -> None:
        """Cleanup function for partial failures."""
        if self.current_worktree_dir and self.current_worktree_dir.exists():
            logger.debug(f"Removing incomplete worktree: {self.current_worktree_dir}")
            try:
                shutil.rmtree(self.current_worktree_dir)
            except Exception:
                pass

            # Prune orphaned git worktree entries
            subprocess.run(['git', 'worktree', 'prune'],
                         capture_output=True, check=False)

    def show_final_status(self) -> None:
        """Show final status and usage information."""
        logger.info("Worktree setup complete!")
        logger.info("Active worktrees:")

        result = subprocess.run(['git', 'worktree', 'list'],
                              capture_output=True, text=True, check=False)
        if result.returncode == 0:
            for line in result.stdout.strip().split('\n'):
                logger.info(f"  {line}")

        logger.info("")
        logger.info("To switch between worktrees:")
        logger.info("  cd trees/[worktree-name]")
        logger.info("  make status")


def main() -> None:
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Setup isolated development environments using git worktrees',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s           # Creates 'dev' worktree
  %(prog)s auth      # Creates 'auth' worktree
  %(prog)s 3         # Creates dev1, dev2, dev3 worktrees

Each worktree gets:
  - Isolated git branch (user/$GIT_USER/name)
  - Dedicated cluster with unique ports
  - GitOps configuration
  - Custom environment settings
        """
    )

    parser.add_argument('target', nargs='?', default='dev',
                       help='Worktree name or number of worktrees to create')

    args = parser.parse_args()

    # Load environment
    load_environment()

    logger.info("HostK8s Worktree Setup")

    # Create setup instance
    setup = WorktreeSetup()

    try:
        # Validate environment
        setup.validate_prerequisites()

        # Determine what to create
        target = args.target

        if target.isdigit():
            # Create numbered worktrees
            count = int(target)
            if count < 1 or count > 10:
                logger.error("Number must be between 1-10")
                sys.exit(1)
            setup.create_numbered_worktrees(count)
        else:
            # Validate name
            if not all(c.isalnum() or c in '-_' for c in target):
                logger.error(f"Invalid name: '{target}'. Use alphanumeric characters, hyphens, or underscores only.")
                sys.exit(1)
            # Create named worktree
            setup.create_worktree(target)

        # Show final status
        setup.show_final_status()

    except KeyboardInterrupt:
        logger.warn("Operation cancelled by user")
        setup.cleanup_on_failure()
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        setup.cleanup_on_failure()
        sys.exit(1)


if __name__ == '__main__':
    main()
