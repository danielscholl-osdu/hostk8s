#!/bin/bash
# infra/scripts/cluster-status.sh - Show cluster health and running services
source "$(dirname "$0")/common.sh"

show_kubeconfig_info() {
    log_debug "export KUBECONFIG=${PWD}/data/kubeconfig/config"
    echo
}

show_gitops_resources() {
    if ! has_flux; then
        return 0
    fi

    # Only show this section if there are actual GitOps resources configured
    local has_git_repos=0
    local has_kustomizations=0

    if has_flux_cli; then
        local git_output=$(flux get sources git 2>/dev/null)
        if [ -n "$git_output" ] && echo "$git_output" | grep -q "^NAME"; then
            has_git_repos=$(echo "$git_output" | grep -v "^NAME" | grep -c "." || echo "0")
        fi

        local kustomization_output=$(flux get kustomizations 2>/dev/null)
        if [ -n "$kustomization_output" ] && echo "$kustomization_output" | grep -q "^NAME"; then
            has_kustomizations=$(echo "$kustomization_output" | grep -v "^NAME" | grep -c "." || echo "0")
        fi
    fi

    if [ "$has_git_repos" -gt 0 ] || [ "$has_kustomizations" -gt 0 ]; then
        log_info "GitOps Resources"
        show_git_repositories
        show_kustomizations
    fi
}

show_git_repositories() {
    if has_flux_cli; then
        local git_output=$(flux get sources git 2>/dev/null)
        if [ -z "$git_output" ] || ! echo "$git_output" | grep -q "^NAME"; then
            echo "📁 No GitRepositories configured"
            echo "   Run 'make restart sample' to configure a software stack"
            echo
            return 0
        fi

        echo "$git_output" | grep -v "^NAME" | while IFS=$'\t' read -r name revision suspended ready message; do
            [ -z "$name" ] && continue
            local name_trimmed=$(echo "$name" | tr -d ' ')
            local repo_url=$(kubectl get gitrepository.source.toolkit.fluxcd.io "$name_trimmed" -n flux-system -o jsonpath='{.spec.url}' 2>/dev/null || echo "unknown")
            local branch=$(kubectl get gitrepository.source.toolkit.fluxcd.io "$name_trimmed" -n flux-system -o jsonpath='{.spec.ref.branch}' 2>/dev/null || echo "unknown")

            echo "📁 Repository: $name"
            echo "   URL: $repo_url"
            echo "   Branch: $branch"
            echo "   Revision: $revision"
            echo "   Ready: $ready"
            echo "   Suspended: $suspended"
            [ "$message" != "-" ] && echo "   Message: $message"
            echo
        done
    else
        echo "flux CLI not available - showing basic repository status:"
        local repos=$(kubectl get gitrepositories.source.toolkit.fluxcd.io -A --no-headers 2>/dev/null)
        if [ -z "$repos" ]; then
            echo "No GitRepositories configured"
            return 0
        fi
        echo "$repos" | while read -r ns name ready status age; do
            local repo_url=$(kubectl get gitrepository.source.toolkit.fluxcd.io "$name" -n "$ns" -o jsonpath='{.spec.url}' 2>/dev/null || echo "unknown")
            echo "Repository: $name ($repo_url)"
            echo "Ready: $ready"
        done
    fi
}

show_kustomizations() {
    if ! has_flux_cli; then
        return 0
    fi

    local kustomization_output=$(flux get kustomizations 2>/dev/null)
    if [ -z "$kustomization_output" ] || ! echo "$kustomization_output" | grep -q "^NAME"; then
        echo "🔧 No Kustomizations configured"
        echo "   GitOps resources will appear here after configuring a stack"
        echo
        return 0
    fi

    echo "$kustomization_output" | grep -v "^NAME" | grep -v "^[[:space:]]*$" | while IFS=$'\t' read -r name revision suspended ready message; do
        local name_trimmed=$(echo "$name" | tr -d ' ')
        [ -z "$name_trimmed" ] && continue

        local source_ref=$(kubectl get kustomization.kustomize.toolkit.fluxcd.io "$name_trimmed" -n flux-system -o jsonpath='{.spec.sourceRef.name}' 2>/dev/null || echo "unknown")
        local suspended_trim=$(echo "$suspended" | tr -d ' ')
        local ready_trim=$(echo "$ready" | tr -d ' ')

        local status_icon
        if [ "$suspended_trim" = "True" ]; then
            status_icon="[PAUSED]"
        elif [ "$ready_trim" = "True" ]; then
            status_icon="[OK]"
        elif [ "$ready_trim" = "False" ]; then
            if echo "$message" | grep -q "dependency.*is not ready"; then
                status_icon="[WAITING]"
            else
                status_icon="[FAIL]"
            fi
        else
            status_icon="[...]"
        fi

        echo "$status_icon Kustomization: $name"
        echo "   Source: $source_ref"
        echo "   Revision: $revision"
        echo "   Ready: $ready"
        echo "   Suspended: $suspended"
        [ "$message" != "-" ] && [ "$message" != "" ] && echo "   Message: $message"
        echo
    done
}

