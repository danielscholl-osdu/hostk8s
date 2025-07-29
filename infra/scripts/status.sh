#!/bin/bash
# infra/scripts/status.sh - Show cluster health and running services
source "$(dirname "$0")/common.sh"

show_kubeconfig_info() {
    log_info "export KUBECONFIG=$(pwd)/data/kubeconfig/config"
    echo
}

show_gitops_status() {
    if ! has_flux; then
        return 0
    fi

    local flux_version=$(get_flux_version)
    log_status "GitOps Status (Flux:$flux_version)"

    show_git_repositories
    show_kustomizations
}

show_git_repositories() {
    if has_flux_cli; then
        flux get sources git 2>/dev/null | grep -v "^NAME" | while IFS=$'\t' read -r name revision suspended ready message; do
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
        kubectl get gitrepositories.source.toolkit.fluxcd.io -A --no-headers 2>/dev/null | while read -r ns name ready status age; do
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

    flux get kustomizations 2>/dev/null | grep -v "^NAME" | grep -v "^[[:space:]]*$" | while IFS=$'\t' read -r name revision suspended ready message; do
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
    local gitops_apps=$(kubectl get deployments -l osdu-ci.application --all-namespaces -o jsonpath='{.items[*].metadata.labels.osdu-ci\.application}' 2>/dev/null | tr ' ' '\n' | sort -u | tr '\n' ' ')

    if [ -z "$gitops_apps" ]; then
        return 0
    fi

    log_status "GitOps Applications"
    show_ingress_controller_status

    for app in $gitops_apps; do
        echo "📱 GitOps Application: $app"
        show_app_deployments "$app" "application"
        show_app_services "$app" "application"
        show_app_ingress "$app" "application"
        echo
    done
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
    local deployed_apps=$(kubectl get all -l osdu-ci.app --all-namespaces -o jsonpath='{.items[*].metadata.labels.osdu-ci\.app}' 2>/dev/null | tr ' ' '\n' | sort -u | tr '\n' ' ')

    if [ -z "$deployed_apps" ]; then
        return 0
    fi

    log_status "Manual Deployed Apps"

    for app in $deployed_apps; do
        echo "📱 $app"
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
        echo "   Deployment: $name ($ready ready, $ns namespace)"
    done
}

show_app_services() {
    local app_name="$1"
    local app_type="$2"

    get_services_for_app "$app_name" "$app_type" | while read -r ns name type cluster_ip external_ip ports age; do
        [ -z "$ns" ] && continue

        case "$type" in
            "NodePort")
                local access=$(get_nodeport_access "$ns $name $type $cluster_ip $external_ip $ports $age")
                echo "   Service: $name ($type, $access)"
                ;;
            "LoadBalancer")
                local access=$(get_loadbalancer_access "$ns $name $type $cluster_ip $external_ip $ports $age")
                echo "   Service: $name ($type, $access)"
                ;;
            "ClusterIP")
                echo "   Service: $name ($type, internal only)"
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
            local access=$(get_ingress_access "$app_name" "$ns $name $class $hosts $address $ports $age")
            if [ "$app_type" = "application" ]; then
                local path=$(kubectl get ingress "$name" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)
                if [ "$path" = "/" ]; then
                    echo "   Access: http://localhost:8080/ ($name ingress)"
                else
                    echo "   Access: http://localhost:8080$path ($name ingress)"
                fi
            else
                echo "   Ingress: $name ($access)"
            fi
        else
            echo "   Ingress: $name (hosts: $hosts)"
        fi
    done
}

show_health_check() {
    if ! kubectl get all -l osdu-ci.app --all-namespaces >/dev/null 2>&1; then
        return 0
    fi

    log_status "Health Check"
    local issues_found=0

    # Check LoadBalancer services
    kubectl get services -l osdu-ci.app --all-namespaces --no-headers 2>/dev/null | while read -r ns name type cluster_ip external_ip ports age; do
        if ! check_service_health "$ns $name $type $cluster_ip $external_ip $ports $age"; then
            log_warn "LoadBalancer $name is pending (MetalLB not installed?)"
            exit 1
        fi
    done && \

    # Check deployments
    kubectl get deployments -l osdu-ci.app --all-namespaces --no-headers 2>/dev/null | while read -r ns name ready up total age; do
        if ! check_deployment_health "$ready"; then
            local ready_count=$(echo "$ready" | cut -d/ -f1)
            local total_count=$(echo "$ready" | cut -d/ -f2)
            log_warn "Deployment $name not fully ready ($ready_count/$total_count)"
            exit 1
        fi
    done && \

    # Check pods
    kubectl get pods -l osdu-ci.app --all-namespaces --no-headers 2>/dev/null | while read -r ns name ready status restarts age; do
        if ! check_pod_health "$status"; then
            log_warn "Pod $name in $status state"
            exit 1
        fi
    done || issues_found=1

    if [ "$issues_found" = "0" ]; then
        log_success "All deployed apps are healthy"
    fi
    echo
}

show_cluster_status() {
    log_status "Cluster Status"
    kubectl get nodes
}

# Main function
main() {
    # Check if cluster exists (but allow status to show when not running)
    if [ ! -f "$KUBECONFIG_PATH" ]; then
        log_warn "No cluster found. Run 'make up' to start a cluster."
        exit 0
    fi

    # Check if cluster is running
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_warn "Cluster not running. Run 'make up' to start the cluster."
        exit 0
    fi

    show_kubeconfig_info
    show_gitops_status
    show_gitops_applications
    show_manual_deployed_apps
    show_health_check
    show_cluster_status
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
