# Optimized multi-stage build for Rust applications
FROM cgr.dev/chainguard/rust:latest AS builder
WORKDIR /app

# Set up build environment  
ENV HOME=/tmp/cargo-home
ENV CARGO_HOME=$HOME/.cargo
RUN mkdir -p $HOME $CARGO_HOME && chmod 755 $HOME $CARGO_HOME

# Copy dependency files first for better layer caching
COPY Cargo.toml ./

# Create dummy main.rs to build dependencies first
RUN mkdir -p src && echo "fn main() {}" > src/main.rs

# Build dependencies (this creates a cache-friendly layer)
RUN cargo build --release && rm -rf src

# Copy source and build application
COPY . .
RUN cargo build --release

# Runtime stage - using Chainguard distroless image for smaller size
FROM cgr.dev/chainguard/glibc-dynamic:latest

# Copy binary from builder stage
COPY --from=builder /app/target/release/openfga-operator /usr/local/bin/openfga-operator

# Switch to non-root user (Chainguard provides nonroot user with uid 65532)
USER 65532:65532

# Expose metrics port
EXPOSE 8080

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/openfga-operator"]