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
use chrono;
use controller::OpenFGAController;
use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Request, Response, Server, StatusCode};
use kube::Client;
use std::convert::Infallible;
use std::env;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use tokio::signal;
use tokio::sync::RwLock;
use tokio::time::{interval, sleep};
use tracing::{debug, error, info, warn, Level};
use tracing_subscriber::{fmt, layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

// Health status shared between health endpoint and main logic
#[derive(Debug, Clone)]
struct HealthStatus {
    status: String,
    kubernetes_connected: bool,
    controller_running: bool,
    uptime_seconds: u64,
}

impl Default for HealthStatus {
    fn default() -> Self {
        Self {
            status: "initializing".to_string(),
            kubernetes_connected: false,
            controller_running: false,
            uptime_seconds: 0,
        }
    }
}

type SharedHealthStatus = Arc<RwLock<HealthStatus>>;

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

    // Initialize shared health status
    let health_status = Arc::new(RwLock::new(HealthStatus::default()));

    // Start health endpoint
    let health_task = start_health_endpoint(health_status.clone());

    // Set up graceful shutdown signal handling
    let _shutdown_signal = setup_signal_handler();

    // Initialize operator with retry logic
    let operator_result = initialize_operator_with_retry(health_status.clone()).await;

    // Clean shutdown
    health_task.abort();

    match operator_result {
        Ok(()) => {
            info!("OpenFGA Operator shutdown completed successfully");
        }
        Err(e) => {
            error!(
                error = %e,
                "OpenFGA Operator encountered a fatal error"
            );
            return Err(e);
        }
    }

    Ok(())
}

fn start_health_endpoint(health_status: SharedHealthStatus) -> tokio::task::JoinHandle<()> {
    tokio::spawn(async move {
        let addr = SocketAddr::from(([0, 0, 0, 0], 8080));

        let make_svc = make_service_fn(move |_conn| {
            let health_status = health_status.clone();
            async move {
                Ok::<_, Infallible>(service_fn(move |req| {
                    handle_health_request(req, health_status.clone())
                }))
            }
        });

        let server = Server::bind(&addr).serve(make_svc);

        info!(
            endpoint = "health",
            address = %addr,
            "Health check endpoint started"
        );

        if let Err(e) = server.await {
            error!(
                error = %e,
                "Health server error"
            );
        }
    })
}

async fn handle_health_request(
    req: Request<Body>,
    health_status: SharedHealthStatus,
) -> Result<Response<Body>, Infallible> {
    match req.uri().path() {
        "/health" | "/healthz" => {
            let status = health_status.read().await;
            let health_response = serde_json::json!({
                "status": status.status,
                "kubernetes_connected": status.kubernetes_connected,
                "controller_running": status.controller_running,
                "uptime_seconds": status.uptime_seconds,
                "version": env!("CARGO_PKG_VERSION"),
                "timestamp": chrono::Utc::now().to_rfc3339()
            });

            let is_healthy = status.kubernetes_connected && status.controller_running;
            let status_code = if is_healthy {
                StatusCode::OK
            } else {
                StatusCode::SERVICE_UNAVAILABLE
            };

            Ok(Response::builder()
                .status(status_code)
                .header("content-type", "application/json")
                .body(Body::from(health_response.to_string()))
                .unwrap())
        }
        "/ready" | "/readiness" => {
            let status = health_status.read().await;
            let is_ready = status.kubernetes_connected;
            let status_code = if is_ready {
                StatusCode::OK
            } else {
                StatusCode::SERVICE_UNAVAILABLE
            };

            Ok(Response::builder()
                .status(status_code)
                .header("content-type", "text/plain")
                .body(Body::from(if is_ready { "ready" } else { "not ready" }))
                .unwrap())
        }
        "/live" | "/liveness" => Ok(Response::builder()
            .status(StatusCode::OK)
            .header("content-type", "text/plain")
            .body(Body::from("alive"))
            .unwrap()),
        _ => Ok(Response::builder()
            .status(StatusCode::NOT_FOUND)
            .body(Body::from("Not Found"))
            .unwrap()),
    }
}

async fn setup_signal_handler() -> tokio::sync::broadcast::Receiver<()> {
    let (shutdown_tx, shutdown_rx) = tokio::sync::broadcast::channel(1);

    tokio::spawn(async move {
        let mut sigterm = signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("Failed to install SIGTERM handler");
        let mut sigint = signal::unix::signal(signal::unix::SignalKind::interrupt())
            .expect("Failed to install SIGINT handler");

        tokio::select! {
            _ = sigterm.recv() => {
                info!(signal = "SIGTERM", "Received shutdown signal");
            }
            _ = sigint.recv() => {
                info!(signal = "SIGINT", "Received shutdown signal");
            }
        }

        let _ = shutdown_tx.send(());
    });

    shutdown_rx
}

