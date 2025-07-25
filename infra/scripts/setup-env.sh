#!/bin/bash
set -e

echo "🛠️  Setting up OSDU-CI development environment..."

# Install pre-commit if not available
if ! command -v pre-commit &> /dev/null; then
    echo "Installing pre-commit..."
    if command -v pip &> /dev/null; then
        pip install pre-commit
    elif command -v pipx &> /dev/null; then
        pipx install pre-commit
    elif command -v brew &> /dev/null; then
        brew install pre-commit
    else
        echo "❌ Could not install pre-commit. Please install manually:"
        echo "   pip install pre-commit"
        exit 1
    fi
fi

# Install yamllint if not available
if ! command -v yamllint &> /dev/null; then
    echo "Installing yamllint..."
    pip install yamllint
fi

# Install pre-commit hooks
echo "Installing pre-commit hooks..."
pre-commit install

echo "✅ Development environment setup complete!"
echo ""
echo "📋 Available commands:"
echo "  make help                    # Show project targets"
echo "  pre-commit run --all-files   # Run all linting checks"
echo "  yamllint .                   # Check YAML files manually"
echo "  make up                      # Start development cluster"
echo ""
echo "💡 Pre-commit hooks will now run automatically on git commit"
