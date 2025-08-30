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
use tracing::{debug, error, info, instrument, warn};

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

        info!(
            controller = "openfga-controller",
            "Starting controller with resource monitoring"
        );
        
        debug!(
            resources = "OpenFGA, Deployment, Service",
            "Controller watching resources"
        );

        // Test Kubernetes API connectivity before starting controller
        match self.test_api_connectivity().await {
            Ok(_) => {
                info!(
                    api_connectivity = "verified",
                    "Kubernetes API connectivity test successful"
                );
            }
            Err(e) => {
                error!(
                    api_connectivity = "failed",
                    error = %e,
                    "Kubernetes API connectivity test failed, but continuing with controller startup"
                );
            }
        }

        Controller::new(openfgas, Config::default().any_semantic())
            .owns(deployments, Config::default())
            .owns(services, Config::default())
            .shutdown_on_signal()
            .run(reconcile, error_policy, Arc::new(self))
            .for_each(|res| async move {
                match res {
                    Ok(o) => {
                        info!(
                            reconciliation_result = "success",
                            object = ?o,
                            "Reconciliation completed successfully"
                        );
                    }
                    Err(e) => {
                        error!(
                            reconciliation_result = "error",
                            error = %e,
                            "Reconciliation failed"
                        );
                    }
                }
            })
            .await;

        Ok(())
    }

    async fn test_api_connectivity(&self) -> Result<(), kube::Error> {
        debug!("Testing Kubernetes API connectivity");
        
        // Try to list namespaces as a basic connectivity test
        let namespaces: Api<k8s_openapi::api::core::v1::Namespace> = Api::all(self.client.clone());
        
        match namespaces.list(&Default::default()).await {
            Ok(namespace_list) => {
                info!(
                    namespace_count = namespace_list.items.len(),
                    "Successfully connected to Kubernetes API and listed namespaces"
                );
                Ok(())
            }
            Err(e) => {
                warn!(
                    error = %e,
                    "Failed to list namespaces during connectivity test"
                );
                Err(e)
            }
        }
    }
}

