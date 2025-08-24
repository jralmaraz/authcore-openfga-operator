use anyhow::Result;
use clap::Parser;
use kube::{Client, CustomResourceExt};
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod controller;
mod crd;
mod telemetry;

use crd::OpenFga;

#[derive(Parser, Debug)]
#[command(name = "openfga-operator")]
#[command(about = "Kubernetes operator for OpenFGA authorization service")]
struct Args {
    /// Enable verbose logging
    #[arg(short, long)]
    verbose: bool,

    /// OpenTelemetry endpoint for traces
    #[arg(long)]
    otel_endpoint: Option<String>,
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    // Initialize tracing
    setup_tracing(&args)?;

    info!("Starting OpenFGA Operator");

    // Print CRD YAML for installation
    if std::env::var("PRINT_CRD").is_ok() {
        println!("{}", serde_yaml::to_string(&OpenFga::crd())?);
        return Ok(());
    }

    // Initialize Kubernetes client
    let client = Client::try_default().await?;
    info!("Connected to Kubernetes cluster");

    // Initialize OpenTelemetry if endpoint provided
    if let Some(endpoint) = args.otel_endpoint {
        telemetry::init_telemetry(&endpoint).await?;
        info!("OpenTelemetry initialized with endpoint: {}", endpoint);
    }

    // Start the controller
    let controller = controller::Controller::new(client);

    info!("Starting OpenFGA controller");
    controller.run().await?;

    Ok(())
}

fn setup_tracing(args: &Args) -> Result<()> {
    let filter = if args.verbose {
        "debug,kube=debug,controller=debug"
    } else {
        "info,kube=info,controller=info"
    };

    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| filter.into()),
        )
        .with(tracing_subscriber::fmt::layer().with_target(false))
        .init();

    Ok(())
}
