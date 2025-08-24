use anyhow::Result;
use futures::StreamExt;
use kube::{
    api::{Api, Patch, PatchParams},
    client::Client,
    runtime::{
        controller::{Action, Controller as KubeController},
        events::{Event, EventType, Recorder, Reporter},
        finalizer::{finalizer, Event as Finalizer},
        watcher::Config,
    },
    ResourceExt,
};
use serde_json::json;
use std::{sync::Arc, time::Duration};
use thiserror::Error;
use tracing::{debug, error, info, warn};

use crate::crd::{OpenFga, OpenFgaStatus};

const OPENFGA_FINALIZER: &str = "openfga.io/finalizer";

#[derive(Debug, Error)]
#[allow(clippy::enum_variant_names)]
pub enum ControllerError {
    #[error("Kubernetes API error: {0}")]
    KubeError(#[from] kube::Error),

    #[error("Serialization error: {0}")]
    SerializationError(#[from] serde_json::Error),

    #[error("OpenFGA instance error: {message}")]
    OpenFgaError { message: String },
}

pub type ControllerResult<T, E = ControllerError> = std::result::Result<T, E>;

pub struct Controller {
    client: Client,
    recorder: Recorder,
}

impl Controller {
    pub fn new(client: Client) -> Self {
        let recorder = Recorder::new(
            client.clone(),
            Reporter {
                controller: "openfga-operator".into(),
                instance: None,
            },
            Default::default(), // Use default ObjectReference
        );

        Self { client, recorder }
    }

    pub async fn run(self) -> Result<()> {
        let api: Api<OpenFga> = Api::all(self.client.clone());
        let controller = Arc::new(self);

        info!("Starting OpenFGA controller");

        KubeController::new(api, Config::default().any_semantic())
            .shutdown_on_signal()
            .run(Controller::reconcile, Controller::error_policy, controller)
            .for_each(|_| futures::future::ready(()))
            .await;

        Ok(())
    }

    async fn reconcile(openfga: Arc<OpenFga>, ctx: Arc<Self>) -> ControllerResult<Action> {
        let ns = openfga.namespace().unwrap();
        let name = openfga.name_any();

        info!(
            "Reconciling OpenFGA instance '{}' in namespace '{}'",
            name, ns
        );

        let api: Api<OpenFga> = Api::namespaced(ctx.client.clone(), &ns);

        // Handle finalizer
        finalizer(&api, OPENFGA_FINALIZER, openfga, |event| async {
            match event {
                Finalizer::Apply(openfga) => ctx.apply_openfga(&openfga).await,
                Finalizer::Cleanup(openfga) => ctx.cleanup_openfga(&openfga).await,
            }
        })
        .await
        .map_err(|e| ControllerError::OpenFgaError {
            message: format!("Finalizer error: {}", e),
        })?;

        Ok(Action::requeue(Duration::from_secs(300)))
    }

    fn error_policy(_openfga: Arc<OpenFga>, error: &ControllerError, _ctx: Arc<Self>) -> Action {
        warn!("Reconcile failed: {:?}", error);
        Action::requeue(Duration::from_secs(60))
    }

    async fn apply_openfga(&self, openfga: &OpenFga) -> ControllerResult<Action> {
        let name = openfga.name_any();
        let ns = openfga.namespace().unwrap();

        info!("Applying OpenFGA instance: {}/{}", ns, name);

        // Update status to "Provisioning"
        self.update_status(
            openfga,
            OpenFgaStatus {
                phase: Some("Provisioning".to_string()),
                message: Some("Creating OpenFGA resources".to_string()),
                ready_replicas: Some(0),
                conditions: None,
            },
        )
        .await?;

        // Record event
        self.recorder
            .publish(Event {
                type_: EventType::Normal,
                reason: "Provisioning".into(),
                note: Some("Starting OpenFGA provisioning".into()),
                action: "Reconciling".into(),
                secondary: None,
            })
            .await
            .map_err(|e| ControllerError::OpenFgaError {
                message: format!("Failed to record event: {}", e),
            })?;

        // TODO: Implement actual resource creation (Deployment, Service, etc.)
        self.create_deployment(openfga).await?;
        self.create_service(openfga).await?;

        // Update status to "Ready"
        self.update_status(
            openfga,
            OpenFgaStatus {
                phase: Some("Ready".to_string()),
                message: Some("OpenFGA instance is ready".to_string()),
                ready_replicas: Some(openfga.spec.server.replicas),
                conditions: None,
            },
        )
        .await?;

        info!("Successfully applied OpenFGA instance: {}/{}", ns, name);

        Ok(Action::requeue(Duration::from_secs(300)))
    }

    async fn cleanup_openfga(&self, openfga: &OpenFga) -> ControllerResult<Action> {
        let name = openfga.name_any();
        let ns = openfga.namespace().unwrap();

        info!("Cleaning up OpenFGA instance: {}/{}", ns, name);

        // TODO: Implement cleanup logic (delete Deployment, Service, etc.)
        self.delete_resources(openfga).await?;

        info!("Successfully cleaned up OpenFGA instance: {}/{}", ns, name);

        Ok(Action::await_change())
    }

    async fn update_status(
        &self,
        openfga: &OpenFga,
        status: OpenFgaStatus,
    ) -> ControllerResult<()> {
        let name = openfga.name_any();
        let ns = openfga.namespace().unwrap();
        let api: Api<OpenFga> = Api::namespaced(self.client.clone(), &ns);

        let patch = json!({
            "status": status
        });

        api.patch_status(&name, &PatchParams::default(), &Patch::Merge(&patch))
            .await?;

        debug!("Updated status for OpenFGA instance: {}/{}", ns, name);

        Ok(())
    }

    async fn create_deployment(&self, _openfga: &OpenFga) -> ControllerResult<()> {
        // TODO: Implement Kubernetes Deployment creation
        info!("Creating Deployment (placeholder)");
        Ok(())
    }

    async fn create_service(&self, _openfga: &OpenFga) -> ControllerResult<()> {
        // TODO: Implement Kubernetes Service creation
        info!("Creating Service (placeholder)");
        Ok(())
    }

    async fn delete_resources(&self, _openfga: &OpenFga) -> ControllerResult<()> {
        // TODO: Implement resource deletion
        info!("Deleting resources (placeholder)");
        Ok(())
    }
}