#[instrument(skip(ctx), fields(namespace = %openfga.namespace().unwrap_or_default(), name = %openfga.name_any()))]
async fn reconcile(openfga: Arc<OpenFGA>, ctx: Arc<OpenFGAController>) -> ControllerResult<Action> {
    let client = &ctx.client;
    let ns = openfga.namespace().unwrap_or_default();
    let name = openfga.name_any();

    info!(
        event = "reconciliation_start",
        namespace = %ns,
        resource_name = %name,
        replicas = openfga.spec.replicas,
        image = %openfga.spec.image,
        "Starting OpenFGA reconciliation"
    );

    debug!(
        event = "resource_analysis",
        namespace = %ns,
        resource_name = %name,
        grpc_port = openfga.spec.grpc.port,
        http_port = openfga.spec.http.port,
        playground_enabled = openfga.spec.playground.enabled,
        datastore_engine = %openfga.spec.datastore.engine,
        "Analyzing OpenFGA resource specification"
    );

    // Create or update Deployment
    debug!(
        event = "deployment_reconciliation_start",
        namespace = %ns,
        resource_name = %name,
        "Starting deployment reconciliation"
    );
    
    let deployment = create_deployment(&openfga, &ns, &name)?;
    let deployments: Api<Deployment> = Api::namespaced(client.clone(), &ns);

    match deployments.get(&name).await {
        Ok(existing_deployment) => {
            debug!(
                event = "deployment_exists",
                namespace = %ns,
                resource_name = %name,
                current_replicas = existing_deployment.spec.as_ref().and_then(|s| s.replicas),
                "Existing deployment found, updating"
            );
            
            match deployments
                .patch(
                    &name,
                    &PatchParams::apply("openfga-operator"),
                    &Patch::Apply(&deployment),
                )
                .await 
            {
                Ok(_) => {
                    info!(
                        event = "deployment_updated",
                        namespace = %ns,
                        resource_name = %name,
                        replicas = openfga.spec.replicas,
                        "Successfully updated deployment"
                    );
                }
                Err(e) => {
                    error!(
                        event = "deployment_update_failed",
                        namespace = %ns,
                        resource_name = %name,
                        error = %e,
                        "Failed to update deployment"
                    );
                    return Err(e.into());
                }
            }
        }
        Err(e) => {
            debug!(
                event = "deployment_not_found",
                namespace = %ns,
                resource_name = %name,
                error = %e,
                "Deployment not found, creating new deployment"
            );
            
            match deployments
                .patch(
                    &name,
                    &PatchParams::apply("openfga-operator"),
                    &Patch::Apply(&deployment),
                )
                .await 
            {
                Ok(_) => {
                    info!(
                        event = "deployment_created",
                        namespace = %ns,
                        resource_name = %name,
                        replicas = openfga.spec.replicas,
                        "Successfully created deployment"
                    );
                }
                Err(e) => {
                    error!(
                        event = "deployment_creation_failed",
                        namespace = %ns,
                        resource_name = %name,
                        error = %e,
                        "Failed to create deployment"
                    );
                    return Err(e.into());
                }
            }
        }
    }

    // Create or update Service
    debug!(
        event = "service_reconciliation_start",
        namespace = %ns,
        resource_name = %name,
        "Starting service reconciliation"
    );
    
    let service = create_service(&openfga, &ns, &name)?;
    let services: Api<Service> = Api::namespaced(client.clone(), &ns);

    match services.get(&name).await {
        Ok(existing_service) => {
            debug!(
                event = "service_exists",
                namespace = %ns,
                resource_name = %name,
                current_type = existing_service.spec.as_ref().and_then(|s| s.type_.as_ref()),
                "Existing service found, updating"
            );
            
            match services
                .patch(
                    &name,
                    &PatchParams::apply("openfga-operator"),
                    &Patch::Apply(&service),
                )
                .await 
            {
                Ok(_) => {
                    info!(
                        event = "service_updated",
                        namespace = %ns,
                        resource_name = %name,
                        ports = ?service.spec.as_ref().and_then(|s| s.ports.as_ref().map(|p| p.len())),
                        "Successfully updated service"
                    );
                }
                Err(e) => {
                    error!(
                        event = "service_update_failed",
                        namespace = %ns,
                        resource_name = %name,
                        error = %e,
                        "Failed to update service"
                    );
                    return Err(e.into());
                }
            }
        }
        Err(e) => {
            debug!(
                event = "service_not_found",
                namespace = %ns,
                resource_name = %name,
                error = %e,
                "Service not found, creating new service"
            );
            
            match services
                .patch(
                    &name,
                    &PatchParams::apply("openfga-operator"),
                    &Patch::Apply(&service),
                )
                .await 
            {
                Ok(_) => {
                    info!(
                        event = "service_created",
                        namespace = %ns,
                        resource_name = %name,
                        ports = ?service.spec.as_ref().and_then(|s| s.ports.as_ref().map(|p| p.len())),
                        "Successfully created service"
                    );
                }
                Err(e) => {
                    error!(
                        event = "service_creation_failed",
                        namespace = %ns,
                        resource_name = %name,
                        error = %e,
                        "Failed to create service"
                    );
                    return Err(e.into());
                }
            }
        }
    }

    // Update status
    debug!(
        event = "status_update_start",
        namespace = %ns,
        resource_name = %name,
        "Starting status update"
    );
    
    match update_status(client, &openfga, &ns, &name).await {
        Ok(_) => {
            debug!(
                event = "status_updated",
                namespace = %ns,
                resource_name = %name,
                "Successfully updated resource status"
            );
        }
        Err(e) => {
            warn!(
                event = "status_update_failed",
                namespace = %ns,
                resource_name = %name,
                error = %e,
                "Failed to update resource status, but continuing reconciliation"
            );
            // Don't fail reconciliation for status update errors
        }
    }

    let requeue_duration = Duration::from_secs(60);
    info!(
        event = "reconciliation_complete",
        namespace = %ns,
        resource_name = %name,
        requeue_after_seconds = requeue_duration.as_secs(),
        "OpenFGA reconciliation completed successfully"
    );

    Ok(Action::requeue(requeue_duration))
}

#[instrument(skip(openfga), fields(namespace = %ns, name = %name))]
fn create_deployment(openfga: &OpenFGA, ns: &str, name: &str) -> ControllerResult<Deployment> {
    debug!(
        event = "deployment_creation_start",
        namespace = %ns,
        name = %name,
        image = %openfga.spec.image,
        replicas = openfga.spec.replicas,
        "Creating deployment specification"
    );
    
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
        debug!(
            event = "playground_port_added",
            namespace = %ns,
            name = %name,
            playground_port = openfga.spec.playground.port,
            "Adding playground port to deployment"
        );
        
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

    debug!(
        event = "deployment_spec_created",
        namespace = %ns,
        name = %name,
        container_ports = deployment.spec.as_ref()
            .and_then(|s| s.template.spec.as_ref())
            .and_then(|s| s.containers.first())
            .and_then(|c| c.ports.as_ref().map(|p| p.len())),
        "Deployment specification created successfully"
    );

    Ok(deployment)
}

#[instrument(skip(openfga), fields(namespace = %ns, name = %name))]
fn create_service(openfga: &OpenFGA, ns: &str, name: &str) -> ControllerResult<Service> {
    debug!(
        event = "service_creation_start",
        namespace = %ns,
        name = %name,
        grpc_port = openfga.spec.grpc.port,
        http_port = openfga.spec.http.port,
        playground_enabled = openfga.spec.playground.enabled,
        "Creating service specification"
    );
    
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
        debug!(
            event = "playground_service_port_added",
            namespace = %ns,
            name = %name,
            playground_port = openfga.spec.playground.port,
            "Adding playground port to service"
        );
        
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

    debug!(
        event = "service_spec_created",
        namespace = %ns,
        name = %name,
        port_count = service.spec.as_ref().and_then(|s| s.ports.as_ref().map(|p| p.len())),
        service_type = service.spec.as_ref().and_then(|s| s.type_.as_ref()),
        "Service specification created successfully"
    );

    Ok(service)
}

