#!/usr/bin/env -S uv run
# -*- coding: utf-8 -*-
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "pyyaml>=6.0.2",
#     "rich>=14.1.0",
#     "requests>=2.32.5"
# ]
# ///

"""
HostK8s Development Environment Setup Script (Python Implementation)

Setup development environment by configuring pre-commit hooks.
This script checks for required tools and sets up git commit hooks.

Note: Tool installation should be done via 'make install'.
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path
from typing import Optional

# Import common utilities
from hostk8s_common import (
    logger, load_environment, get_env
)


class DevelopmentSetup:
    """Handles development environment setup operations."""

    def __init__(self):
        self.home_local_bin = Path.home() / ".local" / "bin"
        self.precommit_config = Path(".pre-commit-config.yaml")

    def check_command(self, command: str) -> bool:
        """Check if a command is available in PATH."""
        return shutil.which(command) is not None

    def ensure_path_configured(self) -> None:
        """Ensure user's local bin is in PATH."""
        # Add to current session
        current_path = get_env('PATH', '')
        local_bin_str = str(self.home_local_bin)
        if local_bin_str not in current_path:
            os.environ['PATH'] = f"{local_bin_str}:{current_path}"
            logger.debug(f"Added {local_bin_str} to PATH for this session")

    def check_prerequisites(self) -> bool:
        """Check if required tools are installed."""
        all_tools_present = True

        # Check for pre-commit
        if not self.check_command('pre-commit'):
            logger.warn("pre-commit is not installed, installing...")
            if not self.install_dev_tools():
                logger.error("Failed to install pre-commit")
                all_tools_present = False
            else:
                logger.info("✓ pre-commit installed successfully")
        else:
            logger.info("✓ pre-commit is installed")

        # Check for yamllint
        if not self.check_command('yamllint'):
            logger.warn("yamllint is not installed (optional but recommended)")
            logger.info("Installing yamllint...")
            self.install_yamllint()  # Don't fail if yamllint install fails
        else:
            logger.info("✓ yamllint is installed")

        return all_tools_present

    def install_dev_tools(self) -> bool:
        """Install pre-commit using pip."""
        try:
            # Determine the appropriate pip command based on environment
            # This is environment-aware, not OS-aware
            if 'uv' in sys.executable.lower() or get_env('UV_PROJECT_ROOT'):
                pip_cmd = ['uv', 'pip']
                logger.info("Installing pre-commit using uv pip...")
            else:
                # Find available pip command
                pip_exe = shutil.which('pip') or shutil.which('pip3')
                if not pip_exe:
                    logger.error("pip is not available. Please install Python with pip.")
                    return False
                pip_cmd = [pip_exe]
                logger.info(f"Installing pre-commit using {os.path.basename(pip_exe)}...")

            # Install pre-commit
            result = subprocess.run(pip_cmd + ['install', 'pre-commit'],
                                  capture_output=True, text=True, check=False)

            if result.returncode == 0:
                return True
            else:
                logger.error(f"Failed to install pre-commit: {result.stderr}")
                return False

        except Exception as e:
            logger.error(f"Failed to install pre-commit: {e}")
            return False

    def install_yamllint(self) -> bool:
        """Install yamllint using pip (optional tool)."""
        try:
            # Determine the appropriate pip command based on environment
            if 'uv' in sys.executable.lower() or get_env('UV_PROJECT_ROOT'):
                pip_cmd = ['uv', 'pip']
                logger.info("Installing yamllint using uv pip...")
            else:
                pip_exe = shutil.which('pip') or shutil.which('pip3')
                if not pip_exe:
                    return False  # Optional tool, don't error
                pip_cmd = [pip_exe]
                logger.info(f"Installing yamllint using {os.path.basename(pip_exe)}...")

            # Install yamllint
            result = subprocess.run(pip_cmd + ['install', 'yamllint'],
                                  capture_output=True, text=True, check=False)

            if result.returncode == 0:
                logger.info("✓ yamllint installed successfully")
                return True

            return False

        except Exception as e:
            logger.debug(f"Could not install yamllint: {e}")
            return False

    def setup_precommit_hooks(self) -> bool:
        """Install pre-commit hooks in the repository."""
        if not self.precommit_config.exists():
            logger.warn("No .pre-commit-config.yaml found - skipping hook installation")
            logger.info("Pre-commit configuration not found in this repository")
            return True

        logger.info("[Install] Installing pre-commit hooks...")

        try:
            # Try direct command first (may not be in PATH yet)
            try:
                result = subprocess.run(['pre-commit', 'install'],
                                      capture_output=True, text=True, check=False)
                if result.returncode == 0:
                    logger.info("[Install] Pre-commit hooks installed successfully ✅")
                    return True
            except (FileNotFoundError, OSError):
                # Command not found, try Python module approach
                pass

            # Try using Python module (more reliable when just installed)
            logger.debug("Trying python -m pre_commit...")
            result = subprocess.run([sys.executable, '-m', 'pre_commit', 'install'],
                                  capture_output=True, text=True, check=False)

            if result.returncode == 0:
                logger.info("[Install] Pre-commit hooks installed successfully ✅")
                return True
            else:
                logger.error("Failed to install pre-commit hooks")
                if result.stderr:
                    logger.debug(f"Error: {result.stderr}")
                return False

        except Exception as e:
            logger.error(f"Failed to install pre-commit hooks: {e}")
            return False

    def run_initial_validation(self) -> None:
        """Optionally run pre-commit on all files to validate setup."""
        logger.info("Running initial validation on all files...")
        logger.info("This may take a moment on first run...")

        try:
            result = subprocess.run(['pre-commit', 'run', '--all-files'],
                                  capture_output=True, text=True, check=False)

            if result.returncode == 0:
                logger.success("All files passed validation")
            else:
                # Pre-commit returns non-zero if any checks fail, which is normal
                logger.info("Some files may need formatting (this is normal)")
                logger.info("Pre-commit will automatically check files on commit")

        except Exception as e:
            logger.warn(f"Could not run initial validation: {e}")

    def setup_development_environment(self) -> None:
        """Main setup process for development environment."""
        logger.info("[Install] Setting up HostK8s development environment...")

        # Ensure PATH is configured
        self.ensure_path_configured()

        # Check prerequisites
        if not self.check_prerequisites():
            logger.error("Missing required tools")
            logger.info("Please run 'make install' to install required tools")
            sys.exit(1)

        # Setup hooks
        if not self.setup_precommit_hooks():
            sys.exit(1)

        # Optionally run initial validation
        # Commented out by default as it can be slow on large repos
        # self.run_initial_validation()

        logger.info("[Install] Development environment setup complete! ✅")
        logger.info("")
        logger.info("You can now use 'git commit' with automatic validation")
        logger.info("Manual validation: 'pre-commit run --all-files'")
        logger.info("Run specific hook: 'pre-commit run <hook-id>'")

        if not self.home_local_bin.exists() or str(self.home_local_bin) not in get_env('PATH', ''):
            logger.info("")
            logger.info("Note: If commands aren't found, add to your shell profile:")
            logger.info(f'  echo \'export PATH="$HOME/.local/bin:$PATH"\' >> ~/.bashrc')
            logger.info("  # or for zsh:")
            logger.info(f'  echo \'export PATH="$HOME/.local/bin:$PATH"\' >> ~/.zshrc')


def main() -> None:
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Setup HostK8s development environment (git hooks)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
This script sets up git commit hooks for the HostK8s project.
It requires pre-commit to be installed (via 'make install').

The following hooks will be configured:
  - pre-commit validation hooks (from .pre-commit-config.yaml)
  - yamllint for YAML files (if installed)
  - Other project-specific checks

Note: Tool installation should be done via 'make install'.
        """
    )

    parser.add_argument('-v', '--validate', action='store_true',
                       help='Run validation on all files after setup')

    args = parser.parse_args()

    # Load environment
    load_environment()

    logger.info("[Script 🐍] Running script: prepare.py")

    # Create setup instance
    setup = DevelopmentSetup()

    try:
        # Run setup
        setup.setup_development_environment()

        # Run validation if requested
        if args.validate:
            setup.run_initial_validation()

    except KeyboardInterrupt:
        logger.warn("Setup cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
