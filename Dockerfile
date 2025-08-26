# Build stage
FROM cgr.dev/chainguard/rust:latest AS builder

WORKDIR /app

# Ensure proper permissions for the working directory and set HOME for Cargo
USER root
RUN chown -R 1000:1000 /app
USER 1000

# Set HOME environment variable for Cargo (required for Podman builds)
ENV HOME=/tmp/cargo-home
RUN mkdir -p $HOME && chmod 755 $HOME

# Set CARGO_HOME to ensure consistent cargo cache location
ENV CARGO_HOME=$HOME/.cargo
RUN mkdir -p $CARGO_HOME && chmod 755 $CARGO_HOME

# Copy dependency files first for better layer caching
COPY Cargo.toml ./

# Fix ownership of copied files (critical for Podman rootless builds)
USER root
RUN chown -R 1000:1000 /app/Cargo.toml
USER 1000

# Create dummy main.rs to build dependencies first
RUN mkdir -p src && echo "fn main() {}" > src/main.rs

# Ensure target directory exists with proper permissions before first build
RUN mkdir -p /app/target && chmod 755 /app/target

# Build dependencies (this creates .cargo-lock and other files)
RUN cargo build --release

# Fix permissions for build artifacts after dependency build (critical for .cargo-lock)
USER root
RUN chown -R 1000:1000 /app/target /app/src
USER 1000

RUN rm src/main.rs

# Copy source code
COPY . .

# Fix ownership of all copied source files (critical for Podman rootless builds - after copying all source files)
USER root
RUN chown -R 1000:1000 /app
USER 1000

# Build the application (dependencies are already cached)
RUN cargo build --release

# Final permission fix for all build artifacts (ensures .cargo-lock access)
USER root
RUN chown -R 1000:1000 /app/target && \
    chmod -R 755 /app/target && \
    # Specifically handle .cargo-lock file permissions
    find /app/target -name ".cargo-lock" -exec chown 1000:1000 {} \; -exec chmod 644 {} \;
USER 1000

# Runtime stage - using Chainguard glibc with dev tools for health checks
FROM cgr.dev/chainguard/gcc-glibc:latest-dev

# Copy binary from builder stage
COPY --from=builder /app/target/release/openfga-operator /usr/local/bin/openfga-operator

# Switch to non-root user (Chainguard provides nonroot user with uid 65532)
USER 65532:65532

# Expose metrics port
EXPOSE 8080

# Health check using curl (available in -dev variant)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/openfga-operator"]