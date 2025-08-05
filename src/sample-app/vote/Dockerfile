# Multi-stage build using uv for faster Python dependency management
FROM python:3.11-slim AS base

# Install uv for faster Python package management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

# Add curl for healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Set the application directory
WORKDIR /usr/local/app

# Copy Python project files
COPY pyproject.toml ./
COPY requirements.txt ./

# Install dependencies with uv (much faster than pip)
RUN uv pip install --system --no-cache -r requirements.txt

# Development stage with hot reload and debugging tools
FROM base AS dev

# Install development dependencies
RUN uv pip install --system --no-cache \
    watchdog \
    pytest \
    pytest-flask

# Copy source code for development
COPY . .

# Development environment variables
ENV FLASK_DEBUG=true
ENV FLASK_ENV=development
ENV PORT=5000

# Expose development port
EXPOSE 5000

# Development command with hot reload
CMD ["python", "app.py"]

# Production stage
FROM base AS prod

# Copy source code
COPY . .

# Production environment variables
ENV FLASK_DEBUG=false
ENV FLASK_ENV=production
ENV PORT=80

# Make port 80 available
EXPOSE 80

# Production command with gunicorn
CMD ["gunicorn", "app:app", "-b", "0.0.0.0:80", "--log-file", "-", "--access-logfile", "-", "--workers", "4", "--keep-alive", "0"]
