#!/bin/bash
set -e

echo "🔧 Fixing YAML formatting issues automatically..."

# Find all YAML files
YAML_FILES=$(find . -name "*.yml" -o -name "*.yaml" | grep -v ".pre-commit" | grep -v "node_modules")

for file in $YAML_FILES; do
    echo "Fixing: $file"
    
    # Remove trailing whitespace
    sed -i '' 's/[[:space:]]*$//' "$file"
    
    # Ensure file ends with newline
    if [ -n "$(tail -c1 "$file")" ]; then
        echo "" >> "$file"
    fi
done

echo "✅ Automatic fixes applied!"
echo ""
echo "⚠️  Manual fixes still needed:"
echo "  - Long lines (>120 chars) need manual breaking"
echo "  - Indentation issues need manual review"
echo "  - Document start markers (---) can be added if desired"
echo ""
echo "Run 'yamllint .' to see remaining issues"