.PHONY: compile build test fmt clippy clean install-crds uninstall-crds run dev deploy-dev deploy-staging deploy-prod minikube-build minikube-load minikube-deploy minikube-deploy-registry minikube-deploy-local

# Configuration
IMAGE_REGISTRY ?= ghcr.io/jralmaraz/authcore-openfga-operator
IMAGE_TAG ?= latest
LOCAL_IMAGE_NAME ?= openfga-operator:latest
VERSION ?= $(shell grep '^version = ' Cargo.toml | cut -d '"' -f 2)
ALPHA_VERSION ?= v0.1.0-alpha

# Function to generate deployment YAML
# Usage: $(call generate-deployment-yaml,image-name,image-pull-policy,temp-file)
define generate-deployment-yaml
	@echo "Creating deployment YAML..."
	@{ \
		echo "apiVersion: apps/v1"; \
		echo "kind: Deployment"; \
		echo "metadata:"; \
		echo "  name: openfga-operator"; \
		echo "  namespace: openfga-system"; \
		echo "spec:"; \
		echo "  replicas: 1"; \
		echo "  selector:"; \
		echo "    matchLabels:"; \
		echo "      app: openfga-operator"; \
		echo "  template:"; \
		echo "    metadata:"; \
		echo "      labels:"; \
		echo "        app: openfga-operator"; \
		echo "    spec:"; \
		echo "      containers:"; \
		echo "      - name: operator"; \
		echo "        image: $(1)"; \
		echo "        imagePullPolicy: $(2)"; \
		echo "        ports:"; \
		echo "        - containerPort: 8080"; \
	} > $(3)
endef

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
		eval $$(minikube docker-env) && docker build -t openfga-operator:latest . || { \
			echo "Build failed in Minikube environment, falling back to local build"; \
			$(MAKE) container-build minikube-load; \
		}; \
	else \
		echo "Minikube not using Docker driver, falling back to container-build + minikube-load"; \
		$(MAKE) container-build minikube-load; \
	fi
	@echo "Verifying image is available in Minikube..."
	@for i in 1 2 3; do \
		if minikube image ls | grep openfga-operator; then \
			echo "✓ Image verified in Minikube"; \
			exit 0; \
		else \
			echo "Image not found, attempt $$i/3..."; \
			sleep 2; \
		fi; \
	done; \
	echo "Error: Image not available in Minikube after 3 attempts"; \
	exit 1

# Load container image into Minikube
minikube-load:
	@echo "Loading container image into Minikube..."
	@if command -v docker >/dev/null 2>&1 && minikube config get driver 2>/dev/null | grep -q docker; then \
		echo "Using Minikube's Docker environment to verify image..."; \
		eval $$(minikube docker-env) && docker images | grep openfga-operator || { \
			echo "Image not found in Minikube's Docker environment, loading..."; \
			for i in 1 2 3; do \
				if minikube image load openfga-operator:latest; then \
					echo "✓ Image loaded successfully"; \
					break; \
				else \
					echo "Load attempt $$i failed, retrying..."; \
					sleep 2; \
				fi; \
			done; \
		}; \
	else \
		echo "Loading image using minikube image load..."; \
		for i in 1 2 3; do \
			if minikube image load openfga-operator:latest; then \
				echo "✓ Image loaded successfully"; \
				break; \
			else \
				echo "Load attempt $$i failed, retrying..."; \
				sleep 2; \
			fi; \
		done; \
	fi
	@echo "Verifying image is available in Minikube..."
	@for i in 1 2 3; do \
		if minikube image ls | grep openfga-operator; then \
			echo "✓ Image verified in Minikube"; \
			exit 0; \
		else \
			echo "Verification attempt $$i/3 failed..."; \
			sleep 2; \
		fi; \
	done; \
	echo "Error: Image not available in Minikube after verification"; \
	exit 1

# Deploy to Minikube using registry image (recommended for reliability)
minikube-deploy-registry: install-crds
	@echo "Deploying to Minikube using registry image..."
	@echo "Using image: $(IMAGE_REGISTRY):$(IMAGE_TAG)"
	kubectl create namespace openfga-system --dry-run=client -o yaml | kubectl apply -f -
	$(eval TEMP_FILE := $(shell mktemp))
	$(call generate-deployment-yaml,$(IMAGE_REGISTRY):$(IMAGE_TAG),Always,$(TEMP_FILE))
	kubectl apply -f $(TEMP_FILE)
	@rm -f $(TEMP_FILE)

# Deploy to Minikube using local image (requires image to be built and loaded)
minikube-deploy-local: minikube-build install-crds
	@echo "Deploying to Minikube using local image..."
	kubectl create namespace openfga-system --dry-run=client -o yaml | kubectl apply -f -
	$(eval TEMP_FILE := $(shell mktemp))
	$(call generate-deployment-yaml,$(LOCAL_IMAGE_NAME),Never,$(TEMP_FILE))
	kubectl apply -f $(TEMP_FILE)
	@rm -f $(TEMP_FILE)

# Deploy to Minikube (legacy - uses local build)
minikube-deploy: minikube-deploy-local

# Validate Minikube deployment (works with both registry and local images)
minikube-validate:
	@echo "Validating Minikube deployment..."
	@echo "Checking Minikube status..."
	@minikube status || { echo "Error: Minikube is not running"; exit 1; }
	@echo "Checking operator deployment..."
	@kubectl get deployment openfga-operator -n openfga-system || { echo "Error: Operator deployment not found"; exit 1; }
	@echo "Checking operator pod status..."
	@kubectl wait --for=condition=ready pod -l app=openfga-operator -n openfga-system --timeout=120s || { \
		echo "Error: Operator pod not ready"; \
		kubectl get pods -n openfga-system; \
		kubectl logs -n openfga-system -l app=openfga-operator --tail=10; \
		exit 1; \
	}
	@echo "Checking CRDs..."
	@kubectl get crd openfgas.authorization.openfga.dev || { echo "Error: OpenFGA CRD not found"; exit 1; }
	@echo "✓ All validation checks passed!"

