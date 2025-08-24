# OpenFGA Operator Makefile

# Variables
CARGO := cargo
DOCKER := docker
KUBECTL := kubectl
IMAGE_NAME := openfga-operator
IMAGE_TAG := latest
REGISTRY := localhost:5000

.PHONY: help build test clean run fmt lint check install-deps install-crd uninstall-crd docker-build docker-push deploy undeploy

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Development targets
build: ## Build the operator binary
	$(CARGO) build --release

test: ## Run all tests
	$(CARGO) test

test-verbose: ## Run tests with verbose output
	$(CARGO) test -- --nocapture

clean: ## Clean build artifacts
	$(CARGO) clean

run: ## Run the operator locally (requires KUBECONFIG)
	$(CARGO) run

run-verbose: ## Run the operator locally with verbose logging
	$(CARGO) run -- --verbose

# Code quality targets
fmt: ## Format code
	$(CARGO) fmt

lint: ## Run clippy linter
	$(CARGO) clippy -- -D warnings

check: fmt lint test ## Run all checks (format, lint, test)

# Dependencies
install-deps: ## Install development dependencies
	@echo "Installing Rust dependencies..."
	$(CARGO) fetch
	@echo "Installing development tools..."
	rustup component add rustfmt clippy

# CRD management
print-crd: build ## Print the OpenFGA CRD YAML
	PRINT_CRD=1 ./target/release/openfga-operator

install-crd: build ## Install the OpenFGA CRD in the cluster
	PRINT_CRD=1 ./target/release/openfga-operator | $(KUBECTL) apply -f -

uninstall-crd: build ## Uninstall the OpenFGA CRD from the cluster
	PRINT_CRD=1 ./target/release/openfga-operator | $(KUBECTL) delete -f -

# Docker targets
docker-build: ## Build Docker image
	$(DOCKER) build -t $(IMAGE_NAME):$(IMAGE_TAG) .

docker-push: docker-build ## Push Docker image to registry
	$(DOCKER) tag $(IMAGE_NAME):$(IMAGE_TAG) $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	$(DOCKER) push $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

# Kubernetes deployment targets
deploy: install-crd ## Deploy the operator to Kubernetes
	$(KUBECTL) apply -f deploy/

undeploy: ## Remove the operator from Kubernetes
	$(KUBECTL) delete -f deploy/ --ignore-not-found=true

# Development workflow
dev-setup: install-deps ## Set up development environment
	@echo "Development environment setup complete!"
	@echo "Run 'make run' to start the operator locally."

# CI/CD targets
ci: check ## Run CI pipeline (format, lint, test)
	@echo "CI pipeline completed successfully!"

# Utility targets
watch: ## Watch for changes and rebuild
	$(CARGO) watch -x build

watch-test: ## Watch for changes and rerun tests
	$(CARGO) watch -x test

# Release targets
release: clean check build ## Build release version
	@echo "Release build complete: ./target/release/openfga-operator"

# Documentation
docs: ## Generate and open documentation
	$(CARGO) doc --open

# Examples
example-install: ## Install an example OpenFGA instance
	$(KUBECTL) apply -f examples/

example-uninstall: ## Remove example OpenFGA instance
	$(KUBECTL) delete -f examples/ --ignore-not-found=true