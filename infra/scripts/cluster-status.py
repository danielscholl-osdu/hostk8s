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
Enhanced HostK8s Cluster Status Script

Shows comprehensive cluster status including:
- Docker services (registry container)
- Cluster services (control plane, add-ons)
- GitOps resources
- Applications
- Health checks
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple

from rich.console import Console

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError, KubectlError,
    run_kubectl, run_flux, has_flux, has_flux_cli,
    detect_kubeconfig, get_env, has_ingress_controller
)

# Create a console instance for Rich formatted output
console = Console()


class EnhancedClusterStatusChecker:
    """Enhanced cluster status checking with add-on support."""

    def __init__(self):
        self.kubeconfig = detect_kubeconfig()

    def show_kubeconfig_info(self) -> None:
        """Show KUBECONFIG information."""
        kubeconfig_path = f"{os.getcwd()}/data/kubeconfig/config"

        # Detect OS and provide appropriate command format
        if os.name == 'nt':  # Windows
            # PowerShell format
            logger.debug(f"$env:KUBECONFIG = \"{kubeconfig_path}\"")
        else:  # Unix/Linux/Mac
            # Bash/shell format
            logger.debug(f"export KUBECONFIG={kubeconfig_path}")
        print()

    def check_docker_services(self) -> None:
        """Check Docker services like registry container."""
        has_services = False

        try:
            # Check for registry container (both naming patterns)
            result = subprocess.run(['docker', 'ps', '--filter', 'name=registry',
                                   '--format', '{{.Names}}\t{{.Status}}\t{{.Ports}}'],
                                  capture_output=True, text=True, check=False)

            if result.returncode == 0 and result.stdout.strip():
                # Only show header if we have services
                logger.info("Docker Services")
                has_services = True

                for line in result.stdout.strip().split('\n'):
                    parts = line.split('\t')
                    if len(parts) >= 2:
                        name = parts[0]
                        status = parts[1]
                        ports = parts[2] if len(parts) > 2 else ''

                        if 'Up' in status:
                            # Get registry version
                            version = "unknown"
                            try:
                                version_result = subprocess.run(
                                    ['docker', 'exec', name, '/bin/registry', '--version'],
                                    capture_output=True, text=True, check=False
                                )
                                if version_result.returncode == 0 and version_result.stdout:
                                    # Output format: "/bin/registry github.com/docker/distribution 2.8.3"
                                    parts = version_result.stdout.strip().split()
                                    if len(parts) >= 3:
                                        version = f"v{parts[-1]}"  # Get last part and add 'v' prefix
                            except Exception:
                                pass

                            print(f"📦 Registry Container: Ready")
                            if ports:
                                print(f"   Status: Running on {ports} - {version}")
                            print(f"   Network: Connected to Kind cluster")
                        else:
                            print(f"📦 Registry Container: {status}")
        except FileNotFoundError:
            # Docker not available is not worth showing
            pass
        except Exception as e:
            logger.debug(f"Error checking Docker services: {e}")
            # Don't show error message unless we had services to show

        # Only print separator if we showed something
        if has_services:
            print()

    def check_cluster_services(self) -> None:
        """Check cluster services and add-ons."""
        logger.info("Cluster Services")

        # Check control plane
        self._check_control_plane()

        # Check add-ons
        self._check_metrics_server()
        self._check_metallb()
        self._check_ingress_controller()
        self._check_gateway_api()
        self._check_registry()
        self._check_vault()
        self._check_flux()

        print()

    def _check_control_plane(self) -> None:
        """Check control plane and worker nodes status."""
        try:
            # Get node info
            result = run_kubectl(['get', 'nodes', '--no-headers'], check=False)
            if result.returncode == 0 and result.stdout:
                control_plane_found = False
                worker_nodes = []

                for line in result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 5:
                            name = parts[0]
                            status = parts[1]
                            roles = parts[2]
                            age = parts[3]
                            version = parts[4]

                            if 'control-plane' in roles:
                                # Display control plane
                                if status == 'Ready':
                                    print(f"🕹️  Control Plane: Ready")
                                    print(f"   Status: Kubernetes {version} (up {age})")
                                    print(f"   Node: {name}")
                                else:
                                    print(f"🕹️  Control Plane: {status}")
                                    print(f"   Node: {name}")
                                control_plane_found = True
                            elif roles == '<none>' or 'worker' in roles.lower():
                                # Collect worker nodes
                                worker_nodes.append({
                                    'name': name,
                                    'status': status,
                                    'version': version,
                                    'age': age
                                })

                # Display worker nodes
                for worker in worker_nodes:
                    if worker['status'] == 'Ready':
                        print(f"🚜 Worker: Ready")
                        print(f"   Status: Kubernetes {worker['version']} (up {worker['age']})")
                        print(f"   Node: {worker['name']}")
                    else:
                        print(f"🚜 Worker: {worker['status']}")
                        print(f"   Node: {worker['name']}")

        except Exception as e:
            logger.debug(f"Error checking nodes: {e}")

    def _check_metrics_server(self) -> None:
        """Check Metrics Server status."""
        if get_env('METRICS_DISABLED', 'false') == 'true':
            return

        try:
            # Check if metrics server deployment exists
            result = run_kubectl(['get', 'deployment', 'metrics-server', '-n', 'kube-system',
                                '--no-headers'], check=False)

            if result.returncode == 0:
                # Get metrics server version from container image
                version_result = run_kubectl(['get', 'deployment', 'metrics-server', '-n', 'kube-system',
                                            '-o', 'jsonpath={.spec.template.spec.containers[0].image}'], check=False)
                version = "unknown"
                if version_result.returncode == 0 and version_result.stdout:
                    image = version_result.stdout.strip()
                    # Handle image format with potential digest
                    if ':v' in image:
                        # Find the version tag starting with 'v'
                        version_start = image.find(':v') + 1  # +1 to include the 'v'
                        if '@' in image[version_start:]:
                            version_end = image.find('@', version_start)
                            version = image[version_start:version_end]
                        else:
                            version = image[version_start:]
                    elif ':' in image:
                        # Fallback to last part after colon
                        version_part = image.split(':')[-1]
                        if '@' in version_part:
                            version = version_part.split('@')[0]
                        else:
                            version = version_part

                # Check if metrics API is available
                api_result = run_kubectl(['top', 'nodes'], check=False, capture_output=True)
                if api_result.returncode == 0:
                    print(f"📊 Metrics Server: Ready")
                    print(f"   Status: Resource metrics available (kubectl top) - {version}")
                else:
                    print(f"📊 Metrics Server: Installed but not ready")
                    print(f"   Status: Waiting for metrics to be available - {version}")
        except Exception as e:
            logger.debug(f"Error checking metrics server: {e}")

    def _check_metallb(self) -> None:
        """Check MetalLB status."""
        try:
            # Check if MetalLB is installed
            result = run_kubectl(['get', 'deployment', 'metallb-controller', '-n', 'hostk8s',
                                '--no-headers'], check=False)

            if result.returncode == 0:
                # Get MetalLB version from controller deployment image
                version_result = run_kubectl(['get', 'deployment', 'metallb-controller', '-n', 'hostk8s',
                                            '-o', 'jsonpath={.spec.template.spec.containers[0].image}'], check=False)
                version = "unknown"
                if version_result.returncode == 0 and version_result.stdout:
                    image = version_result.stdout.strip()
                    # Handle image format with potential digest
                    if ':v' in image:
                        # Find the version tag starting with 'v'
                        version_start = image.find(':v') + 1  # +1 to include the 'v'
                        if '@' in image[version_start:]:
                            version_end = image.find('@', version_start)
                            version = image[version_start:version_end]
                        else:
                            version = image[version_start:]
                    elif ':' in image:
                        # Fallback to last part after colon
                        version_part = image.split(':')[-1]
                        if '@' in version_part:
                            version = version_part.split('@')[0]
                        else:
                            version = version_part

                # Check if MetalLB pods are running
                pods_result = run_kubectl(['get', 'pods', '-n', 'hostk8s', '-l', 'app.kubernetes.io/name=metallb',
                                         '--no-headers'], check=False)

                if pods_result.returncode == 0 and 'Running' in pods_result.stdout:
                    # Check for IP pools
                    pool_result = run_kubectl(['get', 'ipaddresspools', '-n', 'hostk8s',
                                             '--no-headers'], check=False)

                    if pool_result.returncode == 0 and pool_result.stdout.strip():
                        print(f"🔗 MetalLB (LoadBalancer): Ready")
                        print(f"   Status: IP address pool configured - {version}")
                    else:
                        print(f"🔗 MetalLB (LoadBalancer): Running")
                        print(f"   Status: No IP pools configured - {version}")
                else:
                    print(f"🔗 MetalLB (LoadBalancer): Starting")
                    print(f"   Status: Pods not yet running - {version}")
        except Exception as e:
            logger.debug(f"Error checking MetalLB: {e}")

    def _check_ingress_controller(self) -> None:
        """Check NGINX Ingress Controller status."""
        try:
            # Check if ingress controller is installed
            result = run_kubectl(['get', 'deployment', 'ingress-nginx-controller', '-n', 'hostk8s',
                                '--no-headers'], check=False)

            if result.returncode == 0:
                # Get NGINX Ingress version from container image
                version_result = run_kubectl(['get', 'deployment', 'ingress-nginx-controller', '-n', 'hostk8s',
                                            '-o', 'jsonpath={.spec.template.spec.containers[0].image}'], check=False)
                version = "unknown"
                if version_result.returncode == 0 and version_result.stdout:
                    image = version_result.stdout.strip()
                    # Handle image format like registry.k8s.io/ingress-nginx/controller:v1.13.2@sha256:...
                    if ':v' in image:
                        # Find the version tag starting with 'v'
                        version_start = image.find(':v') + 1  # +1 to include the 'v'
                        if '@' in image[version_start:]:
                            version_end = image.find('@', version_start)
                            version = image[version_start:version_end]
                        else:
                            version = image[version_start:]
                    elif ':' in image:
                        # Fallback to last part after colon
                        version_part = image.split(':')[-1]
                        if '@' in version_part:
                            version = version_part.split('@')[0]
                        else:
                            version = version_part

                # Check if pods are running
                pods_result = run_kubectl(['get', 'pods', '-n', 'hostk8s',
                                         '-l', 'app.kubernetes.io/name=ingress-nginx',
                                         '--no-headers'], check=False)

                if pods_result.returncode == 0 and 'Running' in pods_result.stdout:
                    print(f"🌐 NGINX Ingress: Ready")
                    print(f"   Status: Access http:8080, https:8443 - {version}")
                else:
                    print(f"🌐 NGINX Ingress: Starting")
                    print(f"   Status: Controller pod not yet running - {version}")
        except Exception as e:
            logger.debug(f"Error checking ingress controller: {e}")

    def _check_gateway_api(self) -> None:
        """Check Kubernetes Gateway API status."""
        try:
            # Check if Gateway API CRDs are installed
            gateway_crd_result = run_kubectl(['get', 'crd', 'gateways.gateway.networking.k8s.io'],
                                           check=False, capture_output=True)

            if gateway_crd_result.returncode != 0:
                return  # Gateway API not installed

            # Check for Istio Gateway resource
            gateway_result = run_kubectl(['get', 'gateway', 'hostk8s-gateway', '-n', 'istio-system'],
                                       check=False, capture_output=True)

            if gateway_result.returncode == 0:
                # Check if auto-deployed gateway pods are running
                pods_result = run_kubectl(['get', 'pods', '-n', 'istio-system',
                                         '-l', 'gateway.networking.k8s.io/gateway-name=hostk8s-gateway',
                                         '--no-headers'], check=False)

                # Get service port mapping
                svc_result = run_kubectl(['get', 'service', 'hostk8s-gateway-istio', '-n', 'istio-system',
                                        '-o', 'jsonpath={.spec.ports[?(@.name=="http")].nodePort}'],
                                       check=False)

                https_svc_result = run_kubectl(['get', 'service', 'hostk8s-gateway-istio', '-n', 'istio-system',
                                              '-o', 'jsonpath={.spec.ports[?(@.name=="https")].nodePort}'],
                                             check=False)

                # Detect Gateway API implementation (Istio, if available)
                implementation = "Gateway API"
                version = "unknown"

                # Check if this is implemented by Istio
                istio_version_result = run_kubectl(['get', 'deployment', 'istiod', '-n', 'istio-system',
                                                  '-o', 'jsonpath={.spec.template.spec.containers[0].image}'],
                                                 check=False, capture_output=True)
                if istio_version_result.returncode == 0 and istio_version_result.stdout:
                    implementation = "Gateway API (Istio)"
                    image = istio_version_result.stdout.strip()
                    if ':' in image:
                        version_part = image.split(':')[-1]
                        if '-' in version_part:
                            version = version_part.split('-')[0]
                        else:
                            version = version_part

                # Determine ports by checking actual Kind port mapping
                http_port = "8080"  # Default fallback
                https_port = "8443"  # Default fallback

                # Get actual NodePorts from service
                http_nodeport = None
                https_nodeport = None

                if svc_result.returncode == 0 and svc_result.stdout:
                    try:
                        http_nodeport = int(svc_result.stdout.strip())
                    except ValueError:
                        pass

                if https_svc_result.returncode == 0 and https_svc_result.stdout:
                    try:
                        https_nodeport = int(https_svc_result.stdout.strip())
                    except ValueError:
                        pass

                # Check Kind container port mapping for actual host ports
                try:
                    import subprocess
                    # Get cluster name from kubeconfig context
                    cluster_name = "hostk8s"  # Default
                    try:
                        ctx_result = run_kubectl(['config', 'current-context'], check=False, capture_output=True)
                        if ctx_result.returncode == 0 and 'kind-' in ctx_result.stdout:
                            cluster_name = ctx_result.stdout.strip().replace('kind-', '')
                    except:
                        pass

                    # Check Docker port mapping for Kind container
                    docker_result = subprocess.run(['docker', 'port', f'{cluster_name}-control-plane'],
                                                 capture_output=True, text=True, check=False)
                    if docker_result.returncode == 0:
                        for line in docker_result.stdout.strip().split('\n'):
                            if f'{http_nodeport}/tcp' in line and http_nodeport:
                                # Extract host port from "30080/tcp -> 0.0.0.0:8081"
                                if ' -> 0.0.0.0:' in line:
                                    http_port = line.split(' -> 0.0.0.0:')[1]
                            elif f'{https_nodeport}/tcp' in line and https_nodeport:
                                if ' -> 0.0.0.0:' in line:
                                    https_port = line.split(' -> 0.0.0.0:')[1]
                except Exception:
                    # Fallback to NodePort if Docker inspection fails
                    if http_nodeport:
                        http_port = str(http_nodeport)
                    if https_nodeport:
                        https_port = str(https_nodeport)

                if pods_result.returncode == 0 and 'Running' in pods_result.stdout:
                    print(f"🌐 {implementation}: Ready")
                    print(f"   Status: Access http:{http_port}, https:{https_port} - {version}")
                else:
                    print(f"🌐 {implementation}: Starting")
                    print(f"   Status: Gateway pod not yet running - {version}")

        except Exception as e:
            logger.debug(f"Error checking Gateway API: {e}")

    def _check_registry(self) -> None:
        """Check Registry status (both container and UI deployment)."""
        try:
            # First check if the Docker registry container is running
            docker_result = subprocess.run(['docker', 'ps', '--filter', 'name=registry',
                                          '--format', '{{.Names}}'],
                                         capture_output=True, text=True, check=False)

            if docker_result.returncode == 0 and 'registry' in docker_result.stdout:
                # Registry container is running
                print(f"📦 Registry: Ready")
                print(f"   Status: Container registry available at localhost:5002")

                # Check if Registry UI is deployed
                ui_result = run_kubectl(['get', 'deployment', 'registry-ui', '-n', 'hostk8s',
                                       '--no-headers'], check=False)

                if ui_result.returncode == 0:
                    parts = ui_result.stdout.strip().split()
                    if len(parts) >= 2:
                        ready = parts[1]  # READY column (e.g., "1/1")

                        if ready == "1/1":
                            # Check for ingress
                            ingress_result = run_kubectl(['get', 'ingress', 'registry-ui', '-n', 'hostk8s',
                                                        '--no-headers'], check=False)

                            if ingress_result.returncode == 0:
                                # Check if ingress controller is actually ready
                                warning = "" if has_ingress_controller() else " ⚠️ (No Ingress Controller)"
                                if has_ingress_controller():
                                    console.print(f"   Web UI: Available at [cyan]http://localhost:8080/registry/[/cyan]")
                                else:
                                    print(f"   Web UI: http://localhost:8080/registry/{warning}")
                            else:
                                print(f"   Web UI: Deployed but no ingress configured")
                        else:
                            print(f"   Web UI: Starting ({ready} ready)")
            else:
                # Check for K8s deployment (legacy)
                result = run_kubectl(['get', 'deployment', 'docker-registry', '-n', 'hostk8s',
                                    '--no-headers'], check=False)

                if result.returncode == 0:
                    # Parse deployment status
                    parts = result.stdout.strip().split()
                    if len(parts) >= 2:
                        ready = parts[1]  # READY column (e.g., "1/1")

                        if ready == "1/1":
                            print(f"📦 Registry: Ready")
                            print(f"   Status: Internal registry deployment")
                        else:
                            print(f"📦 Registry: Pending")
                            print(f"   Status: Registry deployment {ready} ready")
        except Exception as e:
            logger.debug(f"Error checking registry: {e}")

    def _get_vault_version(self) -> str:
        """Get Vault version from container image."""
        try:
            # Get vault version from statefulset container image
            version_result = run_kubectl(['get', 'statefulset', 'vault', '-n', 'hostk8s',
                                        '-o', 'jsonpath={.spec.template.spec.containers[0].image}'], check=False)
            if version_result.returncode == 0 and version_result.stdout:
                image = version_result.stdout.strip()
                # Handle image format like hashicorp/vault:1.18.2
                if ':' in image:
                    tag = image.split(':')[-1]
                    # Remove any digest information
                    if '@sha256' in tag:
                        tag = tag.split('@')[0]
                    if tag and tag != 'latest':
                        return f"v{tag}"
            return "unknown"
        except Exception:
            return "unknown"

    def _check_vault(self) -> None:
        """Check Vault status."""
        try:
            # Check if Vault is installed
            result = run_kubectl(['get', 'statefulset', 'vault', '-n', 'hostk8s',
                                '--no-headers'], check=False)

            if result.returncode == 0:
                # Check if Vault pod is running
                pod_result = run_kubectl(['get', 'pod', 'vault-0', '-n', 'hostk8s',
                                        '--no-headers'], check=False)

                if pod_result.returncode == 0 and 'Running' in pod_result.stdout:
                    # Get Vault version
                    vault_version = self._get_vault_version()
                    version_text = f" - {vault_version}" if vault_version else ""

                    print(f"🔐 Vault: Ready")

                    # Check for ingress
                    ingress_result = run_kubectl(['get', 'ingress', 'vault-ui', '-n', 'hostk8s',
                                                '--no-headers'], check=False)

                    print(f"   Status: Secret management available (dev mode){version_text}")

                    # Always show UI path, but with appropriate status
                    if ingress_result.returncode == 0:
                        # Ingress exists - check if controller is ready
                        if has_ingress_controller():
                            console.print(f"   Web UI: Available at [cyan]http://localhost:8080/ui/[/cyan]")
                        else:
                            print(f"   Web UI: http://localhost:8080/ui/ ⚠️ (No Ingress Controller)")
                    else:
                        # No ingress configured - show what would be available
                        warning = " ⚠️ (No Ingress Controller)" if not has_ingress_controller() else ""
                        print(f"   Web UI: http://localhost:8080/ui/{warning}")
                else:
                    print(f"🔐 Vault: Starting")
                    print(f"   Status: Vault pod not yet running")
        except Exception as e:
            logger.debug(f"Error checking Vault: {e}")

    def _check_flux(self) -> None:
        """Check Flux (GitOps) status."""
        try:
            if has_flux():
                # Check if Flux controllers are running
                controllers_result = run_kubectl(['get', 'pods', '-n', 'flux-system',
                                                '--no-headers'], check=False)

                if controllers_result.returncode == 0 and controllers_result.stdout:
                    # Count running vs total pods
                    lines = controllers_result.stdout.strip().split('\n')
                    running_count = 0
                    total_count = len([line for line in lines if line.strip()])

                    for line in lines:
                        if 'Running' in line and '1/1' in line:
                            running_count += 1

                    if running_count == total_count and total_count > 0:
                        print(f"🔄 Flux (GitOps): Ready")

                        # Try to get Flux version
                        if has_flux_cli():
                            version_result = run_flux(['version', '--client'], check=False, capture_output=True)
                            if version_result.returncode == 0 and version_result.stdout:
                                # Extract version from output (format: "flux version 2.x.x")
                                version_line = version_result.stdout.strip().split('\n')[0]
                                if 'flux version' in version_line:
                                    version = version_line.replace('flux version ', '')
                                    print(f"   Status: GitOps automation available (v{version})")
                                else:
                                    print(f"   Status: GitOps automation available")
                            else:
                                print(f"   Status: GitOps automation available")
                        else:
                            print(f"   Status: GitOps automation available")

                        # Check for suspended sources
                        if has_flux_cli():
                            suspended_result = run_flux(['get', 'sources', 'git', '--status-selector', 'suspended=True'], check=False, capture_output=True)
                            if suspended_result.returncode == 0 and suspended_result.stdout:
                                lines = suspended_result.stdout.strip().split('\n')
                                # Count lines that aren't headers and aren't empty
                                suspended_count = len([line for line in lines if line.strip() and not line.startswith('NAME')])
                                if suspended_count > 0:
                                    print(f"   Warning: {suspended_count} suspended source(s)")
                    else:
                        print(f"🔄 Flux (GitOps): Starting")
                        print(f"   Status: Controllers {running_count}/{total_count} ready")
                else:
                    print(f"🔄 Flux (GitOps): Pending")
                    print(f"   Status: No controller pods found")
        except Exception as e:
            logger.debug(f"Error checking Flux: {e}")

    def is_ingress_controller_ready(self) -> bool:
        """Check if any ingress controller (NGINX or Gateway API) is ready."""
        try:
            # Check for NGINX Ingress Controller
            for namespace in ['hostk8s', 'ingress-nginx']:
                result = run_kubectl(['get', 'deployment', 'ingress-nginx-controller',
                                    '-n', namespace, '--no-headers'], check=False)
                if result.returncode == 0 and result.stdout:
                    # Parse ready status (e.g., "1/1")
                    parts = result.stdout.split()
                    if len(parts) >= 2:
                        ready_str = parts[1]  # e.g., "1/1"
                        if '/' in ready_str:
                            ready, total = ready_str.split('/')
                            if ready == total and int(ready) > 0:
                                return True

            # Check for Gateway API with Istio controller
            gateway_result = run_kubectl(['get', 'gateway', 'hostk8s-gateway', '-n', 'istio-system'],
                                       check=False, capture_output=True)
            if gateway_result.returncode == 0:
                # Verify the gateway pod is running
                pod_result = run_kubectl(['get', 'pods', '-n', 'istio-system',
                                        '-l', 'gateway.networking.k8s.io/gateway-name=hostk8s-gateway',
                                        '--no-headers'], check=False, capture_output=True)
                if pod_result.returncode == 0 and 'Running' in pod_result.stdout:
                    return True

            return False
        except Exception:
            return False

    def get_flux_git_repositories(self) -> List[Dict[str, Any]]:
        """Get Flux GitRepository resources."""
        repos = []
        try:
            if has_flux_cli():
                result = run_flux(['get', 'sources', 'git'], check=False)
                if result.returncode == 0 and result.stdout:
                    lines = result.stdout.strip().split('\n')
                    if len(lines) > 1 and 'NAME' in lines[0]:  # Has header
                        for line in lines[1:]:
                            if line.strip():
                                parts = line.split('\t')
                                if len(parts) >= 5:
                                    name = parts[0].strip()
                                    # Get additional details via kubectl
                                    url_result = run_kubectl(['get', 'gitrepository.source.toolkit.fluxcd.io',
                                                            name, '-n', 'flux-system',
                                                            '-o', 'jsonpath={.spec.url}'], check=False)
                                    branch_result = run_kubectl(['get', 'gitrepository.source.toolkit.fluxcd.io',
                                                               name, '-n', 'flux-system',
                                                               '-o', 'jsonpath={.spec.ref.branch}'], check=False)

                                    repos.append({
                                        'name': name,
                                        'revision': parts[1].strip(),
                                        'suspended': parts[2].strip(),
                                        'ready': parts[3].strip(),
                                        'message': parts[4].strip() if len(parts) > 4 else '',
                                        'url': url_result.stdout.strip() if url_result.returncode == 0 else 'unknown',
                                        'branch': branch_result.stdout.strip() if branch_result.returncode == 0 else 'unknown'
                                    })
        except Exception as e:
            logger.debug(f"Error getting Git repositories: {e}")
        return repos

    def get_flux_kustomizations(self) -> List[Dict[str, Any]]:
        """Get Flux Kustomization resources."""
        kustomizations = []
        try:
            if has_flux_cli():
                result = run_flux(['get', 'kustomizations'], check=False)
                if result.returncode == 0 and result.stdout:
                    lines = result.stdout.strip().split('\n')
                    if len(lines) > 1 and 'NAME' in lines[0]:  # Has header
                        for line in lines[1:]:
                            if line.strip():
                                parts = line.split('\t')
                                if len(parts) >= 5:
                                    name = parts[0].strip()
                                    # Get source reference via kubectl
                                    source_result = run_kubectl(['get', 'kustomization.kustomize.toolkit.fluxcd.io',
                                                               name, '-n', 'flux-system',
                                                               '-o', 'jsonpath={.spec.sourceRef.name}'], check=False)

                                    suspended = parts[2].strip()
                                    ready = parts[3].strip()
                                    message = parts[4].strip() if len(parts) > 4 else ''

                                    # Determine status icon
                                    if suspended == 'True':
                                        status_icon = '[PAUSED]'
                                    elif ready == 'True':
                                        status_icon = '[OK]'
                                    elif ready == 'False':
                                        if 'dependency' in message and 'is not ready' in message:
                                            status_icon = '[WAITING]'
                                        else:
                                            status_icon = '[FAIL]'
                                    else:
                                        status_icon = '[...]'

                                    kustomizations.append({
                                        'name': name,
                                        'revision': parts[1].strip(),
                                        'suspended': suspended,
                                        'ready': ready,
                                        'message': message,
                                        'source_ref': source_result.stdout.strip() if source_result.returncode == 0 else 'unknown',
                                        'status_icon': status_icon
                                    })
        except Exception as e:
            logger.debug(f"Error getting Kustomizations: {e}")
        return kustomizations

    def get_deployed_apps(self) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
        """Get deployed applications (GitOps and Manual)."""
        gitops_apps = []
        manual_apps = []

        try:
            # GitOps applications (hostk8s.application label)
            gitops_result = run_kubectl(['get', 'deployments', '-l', 'hostk8s.application',
                                       '--all-namespaces', '--no-headers'], check=False)
            if gitops_result.returncode == 0 and gitops_result.stdout:
                for line in gitops_result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 6:
                            gitops_apps.append({
                                'namespace': parts[0],
                                'name': parts[1],
                                'ready': parts[2],
                                'up_to_date': parts[3],
                                'total': parts[4],
                                'age': parts[5]
                            })

            # Manual applications (hostk8s.app label) - check both deployments and statefulsets
            deployment_result = run_kubectl(['get', 'deployments', '-l', 'hostk8s.app',
                                           '--all-namespaces', '--no-headers'], check=False)
            if deployment_result.returncode == 0 and deployment_result.stdout:
                for line in deployment_result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 6:
                            manual_apps.append({
                                'namespace': parts[0],
                                'name': parts[1],
                                'ready': parts[2],
                                'up_to_date': parts[3],
                                'total': parts[4],
                                'age': parts[5],
                                'type': 'deployment'
                            })

            # Manual applications (hostk8s.app label) - StatefulSets
            statefulset_result = run_kubectl(['get', 'statefulsets', '-l', 'hostk8s.app',
                                            '--all-namespaces', '--no-headers'], check=False)
            if statefulset_result.returncode == 0 and statefulset_result.stdout:
                for line in statefulset_result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 4:
                            manual_apps.append({
                                'namespace': parts[0],
                                'name': parts[1],
                                'ready': parts[2],
                                'up_to_date': parts[2],  # StatefulSets don't have separate up_to_date
                                'total': parts[2],       # Use ready count for total
                                'age': parts[3],
                                'type': 'statefulset'
                            })

        except Exception as e:
            logger.debug(f"Error getting deployed apps: {e}")

        return gitops_apps, manual_apps

    def get_app_services(self, app_name: str, label_key: str) -> List[Dict[str, Any]]:
        """Get services for an application."""
        services = []
        try:
            result = run_kubectl(['get', 'services', '-l', f'{label_key}={app_name}',
                                '--all-namespaces', '--no-headers'], check=False)
            if result.returncode == 0 and result.stdout:
                for line in result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 6:
                            services.append({
                                'namespace': parts[0],
                                'name': parts[1],
                                'type': parts[2],
                                'cluster_ip': parts[3],
                                'external_ip': parts[4],
                                'ports': parts[5],
                                'age': parts[6] if len(parts) > 6 else ''
                            })
        except Exception as e:
            logger.debug(f"Error getting services for {app_name}: {e}")
        return services

    def get_app_ingress(self, app_name: str, label_key: str, namespace: str = None) -> List[Dict[str, Any]]:
        """Get ingress resources for an application."""
        ingress_list = []
        try:
            if namespace:
                # Get ingress for specific namespace
                result = run_kubectl(['get', 'ingress', '-l', f'{label_key}={app_name}',
                                    '-n', namespace, '--no-headers'], check=False)
            else:
                # Get ingress across all namespaces (original behavior)
                result = run_kubectl(['get', 'ingress', '-l', f'{label_key}={app_name}',
                                    '--all-namespaces', '--no-headers'], check=False)

            if result.returncode == 0 and result.stdout:
                for line in result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = line.split()
                        if namespace:
                            # For single namespace query, insert namespace at beginning
                            if len(parts) >= 3:
                                ingress_list.append({
                                    'namespace': namespace,
                                    'name': parts[0],
                                    'class': parts[1] if len(parts) > 1 else '',
                                    'hosts': parts[2] if len(parts) > 2 else '',
                                    'address': parts[3] if len(parts) > 3 else '',
                                    'ports': parts[4] if len(parts) > 4 else '',
                                    'age': parts[5] if len(parts) > 5 else ''
                                })
                        else:
                            # For all-namespaces query, namespace is first column
                            if len(parts) >= 4:
                                ingress_list.append({
                                    'namespace': parts[0],
                                    'name': parts[1],
                                    'class': parts[2] if len(parts) > 2 else '',
                                    'hosts': parts[3] if len(parts) > 3 else '',
                                    'address': parts[4] if len(parts) > 4 else '',
                                    'ports': parts[5] if len(parts) > 5 else '',
                                    'age': parts[6] if len(parts) > 6 else ''
                                })
        except Exception as e:
            logger.debug(f"Error getting ingress for {app_name}: {e}")
        return ingress_list

    def get_app_httproutes(self, app_name: str, label_key: str, namespace: str = None) -> List[Dict[str, Any]]:
        """Get HTTPRoute resources for an application."""
        route_list = []
        try:
            if namespace:
                # Get HTTPRoute for specific namespace
                result = run_kubectl(['get', 'httproute', '-l', f'{label_key}={app_name}',
                                    '-n', namespace, '--no-headers'], check=False)
            else:
                # Get HTTPRoute across all namespaces
                result = run_kubectl(['get', 'httproute', '-l', f'{label_key}={app_name}',
                                    '--all-namespaces', '--no-headers'], check=False)

            if result.returncode == 0 and result.stdout:
                for line in result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = line.split()
                        if namespace:
                            # Format: NAME HOSTNAMES AGE
                            if len(parts) >= 2:
                                route_list.append({
                                    'namespace': namespace,
                                    'name': parts[0],
                                    'hostnames': parts[1] if len(parts) > 1 else '',
                                    'age': parts[2] if len(parts) > 2 else ''
                                })
                        else:
                            # Format: NAMESPACE NAME HOSTNAMES AGE
                            if len(parts) >= 3:
                                route_list.append({
                                    'namespace': parts[0],
                                    'name': parts[1],
                                    'hostnames': parts[2] if len(parts) > 2 else '',
                                    'age': parts[3] if len(parts) > 3 else ''
                                })
        except Exception as e:
            logger.debug(f"Error getting HTTPRoutes for {app_name}: {e}")
        return route_list

    def get_ingress_paths(self, name: str, namespace: str) -> List[str]:
        """Get ingress paths for an ingress resource."""
        try:
            result = run_kubectl(['get', 'ingress', name, '-n', namespace,
                                '-o', 'jsonpath={.spec.rules[0].http.paths[*].path}'], check=False)
            if result.returncode == 0 and result.stdout:
                raw_paths = result.stdout.strip().split()
                # Clean up regex patterns to user-friendly paths
                clean_paths = []
                for path in raw_paths:
                    # Convert regex patterns like /path(/|$)(.*) to /path
                    if path.startswith('/'):
                        clean_path = path.split('(')[0]  # Take everything before first (
                        clean_paths.append(clean_path)
                    else:
                        clean_paths.append(path)
                return clean_paths if clean_paths else ['/']
            return ['/']
        except Exception:
            return ['/']

    def get_ingress_urls(self, name: str, namespace: str) -> List[str]:
        """Get complete ingress URLs for an ingress resource, considering both host and paths."""
        try:
            # Get host for the ingress
            host_result = run_kubectl(['get', 'ingress', name, '-n', namespace,
                                     '-o', 'jsonpath={.spec.rules[0].host}'], check=False)

            # Get ingress class to determine correct ports
            class_result = run_kubectl(['get', 'ingress', name, '-n', namespace,
                                      '-o', 'jsonpath={.spec.ingressClassName}'], check=False)

            # Get paths for the ingress
            paths = self.get_ingress_paths(name, namespace)

            # Determine ports based on ingress class
            http_port = "8080"  # Default NGINX
            https_port = "8443"  # Default NGINX

            if class_result.returncode == 0 and class_result.stdout.strip() == "istio":
                # For Istio ingress class, use Gateway API ports
                # Get actual Gateway API ports from our detection method
                try:
                    svc_result = run_kubectl(['get', 'service', 'hostk8s-gateway-istio', '-n', 'istio-system',
                                            '-o', 'jsonpath={.spec.ports[?(@.name=="http")].nodePort}'], check=False)
                    if svc_result.returncode == 0 and svc_result.stdout:
                        nodeport = int(svc_result.stdout.strip())
                        # Check Kind port mapping for this NodePort
                        import subprocess
                        cluster_name = "hostk8s"
                        try:
                            ctx_result = run_kubectl(['config', 'current-context'], check=False, capture_output=True)
                            if ctx_result.returncode == 0 and 'kind-' in ctx_result.stdout:
                                cluster_name = ctx_result.stdout.strip().replace('kind-', '')
                        except:
                            pass

                        docker_result = subprocess.run(['docker', 'port', f'{cluster_name}-control-plane'],
                                                     capture_output=True, text=True, check=False)
                        if docker_result.returncode == 0:
                            for line in docker_result.stdout.strip().split('\n'):
                                if f'{nodeport}/tcp' in line:
                                    if ' -> 0.0.0.0:' in line:
                                        http_port = line.split(' -> 0.0.0.0:')[1]
                                        break
                except:
                    # Fallback to common Gateway API ports
                    http_port = "8081"

            # Determine the host to use
            if host_result.returncode == 0 and host_result.stdout.strip():
                host = host_result.stdout.strip()
                # Use the specific host
                base_url = f"http://{host}:{http_port}"
            else:
                # No host specified, use localhost
                base_url = f"http://localhost:{http_port}"

            # Build complete URLs
            urls = []
            for path in paths:
                if path == '/':
                    urls.append(f"{base_url}/")
                else:
                    # Ensure path starts with / and format properly
                    clean_path = path if path.startswith('/') else f'/{path}'
                    urls.append(f"{base_url}{clean_path}")

            return urls
        except Exception:
            # Fallback - try to detect ingress class for default port
            try:
                class_result = run_kubectl(['get', 'ingress', name, '-n', namespace,
                                          '-o', 'jsonpath={.spec.ingressClassName}'], check=False)
                if class_result.returncode == 0 and class_result.stdout.strip() == "istio":
                    return ["http://localhost:8081/"]
            except:
                pass
            return ["http://localhost:8080/"]

    def has_ingress_tls(self, name: str, namespace: str) -> bool:
        """Check if ingress has TLS configuration."""
        try:
            result = run_kubectl(['get', 'ingress', name, '-n', namespace,
                                '-o', 'jsonpath={.spec.tls}'], check=False)
            return result.returncode == 0 and result.stdout.strip() not in ['', 'null']
        except Exception:
            return False

    def check_health(self) -> None:
        """Perform GitOps-aware health checks."""
        logger.info("Health Check")

        # First check if GitOps stack deployment is in progress
        if has_flux():
            kustomizations = self.get_flux_kustomizations()
            if kustomizations:
                ready_count = sum(1 for k in kustomizations if k['ready'] == 'True')
                total_count = len(kustomizations)

                if ready_count < total_count:
                    print(f"⏳ Stack deployment in progress ({ready_count} of {total_count} components ready)")
                    print()
                    return

        # If GitOps is complete or not used, check individual app health
        unhealthy_apps = []

        # Check manual deployed apps (both deployments and statefulsets)
        try:
            # Check deployments
            deployment_result = run_kubectl(['get', 'deployments', '-l', 'hostk8s.app',
                                           '--all-namespaces', '--no-headers'], check=False)

            if deployment_result.returncode == 0 and deployment_result.stdout:
                for line in deployment_result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 3:
                            namespace = parts[0]
                            name = parts[1]
                            ready = parts[2]

                            if '/' in ready:
                                desired, actual = ready.split('/')
                                if desired != actual or actual == '0':
                                    unhealthy_apps.append(f"{namespace}/{name} ({ready})")

            # Check statefulsets
            statefulset_result = run_kubectl(['get', 'statefulsets', '-l', 'hostk8s.app',
                                            '--all-namespaces', '--no-headers'], check=False)

            if statefulset_result.returncode == 0 and statefulset_result.stdout:
                for line in statefulset_result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 3:
                            namespace = parts[0]
                            name = parts[1]
                            ready = parts[2]

                            if '/' in ready:
                                desired, actual = ready.split('/')
                                if desired != actual or actual == '0':
                                    unhealthy_apps.append(f"{namespace}/{name} ({ready})")
        except Exception as e:
            logger.debug(f"Error checking app health: {e}")

        # Check GitOps apps
        if has_flux():
            try:
                result = run_kubectl(['get', 'deployments', '-l', 'hostk8s.application',
                                    '--all-namespaces', '--no-headers'], check=False)

                if result.returncode == 0 and result.stdout:
                    for line in result.stdout.strip().split('\n'):
                        if line.strip():
                            parts = line.split()
                            if len(parts) >= 3:
                                namespace = parts[0]
                                name = parts[1]
                                ready = parts[2]

                                if '/' in ready:
                                    desired, actual = ready.split('/')
                                    if desired != actual or actual == '0':
                                        unhealthy_apps.append(f"{namespace}/{name} ({ready})")
            except Exception:
                pass

        if unhealthy_apps:
            logger.warn(f"Unhealthy apps detected: {len(unhealthy_apps)}")
            for app in unhealthy_apps:
                print(f"   ⚠️  {app}")
        else:
            logger.info("All deployed apps are healthy")

        print()


