#!/bin/bash

# OpenFGA Operator Repository Initialization Script
# This script scaffolds the complete repository structure for the OpenFGA Kubernetes operator

set -e

echo "🚀 Initializing OpenFGA Operator repository structure..."

# Create main project directories
echo "📁 Creating directory structure..."
mkdir -p {src,config,manifests,demo,docs,charts,examples,tests}
mkdir -p src/{controller,models,utils}
mkdir -p config/{crd,rbac,manager,samples}
mkdir -p manifests/{operator,crds,rbac}
mkdir -p demo/{microservice,manifests}
mkdir -p docs/{design,api}
mkdir -p charts/openfga-operator
mkdir -p examples/{basic,advanced}
mkdir -p tests/{unit,integration,e2e}

# Create Cargo.toml for Rust operator
echo "📦 Creating Cargo.toml..."
cat > Cargo.toml << 'EOF'
[package]
name = "openfga-operator"
version = "0.1.0"
edition = "2021"
description = "Kubernetes operator for managing OpenFGA instances"
authors = ["OpenFGA Operator Team"]
license = "Apache-2.0"
repository = "https://github.com/jralmaraz/Openfga-operator"

[dependencies]
tokio = { version = "1.0", features = ["full"] }
kube = { version = "0.87", features = ["runtime", "derive"] }
k8s-openapi = { version = "0.20", features = ["v1_28"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
serde_yaml = "0.9"
anyhow = "1.0"
thiserror = "1.0"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
futures = "0.3"
clap = { version = "4.0", features = ["derive"] }
reqwest = { version = "0.11", features = ["json"] }
uuid = { version = "1.0", features = ["v4"] }

[dev-dependencies]
tokio-test = "0.4"

[[bin]]
name = "openfga-operator"
path = "src/main.rs"
EOF

# Create .gitignore
echo "🚫 Creating .gitignore..."
cat > .gitignore << 'EOF'
# Rust
/target/
**/*.rs.bk
Cargo.lock

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Kubernetes
*.kubeconfig
*-secret.yaml

# Logs
*.log

# Build artifacts
/dist/
/build/

# Docker
.dockerignore

# Helm
charts/*/charts/
charts/*/Chart.lock

# Temporary files
/tmp/
*.tmp
*.temp

# Environment files
.env
.env.local
.env.*.local
EOF

# Create main Rust source files
echo "🦀 Creating Rust operator source files..."

# Main application entry point
cat > src/main.rs << 'EOF'
use anyhow::Result;
use clap::Parser;
use k8s_openapi::api::core::v1::Namespace;
use kube::{
    api::{Api, ResourceExt},
    runtime::{controller::Action, watcher::Config, Controller},
    Client, CustomResource,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::Duration;
use tokio::time::Duration as TokioDuration;
use tracing::{error, info, instrument, warn};

mod controller;
mod models;
mod utils;

use controller::openfga_store_controller;
use models::{OpenFGAStore, OpenFGAAuthModel};

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Namespace to watch (if not specified, watches all namespaces)
    #[arg(short, long)]
    namespace: Option<String>,
    
    /// Verbosity level
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();
    
    // Initialize tracing
    let log_level = match args.verbose {
        0 => "info",
        1 => "debug", 
        _ => "trace",
    };
    
    tracing_subscriber::fmt()
        .with_env_filter(format!("openfga_operator={}", log_level))
        .init();

    info!("Starting OpenFGA Operator v{}", env!("CARGO_PKG_VERSION"));

    // Initialize Kubernetes client
    let client = Client::try_default().await?;
    
    // Create API clients for our CRDs
    let stores_api: Api<OpenFGAStore> = match &args.namespace {
        Some(ns) => Api::namespaced(client.clone(), ns),
        None => Api::all(client.clone()),
    };
    
    let auth_models_api: Api<OpenFGAAuthModel> = match &args.namespace {
        Some(ns) => Api::namespaced(client.clone(), ns),
        None => Api::all(client.clone()),
    };

    info!("Watching for OpenFGA resources in namespace: {:?}", args.namespace.as_deref().unwrap_or("all"));

    // Start the controller
    let context = Arc::new(ControllerContext {
        client: client.clone(),
    });

    Controller::new(stores_api, Config::default())
        .run(openfga_store_controller, utils::error_policy, context)
        .for_each(|result| async move {
            match result {
                Ok(o) => info!("Reconciled OpenFGAStore: {:?}", o),
                Err(e) => error!("Reconciliation error: {:?}", e),
            }
        })
        .await;

    Ok(())
}

#[derive(Clone)]
pub struct ControllerContext {
    pub client: Client,
}
EOF

# Controller logic
cat > src/controller/mod.rs << 'EOF'
use crate::{models::OpenFGAStore, ControllerContext};
use anyhow::Result;
use k8s_openapi::api::apps::v1::{Deployment, DeploymentSpec};
use k8s_openapi::api::core::v1::{
    Container, PodSpec, PodTemplateSpec, Service, ServicePort, ServiceSpec,
};
use k8s_openapi::apimachinery::pkg::apis::meta::v1::{LabelSelector, ObjectMeta};
use kube::{
    api::{Api, Patch, PatchParams, ResourceExt},
    runtime::controller::Action,
    Resource,
};
use serde_json::json;
use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::Duration;
use tracing::{error, info, instrument, warn};

pub mod openfga_store_controller;

pub use openfga_store_controller::*;
EOF

cat > src/controller/openfga_store_controller.rs << 'EOF'
use super::*;

#[instrument(skip(store, ctx))]
pub async fn openfga_store_controller(
    store: Arc<OpenFGAStore>,
    ctx: Arc<ControllerContext>,
) -> Result<Action, anyhow::Error> {
    let client = &ctx.client;
    let namespace = store.namespace().unwrap_or_default();
    
    info!("Reconciling OpenFGAStore: {} in namespace: {}", store.name_any(), namespace);

    // Create or update OpenFGA deployment
    create_or_update_deployment(client, &store, &namespace).await?;
    
    // Create or update service
    create_or_update_service(client, &store, &namespace).await?;

    // Update status
    update_store_status(client, &store, &namespace).await?;

    Ok(Action::requeue(Duration::from_secs(300)))
}

async fn create_or_update_deployment(
    client: &kube::Client,
    store: &OpenFGAStore,
    namespace: &str,
) -> Result<()> {
    let name = format!("openfga-{}", store.name_any());
    let deployments: Api<Deployment> = Api::namespaced(client.clone(), namespace);
    
    let mut labels = BTreeMap::new();
    labels.insert("app".to_string(), "openfga".to_string());
    labels.insert("store".to_string(), store.name_any());
    
    let deployment = Deployment {
        metadata: ObjectMeta {
            name: Some(name.clone()),
            namespace: Some(namespace.to_string()),
            labels: Some(labels.clone()),
            ..Default::default()
        },
        spec: Some(DeploymentSpec {
            replicas: Some(store.spec.replicas.unwrap_or(1)),
            selector: LabelSelector {
                match_labels: Some(labels.clone()),
                ..Default::default()
            },
            template: PodTemplateSpec {
                metadata: Some(ObjectMeta {
                    labels: Some(labels),
                    ..Default::default()
                }),
                spec: Some(PodSpec {
                    containers: vec![Container {
                        name: "openfga".to_string(),
                        image: Some(store.spec.image.clone().unwrap_or_else(|| "openfga/openfga:latest".to_string())),
                        ports: Some(vec![
                            k8s_openapi::api::core::v1::ContainerPort {
                                container_port: 8080,
                                name: Some("http".to_string()),
                                ..Default::default()
                            },
                            k8s_openapi::api::core::v1::ContainerPort {
                                container_port: 8081,
                                name: Some("grpc".to_string()),
                                ..Default::default()
                            },
                        ]),
                        ..Default::default()
                    }],
                    ..Default::default()
                }),
            },
            ..Default::default()
        }),
        ..Default::default()
    };

    let patch_params = PatchParams::apply("openfga-operator");
    let patch = Patch::Apply(&deployment);
    
    deployments.patch(&name, &patch_params, &patch).await?;
    info!("Deployment {} created/updated", name);
    
    Ok(())
}

async fn create_or_update_service(
    client: &kube::Client,
    store: &OpenFGAStore,
    namespace: &str,
) -> Result<()> {
    let name = format!("openfga-{}", store.name_any());
    let services: Api<Service> = Api::namespaced(client.clone(), namespace);
    
    let mut labels = BTreeMap::new();
    labels.insert("app".to_string(), "openfga".to_string());
    labels.insert("store".to_string(), store.name_any());
    
    let service = Service {
        metadata: ObjectMeta {
            name: Some(name.clone()),
            namespace: Some(namespace.to_string()),
            labels: Some(labels.clone()),
            ..Default::default()
        },
        spec: Some(ServiceSpec {
            selector: Some(labels),
            ports: Some(vec![
                ServicePort {
                    name: Some("http".to_string()),
                    port: 8080,
                    target_port: Some(k8s_openapi::apimachinery::pkg::util::intstr::IntOrString::Int(8080)),
                    ..Default::default()
                },
                ServicePort {
                    name: Some("grpc".to_string()),
                    port: 8081,
                    target_port: Some(k8s_openapi::apimachinery::pkg::util::intstr::IntOrString::Int(8081)),
                    ..Default::default()
                },
            ]),
            ..Default::default()
        }),
        ..Default::default()
    };

    let patch_params = PatchParams::apply("openfga-operator");
    let patch = Patch::Apply(&service);
    
    services.patch(&name, &patch_params, &patch).await?;
    info!("Service {} created/updated", name);
    
    Ok(())
}

async fn update_store_status(
    client: &kube::Client,
    store: &OpenFGAStore,
    namespace: &str,
) -> Result<()> {
    let stores: Api<OpenFGAStore> = Api::namespaced(client.clone(), namespace);
    
    let status_patch = json!({
        "status": {
            "phase": "Ready",
            "lastUpdated": chrono::Utc::now().to_rfc3339()
        }
    });
    
    let patch_params = PatchParams::apply("openfga-operator");
    stores
        .patch_status(&store.name_any(), &patch_params, &Patch::Merge(&status_patch))
        .await?;
        
    info!("Status updated for store: {}", store.name_any());
    Ok(())
}
EOF

# Models (CRD definitions)
cat > src/models/mod.rs << 'EOF'
use kube::CustomResource;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

pub mod openfga_store;
pub mod openfga_auth_model;

pub use openfga_store::*;
pub use openfga_auth_model::*;

#[derive(CustomResource, Deserialize, Serialize, Clone, Debug)]
#[kube(group = "openfga.dev", version = "v1", kind = "OpenFGAStore")]
#[kube(namespaced)]
#[kube(status = "OpenFGAStoreStatus")]
#[kube(printcolumn = r#"{"name":"Phase", "type":"string", "jsonPath":".status.phase"}"#)]
#[kube(printcolumn = r#"{"name":"Age", "type":"date", "jsonPath":".metadata.creationTimestamp"}"#)]
pub struct OpenFGAStoreSpec {
    /// Number of replicas for the OpenFGA deployment
    pub replicas: Option<i32>,
    
    /// Docker image for OpenFGA
    pub image: Option<String>,
    
    /// Database configuration
    pub database: DatabaseConfig,
    
    /// Additional configuration options
    pub config: Option<BTreeMap<String, String>>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct DatabaseConfig {
    /// Database type (postgres, mysql, sqlite)
    pub r#type: String,
    
    /// Database connection string or reference to secret
    pub connection: ConnectionConfig,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct ConnectionConfig {
    /// Direct connection string
    pub connection_string: Option<String>,
    
    /// Reference to a Kubernetes secret containing connection details
    pub secret_ref: Option<SecretReference>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct SecretReference {
    /// Name of the secret
    pub name: String,
    
    /// Key within the secret
    pub key: String,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct OpenFGAStoreStatus {
    /// Current phase of the store
    pub phase: Option<String>,
    
    /// Last update timestamp
    pub last_updated: Option<String>,
    
    /// Conditions
    pub conditions: Option<Vec<Condition>>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct Condition {
    /// Type of condition
    pub r#type: String,
    
    /// Status of the condition
    pub status: String,
    
    /// Last transition time
    pub last_transition_time: Option<String>,
    
    /// Reason for the condition
    pub reason: Option<String>,
    
    /// Human readable message
    pub message: Option<String>,
}

#[derive(CustomResource, Deserialize, Serialize, Clone, Debug)]
#[kube(group = "openfga.dev", version = "v1", kind = "OpenFGAAuthModel")]
#[kube(namespaced)]
#[kube(status = "OpenFGAAuthModelStatus")]
#[kube(printcolumn = r#"{"name":"Store", "type":"string", "jsonPath":".spec.storeRef.name"}"#)]
#[kube(printcolumn = r#"{"name":"Phase", "type":"string", "jsonPath":".status.phase"}"#)]
#[kube(printcolumn = r#"{"name":"Age", "type":"date", "jsonPath":".metadata.creationTimestamp"}"#)]
pub struct OpenFGAAuthModelSpec {
    /// Reference to the OpenFGA store
    pub store_ref: ObjectReference,
    
    /// Authorization model definition
    pub model: AuthModelDefinition,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct ObjectReference {
    /// Name of the referenced object
    pub name: String,
    
    /// Namespace of the referenced object (optional)
    pub namespace: Option<String>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct AuthModelDefinition {
    /// Schema version
    pub schema_version: String,
    
    /// Type definitions
    pub type_definitions: Vec<TypeDefinition>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct TypeDefinition {
    /// Type name
    pub r#type: String,
    
    /// Relations for this type
    pub relations: Option<BTreeMap<String, Relation>>,
    
    /// Metadata
    pub metadata: Option<BTreeMap<String, serde_json::Value>>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct Relation {
    /// Relation definition
    pub this: Option<RelationDefinition>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct RelationDefinition {
    /// Union of relations
    pub union: Option<RelationUnion>,
    
    /// Intersection of relations  
    pub intersection: Option<RelationIntersection>,
    
    /// Exclusion of relations
    pub exclusion: Option<RelationExclusion>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct RelationUnion {
    /// Child relations
    pub child: Vec<RelationChild>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct RelationIntersection {
    /// Child relations
    pub child: Vec<RelationChild>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct RelationExclusion {
    /// Base relation
    pub base: Box<RelationChild>,
    
    /// Subtract relation
    pub subtract: Box<RelationChild>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct RelationChild {
    /// This relation
    pub this: Option<serde_json::Value>,
    
    /// Computed userset
    pub computed_userset: Option<ComputedUserset>,
    
    /// Tuple to userset
    pub tuple_to_userset: Option<TupleToUserset>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct ComputedUserset {
    /// Object type
    pub object: Option<String>,
    
    /// Relation
    pub relation: Option<String>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct TupleToUserset {
    /// Tupleset relation
    pub tupleset: Option<TuplesetRelation>,
    
    /// Computed userset
    pub computed_userset: Option<ComputedUserset>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct TuplesetRelation {
    /// Object type
    pub object: Option<String>,
    
    /// Relation
    pub relation: Option<String>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct OpenFGAAuthModelStatus {
    /// Current phase
    pub phase: Option<String>,
    
    /// Model ID in OpenFGA
    pub model_id: Option<String>,
    
    /// Last update timestamp
    pub last_updated: Option<String>,
    
    /// Conditions
    pub conditions: Option<Vec<Condition>>,
}
EOF

cat > src/models/openfga_store.rs << 'EOF'
// Re-export the main store types
pub use super::{OpenFGAStore, OpenFGAStoreSpec, OpenFGAStoreStatus, DatabaseConfig, ConnectionConfig, SecretReference, Condition};
EOF

cat > src/models/openfga_auth_model.rs << 'EOF'
// Re-export the auth model types
pub use super::{
    OpenFGAAuthModel, OpenFGAAuthModelSpec, OpenFGAAuthModelStatus,
    ObjectReference, AuthModelDefinition, TypeDefinition, Relation,
    RelationDefinition, RelationUnion, RelationIntersection, RelationExclusion,
    RelationChild, ComputedUserset, TupleToUserset, TuplesetRelation, Condition
};
EOF

# Utilities
cat > src/utils/mod.rs << 'EOF'
use anyhow::Error;
use kube::runtime::controller::Action;
use std::time::Duration;
use tracing::error;

pub mod error_handling;

pub use error_handling::*;

/// Error policy for the controller
pub fn error_policy(_object: Arc<dyn std::any::Any + Send + Sync>, error: &Error, _ctx: Arc<crate::ControllerContext>) -> Action {
    error!("Reconciliation error: {:?}", error);
    Action::requeue(Duration::from_secs(60))
}
EOF

cat > src/utils/error_handling.rs << 'EOF'
use thiserror::Error;

#[derive(Error, Debug)]
pub enum OperatorError {
    #[error("Kubernetes API error: {0}")]
    KubeError(#[from] kube::Error),
    
    #[error("Serialization error: {0}")]
    SerializationError(#[from] serde_json::Error),
    
    #[error("Configuration error: {message}")]
    ConfigError { message: String },
    
    #[error("OpenFGA API error: {message}")]
    OpenFGAError { message: String },
    
    #[error("Database error: {message}")]
    DatabaseError { message: String },
}

pub type Result<T> = std::result::Result<T, OperatorError>;
EOF

# Create CRD manifests
echo "📄 Creating CRD manifests..."
cat > config/crd/openfga-store-crd.yaml << 'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: openfgastores.openfga.dev
spec:
  group: openfga.dev
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              replicas:
                type: integer
                minimum: 1
                default: 1
              image:
                type: string
                default: "openfga/openfga:latest"
              database:
                type: object
                properties:
                  type:
                    type: string
                    enum: ["postgres", "mysql", "sqlite"]
                  connection:
                    type: object
                    properties:
                      connectionString:
                        type: string
                      secretRef:
                        type: object
                        properties:
                          name:
                            type: string
                          key:
                            type: string
                        required: ["name", "key"]
                    oneOf:
                    - required: ["connectionString"]
                    - required: ["secretRef"]
                required: ["type", "connection"]
              config:
                type: object
                additionalProperties:
                  type: string
            required: ["database"]
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Ready", "Error"]
              lastUpdated:
                type: string
                format: date-time
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    lastTransitionTime:
                      type: string
                      format: date-time
                    reason:
                      type: string
                    message:
                      type: string
                  required: ["type", "status"]
    additionalPrinterColumns:
    - name: Phase
      type: string
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  scope: Namespaced
  names:
    plural: openfgastores
    singular: openfgastore
    kind: OpenFGAStore
EOF

cat > config/crd/openfga-auth-model-crd.yaml << 'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: openfgaauthmodels.openfga.dev
spec:
  group: openfga.dev
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              storeRef:
                type: object
                properties:
                  name:
                    type: string
                  namespace:
                    type: string
                required: ["name"]
              model:
                type: object
                properties:
                  schemaVersion:
                    type: string
                    default: "1.1"
                  typeDefinitions:
                    type: array
                    items:
                      type: object
                      properties:
                        type:
                          type: string
                        relations:
                          type: object
                          additionalProperties:
                            type: object
                        metadata:
                          type: object
                      required: ["type"]
                required: ["schemaVersion", "typeDefinitions"]
            required: ["storeRef", "model"]
          status:
            type: object
            properties:
              phase:
                type: string
                enum: ["Pending", "Ready", "Error"]
              modelId:
                type: string
              lastUpdated:
                type: string
                format: date-time
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    lastTransitionTime:
                      type: string
                      format: date-time
                    reason:
                      type: string
                    message:
                      type: string
                  required: ["type", "status"]
    additionalPrinterColumns:
    - name: Store
      type: string
      jsonPath: .spec.storeRef.name
    - name: Phase
      type: string
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  scope: Namespaced
  names:
    plural: openfgaauthmodels
    singular: openfgaauthmodel
    kind: OpenFGAAuthModel
EOF

# Create RBAC manifests
echo "🔐 Creating RBAC manifests..."
cat > config/rbac/role.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: openfga-operator-role
rules:
- apiGroups: ["openfga.dev"]
  resources: ["openfgastores", "openfgaauthmodels"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["openfga.dev"]
  resources: ["openfgastores/status", "openfgaauthmodels/status"]
  verbs: ["get", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["services", "secrets", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
EOF

cat > config/rbac/role_binding.yaml << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: openfga-operator-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: openfga-operator-role
subjects:
- kind: ServiceAccount
  name: openfga-operator-service-account
  namespace: openfga-system
EOF

cat > config/rbac/service_account.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openfga-operator-service-account
  namespace: openfga-system
EOF

# Create manager manifests
echo "🎛️ Creating manager manifests..."
cat > config/manager/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openfga-operator-controller-manager
  namespace: openfga-system
  labels:
    app: openfga-operator
    component: controller-manager
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openfga-operator
      component: controller-manager
  template:
    metadata:
      labels:
        app: openfga-operator
        component: controller-manager
    spec:
      serviceAccountName: openfga-operator-service-account
      containers:
      - name: manager
        image: openfga-operator:latest
        command: ["/openfga-operator"]
        args:
        - --verbose=1
        env:
        - name: RUST_LOG
          value: "openfga_operator=info"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
      terminationGracePeriodSeconds: 10
EOF

cat > config/manager/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: openfga-system
  labels:
    name: openfga-system
EOF

# Create sample configurations
echo "📋 Creating sample configurations..."
cat > config/samples/basic-store.yaml << 'EOF'
apiVersion: openfga.dev/v1
kind: OpenFGAStore
metadata:
  name: basic-store
  namespace: default
spec:
  replicas: 1
  image: "openfga/openfga:v1.4.3"
  database:
    type: "postgres"
    connection:
      secretRef:
        name: "postgres-credentials"
        key: "connectionString"
  config:
    OPENFGA_HTTP_ADDR: "0.0.0.0:8080"
    OPENFGA_GRPC_ADDR: "0.0.0.0:8081"
    OPENFGA_LOG_LEVEL: "info"
EOF

cat > config/samples/auth-model.yaml << 'EOF'
apiVersion: openfga.dev/v1
kind: OpenFGAAuthModel
metadata:
  name: basic-auth-model
  namespace: default
spec:
  storeRef:
    name: basic-store
  model:
    schemaVersion: "1.1"
    typeDefinitions:
    - type: "user"
    - type: "organization"
      relations:
        member:
          this: {}
        admin:
          this: {}
    - type: "repository"
      relations:
        owner:
          this: {}
        reader:
          this: {}
        writer:
          union:
            child:
            - this: {}
            - computed_userset:
                object: ""
                relation: "owner"
EOF

# Create demo microservice
echo "🎯 Creating demo microservice..."
mkdir -p demo/microservice/src
cat > demo/microservice/Cargo.toml << 'EOF'
[package]
name = "openfga-demo"
version = "0.1.0"
edition = "2021"

[dependencies]
tokio = { version = "1.0", features = ["full"] }
axum = "0.7"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tracing = "0.1"
tracing-subscriber = "0.3"
reqwest = { version = "0.11", features = ["json"] }
uuid = { version = "1.0", features = ["v4"] }
anyhow = "1.0"
EOF

cat > demo/microservice/src/main.rs << 'EOF'
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tracing::{info, error};

#[derive(Clone)]
struct AppState {
    openfga_url: String,
}

#[derive(Deserialize, Serialize)]
struct CheckRequest {
    user: String,
    relation: String,
    object: String,
}

#[derive(Deserialize, Serialize)]
struct CheckResponse {
    allowed: bool,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::init();
    
    let openfga_url = std::env::var("OPENFGA_URL")
        .unwrap_or_else(|_| "http://openfga-basic-store:8080".to_string());
    
    let state = AppState { openfga_url };
    
    let app = Router::new()
        .route("/health", get(health_check))
        .route("/check", post(check_permission))
        .route("/user/:user/permissions", get(get_user_permissions))
        .with_state(Arc::new(state));
    
    info!("Starting demo service on 0.0.0.0:3000");
    
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000")
        .await
        .unwrap();
        
    axum::serve(listener, app).await.unwrap();
}

async fn health_check() -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "status": "healthy",
        "service": "openfga-demo"
    }))
}

async fn check_permission(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CheckRequest>,
) -> Result<Json<CheckResponse>, StatusCode> {
    // This is a simplified demo - in real usage you'd make actual OpenFGA API calls
    info!("Checking permission for user: {}, relation: {}, object: {}", 
          req.user, req.relation, req.object);
    
    // Mock permission check logic
    let allowed = match req.relation.as_str() {
        "reader" => true,
        "writer" => req.user.contains("admin"),
        "owner" => req.user.contains("owner"),
        _ => false,
    };
    
    Ok(Json(CheckResponse { allowed }))
}

async fn get_user_permissions(
    Path(user): Path<String>,
    State(_state): State<Arc<AppState>>,
) -> Json<serde_json::Value> {
    info!("Getting permissions for user: {}", user);
    
    // Mock response
    Json(serde_json::json!({
        "user": user,
        "permissions": [
            {"object": "repository:demo", "relation": "reader"},
            {"object": "organization:acme", "relation": "member"}
        ]
    }))
}
EOF

cat > demo/manifests/demo-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openfga-demo
  namespace: default
  labels:
    app: openfga-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openfga-demo
  template:
    metadata:
      labels:
        app: openfga-demo
    spec:
      containers:
      - name: demo
        image: openfga-demo:latest
        ports:
        - containerPort: 3000
        env:
        - name: OPENFGA_URL
          value: "http://openfga-basic-store:8080"
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: openfga-demo
  namespace: default
spec:
  selector:
    app: openfga-demo
  ports:
  - port: 80
    targetPort: 3000
    name: http
EOF

# Create Dockerfile
echo "🐳 Creating Dockerfile..."
cat > Dockerfile << 'EOF'
# Build stage
FROM rust:1.75-slim as builder

WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src/ ./src/

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -r -s /bin/false openfga-operator

COPY --from=builder /app/target/release/openfga-operator /openfga-operator

USER openfga-operator

ENTRYPOINT ["/openfga-operator"]
EOF

# Create Helm chart
echo "⛵ Creating Helm chart..."
cat > charts/openfga-operator/Chart.yaml << 'EOF'
apiVersion: v2
name: openfga-operator
description: A Helm chart for OpenFGA Operator
type: application
version: 0.1.0
appVersion: "0.1.0"
home: https://github.com/jralmaraz/Openfga-operator
sources:
- https://github.com/jralmaraz/Openfga-operator
maintainers:
- name: OpenFGA Operator Team
  email: team@openfga.dev
keywords:
- openfga
- authorization
- kubernetes
- operator
EOF

mkdir -p charts/openfga-operator/templates
cat > charts/openfga-operator/values.yaml << 'EOF'
# Default values for openfga-operator
replicaCount: 1

image:
  repository: openfga-operator
  pullPolicy: IfNotPresent
  tag: "latest"

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations: {}
  name: ""

podAnnotations: {}

podSecurityContext:
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

nodeSelector: {}

tolerations: []

affinity: {}

# Operator configuration
operator:
  watchNamespace: ""
  logLevel: info
EOF

# Create Makefile
echo "🔨 Creating Makefile..."
cat > Makefile << 'EOF'
.PHONY: help build test lint clean docker-build docker-push deploy undeploy install-crds uninstall-crds

# Default target
help: ## Show this help
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# Build targets
build: ## Build the operator binary
	cargo build --release

test: ## Run tests
	cargo test

lint: ## Run clippy and format check
	cargo clippy -- -D warnings
	cargo fmt --check

clean: ## Clean build artifacts
	cargo clean

# Docker targets
docker-build: ## Build Docker image
	docker build -t openfga-operator:latest .

docker-push: ## Push Docker image
	docker push openfga-operator:latest

# Demo targets
demo-build: ## Build demo microservice
	cd demo/microservice && cargo build --release

demo-docker: ## Build demo Docker image
	cd demo/microservice && docker build -t openfga-demo:latest .

# Kubernetes targets
install-crds: ## Install CRDs
	kubectl apply -f config/crd/

uninstall-crds: ## Uninstall CRDs
	kubectl delete -f config/crd/

deploy: install-crds ## Deploy operator to Kubernetes
	kubectl apply -f config/rbac/
	kubectl apply -f config/manager/

undeploy: ## Remove operator from Kubernetes
	kubectl delete -f config/manager/
	kubectl delete -f config/rbac/

# Development targets
dev-setup: ## Set up development environment
	rustup component add clippy rustfmt
	cargo install cargo-watch

watch: ## Watch for changes and rebuild
	cargo watch -x check -x test -x run

# Example targets
apply-samples: ## Apply sample configurations
	kubectl apply -f config/samples/

delete-samples: ## Delete sample configurations
	kubectl delete -f config/samples/
EOF

echo "✅ Repository structure initialized successfully!"
echo ""
echo "📁 Created directories:"
echo "   - src/ (Rust operator source code)"
echo "   - config/ (Kubernetes manifests and CRDs)"
echo "   - demo/ (Demo microservice)"
echo "   - charts/ (Helm chart)"
echo "   - examples/ (Usage examples)"
echo "   - tests/ (Test suites)"
echo ""
echo "📄 Created files:"
echo "   - Cargo.toml (Rust project configuration)"
echo "   - Dockerfile (Container image build)"
echo "   - Makefile (Build and deployment automation)"
echo "   - .gitignore (Git ignore rules)"
echo ""
echo "🚀 Next steps:"
echo "   1. Review the generated code and configurations"
echo "   2. Customize the operator logic as needed"
echo "   3. Build and test: make build && make test"
echo "   4. Deploy to Kubernetes: make deploy"
echo "   5. Apply sample resources: make apply-samples"