show_gitops_applications() {
    local gitops_deployments=$(kubectl get deployments -l hostk8s.application --all-namespaces --no-headers 2>/dev/null)

    if [ -z "$gitops_deployments" ]; then
        return 0
    fi

    log_info "GitOps Applications"
    show_ingress_controller_status

    echo "$gitops_deployments" | while read -r ns deployment_name ready up total age; do
        [ -z "$ns" ] && continue

        # Use deployment name as primary identifier with namespace qualification
        local display_name
        if [ "$ns" = "default" ]; then
            display_name="$deployment_name"
        else
            display_name="$ns.$deployment_name"
        fi

        # Get the hostk8s.application label for services/ingress lookup
        local app_label=$(kubectl get deployment "$deployment_name" -n "$ns" -o jsonpath='{.metadata.labels.hostk8s\.application}' 2>/dev/null)

        echo "📱 $display_name"

        # Show deployment status
        echo "   Deployment: $deployment_name ($ready ready)"

        # Show services and ingress for this app
        if [ -n "$app_label" ]; then
            show_app_services "$app_label" "application"
            show_app_ingress "$app_label" "application"
        fi
        echo
    done
}

is_ingress_controller_ready() {
    # Check hostk8s namespace first (HostK8s default), then ingress-nginx namespace (standard)
    local ingress_ready=$(kubectl get deployment ingress-nginx-controller -n hostk8s --no-headers 2>/dev/null | awk '{ready=$2; split(ready,a,"/"); if(a[1]==a[2] && a[1]>0) print "ready"; else print "not ready"}' 2>/dev/null || kubectl get deployment ingress-nginx-controller -n ingress-nginx --no-headers 2>/dev/null | awk '{ready=$2; split(ready,a,"/"); if(a[1]==a[2] && a[1]>0) print "ready"; else print "not ready"}' || echo "not found")
    [ "$ingress_ready" = "ready" ]
}

show_ingress_controller_status() {
    # Check hostk8s namespace first (HostK8s default), then ingress-nginx namespace (standard)
    local ingress_ready=$(kubectl get deployment ingress-nginx-controller -n hostk8s --no-headers 2>/dev/null | awk '{ready=$2; split(ready,a,"/"); if(a[1]==a[2] && a[1]>0) print "ready"; else print "not ready"}' 2>/dev/null || kubectl get deployment ingress-nginx-controller -n ingress-nginx --no-headers 2>/dev/null | awk '{ready=$2; split(ready,a,"/"); if(a[1]==a[2] && a[1]>0) print "ready"; else print "not ready"}' || echo "not found")

    if [ "$ingress_ready" = "ready" ]; then
        echo "🌐 Ingress Controller: ingress-nginx (Ready ✅)"
        echo "   Access: http://localhost:8080, https://localhost:8443"
    else
        echo "🌐 Ingress Controller: ingress-nginx ($ingress_ready !)"
    fi
    echo
}

