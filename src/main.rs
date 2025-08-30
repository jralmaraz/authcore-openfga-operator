mod controller;
mod types;

// Demo modules - included for testing and demonstration
pub mod demos {
    pub mod banking_app {
        include!("../demos/banking-app/banking_demo.rs");
    }
    pub mod genai_rag {
        include!("../demos/genai-rag/genai_rag_demo.rs");
    }
}

use anyhow::Result;
use controller::OpenFGAController;
use kube::Client;
use std::env;
use tracing::{debug, error, info, Level};
use tracing_subscriber::{fmt, layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize structured logging based on environment
    let json_logging = env::var("OPENFGA_LOG_FORMAT").unwrap_or_default() == "json";
    
    let env_filter = EnvFilter::from_default_env()
        .add_directive(Level::INFO.into())
        .add_directive("openfga_operator=debug".parse().unwrap());

    if json_logging {
        // Use JSON structured logging
        tracing_subscriber::registry()
            .with(env_filter)
            .with(fmt::layer().json())
            .init();
    } else {
        // Use standard human-readable logging
        tracing_subscriber::registry()
            .with(env_filter)
            .with(fmt::layer().pretty())
            .init();
    }

    info!(
        operator = "openfga-operator",
        version = env!("CARGO_PKG_VERSION"),
        log_format = if json_logging { "json" } else { "pretty" },
        "Starting OpenFGA Operator"
    );

    // Initialize Kubernetes client with connection logging
    debug!("Attempting to connect to Kubernetes API");
    
    let client = match Client::try_default().await {
        Ok(client) => {
            info!(
                cluster = client.default_namespace(),
                "Successfully connected to Kubernetes API"
            );
            client
        }
        Err(e) => {
            error!(
                error = %e,
                "Failed to connect to Kubernetes API"
            );
            return Err(e.into());
        }
    };

    // Create and run the controller
    debug!("Initializing OpenFGA controller");
    let controller = OpenFGAController::new(client);
    
    info!("Starting OpenFGA controller reconciliation loop");
    if let Err(e) = controller.run().await {
        error!(
            error = %e,
            "OpenFGA controller failed"
        );
        return Err(e);
    }

    Ok(())
}