# Complete Minikube setup and deployment with validation (registry-based, recommended)
minikube-setup-and-deploy-registry: minikube-deploy-registry minikube-validate
	@echo "✓ Minikube deployment completed successfully using registry image!"
	@echo ""
	@echo "Image used: $(IMAGE_REGISTRY):$(IMAGE_TAG)"
	@echo ""
	@echo "Next steps:"
	@echo "1. Run './scripts/minikube/validate-deployment.sh' for additional validation"
	@echo "2. Access OpenFGA API: kubectl port-forward service/openfga-basic-http 8080:8080"
	@echo "3. Deploy demo applications: cd demos/banking-app && kubectl apply -f k8s/"

# Complete Minikube setup and deployment with validation (local build)
minikube-setup-and-deploy-local: minikube-deploy-local minikube-validate
	@echo "✓ Minikube deployment completed successfully using local image!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Run './scripts/minikube/validate-deployment.sh' for additional validation"
	@echo "2. Access OpenFGA API: kubectl port-forward service/openfga-basic-http 8080:8080"
	@echo "3. Deploy demo applications: cd demos/banking-app && kubectl apply -f k8s/"

# Complete Minikube setup and deployment with validation (legacy - uses local build)
minikube-setup-and-deploy: minikube-setup-and-deploy-local

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
	@echo "  minikube-deploy - Build and deploy to Minikube (legacy, uses local build)"
	@echo "  minikube-deploy-registry - Deploy to Minikube using registry image (recommended)"
	@echo "  minikube-deploy-local - Deploy to Minikube using local build"
	@echo "  minikube-validate - Validate Minikube deployment"
	@echo "  minikube-setup-and-deploy - Complete setup with local build (legacy)"
	@echo "  minikube-setup-and-deploy-registry - Complete setup with registry image (recommended)"
	@echo "  minikube-setup-and-deploy-local - Complete setup with local build"
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
	@echo "  IMAGE_REGISTRY   - Container registry for deployment (default: ghcr.io/jralmaraz/authcore-openfga-operator)"
	@echo "  IMAGE_TAG        - Image tag for deployment (default: latest)"
	@echo "  LOCAL_IMAGE_NAME - Local image name for build (default: openfga-operator:latest)"
	@echo ""
	@echo "Registry-based deployment (recommended for reliability):"
	@echo "  make minikube-deploy-registry              # Deploy using GHCR image"
	@echo "  make minikube-setup-and-deploy-registry    # Complete setup with GHCR image"
	@echo ""
	@echo "Local build deployment (for development):"
	@echo "  make minikube-deploy-local                 # Deploy using local build"
	@echo "  make minikube-setup-and-deploy-local       # Complete setup with local build"
	@echo ""
	@echo "Alpha release targets:"
	@echo "  make alpha-build                           # Build alpha release image"
	@echo "  make alpha-push                            # Push alpha release image to registry"
	@echo "  make alpha-release                         # Build, push and tag alpha release"

# Alpha release targets
alpha-build:
	@echo "Building alpha release image..."
	@RUNTIME=$$($(MAKE) detect-runtime 2>/dev/null); \
	if [ -n "$$RUNTIME" ]; then \
		echo "Using container runtime: $$RUNTIME"; \
		$$RUNTIME build -t $(IMAGE_REGISTRY):$(ALPHA_VERSION) .; \
		$$RUNTIME tag $(IMAGE_REGISTRY):$(ALPHA_VERSION) $(IMAGE_REGISTRY):latest; \
		echo "✓ Built image: $(IMAGE_REGISTRY):$(ALPHA_VERSION)"; \
	else \
		echo "Error: No container runtime available"; \
		exit 1; \
	fi

alpha-push:
	@echo "Pushing alpha release image to registry..."
	@RUNTIME=$$($(MAKE) detect-runtime 2>/dev/null); \
	if [ -n "$$RUNTIME" ]; then \
		echo "Pushing $(IMAGE_REGISTRY):$(ALPHA_VERSION)..."; \
		$$RUNTIME push $(IMAGE_REGISTRY):$(ALPHA_VERSION); \
		echo "Pushing $(IMAGE_REGISTRY):latest..."; \
		$$RUNTIME push $(IMAGE_REGISTRY):latest; \
		echo "✓ Pushed images to registry"; \
	else \
		echo "Error: No container runtime available"; \
		exit 1; \
	fi

alpha-tag:
	@echo "Creating git tag for alpha release..."
	@if git tag -l | grep -q "^$(ALPHA_VERSION)$$"; then \
		echo "Tag $(ALPHA_VERSION) already exists"; \
	else \
		git tag -a $(ALPHA_VERSION) -m "Alpha release $(ALPHA_VERSION)"; \
		echo "✓ Created tag: $(ALPHA_VERSION)"; \
	fi

alpha-release: alpha-build alpha-push alpha-tag
	@echo "✓ Alpha release $(ALPHA_VERSION) completed successfully!"
	@echo ""
	@echo "To deploy the alpha release:"
	@echo "  IMAGE_TAG=$(ALPHA_VERSION) make minikube-deploy-registry"
	@echo ""
	@echo "To pull the alpha image:"
	@echo "  docker pull $(IMAGE_REGISTRY):$(ALPHA_VERSION)"
