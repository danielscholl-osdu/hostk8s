# Certificate Management Components

Comprehensive TLS certificate management system providing automated certificate provisioning and renewal for HostK8s applications using cert-manager.

## Components

- **cert-manager**: Kubernetes certificate controller and CRDs
- **Self-Signed CA**: Development certificate authority for internal services
- **ClusterIssuers**: Production Let's Encrypt and development certificate issuers

## Services

- **Certificate Provisioning**: Automatic TLS certificate creation and renewal
- **Multiple Issuers**: Self-signed, internal CA, and Let's Encrypt support
- **Ingress Integration**: Automatic certificate attachment to Ingress resources

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                Certificate Management System                   │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  cert-manager                           │   │
│  │              (Helm Chart v1.13.x)                      │   │
│  │                                                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │ Controller  │  │   Webhook   │  │ CA Injector │     │   │
│  │  │             │  │             │  │             │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                 │
│                    Certificate Requests                        │
│                              │                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 ClusterIssuers                          │   │
│  │                                                         │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌─────────────────┐  │   │
│  │  │  SelfSigned  │ │   Root CA    │ │  Let's Encrypt  │  │   │
│  │  │   Issuer     │ │   Issuer     │ │     Issuers     │  │   │
│  │  │              │ │              │ │ (staging/prod)  │  │   │
│  │  └──────────────┘ └──────────────┘ └─────────────────┘  │   │
│  └─────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
```

## Available Certificate Issuers

### 1. Self-Signed Issuer (`selfsigned-cluster-issuer`)
**Purpose**: Quick certificates for development and testing
**Use Case**: Internal services, development environments

```yaml
# Example Certificate Request
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-cert
  namespace: my-app
spec:
  secretName: my-app-tls
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
    group: cert-manager.io
  dnsNames:
  - my-app.local
  - localhost
```

### 2. Root CA Issuer (`root-ca-cluster-issuer`)
**Purpose**: Internal CA for consistent certificate chain
**Use Case**: Production-like internal certificates

```yaml
# Example Certificate Request
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: api-cert
  namespace: my-stack
spec:
  secretName: api-tls
  issuerRef:
    name: root-ca-cluster-issuer
    kind: ClusterIssuer
    group: cert-manager.io
  dnsNames:
  - api.my-stack.svc.cluster.local
  - api.example.dev
```

### 3. Let's Encrypt Issuers
**Purpose**: Valid certificates for external access
**Use Case**: Production ingress, external services

#### Staging (`letsencrypt-staging`)
```yaml
# Example Certificate Request (Staging)
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: web-cert-staging
  namespace: web
spec:
  secretName: web-tls-staging
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
    group: cert-manager.io
  dnsNames:
  - staging.example.com
```

#### Production (`letsencrypt-production`)
```yaml
# Example Certificate Request (Production)
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: web-cert
  namespace: web
spec:
  secretName: web-tls
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
    group: cert-manager.io
  dnsNames:
  - example.com
  - www.example.com
```

## Ingress Integration

Automatic certificate provisioning via Ingress annotations:

```yaml
# Automatic Certificate via Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    cert-manager.io/cluster-issuer: "root-ca-cluster-issuer"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - my-app.example.dev
    secretName: my-app-tls  # cert-manager creates this automatically
  rules:
  - host: my-app.example.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

## Certificate Lifecycle

1. **Request**: Create Certificate resource or annotated Ingress
2. **Validation**: cert-manager validates domain ownership (for Let's Encrypt)
3. **Issuance**: Certificate issued by selected ClusterIssuer
4. **Storage**: Certificate stored in Kubernetes Secret
5. **Renewal**: Automatic renewal before expiration
6. **Application**: Pods automatically pick up renewed certificates

## Storage and Secrets

Certificates are stored as Kubernetes TLS secrets:

```bash
# View certificate secrets
kubectl get secrets --field-selector type=kubernetes.io/tls

# Examine certificate details
kubectl describe secret my-app-tls

# View certificate content
kubectl get secret my-app-tls -o yaml
```

## Configuration

### cert-manager Settings
- **Version**: 1.13.x (Helm chart)
- **CRD Installation**: Enabled (`installCRDs: true`)
- **Resource Limits**: Controller (128Mi), Webhook (64Mi), CA Injector (128Mi)
- **Namespace**: `cert-manager`

### Let's Encrypt Configuration
- **Email**: `admin@mail.com` (update for production)
- **HTTP01 Challenge**: Gateway HTTP Route solver
- **Gateway**: `external-gateway` in `istio-system` namespace

## Commands

```bash
# Deploy certificate components
kubectl apply -k software/components/certs/
kubectl apply -k software/components/certs-ca/
kubectl apply -k software/components/certs-issuer/

# Check cert-manager status
kubectl get pods -n cert-manager

# List available ClusterIssuers
kubectl get clusterissuers

# Check ClusterIssuer status
kubectl describe clusterissuer root-ca-cluster-issuer

# List certificates across all namespaces
kubectl get certificates --all-namespaces

# Check certificate status
kubectl describe certificate my-app-cert -n my-namespace

# View certificate events
kubectl get events --field-selector involvedObject.kind=Certificate

# Check certificate secrets
kubectl get secrets --field-selector type=kubernetes.io/tls

# Test certificate with openssl
kubectl get secret my-app-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

## Troubleshooting

### Certificate Not Issued
```bash
# Check CertificateRequest status
kubectl get certificaterequests

# Check Order status (for Let's Encrypt)
kubectl get orders

# Check Challenge status (for Let's Encrypt)
kubectl get challenges

# View cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

### ClusterIssuer Issues
```bash
# Check ClusterIssuer status
kubectl describe clusterissuer letsencrypt-production

# Check webhook configuration
kubectl get validatingwebhookconfiguration cert-manager-webhook

# Verify CRDs are installed
kubectl get crd | grep cert-manager
```

### Ingress Certificate Issues
```bash
# Check Ingress annotations
kubectl describe ingress my-app-ingress

# Verify certificate secret exists
kubectl get secret my-app-tls

# Check nginx ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

## Production Considerations

### Let's Encrypt Rate Limits
- **Use Staging First**: Test with `letsencrypt-staging` before production
- **Certificate Limits**: 50 certificates per week per domain
- **Duplicate Limits**: 5 certificates per week with same SAN set

### Security Best Practices
- **Update Email**: Change `admin@mail.com` to valid email in production
- **Certificate Monitoring**: Monitor certificate expiration dates
- **Secret Protection**: Restrict access to certificate secrets
- **CA Certificate Distribution**: Distribute root CA certificate to clients for internal issuers

This certificate management system provides comprehensive TLS support for both development and production HostK8s deployments.
