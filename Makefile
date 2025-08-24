# OpenFGA Operator Makefile
# Supports both Rust and Go implementations

##@ Rust Implementation Targets

.PHONY: rust-compile rust-build rust-test rust-fmt rust-clippy rust-clean rust-install-crds rust-uninstall-crds rust-run rust-dev rust-check-all

# Rust: Compile the project (check syntax and dependencies)
rust-compile:
	@echo "Compiling Rust OpenFGA Operator..."
	cargo check

# Rust: Build the project
rust-build:
	@echo "Building Rust OpenFGA Operator..."
	cargo build --release

# Rust: Run tests
rust-test:
	@echo "Running Rust tests..."
	cargo test

# Rust: Format code
rust-fmt:
	@echo "Formatting Rust code..."
	cargo fmt

# Rust: Run clippy for linting
rust-clippy:
	@echo "Running Rust clippy..."
	cargo clippy -- -D warnings

# Rust: Clean build artifacts
rust-clean:
	@echo "Cleaning Rust build artifacts..."
	cargo clean

# Rust: Install CRDs to the cluster
rust-install-crds:
	@echo "Installing Rust CRDs..."
	kubectl apply -f crds/

# Rust: Uninstall CRDs from the cluster
rust-uninstall-crds:
	@echo "Uninstalling Rust CRDs..."
	kubectl delete -f crds/

# Rust: Run the operator locally
rust-run:
	@echo "Running Rust OpenFGA Operator locally..."
	cargo run

# Rust: Development mode with auto-reload
rust-dev:
	@echo "Running Rust operator in development mode..."
	cargo watch -x run

# Rust: Build Docker image
rust-docker-build:
	@echo "Building Rust Docker image..."
	docker build -t openfga-operator-rust:latest -f Dockerfile.rust .

# Rust: Run all quality checks
rust-check-all: rust-fmt rust-clippy rust-compile rust-test
	@echo "All Rust checks passed!"

##@ Go Implementation Targets

# Image URL to use all building/pushing image targets
IMG ?= openfga-operator:latest
# ENVTEST_K8S_VERSION refers to the version of kubebuilder assets to be downloaded by envtest binary.
ENVTEST_K8S_VERSION = 1.28.0

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

.PHONY: go-manifests go-generate go-fmt go-vet go-test go-build go-run go-docker-build go-docker-push go-docker-buildx

# Go: Generate WebhookConfiguration, ClusterRole and CustomResourceDefinition objects.
go-manifests: controller-gen
	$(CONTROLLER_GEN) rbac:roleName=manager-role crd webhook paths="./..." output:crd:artifacts:config=config/crd

# Go: Generate code containing DeepCopy, DeepCopyInto, and DeepCopyObject method implementations.
go-generate: controller-gen
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

# Go: Run go fmt against code.
go-fmt:
	go fmt ./...

# Go: Run go vet against code.
go-vet:
	go vet ./...

# Go: Run tests.
go-test: go-manifests go-generate go-fmt go-vet envtest
	KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) --bin-dir $(LOCALBIN) -p path)" go test ./... -coverprofile cover.out

# Go: Build manager binary.
go-build: go-manifests go-generate go-fmt go-vet
	go build -o bin/manager main.go

# Go: Run a controller from your host.
go-run: go-manifests go-generate go-fmt go-vet
	go run ./main.go

# Go: Build docker image with the manager.
go-docker-build: go-test
	docker build -t ${IMG} .

# Go: Push docker image with the manager.
go-docker-push:
	docker push ${IMG}

# PLATFORMS defines the target platforms for  the manager image be build to provide support to multiple
# architectures. (i.e. make docker-buildx IMG=myregistry/mypoperator:0.0.1). To use this option you need to:
# - able to use docker buildx . More info: https://docs.docker.com/build/buildx/
# - have a multi-arch builder. More info: https://docs.docker.com/build/building/multi-platform/
# - be able to push the image for your registry (i.e. if you do not inform a valid value via IMG=<myregistry/image:<tag>> then the export will fail)
# To properly provided solutions that supports more than one platform you should use this option.
PLATFORMS ?= linux/arm64,linux/amd64,linux/s390x,linux/ppc64le
.PHONY: go-docker-buildx
go-docker-buildx: go-test ## Build and push docker image for the manager for cross-platform support
	# copy existing Dockerfile and insert --platform=${BUILDPLATFORM} into Dockerfile.cross, and preserve the original Dockerfile
	sed -e '1 s/\(^FROM\)/FROM --platform=\$$\{BUILDPLATFORM\}/; t' -e ' 1,// s//FROM --platform=\$$\{BUILDPLATFORM\}/' Dockerfile > Dockerfile.cross
	- docker buildx create --name project-v3-builder
	docker buildx use project-v3-builder
	- docker buildx build --push --platform=$(PLATFORMS) --tag ${IMG} -f Dockerfile.cross .
	- docker buildx rm project-v3-builder
	rm Dockerfile.cross