#[instrument(skip(client, _openfga), fields(namespace = %ns, name = %name))]
async fn update_status(
    client: &Client,
    _openfga: &OpenFGA,
    ns: &str,
    name: &str,
) -> ControllerResult<()> {
    debug!(
        event = "status_update_start",
        namespace = %ns,
        name = %name,
        "Starting status update process"
    );
    
    let deployments: Api<Deployment> = Api::namespaced(client.clone(), ns);

    match deployments.get(name).await {
        Ok(deployment) => {
            let current_replicas = deployment.status.as_ref().and_then(|s| s.replicas);
            let ready_replicas = deployment.status.as_ref().and_then(|s| s.ready_replicas);
            
            debug!(
                event = "deployment_status_retrieved",
                namespace = %ns,
                name = %name,
                current_replicas = current_replicas,
                ready_replicas = ready_replicas,
                "Retrieved deployment status"
            );
            
            let status = OpenFGAStatus {
                replicas: current_replicas,
                ready_replicas,
                conditions: None,
            };

            let openfgas: Api<OpenFGA> = Api::namespaced(client.clone(), ns);
            let status_patch = serde_json::json!({
                "status": status
            });

            match openfgas
                .patch_status(name, &PatchParams::default(), &Patch::Merge(&status_patch))
                .await 
            {
                Ok(_) => {
                    debug!(
                        event = "status_patch_applied",
                        namespace = %ns,
                        name = %name,
                        replicas = current_replicas,
                        ready_replicas = ready_replicas,
                        "Status patch applied successfully"
                    );
                }
                Err(e) => {
                    error!(
                        event = "status_patch_failed",
                        namespace = %ns,
                        name = %name,
                        error = %e,
                        "Failed to apply status patch"
                    );
                    return Err(e.into());
                }
            }
        }
        Err(e) => {
            warn!(
                event = "deployment_not_found_for_status",
                namespace = %ns,
                name = %name,
                error = %e,
                "Deployment not found when updating status, this may be expected during resource creation"
            );
        }
    }

    Ok(())
}

#[instrument(skip(_ctx))]
fn error_policy(
    openfga: Arc<OpenFGA>,
    error: &ControllerError,
    _ctx: Arc<OpenFGAController>,
) -> Action {
    let ns = openfga.namespace().unwrap_or_default();
    let name = openfga.name_any();
    
    let requeue_duration = match error {
        ControllerError::Kube(kube_error) => {
            // More intelligent error handling based on kube-rs patterns
            if kube_error.to_string().contains("NotFound") {
                info!(
                    namespace = %ns,
                    resource_name = %name,
                    error_type = "NotFound",
                    "Resource not found, fast retry for creation"
                );
                Duration::from_secs(5)
            } else if kube_error.to_string().contains("Conflict") {
                info!(
                    namespace = %ns,
                    resource_name = %name,
                    error_type = "Conflict",
                    "Resource conflict, immediate retry"
                );
                Duration::from_secs(1)
            } else if kube_error.to_string().contains("Forbidden") || kube_error.to_string().contains("Unauthorized") {
                warn!(
                    namespace = %ns,
                    resource_name = %name,
                    error_type = "Permission",
                    "Permission error, longer retry interval"
                );
                Duration::from_secs(300) // 5 minutes for permission issues
            } else if kube_error.to_string().contains("TooManyRequests") || kube_error.to_string().contains("throttled") {
                warn!(
                    namespace = %ns,
                    resource_name = %name,
                    error_type = "RateLimit",
                    "Rate limited, backing off"
                );
                Duration::from_secs(60) // 1 minute for rate limiting
            } else if kube_error.to_string().contains("timeout") || kube_error.to_string().contains("connection") {
                warn!(
                    namespace = %ns,
                    resource_name = %name,
                    error_type = "Network",
                    "Network issue, standard retry"
                );
                Duration::from_secs(30)
            } else {
                warn!(
                    namespace = %ns,
                    resource_name = %name,
                    error_type = "Unknown",
                    error_message = %kube_error,
                    "Unknown Kubernetes error, standard retry"
                );
                Duration::from_secs(30)
            }
        }
        ControllerError::Serialization(_) => {
            error!(
                namespace = %ns,
                resource_name = %name,
                error_type = "Serialization",
                "Serialization error, longer retry interval"
            );
            Duration::from_secs(120)
        }
    };
    
    error!(
        event = "reconciliation_error",
        namespace = %ns,
        resource_name = %name,
        error_type = ?std::mem::discriminant(error),
        error_message = %error,
        requeue_after_seconds = requeue_duration.as_secs(),
        "Reconciliation failed, scheduling retry with intelligent backoff"
    );
    
    Action::requeue(requeue_duration)
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
