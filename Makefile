.PHONY: compile build test fmt clippy clean install-crds uninstall-crds run dev deploy-dev deploy-staging deploy-prod

# Default target
all: compile build

# Compile the project (check syntax and dependencies)
compile:
	@echo "Compiling OpenFGA Operator..."
	cargo check

# Build the project
build:
	@echo "Building OpenFGA Operator..."
	cargo build --release

# Run tests
test:
	@echo "Running tests..."
	cargo test

# Format code
fmt:
	@echo "Formatting code..."
	cargo fmt

# Run clippy for linting
clippy:
	@echo "Running clippy..."
	cargo clippy -- -D warnings

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	cargo clean

# Install CRDs to the cluster
install-crds:
	@echo "Installing CRDs..."
	kubectl apply -f crds/

# Uninstall CRDs from the cluster
uninstall-crds:
	@echo "Uninstalling CRDs..."
	kubectl delete -f crds/

# Run the operator locally
run:
	@echo "Running OpenFGA Operator locally..."
	cargo run

# Development mode with auto-reload
dev:
	@echo "Running in development mode..."
	cargo watch -x run

# Build Docker image
docker-build:
	@echo "Building Docker image..."
	docker build -t openfga-operator:latest .

# Deploy to development environment
deploy-dev:
	@echo "Deploying to development environment..."
	kubectl apply -k kustomize/overlays/dev/

# Deploy to staging environment
deploy-staging:
	@echo "Deploying to staging environment..."
	kubectl apply -k kustomize/overlays/staging/

# Deploy to production environment
deploy-prod:
	@echo "Deploying to production environment..."
	kubectl apply -k kustomize/overlays/prod/

# Deploy enterprise base
deploy-base:
	@echo "Deploying enterprise base configuration..."
	kubectl apply -k kustomize/base/

# Verify deployment
verify-deployment:
	@echo "Verifying deployment..."
	kubectl get pods -n openfga-system
	kubectl get openfgas -A
	kubectl get networkpolicies -n openfga-system

# Check kustomize build
check-kustomize:
	@echo "Checking kustomize configurations..."
	kustomize build kustomize/base/ > /dev/null && echo "✓ Base configuration valid"
	kustomize build kustomize/overlays/dev/ > /dev/null && echo "✓ Dev overlay valid"
	kustomize build kustomize/overlays/prod/ > /dev/null && echo "✓ Prod overlay valid"

# Clean up deployments
clean-dev:
	@echo "Cleaning up development deployment..."
	kubectl delete -k kustomize/overlays/dev/ --ignore-not-found=true

clean-staging:
	@echo "Cleaning up staging deployment..."
	kubectl delete -k kustomize/overlays/staging/ --ignore-not-found=true

clean-prod:
	@echo "Cleaning up production deployment..."
	kubectl delete -k kustomize/overlays/prod/ --ignore-not-found=true

# Run all quality checks
check-all: fmt clippy compile test check-kustomize
	@echo "All checks passed!"

# Help target
help:
	@echo "Available targets:"
	@echo "  compile      - Check syntax and dependencies"
	@echo "  build        - Build the project in release mode"
	@echo "  test         - Run tests"
	@echo "  fmt          - Format code"
	@echo "  clippy       - Run clippy linter"
	@echo "  clean        - Clean build artifacts"
	@echo "  install-crds - Install CRDs to Kubernetes cluster"
	@echo "  uninstall-crds - Remove CRDs from Kubernetes cluster"
	@echo "  run          - Run the operator locally"
	@echo "  dev          - Run in development mode with auto-reload"
	@echo "  docker-build - Build Docker image"
	@echo "  deploy-dev   - Deploy to development environment"
	@echo "  deploy-staging - Deploy to staging environment"
	@echo "  deploy-prod  - Deploy to production environment"
	@echo "  deploy-base  - Deploy enterprise base configuration"
	@echo "  verify-deployment - Verify deployment status"
	@echo "  check-kustomize - Validate kustomize configurations"
	@echo "  clean-dev    - Clean up development deployment"
	@echo "  clean-staging - Clean up staging deployment"
	@echo "  clean-prod   - Clean up production deployment"
	@echo "  check-all    - Run all quality checks"
	@echo "  help         - Show this help message"