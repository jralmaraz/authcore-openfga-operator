# Build stage
FROM cgr.dev/chainguard/rust:latest AS builder

WORKDIR /app

# Copy dependency files first for better layer caching
COPY Cargo.toml Cargo.lock ./

# Create dummy main.rs to build dependencies first
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release --locked
RUN rm src/main.rs

COPY . .

# Build the application (dependencies are already cached)
RUN cargo build --release --locked

# Runtime stage  
FROM cgr.dev/chainguard/wolfi-base:latest

# Install CA certificates and other runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl

# Runtime stage - using distroless cc (includes glibc)
FROM gcr.io/distroless/cc:latest

# Copy binary from builder stage
COPY --from=builder /app/target/release/openfga-operator /usr/local/bin/openfga-operator

# Switch to non-root user (distroless already provides nonroot user with uid 65532)
USER 65532:65532

# Expose metrics port
EXPOSE 8080

# Note: Health checks removed as distroless images don't have shell or external tools
# Health monitoring should be implemented at the orchestration level (e.g., Kubernetes probes)

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/openfga-operator"]