def show_gitops_resources() -> None:
    """Show GitOps resources if Flux is installed."""
    if not has_flux():
        return

    checker = EnhancedClusterStatusChecker()
    repos = checker.get_flux_git_repositories()
    kustomizations = checker.get_flux_kustomizations()

    if not repos and not kustomizations:
        return

    logger.info("GitOps Resources")

    # Show Git Repositories
    if repos:
        for repo in repos:
            print(f"📁 Repository: {repo['name']}")
            print(f"   URL: {repo['url']}")
            print(f"   Branch: {repo['branch']}")
            print(f"   Revision: {repo['revision']}")
            print(f"   Ready: {repo['ready']}")
            print(f"   Suspended: {repo['suspended']}")
            if repo['message'] and repo['message'] != '-':
                print(f"   Message: {repo['message']}")
            print()
    else:
        print("📁 No GitRepositories configured")
        print("   Run 'make restart sample' to configure a software stack")
        print()

    # Show Kustomizations
    if kustomizations:
        for kust in kustomizations:
            print(f"{kust['status_icon']} Kustomization: {kust['name']}")
            print(f"   Source: {kust['source_ref']}")
            print(f"   Revision: {kust['revision']}")
            print(f"   Ready: {kust['ready']}")
            print(f"   Suspended: {kust['suspended']}")
            if kust['message'] and kust['message'] not in ['-', '']:
                print(f"   Message: {kust['message']}")
            print()
    else:
        print("🔧 No Kustomizations configured")
        print("   GitOps resources will appear here after configuring a stack")
        print()


