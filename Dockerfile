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

# Copy dependency files first for better layer caching
COPY Cargo.toml Cargo.lock ./

# Create dummy main.rs to build dependencies first
RUN mkdir -p src && echo "fn main() {}" > src/main.rs
RUN cargo build --release --locked
RUN rm src/main.rs

COPY . .

# Build the application (dependencies are already cached)
RUN cargo build --release --locked

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