use kube::CustomResource;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(CustomResource, Serialize, Deserialize, Debug, Clone, JsonSchema)]
#[kube(
    group = "authorization.openfga.dev",
    version = "v1alpha1",
    kind = "OpenFGA",
    plural = "openfgas",
    shortname = "ofga",
    status = "OpenFGAStatus",
    namespaced
)]
#[serde(rename_all = "camelCase")]
pub struct OpenFGASpec {
    #[serde(default = "default_replicas")]
    pub replicas: i32,

    #[serde(default = "default_image")]
    pub image: String,

    pub datastore: DatastoreConfig,

    #[serde(default)]
    pub playground: PlaygroundConfig,

    #[serde(default)]
    pub grpc: GrpcConfig,

    #[serde(default)]
    pub http: HttpConfig,
}

#[derive(Serialize, Deserialize, Debug, Clone, JsonSchema)]
#[serde(rename_all = "camelCase")]
pub struct DatastoreConfig {
    #[serde(default = "default_engine")]
    pub engine: String,

    pub uri: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone, JsonSchema)]
#[serde(rename_all = "camelCase")]
pub struct PlaygroundConfig {
    #[serde(default)]
    pub enabled: bool,

    #[serde(default = "default_playground_port")]
    pub port: i32,
}

impl Default for PlaygroundConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            port: default_playground_port(),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, JsonSchema)]
#[serde(rename_all = "camelCase")]
pub struct GrpcConfig {
    #[serde(default = "default_grpc_port")]
    pub port: i32,
}

impl Default for GrpcConfig {
    fn default() -> Self {
        Self {
            port: default_grpc_port(),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, JsonSchema)]
#[serde(rename_all = "camelCase")]
pub struct HttpConfig {
    #[serde(default = "default_http_port")]
    pub port: i32,
}

impl Default for HttpConfig {
    fn default() -> Self {
        Self {
            port: default_http_port(),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, JsonSchema)]
#[serde(rename_all = "camelCase")]
pub struct OpenFGACondition {
    #[serde(rename = "type")]
    pub type_: String,
    pub status: String,
    #[serde(rename = "lastTransitionTime")]
    pub last_transition_time: Option<String>,
    pub reason: Option<String>,
    pub message: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone, Default, JsonSchema)]
#[serde(rename_all = "camelCase")]
pub struct OpenFGAStatus {
    pub replicas: Option<i32>,
    pub ready_replicas: Option<i32>,
    pub conditions: Option<Vec<OpenFGACondition>>,
}

// Default value functions
fn default_replicas() -> i32 {
    1
}
fn default_image() -> String {
    "openfga/openfga:latest".to_string()
}
fn default_engine() -> String {
    "memory".to_string()
}
fn default_playground_port() -> i32 {
    3000
}
fn default_grpc_port() -> i32 {
    8081
}
fn default_http_port() -> i32 {
    8080
}

impl Default for DatastoreConfig {
    fn default() -> Self {
        Self {
            engine: default_engine(),
            uri: None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_values() {
        let datastore = DatastoreConfig::default();
        assert_eq!(datastore.engine, "memory");
        assert_eq!(datastore.uri, None);

        let playground = PlaygroundConfig::default();
        assert_eq!(playground.enabled, false);
        assert_eq!(playground.port, 3000);

        let grpc = GrpcConfig::default();
        assert_eq!(grpc.port, 8081);

        let http = HttpConfig::default();
        assert_eq!(http.port, 8080);
    }

    #[test]
    fn test_openfga_spec_serialization() {
        let spec = OpenFGASpec {
            replicas: 2,
            image: "openfga/openfga:v1.0.0".to_string(),
            datastore: DatastoreConfig {
                engine: "postgres".to_string(),
                uri: Some("postgresql://localhost:5432/openfga".to_string()),
            },
            playground: PlaygroundConfig {
                enabled: true,
                port: 3000,
            },
            grpc: GrpcConfig { port: 8081 },
            http: HttpConfig { port: 8080 },
        };

        // Test serialization to JSON
        let json = serde_json::to_string(&spec).unwrap();
        assert!(json.contains("\"replicas\":2"));
        assert!(json.contains("\"image\":\"openfga/openfga:v1.0.0\""));
        assert!(json.contains("\"engine\":\"postgres\""));

        // Test deserialization from JSON
        let _deserialized: OpenFGASpec = serde_json::from_str(&json).unwrap();
    }

    #[test]
    fn test_condition_serialization() {
        let condition = OpenFGACondition {
            type_: "Ready".to_string(),
            status: "True".to_string(),
            last_transition_time: Some("2024-01-01T00:00:00Z".to_string()),
            reason: Some("Deployed".to_string()),
            message: Some("OpenFGA is ready".to_string()),
        };

        let json = serde_json::to_string(&condition).unwrap();
        assert!(json.contains("\"type\":\"Ready\""));
        assert!(json.contains("\"status\":\"True\""));

        let _deserialized: OpenFGACondition = serde_json::from_str(&json).unwrap();
    }

    #[test]
    fn test_status_serialization() {
        let status = OpenFGAStatus {
            replicas: Some(2),
            ready_replicas: Some(2),
            conditions: Some(vec![OpenFGACondition {
                type_: "Ready".to_string(),
                status: "True".to_string(),
                last_transition_time: None,
                reason: None,
                message: None,
            }]),
        };

        let json = serde_json::to_string(&status).unwrap();
        assert!(json.contains("\"replicas\":2"));
        assert!(json.contains("\"readyReplicas\":2"));

        let _deserialized: OpenFGAStatus = serde_json::from_str(&json).unwrap();
    }
}