def show_gitops_applications() -> None:
    """Show GitOps-deployed applications."""
    checker = EnhancedClusterStatusChecker()
    gitops_apps, _ = checker.get_deployed_apps()

    if not gitops_apps:
        return

    logger.info("Stack Applications")

    # Show ingress controller status only when it's ready
    if checker.is_ingress_controller_ready():
        print("🌐 Ingress Controller: ingress-nginx (Ready ✅)")
        print("   Access: http://localhost:8080, https://localhost:8443")
        print()

    for app in gitops_apps:
        # Display name with namespace qualification if not default
        if app['namespace'] == 'default':
            display_name = app['name']
        else:
            display_name = f"{app['namespace']}.{app['name']}"

        print(f"📱 {display_name}")
        print(f"   Deployment: {app['name']} ({app['ready']} ready)")

        # Get app label for services/ingress lookup
        try:
            label_result = run_kubectl(['get', 'deployment', app['name'], '-n', app['namespace'],
                                      '-o', 'jsonpath={.metadata.labels.hostk8s\\.application}'], check=False)
            if label_result.returncode == 0 and label_result.stdout:
                app_label = label_result.stdout.strip()

                # Show services
                services = checker.get_app_services(app_label, 'hostk8s.application')
                for service in services:
                    if service['type'] == 'NodePort':
                        # Extract NodePort
                        port_info = service['ports']  # e.g., "80:30080/TCP"
                        if ':' in port_info:
                            nodeport = port_info.split(':')[1].split('/')[0]
                            print(f"   Service: {service['name']} (NodePort {nodeport})")
                        else:
                            print(f"   Service: {service['name']} (NodePort)")
                    elif service['type'] == 'LoadBalancer':
                        external_ip = service['external_ip']
                        if external_ip and external_ip != '<none>':
                            print(f"   Service: {service['name']} (LoadBalancer, {external_ip})")
                        else:
                            print(f"   Service: {service['name']} (LoadBalancer, pending)")
                    else:
                        print(f"   Service: {service['name']} ({service['type']})")

                # Show ingress and HTTPRoute resources
                ingress_list = checker.get_app_ingress(app_label, 'hostk8s.application')
                httproute_list = checker.get_app_httproutes(app_label, 'hostk8s.application')

                # Process traditional Ingress resources
                for ingress in ingress_list:
                    if ingress['hosts'] in ['localhost', '*']:
                        # Use the centralized URL detection that handles ingress class properly
                        urls = checker.get_ingress_urls(ingress['name'], ingress['namespace'])

                        if checker.is_ingress_controller_ready():
                            if len(urls) == 1:
                                print(f"   Access: {urls[0]} ({ingress['name']} ingress)")
                            else:
                                print(f"   Access: {', '.join(urls)} ({ingress['name']} ingress)")
                        else:
                            # Show URL with warning to match UX pattern
                            if len(urls) == 1:
                                print(f"   Ingress: {ingress['name']} -> {urls[0]} ⚠️ (No Ingress Controller)")
                            else:
                                print(f"   Ingress: {ingress['name']} -> {', '.join(urls)} ⚠️ (No Ingress Controller)")
                    else:
                        # Non-localhost hosts
                        if checker.is_ingress_controller_ready():
                            if ingress['hosts'].endswith('.localhost'):
                                paths = checker.get_ingress_paths(ingress['name'], ingress['namespace'])
                                if len(paths) == 1 and paths[0] == '/':
                                    print(f"   Access: http://{ingress['hosts']}:8080/ ({ingress['name']} ingress)")
                                else:
                                    url_list = [f"http://{ingress['hosts']}:8080{path}{'/' if not path.endswith('/') else ''}" for path in paths]
                                    print(f"   Access: {', '.join(url_list)} ({ingress['name']} ingress)")
                            else:
                                print(f"   Ingress: {ingress['name']} (hosts: {ingress['hosts']})")
                        else:
                            print(f"   Ingress: {ingress['name']} (hosts: {ingress['hosts']}) ⚠️ (No Ingress Controller)")

                # Process HTTPRoute resources (Gateway API)
                for httproute in httproute_list:
                    if 'localhost' in httproute['hostnames']:
                        # HTTPRoutes with localhost - determine correct Gateway API ports
                        try:
                            # Get actual Gateway API ports from service
                            svc_result = run_kubectl(['get', 'service', 'hostk8s-gateway-istio', '-n', 'istio-system',
                                                    '-o', 'jsonpath={.spec.ports[?(@.name=="http")].nodePort}'], check=False)
                            https_svc_result = run_kubectl(['get', 'service', 'hostk8s-gateway-istio', '-n', 'istio-system',
                                                          '-o', 'jsonpath={.spec.ports[?(@.name=="https")].nodePort}'], check=False)

                            # Default Gateway API ports
                            http_port = "8081"
                            https_port = "8444"

                            # Get actual host ports from Kind mapping
                            if svc_result.returncode == 0 and svc_result.stdout:
                                try:
                                    nodeport = int(svc_result.stdout.strip())
                                    import subprocess
                                    cluster_name = "hostk8s"
                                    try:
                                        ctx_result = run_kubectl(['config', 'current-context'], check=False, capture_output=True)
                                        if ctx_result.returncode == 0 and 'kind-' in ctx_result.stdout:
                                            cluster_name = ctx_result.stdout.strip().replace('kind-', '')
                                    except:
                                        pass

                                    docker_result = subprocess.run(['docker', 'port', f'{cluster_name}-control-plane'],
                                                                 capture_output=True, text=True, check=False)
                                    if docker_result.returncode == 0:
                                        for line in docker_result.stdout.strip().split('\n'):
                                            if f'{nodeport}/tcp' in line:
                                                if ' -> 0.0.0.0:' in line:
                                                    http_port = line.split(' -> 0.0.0.0:')[1]
                                                    break
                                except:
                                    pass

                            if https_svc_result.returncode == 0 and https_svc_result.stdout:
                                try:
                                    nodeport = int(https_svc_result.stdout.strip())
                                    docker_result = subprocess.run(['docker', 'port', f'{cluster_name}-control-plane'],
                                                                 capture_output=True, text=True, check=False)
                                    if docker_result.returncode == 0:
                                        for line in docker_result.stdout.strip().split('\n'):
                                            if f'{nodeport}/tcp' in line:
                                                if ' -> 0.0.0.0:' in line:
                                                    https_port = line.split(' -> 0.0.0.0:')[1]
                                                    break
                                except:
                                    pass

                            if checker.is_ingress_controller_ready():
                                # Show HTTP access URL (main productpage)
                                print(f"   Access: http://localhost:{http_port}/productpage ({httproute['name']} httproute)")
                            else:
                                print(f"   HTTPRoute: {httproute['name']} -> http://localhost:{http_port}/productpage ⚠️ (No Gateway API)")
                        except Exception:
                            # Fallback
                            if checker.is_ingress_controller_ready():
                                print(f"   Access: http://localhost:8081/productpage ({httproute['name']} httproute)")
                            else:
                                print(f"   HTTPRoute: {httproute['name']} -> http://localhost:8081/productpage ⚠️ (No Gateway API)")

        except Exception:
            pass

        print()


