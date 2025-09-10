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
HostK8s Application Build Script (Python Implementation)

Build and push applications from src/ directory using Docker Bake or Docker Compose.

Supports:
- Application discovery (docker-bake.hcl preferred, docker-compose.yml fallback)
- Cross-platform Docker CLI orchestration
- Build metadata injection (BUILD_DATE, BUILD_VERSION)
- Comprehensive error handling and logging
- Automatic registry push operations

This replaces the dual shell/PowerShell scripts with a single, maintainable implementation.
"""

import argparse
import os
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Tuple, Optional

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError,
    check_cluster_running, get_env, load_environment
)


class ApplicationBuilder:
    """Handles application building and pushing operations."""

    def __init__(self):
        self.build_version = "1.0.0"
        self.registry_url = None

    def find_applications(self) -> List[Tuple[Path, str]]:
        """Find all buildable applications in src/ directory.

        Returns:
            List of tuples (app_path, build_file_type)
        """
        applications = []
        src_path = Path("src")

        if not src_path.exists():
            logger.warn("src/ directory not found")
            return applications

        # Track directories that already have bake files
        bake_dirs = set()

        # Look for docker-bake.hcl files first (preferred)
        for bake_file in src_path.rglob("docker-bake.hcl"):
            app_dir = bake_file.parent
            applications.append((app_dir, "docker-bake.hcl"))
            bake_dirs.add(app_dir)

        # Look for docker-compose.yml files, but skip directories with bake files
        for compose_file in src_path.rglob("docker-compose.yml"):
            app_dir = compose_file.parent
            if app_dir not in bake_dirs:
                applications.append((app_dir, "docker-compose.yml"))

        return sorted(applications, key=lambda x: str(x[0]))

    def detect_registry_url(self) -> str:
        """Detect working registry URL by testing multiple endpoints.

        Returns:
            Working registry URL

        Raises:
            HostK8sError: If no registry endpoints are accessible
        """
        # Allow override via environment variable
        registry_override = get_env('REGISTRY_URL', '')
        if registry_override:
            logger.info(f"[Build] Using REGISTRY_URL override: {registry_override}")
            return registry_override

        # Test registry endpoints in priority order
        test_urls = [
            "localhost:5002",
            "127.0.0.1:5002",
            "host.docker.internal:5002"
        ]

        for url in test_urls:
            try:
                # Test if registry is accessible
                catalog_url = f"http://{url}/v2/_catalog"
                logger.debug(f"[Build] Testing registry endpoint: {url}")

                with urllib.request.urlopen(catalog_url, timeout=5) as response:
                    if response.status == 200:
                        logger.info(f"[Build] Using registry: {url}")
                        return url

            except Exception as e:
                logger.debug(f"[Build] Registry {url} not accessible: {e}")
                continue

        raise HostK8sError(
            "No accessible registry found. Ensure the cluster is running with registry enabled.\n"
            f"Tested endpoints: {', '.join(test_urls)}\n"
            "You can override with: REGISTRY_URL=your-registry-url make build"
        )

    def ensure_buildx_registry_config(self, registry_url: str) -> None:
        """Ensure buildx is configured for insecure HTTP registry access.

        Args:
            registry_url: Registry URL to configure
        """
        try:
            # Create buildx builder with insecure registry support if needed
            builder_name = "hostk8s-builder"

            # Check if builder exists
            result = subprocess.run(
                ["docker", "buildx", "inspect", builder_name],
                capture_output=True, text=True
            )

            if result.returncode != 0:
                logger.info(f"[Build] Creating buildx builder: {builder_name}")

                # Create builder with buildkit config for insecure registries
                buildkitd_config = f"""
[registry."{registry_url}"]
  http = true
  insecure = true

[registry."localhost:5002"]
  http = true
  insecure = true

[registry."127.0.0.1:5002"]
  http = true
  insecure = true

[registry."host.docker.internal:5002"]
  http = true
  insecure = true
