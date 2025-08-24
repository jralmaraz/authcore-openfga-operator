mod controller;
mod types;

use anyhow::Result;
use controller::OpenFGAController;
use kube::Client;
use tracing::{info, Level};
use tracing_subscriber::{EnvFilter, FmtSubscriber};

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    let subscriber = FmtSubscriber::builder()
        .with_env_filter(EnvFilter::from_default_env().add_directive(Level::INFO.into()))
        .finish();
    tracing::subscriber::set_global_default(subscriber)?;

    info!("Starting OpenFGA Operator");

    // Initialize Kubernetes client
    let client = Client::try_default().await?;
    info!("Connected to Kubernetes API");

    // Create and run the controller
    let controller = OpenFGAController::new(client);
    controller.run().await?;

    Ok(())
}
