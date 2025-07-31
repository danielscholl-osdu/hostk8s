FROM nginx:alpine

# Copy custom HTML content
COPY index.html /usr/share/nginx/html/index.html

# Add build metadata
ARG BUILD_DATE
ARG BUILD_VERSION=1.0.0

LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.title="HostK8s Registry Demo"
LABEL org.opencontainers.image.description="Demonstrates local registry integration with Kind"

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