""".strip()

                # Write temporary buildkitd config
                config_path = Path("buildkitd.toml")
                config_path.write_text(buildkitd_config)

                try:
                    # Create builder with config
                    subprocess.run([
                        "docker", "buildx", "create",
                        "--name", builder_name,
                        "--config", str(config_path),
                        "--use"
                    ], check=True, capture_output=True)

                    logger.info(f"[Build] Created and configured buildx builder: {builder_name}")
                finally:
                    # Clean up temporary config
                    if config_path.exists():
                        config_path.unlink()
            else:
                # Use existing builder
                subprocess.run([
                    "docker", "buildx", "use", builder_name
                ], check=True, capture_output=True)
                logger.debug(f"[Build] Using existing buildx builder: {builder_name}")

        except subprocess.CalledProcessError as e:
            logger.warn(f"[Build] Could not configure buildx builder: {e}")
            logger.info("[Build] Continuing with default builder...")

    def list_available_applications(self) -> None:
        """Display available applications that can be built."""
        applications = self.find_applications()

        if not applications:
            logger.info("No applications found in src/")
            return

        logger.info("Available applications:")
        for app_path, build_type in applications:
            logger.info(f"  {app_path} ({build_type})")

    def validate_application_path(self, app_path: str) -> Tuple[Path, str]:
        """Validate application path and determine build method.

        Args:
            app_path: Path to application directory

        Returns:
            Tuple of (validated_path, build_file_type)

        Raises:
            HostK8sError: If path is invalid or no build file found
        """
        path = Path(app_path)

        if not path.exists():
            self.list_available_applications()
            raise HostK8sError(f"Directory not found: {app_path}")

        if not path.is_dir():
            raise HostK8sError(f"Path is not a directory: {app_path}")

        # Check for build files (prefer bake over compose)
        bake_file = path / "docker-bake.hcl"
        compose_file = path / "docker-compose.yml"

        if bake_file.exists():
            return path, "docker-bake.hcl"
        elif compose_file.exists():
            return path, "docker-compose.yml"
        else:
            raise HostK8sError(
                f"No docker-bake.hcl or docker-compose.yml found in {app_path}\n"
                f"Expected: {app_path}/docker-bake.hcl or {app_path}/docker-compose.yml"
            )

    def set_build_environment(self) -> None:
        """Set build metadata environment variables."""
        build_date = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

        # Detect working registry URL if not already set
        if not self.registry_url:
            self.registry_url = self.detect_registry_url()

        # Ensure buildx is configured for HTTP registry access
        self.ensure_buildx_registry_config(self.registry_url)

        os.environ["BUILD_DATE"] = build_date
        os.environ["BUILD_VERSION"] = self.build_version
        os.environ["REGISTRY"] = self.registry_url

        logger.info(f"[Build] Build date: {build_date}")
        logger.info(f"[Build] Version: {self.build_version}")
        logger.info(f"[Build] Registry: {self.registry_url}")

    def run_docker_command(self, cmd: List[str], cwd: Path) -> None:
        """Run Docker command with proper error handling.

        Args:
            cmd: Docker command as list of strings
            cwd: Working directory for command execution

        Raises:
            HostK8sError: If Docker command fails
        """
        logger.info(f"[Build] Running: {' '.join(cmd)}")

        try:
            result = subprocess.run(
                cmd,
                cwd=cwd,
                check=True,
                capture_output=False,  # Show output in real-time
                text=True
            )
        except subprocess.CalledProcessError as e:
            raise HostK8sError(f"Docker command failed with exit code {e.returncode}: {' '.join(cmd)}")
        except FileNotFoundError:
            raise HostK8sError("Docker command not found. Ensure Docker is installed and in PATH.")

    def build_with_bake(self, app_path: Path) -> None:
        """Build application using docker-bake.hcl.

        Args:
            app_path: Path to application directory
        """
        logger.info("[Build] Using docker-bake.hcl for build and push...")
        logger.info("[Build] Building and pushing Docker images...")

        self.run_docker_command(["docker", "buildx", "bake", "--push"], app_path)

    def build_with_compose(self, app_path: Path) -> None:
        """Build application using docker-compose.yml.

        Args:
            app_path: Path to application directory
        """
        logger.info("[Build] Using docker-compose.yml for build and push...")

        # Build the application
        logger.info("[Build] Building Docker images...")
        self.run_docker_command(["docker", "compose", "build"], app_path)

        # Push to registry
        logger.info("[Build] Pushing to registry...")
        self.run_docker_command(["docker", "compose", "push"], app_path)

    def build_application(self, app_path: str) -> None:
        """Build and push application.

        Args:
            app_path: Path to application directory
        """
        # Validate application path
        validated_path, build_type = self.validate_application_path(app_path)

        logger.info(f"[Build] Building application: {validated_path}")

        # Set build environment
        self.set_build_environment()

        # Build based on file type
        if build_type == "docker-bake.hcl":
            self.build_with_bake(validated_path)
        elif build_type == "docker-compose.yml":
            self.build_with_compose(validated_path)
        else:
            raise HostK8sError(f"Unsupported build type: {build_type}")

        logger.success("[Build] Build and push complete")


def create_argument_parser(default_app: str) -> argparse.ArgumentParser:
    """Create argument parser for build command."""
    parser = argparse.ArgumentParser(
        description="Build and push application from src/ directory",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Examples:
  %(prog)s                     # Build {default_app} (default)
  %(prog)s src/registry-demo    # Build registry demo app
  %(prog)s --list               # List available applications
        """
    )

    parser.add_argument(
        "app_path",
        nargs="?",
        default=default_app,
        help=f"Path to application directory (default: {default_app})"
    )

    parser.add_argument(
        "--list", "-l",
        action="store_true",
        help="List available applications"
    )

    parser.add_argument(
        "--version", "-v",
        action="version",
        version="1.0.0"
    )

    return parser


def main() -> int:
    """Main entry point."""
    # Load environment variables from .env file
    load_environment()

    # Get default app from environment
    default_build = get_env('SOFTWARE_BUILD', 'sample-app')
    default_app_path = f"src/{default_build}"

    parser = create_argument_parser(default_app_path)
    args = parser.parse_args()

    builder = ApplicationBuilder()

    try:
        # Handle list option
        if args.list:
            builder.list_available_applications()
            return 0

        # app_path is always provided now (either from args or default)
        if not args.app_path:
            parser.print_help()
            logger.error("Application path is required")
            return 1

        # Ensure cluster is running
        try:
            check_cluster_running()
        except HostK8sError as e:
            logger.error(f"Cluster check failed: {e}")
            return 1

        # Log script execution
        script_name = Path(__file__).name
        logger.info(f"[Script 🐍] Running script: [cyan]{script_name}[/cyan] [green]{args.app_path}[/green]")

        # Build the application
        builder.build_application(args.app_path)
        return 0

    except KeyboardInterrupt:
        logger.warn("Operation cancelled by user")
        return 1
    except HostK8sError as e:
        logger.error(str(e))
        return 1
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
