use crate::types::{OpenFGA, OpenFGAStatus};
use anyhow::Result;
use futures::StreamExt;
use k8s_openapi::api::apps::v1::{Deployment, DeploymentSpec};
use k8s_openapi::api::core::v1::{
    Container, ContainerPort, PodSpec, PodTemplateSpec, Service, ServicePort, ServiceSpec,
};
use k8s_openapi::apimachinery::pkg::apis::meta::v1::{LabelSelector, ObjectMeta};
use k8s_openapi::apimachinery::pkg::util::intstr::IntOrString;
use kube::api::{Api, Patch, PatchParams};
use kube::runtime::controller::{Action, Controller};
use kube::runtime::watcher::Config;
use kube::{Client, ResourceExt};
use std::collections::BTreeMap;
use std::sync::Arc;
use thiserror::Error;
use tokio::time::Duration;
use tracing::{error, info, warn};

#[derive(Error, Debug)]
pub enum ControllerError {
    #[error("Kubernetes API error: {0}")]
    Kube(#[from] kube::Error),
    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
}

pub type ControllerResult<T> = std::result::Result<T, ControllerError>;

pub struct OpenFGAController {
    client: Client,
}

impl OpenFGAController {
    pub fn new(client: Client) -> Self {
        Self { client }
    }

    pub async fn run(self) -> Result<()> {
        let client = self.client.clone();
        let openfgas: Api<OpenFGA> = Api::all(client.clone());
        let deployments: Api<Deployment> = Api::all(client.clone());
        let services: Api<Service> = Api::all(client.clone());

        Controller::new(openfgas, Config::default().any_semantic())
            .owns(deployments, Config::default())
            .owns(services, Config::default())
            .shutdown_on_signal()
            .run(reconcile, error_policy, Arc::new(self))
            .for_each(|res| async move {
                match res {
                    Ok(o) => info!("Reconciled {:?}", o),
                    Err(e) => warn!("Reconcile failed: {:?}", e),
                }
            })
            .await;

        Ok(())
    }
}

async fn reconcile(openfga: Arc<OpenFGA>, ctx: Arc<OpenFGAController>) -> ControllerResult<Action> {
    let client = &ctx.client;
    let ns = openfga.namespace().unwrap_or_default();
    let name = openfga.name_any();

    info!("Reconciling OpenFGA: {} in namespace: {}", name, ns);

    // Create or update Deployment
    let deployment = create_deployment(&openfga, &ns, &name)?;
    let deployments: Api<Deployment> = Api::namespaced(client.clone(), &ns);

    match deployments.get(&name).await {
        Ok(_) => {
            deployments
                .patch(
                    &name,
                    &PatchParams::apply("openfga-operator"),
                    &Patch::Apply(&deployment),
                )
                .await?;
            info!("Updated deployment: {}", name);
        }
        Err(_) => {
            deployments
                .patch(
                    &name,
                    &PatchParams::apply("openfga-operator"),
                    &Patch::Apply(&deployment),
                )
                .await?;
            info!("Created deployment: {}", name);
        }
    }

    // Create or update Service
    let service = create_service(&openfga, &ns, &name)?;
    let services: Api<Service> = Api::namespaced(client.clone(), &ns);

    match services.get(&name).await {
        Ok(_) => {
            services
                .patch(
                    &name,
                    &PatchParams::apply("openfga-operator"),
                    &Patch::Apply(&service),
                )
                .await?;
            info!("Updated service: {}", name);
        }
        Err(_) => {
            services
                .patch(
                    &name,
                    &PatchParams::apply("openfga-operator"),
                    &Patch::Apply(&service),
                )
                .await?;
            info!("Created service: {}", name);
        }
    }

    // Update status
    update_status(client, &openfga, &ns, &name).await?;

    Ok(Action::requeue(Duration::from_secs(60)))
}

fn create_deployment(openfga: &OpenFGA, ns: &str, name: &str) -> ControllerResult<Deployment> {
    let labels = BTreeMap::from([
        ("app".to_string(), "openfga".to_string()),
        ("instance".to_string(), name.to_string()),
    ]);

    let mut container_ports = vec![
        ContainerPort {
            container_port: openfga.spec.grpc.port,
            name: Some("grpc".to_string()),
            protocol: Some("TCP".to_string()),
            ..Default::default()
        },
        ContainerPort {
            container_port: openfga.spec.http.port,
            name: Some("http".to_string()),
            protocol: Some("TCP".to_string()),
            ..Default::default()
        },
    ];

    if openfga.spec.playground.enabled {
        container_ports.push(ContainerPort {
            container_port: openfga.spec.playground.port,
            name: Some("playground".to_string()),
            protocol: Some("TCP".to_string()),
            ..Default::default()
        });
    }

    let container = Container {
        name: "openfga".to_string(),
        image: Some(openfga.spec.image.clone()),
        ports: Some(container_ports),
        env: Some(vec![]),
        ..Default::default()
    };

    let deployment = Deployment {
        metadata: ObjectMeta {
            name: Some(name.to_string()),
            namespace: Some(ns.to_string()),
            labels: Some(labels.clone()),
            ..Default::default()
        },
        spec: Some(DeploymentSpec {
            replicas: Some(openfga.spec.replicas),
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
                    containers: vec![container],
                    ..Default::default()
                }),
            },
            ..Default::default()
        }),
        ..Default::default()
    };

    Ok(deployment)
}

