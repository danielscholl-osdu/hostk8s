#!/bin/bash
set -e

echo "🔧 Fixing Kubernetes YAML indentation issues..."

# Function to fix common Kubernetes YAML indentation
fix_k8s_yaml() {
    local file="$1"
    echo "Fixing: $file"
    
    # Use a temp file for safety
    tmp_file=$(mktemp)
    
    # Fix common indentation patterns for Kubernetes YAML
    # This handles the most common cases we saw in the errors
    sed -E '
        # Fix containers: section (should be 6 spaces, then 8 for name/image)
        s/^    containers:/      containers:/
        s/^    - name:/      - name:/
        s/^      image:/        image:/
        s/^      ports:/        ports:/
        s/^      - containerPort:/        - containerPort:/
        s/^      resources:/        resources:/
        s/^        requests:/          requests:/
        s/^        limits:/          limits:/
        s/^      volumeMounts:/        volumeMounts:/
        s/^      - name:/        - name:/
        s/^        mountPath:/          mountPath:/
        
        # Fix volumes: section  
        s/^    volumes:/      volumes:/
        s/^    - name:/      - name:/
        s/^      configMap:/        configMap:/
        
        # Fix Service spec
        s/^  ports:/    ports:/
        s/^  - port:/    - port:/
        s/^    targetPort:/      targetPort:/
        s/^    nodePort:/      nodePort:/
    ' "$file" > "$tmp_file"
    
    # Only replace if the content changed
    if ! cmp -s "$file" "$tmp_file"; then
        mv "$tmp_file" "$file"
        echo "  ✅ Fixed indentation in $file"
    else
        rm "$tmp_file"
        echo "  ⏭️  No changes needed in $file"
    fi
}

# Fix Kubernetes YAML files
find software/apps -name "*.yaml" | while read -r file; do
    fix_k8s_yaml "$file"
done

echo "✅ Kubernetes YAML indentation fixes complete!"
echo "Run 'yamllint -c .yamllint.yaml software/' to check remaining issues"