# Build stage
FROM cgr.dev/chainguard/rust:latest AS builder

WORKDIR /app

# Copy the entire project
COPY . .

# Build the application
RUN cargo build --release

# Runtime stage  
FROM cgr.dev/chainguard/wolfi-base:latest

# Install CA certificates and other runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl

# Create non-root user
RUN groupadd -r openfga && useradd -r -g openfga openfga

# Copy binary from builder stage
COPY --from=builder /app/target/release/openfga-operator /usr/local/bin/openfga-operator

# Set ownership and permissions
RUN chown openfga:openfga /usr/local/bin/openfga-operator

# Switch to non-root user
USER openfga

# Expose metrics port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Set entrypoint
CMD ["openfga-operator"]