def show_manual_deployed_apps() -> None:
    """Show manually deployed applications."""
    checker = EnhancedClusterStatusChecker()
    _, manual_apps = checker.get_deployed_apps()

    if not manual_apps:
        return

    logger.info("Component Services")

    # Group apps by label and namespace to avoid duplicates
    app_groups = {}
    for app in manual_apps:
        try:
            # Get app label from the appropriate resource type
            resource_type = app.get('type', 'deployment')
            label_result = run_kubectl(['get', resource_type, app['name'], '-n', app['namespace'],
                                      '-o', 'jsonpath={.metadata.labels.hostk8s\\.app}'], check=False)
            if label_result.returncode == 0 and label_result.stdout:
                app_label = label_result.stdout.strip()
                if app['namespace'] == 'default':
                    key = app_label
                else:
                    key = f"{app['namespace']}.{app_label}"

                if key not in app_groups:
                    app_groups[key] = {'apps': [], 'label': app_label, 'namespaces': set()}
                app_groups[key]['apps'].append(app)
                app_groups[key]['namespaces'].add(app['namespace'])
        except Exception:
            continue

    for display_name, group in app_groups.items():
        print(f"📱 {display_name}")

        # Show deployments and statefulsets
        for app in group['apps']:
            resource_type = app.get('type', 'deployment').title()
            print(f"   {resource_type}: {app['name']} ({app['ready']} ready)")

        # Show services
        services = checker.get_app_services(group['label'], 'hostk8s.app')
        for service in services:
            print(f"   Service: {service['name']} ({service['type']})")

        # Show ingress - check each namespace individually to avoid duplicates
        shown_ingress = set()
        for namespace in group['namespaces']:
            ingress_list = checker.get_app_ingress(group['label'], 'hostk8s.app', namespace)
            for ingress in ingress_list:
                # Use namespace+name as unique key to avoid showing duplicates
                ingress_key = f"{ingress['namespace']}.{ingress['name']}"
                if ingress_key not in shown_ingress:
                    shown_ingress.add(ingress_key)

                    # Get complete URLs from the ingress
                    urls = checker.get_ingress_urls(ingress['name'], ingress['namespace'])

                    # Check if ingress controller is available
                    warning = "" if has_ingress_controller() else " ⚠️ (No Ingress Controller)"

                    if len(urls) == 1:
                        print(f"   Ingress: {ingress['name']} -> {urls[0]}{warning}")
                    else:
                        print(f"   Ingress: {ingress['name']} -> {', '.join(urls)}{warning}")

        print()


def main() -> None:
    """Main entry point."""
    logger.info("[Script 🐍] Running script: [cyan]cluster-status.py[/cyan]")
    try:
        # Ensure we have a valid kubeconfig
        kubeconfig = detect_kubeconfig()

        # Show kubeconfig info (debug only)
        checker = EnhancedClusterStatusChecker()
        checker.show_kubeconfig_info()

        # Show comprehensive status
        checker.check_docker_services()
        checker.check_cluster_services()

        # Show applications (keep existing functionality)
        show_gitops_resources()
        show_gitops_applications()
        show_manual_deployed_apps()

        # Health check
        checker.check_health()

    except HostK8sError as e:
        logger.error(str(e))
        sys.exit(1)
    except KeyboardInterrupt:
        logger.warn("Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
