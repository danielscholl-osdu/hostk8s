# Multi-stage build for Spring Boot Java 17 application
FROM eclipse-temurin:17-jdk AS build

# Install Maven
RUN apt-get update && apt-get install -y maven && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace/app

# Copy Maven files for dependency resolution
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src src
RUN mvn clean package -DskipTests

# Extract JAR layers for better caching
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*.jar)

# Production runtime stage
FROM eclipse-temurin:17-jre AS prod

# Create non-root user for security
RUN groupadd -g 1001 appuser && \
    useradd -u 1001 -g appuser -m appuser

# Set working directory
WORKDIR /app

# Copy application layers from build stage
COPY --from=build --chown=appuser:appuser /workspace/app/target/dependency/BOOT-INF/lib /app/lib
COPY --from=build --chown=appuser:appuser /workspace/app/target/dependency/META-INF /app/META-INF
COPY --from=build --chown=appuser:appuser /workspace/app/target/dependency/BOOT-INF/classes /app

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# JVM optimization for containers
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"

# Expose actuator port
EXPOSE 8080

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -cp app:app/lib/* com.hostk8s.worker.WorkerApplication"]
