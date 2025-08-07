# Multi-stage build using Bun for faster Node.js development
FROM oven/bun:1 AS base

WORKDIR /usr/local/app

# Copy package files
COPY package.json ./
COPY bun.lockb* ./

# Install dependencies with bun (much faster than npm)
RUN bun install --frozen-lockfile

# Development stage with hot reload
FROM base AS dev

# Install development dependencies
RUN bun install --frozen-lockfile --dev

# Copy source code for development
COPY . .

# Development environment variables
ENV NODE_ENV=development
ENV PORT=4000

# Expose development port
EXPOSE 4000

# Development command with hot reload using bun --watch
CMD ["bun", "--watch", "server.js"]

# Production stage
FROM base AS prod

# Copy source code
COPY . .

# Production environment variables
ENV NODE_ENV=production
ENV PORT=80

# Make port 80 available
EXPOSE 80

# Production command
CMD ["bun", "server.js"]
