# Optimized multi-stage build for Rust applications with sccache support
FROM cgr.dev/chainguard/rust:latest AS builder
WORKDIR /app

# Accept build arguments
ARG VERSION
ARG SCCACHE_GHA_ENABLED
ARG RUSTC_WRAPPER

# Set up environment variables
ENV VERSION=${VERSION}
ENV HOME=/tmp/cargo-home
ENV CARGO_HOME=$HOME/.cargo
ENV SCCACHE_GHA_ENABLED=${SCCACHE_GHA_ENABLED:-false}
ENV RUSTC_WRAPPER=${RUSTC_WRAPPER:-}

# Set up build environment with proper permissions
RUN mkdir -p $HOME $CARGO_HOME && chmod 755 $HOME $CARGO_HOME

# Copy dependency files first for better layer caching
COPY Cargo.toml Cargo.lock* ./

# Pre-fetch dependencies in a dummy project structure
RUN mkdir -p src && echo "fn main() {}" > src/main.rs

# Build dependencies only (this creates a highly cache-friendly layer)
RUN cargo build --release && \
    rm -rf src target/release/deps/openfga_operator* target/release/openfga-operator*

# Copy all source code
COPY src ./src

# Build the actual application with all optimizations
RUN cargo build --release && \
    cp target/release/openfga-operator /tmp/openfga-operator

# Runtime stage - using Chainguard distroless image for smaller size
FROM cgr.dev/chainguard/glibc-dynamic:latest

# Accept version as build argument
ARG VERSION
ENV VERSION=${VERSION}

# Add version information as labels for better traceability
LABEL org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.title="OpenFGA Operator" \
      org.opencontainers.image.description="Kubernetes operator for OpenFGA"

# Copy binary from builder stage
COPY --from=builder /tmp/openfga-operator /usr/local/bin/openfga-operator

# Switch to non-root user (Chainguard provides nonroot user with uid 65532)
USER 65532:65532

# Expose metrics port
EXPOSE 8080

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/openfga-operator"]