async fn initialize_operator_with_retry(health_status: SharedHealthStatus) -> Result<()> {
    let max_retry_attempts = 10;
    let base_delay = Duration::from_secs(5);
    let max_delay = Duration::from_secs(300); // 5 minutes max
    let start_time = std::time::Instant::now();

    // Start health reporting
    let mut health_interval = interval(Duration::from_secs(30));
    let mut retry_count = 0;

    info!(
        max_attempts = max_retry_attempts,
        base_delay_seconds = base_delay.as_secs(),
        max_delay_seconds = max_delay.as_secs(),
        "Starting operator initialization with retry logic"
    );

    loop {
        // Update uptime in health status
        {
            let mut status = health_status.write().await;
            status.uptime_seconds = start_time.elapsed().as_secs();
        }

        // Report health status
        tokio::select! {
            _ = health_interval.tick() => {
                let status = health_status.read().await;
                info!(
                    operator_status = %status.status,
                    retry_attempt = retry_count,
                    max_attempts = max_retry_attempts,
                    uptime_seconds = status.uptime_seconds,
                    "OpenFGA Operator health check - attempting Kubernetes connection"
                );
            }
            result = attempt_kubernetes_connection() => {
                match result {
                    Ok(client) => {
                        info!(
                            cluster = client.default_namespace(),
                            retry_attempt = retry_count,
                            "Successfully connected to Kubernetes API, starting controller"
                        );

                        // Update health status
                        {
                            let mut status = health_status.write().await;
                            status.status = "running".to_string();
                            status.kubernetes_connected = true;
                        }

                        // Start the main controller loop
                        return run_controller_with_health_monitoring(client, health_status).await;
                    }
                    Err(e) => {
                        retry_count += 1;

                        // Update health status
                        {
                            let mut status = health_status.write().await;
                            status.status = format!("retrying (attempt {})", retry_count);
                            status.kubernetes_connected = false;
                        }

                        if retry_count >= max_retry_attempts {
                            error!(
                                error = %e,
                                retry_attempt = retry_count,
                                max_attempts = max_retry_attempts,
                                "Exhausted all retry attempts to connect to Kubernetes API"
                            );

                            // Update health status to failed
                            {
                                let mut status = health_status.write().await;
                                status.status = "failed".to_string();
                            }

                            return Err(e.into());
                        }

                        // Calculate exponential backoff delay
                        let delay = std::cmp::min(
                            base_delay * 2_u32.pow((retry_count - 1) as u32),
                            max_delay
                        );

                        warn!(
                            error = %e,
                            retry_attempt = retry_count,
                            max_attempts = max_retry_attempts,
                            retry_delay_seconds = delay.as_secs(),
                            "Failed to connect to Kubernetes API, retrying with exponential backoff"
                        );

                        sleep(delay).await;
                    }
                }
            }
        }
    }
}

async fn attempt_kubernetes_connection() -> Result<Client, kube::Error> {
    debug!("Attempting to connect to Kubernetes API");
    Client::try_default().await
}

async fn run_controller_with_health_monitoring(
    client: Client,
    health_status: SharedHealthStatus,
) -> Result<()> {
    // Create controller
    debug!("Initializing OpenFGA controller");
    let controller = OpenFGAController::new(client);

    // Update health status
    {
        let mut status = health_status.write().await;
        status.controller_running = true;
    }

    // Start health monitoring
    let health_task = {
        let health_status = health_status.clone();
        tokio::spawn(async move {
            let mut health_interval = interval(Duration::from_secs(60));
            let start_time = std::time::Instant::now();

            loop {
                health_interval.tick().await;

                let mut status = health_status.write().await;
                status.uptime_seconds = start_time.elapsed().as_secs();

                info!(
                    operator_status = %status.status,
                    controller_status = "active",
                    uptime_seconds = status.uptime_seconds,
                    "OpenFGA Operator health check - controller running normally"
                );
            }
        })
    };

    info!("Starting OpenFGA controller reconciliation loop");

    // Run controller with proper error handling
    tokio::select! {
        result = controller.run() => {
            health_task.abort();

            // Update health status
            {
                let mut status = health_status.write().await;
                status.controller_running = false;
            }

            match result {
                Ok(_) => {
                    info!("OpenFGA controller completed successfully");
                    Ok(())
                }
                Err(e) => {
                    error!(
                        error = %e,
                        "OpenFGA controller failed"
                    );

                    // Update health status to failed
                    {
                        let mut status = health_status.write().await;
                        status.status = "controller_failed".to_string();
                    }

                    Err(e)
                }
            }
        }
        _ = signal::ctrl_c() => {
            info!("Received interrupt signal, shutting down gracefully");
            health_task.abort();

            // Update health status
            {
                let mut status = health_status.write().await;
                status.status = "shutting_down".to_string();
                status.controller_running = false;
            }

            Ok(())
        }
    }
}
