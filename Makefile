.PHONY: compile build test fmt clippy clean install-crds uninstall-crds run dev deploy-dev deploy-staging deploy-prod minikube-build minikube-load minikube-deploy

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

# Detect container runtime
detect-runtime:
	@if [ -n "$(CONTAINER_RUNTIME)" ]; then \
		case "$(CONTAINER_RUNTIME)" in \
			docker|podman) \
				if command -v $(CONTAINER_RUNTIME) >/dev/null 2>&1; then \
					echo $(CONTAINER_RUNTIME); \
				else \
					echo "Error: Specified runtime '$(CONTAINER_RUNTIME)' not found" >&2; \
					exit 1; \
				fi ;; \
			*) \
				echo "Error: Invalid CONTAINER_RUNTIME '$(CONTAINER_RUNTIME)'" >&2; \
				exit 1 ;; \
		esac; \
	elif command -v docker >/dev/null 2>&1; then \
		echo docker; \
	elif command -v podman >/dev/null 2>&1; then \
		echo podman; \
	else \
		echo "Error: No container runtime found. Please install Docker or Podman." >&2; \
		exit 1; \
	fi

# Build container image using detected runtime
container-build:
	@echo "Building container image..."
	@if [ -n "$(CONTAINER_RUNTIME)" ]; then \
		case "$(CONTAINER_RUNTIME)" in \
			docker) \
				if command -v $(CONTAINER_RUNTIME) >/dev/null 2>&1; then \
					echo "Using container runtime: $(CONTAINER_RUNTIME)"; \
					$(CONTAINER_RUNTIME) build -t openfga-operator:latest .; \
				else \
					echo "Error: Specified runtime '$(CONTAINER_RUNTIME)' not found" >&2; \
					exit 1; \
				fi ;; \
			podman) \
				if command -v $(CONTAINER_RUNTIME) >/dev/null 2>&1; then \
					echo "Using container runtime: $(CONTAINER_RUNTIME)"; \
					echo "Note: Podman may require sudo for proper permissions in some environments"; \
					if ! $(CONTAINER_RUNTIME) build --security-opt label=disable -t openfga-operator:latest . 2>/dev/null; then \
						echo "Rootless podman failed, trying with sudo..."; \
						sudo $(CONTAINER_RUNTIME) build -t openfga-operator:latest .; \
					fi; \
				else \
					echo "Error: Specified runtime '$(CONTAINER_RUNTIME)' not found" >&2; \
					exit 1; \
				fi ;; \
			*) \
				echo "Error: Invalid CONTAINER_RUNTIME '$(CONTAINER_RUNTIME)'" >&2; \
				exit 1 ;; \
		esac; \
	elif command -v docker >/dev/null 2>&1; then \
		echo "Using container runtime: docker"; \
		docker build -t openfga-operator:latest .; \
	elif command -v podman >/dev/null 2>&1; then \
		echo "Using container runtime: podman"; \
		echo "Note: Podman may require sudo for proper permissions in some environments"; \
		if ! podman build --security-opt label=disable -t openfga-operator:latest . 2>/dev/null; then \
			echo "Rootless podman failed, trying with sudo..."; \
			sudo podman build -t openfga-operator:latest .; \
		fi; \
	else \
		echo "Error: No container runtime found. Please install Docker or Podman." >&2; \
		exit 1; \
	fi

# Test Podman build with permission fixes
test-podman-build:
	@echo "Testing Podman build with permission fixes..."
	@./scripts/test-podman-build.sh

# Legacy target for backward compatibility
docker-build: container-build

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

# Build container image using Minikube's docker environment
minikube-build:
	@echo "Building container image using Minikube's Docker environment..."
	@if command -v docker >/dev/null 2>&1 && minikube config get driver 2>/dev/null | grep -q docker; then \
		echo "Using Minikube's Docker environment"; \
		eval $$(minikube docker-env) && docker build -t openfga-operator:latest .; \
	else \
		echo "Minikube not using Docker driver, falling back to container-build + minikube-load"; \
		$(MAKE) container-build minikube-load; \
	fi
	@echo "Verifying image is available in Minikube..."
	@minikube image ls | grep openfga-operator || { echo "Error: Image not available in Minikube"; exit 1; }

# Load container image into Minikube
minikube-load:
	@echo "Loading container image into Minikube..."
	@if command -v docker >/dev/null 2>&1 && minikube config get driver 2>/dev/null | grep -q docker; then \
		echo "Using Minikube's Docker environment to verify image..."; \
		eval $$(minikube docker-env) && docker images | grep openfga-operator || { \
			echo "Image not found in Minikube's Docker environment, loading..."; \
			minikube image load openfga-operator:latest; \
		}; \
	else \
		echo "Loading image using minikube image load..."; \
		minikube image load openfga-operator:latest; \
	fi
	@echo "Verifying image is available in Minikube..."
	@minikube image ls | grep openfga-operator || { echo "Error: Image not available in Minikube"; exit 1; }

# Deploy to Minikube (requires image to be built and loaded)
minikube-deploy: minikube-build install-crds
	@echo "Deploying to Minikube..."
	kubectl create namespace openfga-system --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f - <<< 'apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: openfga-operator\n  namespace: openfga-system\nspec:\n  replicas: 1\n  selector:\n    matchLabels:\n      app: openfga-operator\n  template:\n    metadata:\n      labels:\n        app: openfga-operator\n    spec:\n      containers:\n      - name: operator\n        image: openfga-operator:latest\n        imagePullPolicy: Never\n        ports:\n        - containerPort: 8080'

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
	@echo "  container-build - Build container image (Docker or Podman)"
	@echo "  test-podman-build - Test Podman build with permission fixes"
	@echo "  docker-build - Build container image (legacy, uses container-build)"
	@echo "  deploy-dev   - Deploy to development environment"
	@echo "  deploy-staging - Deploy to staging environment"
	@echo "  deploy-prod  - Deploy to production environment"
	@echo "  minikube-build - Build container image using Minikube's Docker environment"
	@echo "  minikube-load - Load container image into Minikube"
	@echo "  minikube-deploy - Build and deploy to Minikube"
	@echo "  verify-deployment - Verify deployment status"
	@echo "  check-kustomize - Validate kustomize configurations"
	@echo "  clean-dev    - Clean up development deployment"
	@echo "  clean-staging - Clean up staging deployment"
	@echo "  clean-prod   - Clean up production deployment"
	@echo "  check-all    - Run all quality checks"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Environment variables:"
	@echo "  CONTAINER_RUNTIME - Set container runtime (docker|podman)"
