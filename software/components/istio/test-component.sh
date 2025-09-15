#!/bin/bash
# Test script for Istio component validation

set -e

echo "=== Testing Istio Component Structure ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Test function
test_file() {
    local file=$1
    local description=$2

    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description exists"
        # Validate YAML syntax
        if command -v yamllint >/dev/null 2>&1; then
            if yamllint -d relaxed "$file" >/dev/null 2>&1; then
                echo -e "${GREEN}  ✓${NC} Valid YAML syntax"
            else
                echo -e "${RED}  ✗${NC} Invalid YAML syntax"
                return 1
            fi
        fi
    else
        echo -e "${RED}✗${NC} $description missing"
        return 1
    fi
}

# Base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "Testing directory structure..."
echo "------------------------------"

# Test directory structure
for dir in base ambient gateway gateway/routes; do
    if [ -d "$BASE_DIR/$dir" ]; then
        echo -e "${GREEN}✓${NC} Directory $dir exists"
    else
        echo -e "${RED}✗${NC} Directory $dir missing"
    fi
done

echo ""
echo "Testing component files..."
echo "-------------------------"

# Test main files
test_file "$BASE_DIR/kustomization.yaml" "Root kustomization"
test_file "$BASE_DIR/component.yaml" "Component orchestration"
test_file "$BASE_DIR/README.md" "Documentation"

echo ""
echo "Testing base component..."
echo "------------------------"

test_file "$BASE_DIR/base/kustomization.yaml" "Base kustomization"
test_file "$BASE_DIR/base/namespace.yaml" "Namespace definition"
test_file "$BASE_DIR/base/gateway-api-crds.yaml" "Gateway API CRDs"
test_file "$BASE_DIR/base/source.yaml" "Helm repository"
test_file "$BASE_DIR/base/release-base.yaml" "Istio base release"
test_file "$BASE_DIR/base/release-istiod.yaml" "Istiod release"

echo ""
echo "Testing ambient component..."
echo "---------------------------"

test_file "$BASE_DIR/ambient/kustomization.yaml" "Ambient kustomization"
test_file "$BASE_DIR/ambient/release-ztunnel.yaml" "ZTunnel release"
test_file "$BASE_DIR/ambient/waypoint-class.yaml" "Waypoint GatewayClass"

echo ""
echo "Testing gateway component..."
echo "---------------------------"

test_file "$BASE_DIR/gateway/kustomization.yaml" "Gateway kustomization"
test_file "$BASE_DIR/gateway/gateway-class.yaml" "Gateway class"
test_file "$BASE_DIR/gateway/gateway-config.yaml" "Gateway configuration"
test_file "$BASE_DIR/gateway/gateway.yaml" "Gateway resource"
test_file "$BASE_DIR/gateway/certificate.yaml" "TLS certificate"

echo ""
echo "Testing sample routes..."
echo "-----------------------"

test_file "$BASE_DIR/gateway/routes/default-route.yaml" "Default route"
test_file "$BASE_DIR/gateway/routes/example-app.yaml.example" "Example app route"

echo ""
echo "Validating Kustomization builds..."
echo "---------------------------------"

# Test if kustomize can build each component
if command -v kubectl >/dev/null 2>&1; then
    for component in base ambient gateway; do
        echo -n "Testing $component build... "
        if kubectl kustomize "$BASE_DIR/$component" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            echo "  Error building $component"
        fi
    done

    echo -n "Testing root build... "
    if kubectl kustomize "$BASE_DIR" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
else
    echo "kubectl not available, skipping kustomize validation"
fi

echo ""
echo "=== Component Structure Test Complete ==="
echo ""
echo "To deploy this component:"
echo "  1. Ensure cert-manager is installed:"
echo "     kubectl apply -k software/components/certs"
echo ""
echo "  2. Deploy Istio component:"
echo "     kubectl apply -k software/components/istio"
echo ""
echo "Or include in a stack:"
echo "  resources:"
echo "    - ../../components/certs"
echo "    - ../../components/istio"