show_manual_deployed_apps() {
    local deployed_deployments=$(kubectl get deployments -l hostk8s.app --all-namespaces --no-headers 2>/dev/null)

    if [ -z "$deployed_deployments" ]; then
        return 0
    fi

    log_info "Manual Deployed Apps"

    # Get unique app identifiers using two-tier grouping strategy
    local unique_apps=$(echo "$deployed_deployments" | while read -r ns deployment_name ready up total age; do
        [ -z "$ns" ] && continue

        # Check if this is a Helm-managed app
        local managed_by=$(kubectl get deployment "$deployment_name" -n "$ns" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null)

        if [ "$managed_by" = "Helm" ]; then
            # For Helm apps: use app.kubernetes.io/instance + namespace
            local instance=$(kubectl get deployment "$deployment_name" -n "$ns" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null)
            if [ -n "$instance" ]; then
                if [ "$ns" = "default" ]; then
                    echo "helm:$instance"
                else
                    echo "helm:$ns.$instance"
                fi
            fi
        else
            # For non-Helm apps: use hostk8s.app + namespace
            local app_label=$(kubectl get deployment "$deployment_name" -n "$ns" -o jsonpath='{.metadata.labels.hostk8s\.app}' 2>/dev/null)
            if [ -n "$app_label" ]; then
                if [ "$ns" = "default" ]; then
                    echo "app:$app_label"
                else
                    echo "app:$ns.$app_label"
                fi
            fi
        fi
    done | sort -u)

    if [ -z "$unique_apps" ]; then
        return 0
    fi

    echo "$unique_apps" | while read -r app_identifier; do
        [ -z "$app_identifier" ] && continue

        local app_type=$(echo "$app_identifier" | cut -d':' -f1)
        local app_key=$(echo "$app_identifier" | cut -d':' -f2)

        if [ "$app_type" = "helm" ]; then
            # Handle Helm app
            local display_name="$app_key"
            echo "📱 $display_name"

            # Show chart info for Helm apps
            show_helm_chart_info_by_instance "$app_key"

            # Show deployments, services, and ingress for this Helm instance
            show_helm_app_resources "$app_key"
        else
            # Handle non-Helm app
            local display_name="$app_key"
            echo "📱 $display_name"

            # Extract actual app name (remove namespace prefix if present)
            local actual_app_name="$app_key"
            if echo "$app_key" | grep -q '\.' ; then
                actual_app_name=$(echo "$app_key" | sed 's/^[^.]*\.//')
            fi

            # Show all deployments for this app
            show_app_deployments "$actual_app_name" "app"

            # Show services and ingress for this app
            show_app_services "$actual_app_name" "app"
            show_app_ingress "$actual_app_name" "app"
        fi
        echo
    done
}

show_app_deployments() {
    local app_name="$1"
    local app_type="$2"

    get_deployments_for_app "$app_name" "$app_type" | while read -r ns name ready up total age; do
        [ -z "$ns" ] && continue
        echo "   Deployment: $name ($ready ready)"
    done
}

show_app_services() {
    local app_name="$1"
    local app_type="$2"

    get_services_for_app "$app_name" "$app_type" | while read -r ns name type cluster_ip external_ip ports age; do
        [ -z "$ns" ] && continue

        case "$type" in
            "NodePort")
                local nodeport=$(get_nodeport_access "$ns $name $type $cluster_ip $external_ip $ports $age")
                echo "   Service: $name (NodePort $nodeport)"
                ;;
            "LoadBalancer")
                local access=$(get_loadbalancer_access "$ns $name $type $cluster_ip $external_ip $ports $age")
                echo "   Service: $name ($type, $access)"
                ;;
            "ClusterIP")
                echo "   Service: $name (ClusterIP)"
                ;;
            *)
                echo "   Service: $name ($type)"
                ;;
        esac
    done
}

