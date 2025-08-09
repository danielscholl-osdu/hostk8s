#!/bin/bash
# infra/scripts/cluster-status.sh - Show cluster health and running services
source "$(dirname "$0")/common.sh"

show_kubeconfig_info() {
    log_debug "export KUBECONFIG=$(pwd)/data/kubeconfig/config"
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
            local repo_url=$(kubectl get gitrepository.source.toolkit.fluxcd.io "$name" -n flux-system -o jsonpath='{.spec.url}' 2>/dev/null || echo "unknown")
            local branch=$(kubectl get gitrepository.source.toolkit.fluxcd.io "$name" -n flux-system -o jsonpath='{.spec.ref.branch}' 2>/dev/null || echo "unknown")

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

        local source_ref=$(kubectl get kustomization.kustomize.toolkit.fluxcd.io "$name" -n flux-system -o jsonpath='{.spec.sourceRef.name}' 2>/dev/null || echo "unknown")
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
    local gitops_apps=$(kubectl get deployments -l hostk8s.application --all-namespaces -o jsonpath='{.items[*].metadata.labels.hostk8s\.application}' 2>/dev/null | tr ' ' '\n' | sort -u | tr '\n' ' ')

    if [ -z "$gitops_apps" ]; then
        return 0
    fi

    log_info "GitOps Applications"
    show_ingress_controller_status

    for app in $gitops_apps; do
        local namespaces=$(get_app_namespaces "$app" "application")
        local display_name
        if [ "$namespaces" = "default" ]; then
            display_name="$app"
        else
            display_name="$namespaces.$app"
        fi
        echo "📱 $display_name (GitOps)"
        show_app_deployments "$app" "application"
        show_app_services "$app" "application"
        show_app_ingress "$app" "application"
        echo
    done
}

is_ingress_controller_ready() {
    local ingress_ready=$(kubectl get deployment ingress-nginx-controller -n ingress-nginx --no-headers 2>/dev/null | awk '{ready=$2; split(ready,a,"/"); if(a[1]==a[2] && a[1]>0) print "ready"; else print "not ready"}' || echo "not found")
    [ "$ingress_ready" = "ready" ]
}

show_ingress_controller_status() {
    local ingress_ready=$(kubectl get deployment ingress-nginx-controller -n ingress-nginx --no-headers 2>/dev/null | awk '{ready=$2; split(ready,a,"/"); if(a[1]==a[2] && a[1]>0) print "ready"; else print "not ready"}' || echo "not found")

    if [ "$ingress_ready" = "ready" ]; then
        echo "🌐 Ingress Controller: ingress-nginx (Ready ✅)"
        echo "   Access: http://localhost:8080, https://localhost:8443"
    else
        echo "🌐 Ingress Controller: ingress-nginx ($ingress_ready ⚠️)"
    fi
    echo
}

show_manual_deployed_apps() {
    local deployed_apps=$(kubectl get all -l hostk8s.app --all-namespaces -o jsonpath='{.items[*].metadata.labels.hostk8s\.app}' 2>/dev/null | tr ' ' '\n' | sort -u | tr '\n' ' ')

    if [ -z "$deployed_apps" ]; then
        return 0
    fi

    log_info "Manual Deployed Apps"

    for app in $deployed_apps; do
        local namespaces=$(get_app_namespaces "$app" "app")
        local display_name
        if [ "$namespaces" = "default" ]; then
            display_name="$app"
        else
            display_name="$namespaces.$app"
        fi

        if is_helm_managed_app "$app"; then
            local helm_info=$(get_helm_chart_info "$app")
            if [ -n "$helm_info" ]; then
                local chart=$(echo "$helm_info" | cut -d',' -f1 | cut -d':' -f2)
                local version=$(echo "$helm_info" | cut -d',' -f2 | cut -d':' -f2)
                local release=$(echo "$helm_info" | cut -d',' -f3 | cut -d':' -f2)
                echo "📱 $display_name (Helm Chart: $chart, App: $version, Release: $release)"
            else
                echo "📱 $display_name (Helm-managed)"
            fi
        else
            echo "📱 $display_name"
        fi
        show_app_deployments "$app" "app"
        show_app_services "$app" "app"
        show_app_ingress "$app" "app"
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

        if [ "$hosts" = "localhost" ]; then
            if is_ingress_controller_ready; then
                local access=$(get_ingress_access "$app_name" "$ns $name $class $hosts $address $ports $age")
                if [ "$app_type" = "application" ]; then
                    local path=$(kubectl get ingress "$name" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)
                    if [ "$path" = "/" ]; then
                        echo "   Access: http://localhost:8080/ ($name ingress)"
                    else
                        echo "   Access: http://localhost:8080$path ($name ingress)"
                    fi
                else
                    echo "   Ingress: $name -> $access"
                fi
            else
                echo "   Ingress: $name (configured but controller not ready)"
                echo "   Enable with: export INGRESS_ENABLED=true && make restart"
            fi
        else
            echo "   Ingress: $name (hosts: $hosts)"
        fi
    done
}

show_health_check() {
    if ! kubectl get all -l hostk8s.app --all-namespaces >/dev/null 2>&1; then
        return 0
    fi

    log_info "Health Check"
    local issues_found=0

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
    done || issues_found=1

    if [ "$issues_found" = "0" ]; then
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

show_addon_status() {
    # Always show addons section since control plane is always present
    log_info "Cluster Addons"

    # Show all cluster nodes
    show_cluster_nodes

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
    fi

    # Show MetalLB status if installed
    if has_metallb; then
        local metallb_status="NotReady"
        local metallb_message=""

        # Check if MetalLB pods are running
        local metallb_pods=$(kubectl get pods -n metallb-system -l app=metallb --no-headers 2>/dev/null | awk '{print $3}' | tr '\n' ' ')
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
        local ingress_ready=$(kubectl get deployment ingress-nginx-controller -n ingress-nginx --no-headers 2>/dev/null | awk '{ready=$2; split(ready,a,"/"); if(a[1]==a[2] && a[1]>0) print "ready"; else print a[1] "/" a[2]}' || echo "not found")

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