fn create_service(openfga: &OpenFGA, ns: &str, name: &str) -> ControllerResult<Service> {
    let labels = BTreeMap::from([
        ("app".to_string(), "openfga".to_string()),
        ("instance".to_string(), name.to_string()),
    ]);

    let mut service_ports = vec![
        ServicePort {
            port: openfga.spec.grpc.port,
            target_port: Some(IntOrString::Int(openfga.spec.grpc.port)),
            name: Some("grpc".to_string()),
            protocol: Some("TCP".to_string()),
            ..Default::default()
        },
        ServicePort {
            port: openfga.spec.http.port,
            target_port: Some(IntOrString::Int(openfga.spec.http.port)),
            name: Some("http".to_string()),
            protocol: Some("TCP".to_string()),
            ..Default::default()
        },
    ];

    if openfga.spec.playground.enabled {
        service_ports.push(ServicePort {
            port: openfga.spec.playground.port,
            target_port: Some(IntOrString::Int(openfga.spec.playground.port)),
            name: Some("playground".to_string()),
            protocol: Some("TCP".to_string()),
            ..Default::default()
        });
    }

    let service = Service {
        metadata: ObjectMeta {
            name: Some(name.to_string()),
            namespace: Some(ns.to_string()),
            labels: Some(labels.clone()),
            ..Default::default()
        },
        spec: Some(ServiceSpec {
            selector: Some(labels),
            ports: Some(service_ports),
            type_: Some("ClusterIP".to_string()),
            ..Default::default()
        }),
        ..Default::default()
    };

    Ok(service)
}

async fn update_status(
    client: &Client,
    _openfga: &OpenFGA,
    ns: &str,
    name: &str,
) -> ControllerResult<()> {
    let deployments: Api<Deployment> = Api::namespaced(client.clone(), ns);

    if let Ok(deployment) = deployments.get(name).await {
        let status = OpenFGAStatus {
            replicas: deployment.status.as_ref().and_then(|s| s.replicas),
            ready_replicas: deployment.status.as_ref().and_then(|s| s.ready_replicas),
            conditions: None,
        };

        let openfgas: Api<OpenFGA> = Api::namespaced(client.clone(), ns);
        let status_patch = serde_json::json!({
            "status": status
        });

        openfgas
            .patch_status(name, &PatchParams::default(), &Patch::Merge(&status_patch))
            .await?;
    }

    Ok(())
}

fn error_policy(
    _openfga: Arc<OpenFGA>,
    error: &ControllerError,
    _ctx: Arc<OpenFGAController>,
) -> Action {
    error!("Error reconciling OpenFGA: {:?}", error);
    Action::requeue(Duration::from_secs(60))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{DatastoreConfig, GrpcConfig, HttpConfig, PlaygroundConfig};

    #[test]
    fn test_create_deployment() {
        let openfga = create_test_openfga();
        let deployment = create_deployment(&openfga, "test-ns", "test-openfga").unwrap();

        assert_eq!(deployment.metadata.name, Some("test-openfga".to_string()));
        assert_eq!(deployment.metadata.namespace, Some("test-ns".to_string()));

        let spec = deployment.spec.unwrap();
        assert_eq!(spec.replicas, Some(2));

        let container = &spec.template.spec.unwrap().containers[0];
        assert_eq!(container.name, "openfga");
        assert_eq!(container.image, Some("openfga/openfga:v1.0.0".to_string()));

        let ports = container.ports.as_ref().unwrap();
        assert_eq!(ports.len(), 2); // grpc and http
    }

    #[test]
    fn test_create_service() {
        let openfga = create_test_openfga();
        let service = create_service(&openfga, "test-ns", "test-openfga").unwrap();

        assert_eq!(service.metadata.name, Some("test-openfga".to_string()));
        assert_eq!(service.metadata.namespace, Some("test-ns".to_string()));

        let spec = service.spec.unwrap();
        let ports = spec.ports.unwrap();
        assert_eq!(ports.len(), 2); // grpc and http

        // Check that grpc port is present
        assert!(ports
            .iter()
            .any(|p| p.name == Some("grpc".to_string()) && p.port == 8081));
        // Check that http port is present
        assert!(ports
            .iter()
            .any(|p| p.name == Some("http".to_string()) && p.port == 8080));
    }

    #[test]
    fn test_create_service_with_playground() {
        let mut openfga = create_test_openfga();
        openfga.spec.playground.enabled = true;

        let service = create_service(&openfga, "test-ns", "test-openfga").unwrap();
        let spec = service.spec.unwrap();
        let ports = spec.ports.unwrap();

        assert_eq!(ports.len(), 3); // grpc, http, and playground
        assert!(ports
            .iter()
            .any(|p| p.name == Some("playground".to_string()) && p.port == 3000));
    }

    fn create_test_openfga() -> OpenFGA {
        use k8s_openapi::apimachinery::pkg::apis::meta::v1::ObjectMeta;

        OpenFGA {
            metadata: ObjectMeta {
                name: Some("test-openfga".to_string()),
                namespace: Some("test-ns".to_string()),
                ..Default::default()
            },
            spec: crate::types::OpenFGASpec {
                replicas: 2,
                image: "openfga/openfga:v1.0.0".to_string(),
                datastore: DatastoreConfig {
                    engine: "memory".to_string(),
                    uri: None,
                },
                playground: PlaygroundConfig {
                    enabled: false,
                    port: 3000,
                },
                grpc: GrpcConfig { port: 8081 },
                http: HttpConfig { port: 8080 },
            },
            status: None,
        }
    }
}