show_app_ingress() {
    local app_name="$1"
    local app_type="$2"

    get_ingress_for_app "$app_name" "$app_type" | while read -r ns name class hosts address ports age; do
        [ -z "$ns" ] && continue

        if [ "$hosts" = "localhost" ] || [ "$hosts" = "*" ]; then
            if is_ingress_controller_ready; then
                if [ "$app_type" = "application" ]; then
                    local paths=$(kubectl get ingress "$name" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[*].path}' 2>/dev/null)
                    local has_tls=$(kubectl get ingress "$name" -n "$ns" -o jsonpath='{.spec.tls}' 2>/dev/null)

                    # Format paths for display
                    local formatted_paths=""
                    if [ "$paths" = "/" ]; then
                        formatted_paths="/"
                    else
                        # Convert space-separated paths to comma-separated for display
                        formatted_paths=$(echo "$paths" | tr ' ' ',' | sed 's/,/, /g')
                        # For URLs, show each path separately
                        local url_list=""
                        for path in $paths; do
                            if [ -z "$url_list" ]; then
                                url_list="http://localhost:8080$path"
                            else
                                url_list="$url_list, http://localhost:8080$path"
                            fi
                        done
                        if [ -n "$has_tls" ] && [ "$has_tls" != "null" ]; then
                            for path in $paths; do
                                url_list="$url_list, https://localhost:8443$path"
                            done
                        fi
                        echo "   Access: $url_list ($name ingress)"
                        continue
                    fi

                    # Handle single root path
                    if [ -n "$has_tls" ] && [ "$has_tls" != "null" ]; then
                        echo "   Access: http://localhost:8080/, https://localhost:8443/ ($name ingress)"
                    else
                        echo "   Access: http://localhost:8080/ ($name ingress)"
                    fi
                else
                    # Handle other app types with multi-path support
                    local paths=$(kubectl get ingress "$name" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[*].path}' 2>/dev/null)
                    if [ "$paths" = "/" ]; then
                        echo "   Ingress: $name -> http://localhost:8080/"
                    else
                        local url_list=""
                        for path in $paths; do
                            # Clean up regex patterns for display
                            local clean_path=$(echo "$path" | sed 's|(.*)||' | sed 's|/$||')
                            if [ -z "$url_list" ]; then
                                url_list="http://localhost:8080$clean_path"
                            else
                                url_list="$url_list, http://localhost:8080$clean_path"
                            fi
                        done
                        echo "   Ingress: $name -> $url_list"
                    fi
                fi
            else
                echo "   Ingress: $name (configured but controller not ready)"
                echo "   Enable with: export INGRESS_ENABLED=true && make restart"
            fi
        else
            # Handle namespace-based hostnames (e.g., test.localhost)
            if is_ingress_controller_ready; then
                if [ "$app_type" = "application" ] && [[ "$hosts" == *.localhost ]]; then
                    local paths=$(kubectl get ingress "$name" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[*].path}' 2>/dev/null)
                    if [ "$paths" = "/" ]; then
                        echo "   Access: http://$hosts:8080/ ($name ingress)"
                    else
                        # Show all paths
                        local url_list=""
                        for path in $paths; do
                            if [ -z "$url_list" ]; then
                                url_list="http://$hosts:8080$path"
                            else
                                url_list="$url_list, http://$hosts:8080$path"
                            fi
                        done
                        echo "   Access: $url_list ($name ingress)"
                    fi
                else
                    echo "   Ingress: $name (hosts: $hosts)"
                fi
            else
                echo "   Ingress: $name (configured but controller not ready)"
            fi
        fi
    done
}

# Helm-specific helper functions
show_helm_chart_info_by_instance() {
    local app_key="$1"

    # Extract namespace and instance name
    local namespace="default"
    local instance="$app_key"
    if echo "$app_key" | grep -q '\.'; then
        namespace=$(echo "$app_key" | cut -d'.' -f1)
        instance=$(echo "$app_key" | cut -d'.' -f2-)
    fi

    # Get chart info from any deployment with this instance label in the namespace
    local first_deployment=$(kubectl get deployments -l "app.kubernetes.io/instance=$instance" -n "$namespace" --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    if [ -n "$first_deployment" ]; then
        local chart_info=$(kubectl get deployment "$first_deployment" -n "$namespace" -o jsonpath='{.metadata.labels.helm\.sh/chart}' 2>/dev/null)
        if [ -n "$chart_info" ]; then
            echo "   Chart: $chart_info"
        fi
    fi
}

show_helm_app_resources() {
    local app_key="$1"

    # Extract namespace and instance name
    local namespace="default"
    local instance="$app_key"
    if echo "$app_key" | grep -q '\.'; then
        namespace=$(echo "$app_key" | cut -d'.' -f1)
        instance=$(echo "$app_key" | cut -d'.' -f2-)
    fi

    # Show deployments for this Helm instance
    kubectl get deployments -l "app.kubernetes.io/instance=$instance" -n "$namespace" --no-headers 2>/dev/null | while read -r name ready up total age; do
        [ -z "$name" ] && continue
        echo "   Deployment: $name ($ready ready)"
    done

    # Show services for this Helm instance
    kubectl get services -l "app.kubernetes.io/instance=$instance" -n "$namespace" --no-headers 2>/dev/null | while read -r name type cluster_ip external_ip ports age; do
        [ -z "$name" ] && continue

        case "$type" in
            "NodePort")
                local nodeport=$(get_nodeport_access "$namespace $name $type $cluster_ip $external_ip $ports $age")
                echo "   Service: $name (NodePort $nodeport)"
                ;;
            "LoadBalancer")
                local access=$(get_loadbalancer_access "$namespace $name $type $cluster_ip $external_ip $ports $age")
                echo "   Service: $name ($type, $access)"
                ;;
            "ClusterIP")
                echo "   Service: $name (ClusterIP)"
                ;;
            *)
                echo "   Service: $name ($type)"
                ;;
        esac
    done

    # Show ingress for this Helm instance
    kubectl get ingress -l "app.kubernetes.io/instance=$instance" -n "$namespace" --no-headers 2>/dev/null | while read -r name class hosts address ports age; do
        [ -z "$name" ] && continue

        if [ "$hosts" = "localhost" ] || [ "$hosts" = "*" ]; then
            if is_ingress_controller_ready; then
                local path=$(kubectl get ingress "$name" -n "$namespace" -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)
                local has_tls=$(kubectl get ingress "$name" -n "$namespace" -o jsonpath='{.spec.tls}' 2>/dev/null)
                if [ "$path" = "/" ]; then
                    if [ -n "$has_tls" ] && [ "$has_tls" != "null" ]; then
                        echo "   Access: http://localhost:8080/, https://localhost:8443/ ($name ingress)"
                    else
                        echo "   Access: http://localhost:8080/ ($name ingress)"
                    fi
                else
                    if [ -n "$has_tls" ] && [ "$has_tls" != "null" ]; then
                        echo "   Access: http://localhost:8080$path, https://localhost:8443$path ($name ingress)"
                    else
                        echo "   Access: http://localhost:8080$path ($name ingress)"
                    fi
                fi
            else
                echo "   Ingress: $name (configured but controller not ready)"
                echo "   Enable with: export INGRESS_ENABLED=true && make restart"
            fi
        else
            # Handle namespace-based hostnames (e.g., test.localhost)
            if is_ingress_controller_ready; then
                if [[ "$hosts" == *.localhost ]]; then
                    local path=$(kubectl get ingress "$name" -n "$namespace" -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)
                    if [ "$path" = "/" ]; then
                        echo "   Access: http://$hosts:8080/ ($name ingress)"
                    else
                        echo "   Access: http://$hosts:8080$path ($name ingress)"
                    fi
                else
                    echo "   Ingress: $name (hosts: $hosts)"
                fi
            else
                echo "   Ingress: $name (configured but controller not ready)"
            fi
        fi
    done
}

