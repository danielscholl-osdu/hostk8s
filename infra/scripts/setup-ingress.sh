#!/bin/bash
set -euo pipefail

# Function for logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [Ingress] $*"
}

# Function for error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Auto-detect execution environment and set kubeconfig path
detect_kubeconfig() {
    if [ -n "${KUBECONFIG:-}" ]; then
        KUBECONFIG_PATH="${KUBECONFIG}"
        log "Using KUBECONFIG environment variable: $KUBECONFIG_PATH"
    elif [ -f "/kubeconfig/config" ]; then
        KUBECONFIG_PATH="/kubeconfig/config"  # Container mode
        log "Using container kubeconfig: $KUBECONFIG_PATH"
    elif [ -f "$(pwd)/data/kubeconfig/config" ]; then
        KUBECONFIG_PATH="$(pwd)/data/kubeconfig/config"  # Host mode
        log "Using host-mode kubeconfig: $KUBECONFIG_PATH"
    else
        error_exit "No kubeconfig found. Ensure cluster is running."
    fi
}

detect_kubeconfig

log "Setting up NGINX Ingress Controller..."

# Check if NGINX Ingress is already installed
if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace ingress-nginx >/dev/null 2>&1; then
    log "NGINX Ingress namespace already exists, checking if installation is complete..."
    if kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx | grep -q Running; then
        log "NGINX Ingress appears to already be running"
        exit 0
    fi
fi

# Install NGINX Ingress Controller for Kind
log "Installing NGINX Ingress Controller..."
kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/kind/deploy.yaml || error_exit "Failed to install NGINX Ingress Controller"

# Check if MetalLB is installed and configure LoadBalancer service
if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace metallb-system >/dev/null 2>&1; then
    log "MetalLB detected, configuring NGINX Ingress for LoadBalancer integration..."
    
    # Wait for the ingress controller service to be created first
    kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=jsonpath='{.metadata.name}' service/ingress-nginx-controller -n ingress-nginx --timeout=60s || log "WARNING: Ingress service not found"
    
    # Patch the service to use LoadBalancer type with correct NodePorts for Kind
    kubectl --kubeconfig="$KUBECONFIG_PATH" patch service ingress-nginx-controller -n ingress-nginx -p '{
        "spec": {
            "type": "LoadBalancer",
            "ports": [
                {"name": "http", "port": 80, "protocol": "TCP", "targetPort": "http", "nodePort": 30080},
                {"name": "https", "port": 443, "protocol": "TCP", "targetPort": "https", "nodePort": 30443}
            ]
        }
    }' || log "WARNING: Failed to patch ingress service for LoadBalancer"
    
    log "Ingress controller configured for MetalLB LoadBalancer"
else
    log "MetalLB not detected, configuring NodePort for Kind port mapping..."
    
    # Wait for the ingress controller service to be created first
    kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=jsonpath='{.metadata.name}' service/ingress-nginx-controller -n ingress-nginx --timeout=60s || log "WARNING: Ingress service not found"
    
    # Patch the service to use specific NodePorts that match Kind port mapping (30080->8080, 30443->8443)
    kubectl --kubeconfig="$KUBECONFIG_PATH" patch service ingress-nginx-controller -n ingress-nginx -p '{
        "spec": {
            "type": "NodePort",
            "ports": [
                {"name": "http", "port": 80, "protocol": "TCP", "targetPort": "http", "nodePort": 30080},
                {"name": "https", "port": 443, "protocol": "TCP", "targetPort": "https", "nodePort": 30443}
            ]
        }
    }' || log "WARNING: Failed to patch ingress service for NodePort"
    
    log "Ingress controller configured for Kind NodePort mapping (30080->8080, 30443->8443)"
fi

# Wait for NGINX Ingress pods to be ready
log "Waiting for NGINX Ingress Controller to be ready..."
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s || error_exit "NGINX Ingress Controller failed to become ready"

# Wait for admission webhook jobs to complete
log "Waiting for admission webhook setup jobs to complete..."
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --namespace ingress-nginx \
  --for=condition=complete job \
  --selector=app.kubernetes.io/component=admission-webhook \
  --timeout=120s || log "WARNING: Admission webhook jobs did not complete in time, continuing..."

# Verify admission webhook is configured
log "Verifying admission webhook configuration..."
if kubectl --kubeconfig="$KUBECONFIG_PATH" get validatingwebhookconfiguration ingress-nginx-admission >/dev/null 2>&1; then
    log "✅ Admission webhook successfully configured"
else
    log "WARNING: Admission webhook configuration not found"
fi

# Test NGINX Ingress with a simple test application
log "Testing NGINX Ingress with test application..."
cat <<EOF | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - || log "WARNING: Failed to create test application"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-test
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ingress-test
  template:
    metadata:
      labels:
        app: ingress-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: ingress-test-html
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-test-html
  namespace: default
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Kind Cluster - Ingress Test</title>
    </head>
    <body>
        <h1>NGINX Ingress Test Successful!</h1>
        <p>This page is served through NGINX Ingress Controller in your Kind cluster.</p>
        <p>Hostname: <code id="hostname"></code></p>
        <script>
            document.getElementById('hostname').textContent = window.location.hostname;
        </script>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: ingress-test
  namespace: default
spec:
  selector:
    app: ingress-test
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-test
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: localhost
    http:
      paths:
      - path: /test
        pathType: Prefix
        backend:
          service:
            name: ingress-test
            port:
              number: 80
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ingress-test
            port:
              number: 80
EOF

# Wait for test deployment to be ready
log "Waiting for test deployment..."
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=condition=available --timeout=120s deployment/ingress-test || log "WARNING: Test deployment not ready"

# Test ingress connectivity
log "Testing Ingress connectivity..."
sleep 10  # Give ingress a moment to update

# Test via localhost (should work due to port mapping)
if curl -s --connect-timeout 5 "http://localhost/test" >/dev/null; then
    log "Ingress test via localhost:80/test successful!"
else
    log "WARNING: Could not connect to Ingress via localhost:80/test"
fi

# Show ingress status
log "Ingress status:"
kubectl --kubeconfig="$KUBECONFIG_PATH" get ingress ingress-test -o wide || log "WARNING: Could not get ingress status"

# Clean up test resources
log "Cleaning up test resources..."
kubectl --kubeconfig="$KUBECONFIG_PATH" delete deployment,service,configmap,ingress ingress-test --ignore-not-found=true

log "NGINX Ingress Controller setup complete"
log "Access your applications at http://localhost or https://localhost"