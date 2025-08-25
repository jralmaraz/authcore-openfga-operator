.PHONY: compile build test fmt clippy clean install-crds uninstall-crds run dev

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

# Load Docker image into Minikube
minikube-load:
	@echo "Loading Docker image into Minikube..."
	minikube image load openfga-operator:latest

# Deploy to Minikube (requires image to be built and loaded)
minikube-deploy: docker-build minikube-load install-crds
	@echo "Deploying to Minikube..."
	kubectl create namespace openfga-system --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f - <<< 'apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: openfga-operator\n  namespace: openfga-system\nspec:\n  replicas: 1\n  selector:\n    matchLabels:\n      app: openfga-operator\n  template:\n    metadata:\n      labels:\n        app: openfga-operator\n    spec:\n      containers:\n      - name: operator\n        image: openfga-operator:latest\n        imagePullPolicy: Never\n        ports:\n        - containerPort: 8080'

# Run all quality checks
check-all: fmt clippy compile test
	@echo "All checks passed!"

# Help target
help:
	@echo "Available targets:"
	@echo "  compile         - Check syntax and dependencies"
	@echo "  build           - Build the project in release mode"
	@echo "  test            - Run tests"
	@echo "  fmt             - Format code"
	@echo "  clippy          - Run clippy linter"
	@echo "  clean           - Clean build artifacts"
	@echo "  install-crds    - Install CRDs to Kubernetes cluster"
	@echo "  uninstall-crds  - Remove CRDs from Kubernetes cluster"
	@echo "  run             - Run the operator locally"
	@echo "  dev             - Run in development mode with auto-reload"
	@echo "  docker-build    - Build Docker image"
	@echo "  minikube-load   - Load Docker image into Minikube"
	@echo "  minikube-deploy - Deploy to Minikube (build + load + deploy)"
	@echo "  check-all       - Run all quality checks"
	@echo "  help            - Show this help message"