check_gitops_health() {
    local gitops_issues_found=0

    if ! has_flux_cli; then
        return 0
    fi

    # Check Kustomization status for GitOps stacks
    local kustomization_output=$(flux get kustomizations 2>/dev/null)
    if [ -n "$kustomization_output" ] && echo "$kustomization_output" | grep -q "^NAME"; then
        echo "$kustomization_output" | grep -v "^NAME" | grep -v "^[[:space:]]*$" | while IFS=$'\t' read -r name revision suspended ready message; do
            local name_trimmed=$(echo "$name" | tr -d ' ')
            [ -z "$name_trimmed" ] && continue

            local ready_trim=$(echo "$ready" | tr -d ' ')
            local suspended_trim=$(echo "$suspended" | tr -d ' ')

            # Skip if suspended (paused by design)
            if [ "$suspended_trim" = "True" ]; then
                continue
            fi

            # Check if not ready
            if [ "$ready_trim" = "False" ]; then
                log_warn "GitOps Kustomization $name_trimmed not ready: $message"
                exit 1
            fi
        done || gitops_issues_found=1
    fi

    return $gitops_issues_found
}

check_manual_apps_health() {
    local manual_issues_found=0

    # Check if any manual apps exist
    if ! kubectl get all -l hostk8s.app --all-namespaces >/dev/null 2>&1; then
        return 0
    fi

    # Check LoadBalancer services
    kubectl get services -l hostk8s.app --all-namespaces --no-headers 2>/dev/null | while read -r ns name type cluster_ip external_ip ports age; do
        if ! check_service_health "$ns $name $type $cluster_ip $external_ip $ports $age"; then
            log_warn "LoadBalancer $name is pending (MetalLB not installed?)"
            exit 1
        fi
    done && \

    # Check deployments
    kubectl get deployments -l hostk8s.app --all-namespaces --no-headers 2>/dev/null | while read -r ns name ready up total age; do
        if ! check_deployment_health "$ready"; then
            local ready_count=$(echo "$ready" | cut -d/ -f1)
            local total_count=$(echo "$ready" | cut -d/ -f2)
            log_warn "Deployment $name not fully ready ($ready_count/$total_count)"
            exit 1
        fi
    done && \

    # Check pods
    kubectl get pods -l hostk8s.app --all-namespaces --no-headers 2>/dev/null | while read -r ns name ready status restarts age; do
        if ! check_pod_health "$status"; then
            log_warn "Pod $name in $status state"
            exit 1
        fi
    done || manual_issues_found=1

    return $manual_issues_found
}

