use kube::CustomResource;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// OpenFGA Custom Resource Definition
#[derive(CustomResource, Debug, Serialize, Deserialize, Clone, JsonSchema)]
#[kube(
    group = "openfga.io",
    version = "v1alpha1",
    kind = "OpenFga",
    plural = "openfgas",
    namespaced
)]
#[kube(status = "OpenFgaStatus")]
#[kube(printcolumn = r#"{"name":"Ready", "type":"string", "jsonPath":".status.phase"}"#)]
#[kube(printcolumn = r#"{"name":"Age", "type":"date", "jsonPath":".metadata.creationTimestamp"}"#)]
pub struct OpenFgaSpec {
    /// OpenFGA server configuration
    pub server: OpenFgaServerSpec,

    /// Storage configuration
    pub storage: StorageSpec,

    /// Optional observability configuration
    #[serde(skip_serializing_if = "Option::is_none")]
    pub observability: Option<ObservabilitySpec>,

    /// Resource requirements
    #[serde(skip_serializing_if = "Option::is_none")]
    pub resources: Option<ResourceSpec>,
}

#[derive(Debug, Serialize, Deserialize, Clone, JsonSchema)]
pub struct OpenFgaServerSpec {
    /// OpenFGA server image
    pub image: String,

    /// Image pull policy
    #[serde(default = "default_image_pull_policy")]
    pub image_pull_policy: String,

    /// Number of replicas
    #[serde(default = "default_replicas")]
    pub replicas: i32,

    /// Server configuration
    #[serde(skip_serializing_if = "Option::is_none")]
    pub config: Option<BTreeMap<String, String>>,
}

#[derive(Debug, Serialize, Deserialize, Clone, JsonSchema)]
pub struct StorageSpec {
    /// Storage type (postgres, mysql, memory)
    pub r#type: String,

    /// Connection string or configuration
    #[serde(skip_serializing_if = "Option::is_none")]
    pub connection: Option<String>,

    /// Storage-specific configuration
    #[serde(skip_serializing_if = "Option::is_none")]
    pub config: Option<BTreeMap<String, String>>,
}

#[derive(Debug, Serialize, Deserialize, Clone, JsonSchema)]
pub struct ObservabilitySpec {
    /// Enable metrics
    #[serde(default)]
    pub metrics: bool,

    /// Enable tracing
    #[serde(default)]
    pub tracing: bool,

    /// OpenTelemetry configuration
    #[serde(skip_serializing_if = "Option::is_none")]
    pub opentelemetry: Option<OpenTelemetrySpec>,
}

#[derive(Debug, Serialize, Deserialize, Clone, JsonSchema)]
pub struct OpenTelemetrySpec {
    /// OTLP endpoint
    pub endpoint: String,

    /// Additional headers
    #[serde(skip_serializing_if = "Option::is_none")]
    pub headers: Option<BTreeMap<String, String>>,
}

#[derive(Debug, Serialize, Deserialize, Clone, JsonSchema)]
pub struct ResourceSpec {
    /// CPU request
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_request: Option<String>,

    /// Memory request
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_request: Option<String>,

    /// CPU limit
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cpu_limit: Option<String>,

    /// Memory limit
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_limit: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone, JsonSchema)]
pub struct OpenFgaStatus {
    /// Current phase of the OpenFGA instance
    #[serde(skip_serializing_if = "Option::is_none")]
    pub phase: Option<String>,

    /// Human-readable message about the current status
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,

    /// Ready replicas count
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ready_replicas: Option<i32>,

    /// Conditions array
    #[serde(skip_serializing_if = "Option::is_none")]
    pub conditions: Option<Vec<OpenFgaCondition>>,
}

#[derive(Debug, Serialize, Deserialize, Clone, JsonSchema)]
pub struct OpenFgaCondition {
    /// Type of condition
    pub r#type: String,

    /// Status of the condition
    pub status: String,

    /// Last transition time
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_transition_time: Option<String>,

    /// Reason for the condition
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,

    /// Human-readable message
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

fn default_image_pull_policy() -> String {
    "IfNotPresent".to_string()
}

fn default_replicas() -> i32 {
    1
}
