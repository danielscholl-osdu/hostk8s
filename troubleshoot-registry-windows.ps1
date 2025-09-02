# Troubleshooting script for Windows registry UI ingress issues
# Run this after registry setup to diagnose ingress problems

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "[$timestamp] Registry UI Troubleshooting - Windows Edition"
Write-Host ""

# 1. Check namespace
Write-Host "=== Namespace Check ==="
kubectl get namespace hostk8s

# 2. Check all registry resources
Write-Host ""
Write-Host "=== Registry Resources ==="
kubectl get all -n hostk8s -l hostk8s.addon=registry

# 3. Check ingresses specifically
Write-Host ""
Write-Host "=== Ingress Resources ==="
kubectl get ingress -n hostk8s -l hostk8s.addon=registry -o wide

# 4. Check if UI ingress exists
Write-Host ""
Write-Host "=== UI Ingress Detail ==="
kubectl get ingress registry-ui -n hostk8s -o yaml 2>&1

# 5. Check nginx ingress controller
Write-Host ""
Write-Host "=== Nginx Ingress Controller ==="
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=20

# 6. Test manifest validation
Write-Host ""
Write-Host "=== Manifest Validation ==="
kubectl apply --dry-run=client -f infra/manifests/registry-ui.yaml

# 7. Check events for errors
Write-Host ""
Write-Host "=== Recent Events ==="
kubectl get events -n hostk8s --sort-by='.lastTimestamp' | tail -10

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "If UI ingress is missing, likely causes:"
Write-Host "1. Complex regex path '/registry(/|\$)(.*)' failed parsing"
Write-Host "2. Server-snippet annotation unsupported on Windows nginx"
Write-Host "3. PathType 'ImplementationSpecific' not recognized"
Write-Host ""
Write-Host "Next steps: Check nginx controller logs for parsing errors"