check_gitops_apps_health() {
    local gitops_app_issues_found=0

    # Check if any GitOps apps exist
    if ! kubectl get all -l hostk8s.application --all-namespaces >/dev/null 2>&1; then
        return 0
    fi

    # Check LoadBalancer services
    kubectl get services -l hostk8s.application --all-namespaces --no-headers 2>/dev/null | while read -r ns name type cluster_ip external_ip ports age; do
        if ! check_service_health "$ns $name $type $cluster_ip $external_ip $ports $age"; then
            log_warn "LoadBalancer $name is pending (MetalLB not installed?)"
            exit 1
        fi
    done && \

    # Check deployments
    kubectl get deployments -l hostk8s.application --all-namespaces --no-headers 2>/dev/null | while read -r ns name ready up total age; do
        if ! check_deployment_health "$ready"; then
            local ready_count=$(echo "$ready" | cut -d/ -f1)
            local total_count=$(echo "$ready" | cut -d/ -f2)
            log_warn "Deployment $name not fully ready ($ready_count/$total_count)"
            exit 1
        fi
    done && \

    # Check pods
    kubectl get pods -l hostk8s.application --all-namespaces --no-headers 2>/dev/null | while read -r ns name ready status restarts age; do
        if ! check_pod_health "$status"; then
            log_warn "Pod $name in $status state"
            exit 1
        fi
    done || gitops_app_issues_found=1

    return $gitops_app_issues_found
}

show_health_check() {
    # Check if there are any deployed resources to check
    local has_manual_apps=0
    local has_gitops_apps=0
    local has_gitops_stacks=0

    # Check for manual apps
    if kubectl get all -l hostk8s.app --all-namespaces >/dev/null 2>&1; then
        has_manual_apps=1
    fi

    # Check for GitOps applications
    if kubectl get all -l hostk8s.application --all-namespaces >/dev/null 2>&1; then
        has_gitops_apps=1
    fi

    # Check for GitOps stacks (Flux Kustomizations)
    if has_flux_cli; then
        local kustomization_output=$(flux get kustomizations 2>/dev/null)
        if [ -n "$kustomization_output" ] && echo "$kustomization_output" | grep -q "^NAME"; then
            has_gitops_stacks=1
        fi
    fi

    # If nothing is deployed, skip health check
    if [ "$has_manual_apps" = "0" ] && [ "$has_gitops_apps" = "0" ] && [ "$has_gitops_stacks" = "0" ]; then
        return 0
    fi

    log_info "Health Check"
    local total_issues_found=0

    # Check GitOps stack reconciliation status first (most important for stacks)
    if [ "$has_gitops_stacks" = "1" ]; then
        if ! check_gitops_health; then
            total_issues_found=1
        fi
    fi

    # Check GitOps application resources
    if [ "$has_gitops_apps" = "1" ]; then
        if ! check_gitops_apps_health; then
            total_issues_found=1
        fi
    fi

    # Check manual application resources
    if [ "$has_manual_apps" = "1" ]; then
        if ! check_manual_apps_health; then
            total_issues_found=1
        fi
    fi

    if [ "$total_issues_found" = "0" ]; then
        log_success "All deployed apps are healthy"
    fi
}

show_cluster_nodes() {
    # Get all nodes info
    local all_nodes=$(kubectl get nodes --no-headers 2>/dev/null)
    if [ -z "$all_nodes" ]; then
        echo "🕹️ Cluster Nodes: NotFound"
        echo "   Status: No nodes found"
        return
    fi

    # Count total nodes and check if multi-node
    local node_count=$(echo "$all_nodes" | wc -l | tr -d ' ')
    local is_multinode=false
    if [ "$node_count" -gt 1 ]; then
        is_multinode=true
    fi

    # Process each node
    echo "$all_nodes" | while read -r name status roles age k8s_version; do
        local node_type="Node"
        local node_icon="🖥️ "

        # Determine node type and icon based on roles
        if echo "$roles" | grep -q "control-plane"; then
            node_type="Control Plane"
            node_icon="🕹️ "
        elif echo "$roles" | grep -q "worker"; then
            node_type="Worker"
            node_icon="🚜 "
        elif echo "$roles" | grep -q "agent"; then
            node_type="Agent"
            node_icon="🤖 "
        elif [ "$roles" = "<none>" ]; then
            node_type="Worker"
            node_icon="🚜 "
        fi

        # Show node status
        echo "${node_icon}${node_type}: $status"
        if [ "$status" = "Ready" ]; then
            echo "   Status: Kubernetes $k8s_version (up $age)"
        else
            echo "   Status: Node status: $status"
        fi

        # Add node name for multi-node clusters
        if [ "$is_multinode" = "true" ]; then
            echo "   Node: $name"
        fi
    done
}

