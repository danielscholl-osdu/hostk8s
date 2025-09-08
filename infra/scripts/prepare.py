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
HostK8s Development Environment Setup Script (Python Implementation)

Setup development environment by configuring pre-commit hooks.
This script checks for required tools and sets up git commit hooks.

Note: Tool installation should be done via 'make install'.
"""

import os
import sys
import subprocess
from pathlib import Path
from typing import Optional

# Import common utilities
from hostk8s_common import (
    logger, load_environment
)


class DevelopmentSetup:
    """Handles development environment setup operations."""

    def __init__(self):
        self.home_local_bin = Path.home() / ".local" / "bin"
        self.precommit_config = Path(".pre-commit-config.yaml")

    def check_command(self, command: str) -> bool:
        """Check if a command is available in PATH."""
        try:
            result = subprocess.run(['which', command],
                                  capture_output=True, text=True, check=False)
            return result.returncode == 0
        except Exception:
            return False

    def ensure_path_configured(self) -> None:
        """Ensure user's local bin is in PATH."""
        # Add to current session
        current_path = os.environ.get('PATH', '')
        local_bin_str = str(self.home_local_bin)
        if local_bin_str not in current_path:
            os.environ['PATH'] = f"{local_bin_str}:{current_path}"
            logger.debug(f"Added {local_bin_str} to PATH for this session")

    def check_prerequisites(self) -> bool:
        """Check if required tools are installed."""
        all_tools_present = True

        # Check for pre-commit
        if not self.check_command('pre-commit'):
            logger.error("pre-commit is not installed")
            logger.info("Install with: make install")
            all_tools_present = False
        else:
            logger.info("✓ pre-commit is installed")

        # Check for yamllint
        if not self.check_command('yamllint'):
            logger.warn("yamllint is not installed (optional but recommended)")
            logger.info("Install with: make install")
            # Don't fail for yamllint as it's optional
        else:
            logger.info("✓ yamllint is installed")

        return all_tools_present

    def setup_precommit_hooks(self) -> bool:
        """Install pre-commit hooks in the repository."""
        if not self.precommit_config.exists():
            logger.warn("No .pre-commit-config.yaml found - skipping hook installation")
            logger.info("Pre-commit configuration not found in this repository")
            return True

        logger.info("[Install] Installing pre-commit hooks...")

        try:
            # Run pre-commit install
            result = subprocess.run(['pre-commit', 'install'],
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

        if not self.home_local_bin.exists() or str(self.home_local_bin) not in os.environ.get('PATH', ''):
            logger.info("")
            logger.info("Note: If commands aren't found, add to your shell profile:")
            logger.info(f'  echo \'export PATH="$HOME/.local/bin:$PATH"\' >> ~/.bashrc')
            logger.info("  # or for zsh:")
            logger.info(f'  echo \'export PATH="$HOME/.local/bin:$PATH"\' >> ~/.zshrc')


def main():
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