##@ Deployment

ifndef ignore-not-found
  ignore-not-found = false
endif

.PHONY: go-install go-uninstall go-deploy go-undeploy

# Go: Install CRDs into the K8s cluster specified in ~/.kube/config.
go-install: go-manifests kustomize
	$(KUSTOMIZE) build config/crd | kubectl apply -f -

# Go: Uninstall CRDs from the K8s cluster specified in ~/.kube/config. Call with ignore-not-found=true to ignore resource not found errors during deletion.
go-uninstall: go-manifests kustomize
	$(KUSTOMIZE) build config/crd | kubectl delete --ignore-not-found=$(ignore-not-found) -f -

# Go: Deploy controller to the K8s cluster specified in ~/.kube/config.
go-deploy: go-manifests kustomize
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	$(KUSTOMIZE) build config/default | kubectl apply -f -

# Go: Undeploy controller from the K8s cluster specified in ~/.kube/config. Call with ignore-not-found=true to ignore resource not found errors during deletion.
go-undeploy:
	$(KUSTOMIZE) build config/default | kubectl delete --ignore-not-found=$(ignore-not-found) -f -

##@ Build Dependencies

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## Tool Binaries
KUSTOMIZE ?= $(LOCALBIN)/kustomize
CONTROLLER_GEN ?= $(LOCALBIN)/controller-gen
ENVTEST ?= $(LOCALBIN)/setup-envtest

## Tool Versions
KUSTOMIZE_VERSION ?= v3.8.7
CONTROLLER_TOOLS_VERSION ?= v0.13.0

KUSTOMIZE_INSTALL_SCRIPT ?= "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"
.PHONY: kustomize
kustomize: $(KUSTOMIZE) ## Download kustomize locally if necessary. If wrong version is installed, it will be removed before downloading.
$(KUSTOMIZE): $(LOCALBIN)
	@if test -x $(LOCALBIN)/kustomize && ! $(LOCALBIN)/kustomize version | grep -q $(KUSTOMIZE_VERSION); then \
		echo "$(LOCALBIN)/kustomize version is not expected $(KUSTOMIZE_VERSION). Removing it before installing."; \
		rm -rf $(LOCALBIN)/kustomize; \
	fi
	test -s $(LOCALBIN)/kustomize || { curl -Ss $(KUSTOMIZE_INSTALL_SCRIPT) | bash -s -- $(subst v,,$(KUSTOMIZE_VERSION)) $(LOCALBIN); }

.PHONY: controller-gen
controller-gen: $(CONTROLLER_GEN) ## Download controller-gen locally if necessary. If wrong version is installed, it will be overwritten.
$(CONTROLLER_GEN): $(LOCALBIN)
	test -s $(LOCALBIN)/controller-gen && $(LOCALBIN)/controller-gen --version | grep -q $(CONTROLLER_TOOLS_VERSION) || \
	GOBIN=$(LOCALBIN) go install sigs.k8s.io/controller-tools/cmd/controller-gen@$(CONTROLLER_TOOLS_VERSION)

.PHONY: envtest
envtest: $(ENVTEST) ## Download envtest-setup locally if necessary.
$(ENVTEST): $(LOCALBIN)
	test -s $(LOCALBIN)/setup-envtest || GOBIN=$(LOCALBIN) go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest

##@ Unified Targets (Both Implementations)

.PHONY: all compile build test fmt vet run clean install uninstall check-all help

# Default target - builds both implementations
all: rust-build go-build

# Compile both implementations
compile: rust-compile go-manifests go-generate

# Build both implementations
build: rust-build go-build

# Test both implementations
test: rust-test go-test

# Format code for both implementations
fmt: rust-fmt go-fmt

# Vet/lint both implementations
vet: rust-clippy go-vet

# Clean both implementations
clean: rust-clean
	rm -rf bin/ cover.out

# Install CRDs for both implementations
install: rust-install-crds go-install

# Uninstall CRDs for both implementations
uninstall: rust-uninstall-crds go-uninstall

# Run all checks for both implementations
check-all: rust-check-all go-test
	@echo "All checks passed for both Rust and Go implementations!"

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.PHONY: help
help: ## Display this help.
	@echo "OpenFGA Operator - Dual Implementation (Rust + Go)"
	@echo "=================================================="
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""
	@echo "Quick Start:"
	@echo "  make help           - Show this help"
	@echo "  make all            - Build both implementations"
	@echo "  make test           - Test both implementations"
	@echo "  make rust-run       - Run Rust operator locally"
	@echo "  make go-run         - Run Go operator locally"