# Function to show Docker services status
show_docker_services() {
    log_info "Docker Services"

    local docker_services_found=false

    # Check for hostk8s-registry container
    if docker inspect hostk8s-registry >/dev/null 2>&1; then
        local container_status=$(docker inspect -f '{{.State.Status}}' hostk8s-registry 2>/dev/null)
        local port_info=$(docker port hostk8s-registry 2>/dev/null | head -1 | cut -d' ' -f3 || echo "localhost:5002")

        if [ "$container_status" = "running" ]; then
            echo "📦 Registry Container: Ready"
            echo "   Status: Running on $port_info"
            echo "   Network: Connected to Kind cluster"
        else
            echo "📦 Registry Container: $container_status"
        fi
        docker_services_found=true
    fi

    # Check for other hostk8s-* containers (future extensions, excluding Kind cluster nodes)
    local other_containers=$(docker ps -a --filter "name=hostk8s-*" --format "{{.Names}}" | grep -v "hostk8s-registry" | grep -v "hostk8s-control-plane" | grep -v "hostk8s-worker" 2>/dev/null || true)
    if [ -n "$other_containers" ]; then
        while IFS= read -r container; do
            local status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
            echo "🔧 $container: $status"
            docker_services_found=true
        done <<< "$other_containers"
    fi

    if [ "$docker_services_found" = false ]; then
        echo "   No Docker services running"
    fi
    echo
}

