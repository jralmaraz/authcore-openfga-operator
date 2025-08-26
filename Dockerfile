# Use cargo-chef for optimal dependency caching
FROM cgr.dev/chainguard/rust:latest AS chef
RUN cargo install cargo-chef
WORKDIR /app

# Prepare recipe for dependencies
FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

# Build dependencies - this is the caching Docker layer!
FROM chef AS builder

# Set up build environment  
ENV HOME=/tmp/cargo-home
ENV CARGO_HOME=$HOME/.cargo
RUN mkdir -p $HOME $CARGO_HOME && chmod 755 $HOME $CARGO_HOME

# Copy and build dependencies (this will be cached)
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json

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