show_addon_status() {
    # Always show services section since control plane is always present
    log_info "Cluster Services"

    # Show all cluster nodes
    show_cluster_nodes

    # Metrics Server status (core cluster infrastructure)
    if [[ "${METRICS_DISABLED:-false}" != "true" ]]; then
        metrics_status=""
        metrics_message=""

        if has_metrics; then
            # Check if metrics API is available
            if kubectl top nodes >/dev/null 2>&1; then
                metrics_status="Ready"
                metrics_message="Resource metrics available (kubectl top)"
            else
                metrics_status="Starting"
                metrics_message="Metrics API not yet available"
            fi
        else
            metrics_status="NotReady"
            metrics_message="Deployment not found in kube-system namespace"
        fi

        echo "📊 Metrics Server: $metrics_status"
        [ -n "$metrics_message" ] && echo "   Status: $metrics_message"
    fi

    # Show Flux status if installed
    if has_flux; then
        local flux_status="NotReady"
        local flux_message=""
        local flux_version=$(get_flux_version)

        # Check if Flux controllers are running
        local flux_pods=$(kubectl get pods -n flux-system --no-headers 2>/dev/null | awk '{print $3}' | tr '\n' ' ')
        if echo "$flux_pods" | grep -q "Running"; then
            local running_count=$(echo "$flux_pods" | grep -o "Running" | wc -l | tr -d ' ')
            local total_count=$(echo "$flux_pods" | wc -w | tr -d ' ')
            if [ "$running_count" = "$total_count" ] && [ "$total_count" -gt 0 ]; then
                flux_status="Ready"
                flux_message="GitOps automation available ($flux_version)"
            else
                flux_status="Pending"
                flux_message="$running_count/$total_count controllers running"
            fi
        else
            flux_status="NotReady"
            flux_message="Controllers not running"
        fi

        echo "🔄 Flux (GitOps): $flux_status"
        [ -n "$flux_message" ] && echo "   Status: $flux_message"

        # Show suspended sources count if any
        if has_flux_cli; then
            local suspended_count=0
            local git_output=$(flux get sources git 2>/dev/null)
            if [ -n "$git_output" ] && echo "$git_output" | grep -q "^NAME"; then
                suspended_count=$(echo "$git_output" | grep -v "^NAME" | awk -F'\t' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); if($3=="True") count++} END {print count+0}')
            fi
            if [ "$suspended_count" -gt 0 ]; then
                echo "   Sources: $suspended_count suspended ⏸️"
            fi
        fi
    fi

    # Show MetalLB status if installed
    if has_metallb; then
        local metallb_status="NotReady"
        local metallb_message=""

        # Check if MetalLB pods are running
        local metallb_pods=$(kubectl get pods -n hostk8s -l app=metallb --no-headers 2>/dev/null | awk '{print $3}' | tr '\n' ' ')
        if echo "$metallb_pods" | grep -q "Running"; then
            local running_count=$(echo "$metallb_pods" | grep -o "Running" | wc -l | tr -d ' ')
            local total_count=$(echo "$metallb_pods" | wc -w | tr -d ' ')
            if [ "$running_count" = "$total_count" ] && [ "$total_count" -gt 0 ]; then
                metallb_status="Ready"
                metallb_message="LoadBalancer support available"
            else
                metallb_status="Pending"
                metallb_message="$running_count/$total_count pods running"
            fi
        else
            metallb_status="NotReady"
            metallb_message="Pods not running"
        fi

        echo "🔗 MetalLB (LoadBalancer): $metallb_status"
        [ -n "$metallb_message" ] && echo "   Status: $metallb_message"
    fi

    # Show Ingress status if installed
    if has_ingress; then
        local ingress_status="NotReady"
        local ingress_message=""

        # Check if ingress controller deployment is ready
        local ingress_ready=$(kubectl get deployment ingress-nginx-controller -n hostk8s --no-headers 2>/dev/null | awk '{ready=$2; split(ready,a,"/"); if(a[1]==a[2] && a[1]>0) print "ready"; else print a[1] "/" a[2]}' || echo "not found")

        if [ "$ingress_ready" = "ready" ]; then
            ingress_status="Ready"
            ingress_message="HTTP/HTTPS ingress available at localhost:8080/8443"
        elif [ "$ingress_ready" = "not found" ]; then
            ingress_status="NotReady"
            ingress_message="Controller deployment not found"
        else
            ingress_status="Pending"
            ingress_message="Controller deployment $ingress_ready ready"
        fi

        echo "🌐 NGINX Ingress: $ingress_status"
        [ -n "$ingress_message" ] && echo "   Status: $ingress_message"
    fi

    # Show Registry status if installed (hybrid Docker/K8s)
    if has_registry; then
        local registry_status="NotReady"
        local registry_message=""

        # Check Docker registry first (preferred)
        if has_registry_docker; then
            # Check if Kubernetes registry UI is also running
            local ui_ready=$(kubectl get deployment registry-ui -n hostk8s --no-headers 2>/dev/null | awk '{ready=$2; split(ready,a,"/"); if(a[1]==a[2] && a[1]>0) print "ready"; else print "not ready"}' || echo "not found")

            if [ "$ui_ready" = "ready" ]; then
                registry_status="Ready"
                registry_message="Docker registry with Web UI at http://localhost:8080/registry/"
            else
                registry_status="Ready"
                registry_message="Docker registry API at http://localhost:5002 (UI not deployed)"
            fi
        elif has_registry_k8s; then
            # Fallback to Kubernetes registry
            local core_ready=$(kubectl get deployment registry-core -n hostk8s --no-headers 2>/dev/null | awk '{ready=$2; split(ready,a,"/"); if(a[1]==a[2] && a[1]>0) print "ready"; else print a[1] "/" a[2]}' || echo "not found")

            if [ "$core_ready" = "ready" ]; then
                registry_status="Ready"
                registry_message="Kubernetes registry at http://localhost:5001"

                # Check if registry UI is also running
                local ui_ready=$(kubectl get deployment registry-ui -n hostk8s --no-headers 2>/dev/null | awk '{ready=$2; split(ready,a,"/"); if(a[1]==a[2] && a[1]>0) print "ready"; else print "not ready"}' || echo "not found")
                if [ "$ui_ready" = "ready" ]; then
                    registry_message="${registry_message}, Web UI: Available at http://localhost:8080/registry/"
                fi
            elif [ "$core_ready" = "not found" ]; then
                registry_status="NotReady"
                registry_message="Registry deployment not found"
            else
                registry_status="Pending"
                registry_message="Registry deployment $core_ready ready"
            fi
        else
            registry_status="NotReady"
            registry_message="No registry found (Docker or Kubernetes)"
        fi

        echo "📦 Registry: $registry_status"
        [ -n "$registry_message" ] && echo "   Status: $registry_message"
    fi


    echo
}

# Main function
main() {
    # Check if cluster exists (but allow status to show when not running)
    if [ ! -f "$KUBECONFIG_PATH" ]; then
        log_warn "No cluster found. Run 'make start' to start a cluster."
        exit 0
    fi

    # Check if cluster is running
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_warn "Cluster not running. Run 'make start' to start the cluster."
        exit 0
    fi

    show_kubeconfig_info
    show_docker_services
    show_addon_status
    show_gitops_resources
    show_gitops_applications
    show_manual_deployed_apps
    show_health_check
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
