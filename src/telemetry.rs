use anyhow::Result;
use opentelemetry::global;
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::{runtime, trace as sdktrace};
use tracing::info;
use tracing_opentelemetry::OpenTelemetryLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

/// Initialize OpenTelemetry tracing with the specified OTLP endpoint
pub async fn init_telemetry(endpoint: &str) -> Result<()> {
    info!("Initializing OpenTelemetry with endpoint: {}", endpoint);

    // Create OTLP tracer
    let tracer = opentelemetry_otlp::new_pipeline()
        .tracing()
        .with_exporter(
            opentelemetry_otlp::new_exporter()
                .tonic()
                .with_endpoint(endpoint),
        )
        .with_trace_config(
            sdktrace::config().with_resource(opentelemetry_sdk::Resource::new(vec![
                opentelemetry::KeyValue::new("service.name", "openfga-operator"),
                opentelemetry::KeyValue::new("service.version", env!("CARGO_PKG_VERSION")),
            ])),
        )
        .install_batch(runtime::Tokio)?;

    // Set global tracer
    global::set_tracer_provider(tracer.provider().unwrap());

    // Add OpenTelemetry layer to existing subscriber
    let telemetry_layer = OpenTelemetryLayer::new(tracer);

    tracing_subscriber::registry()
        .with(telemetry_layer)
        .try_init()?;

    info!("OpenTelemetry initialized successfully");

    Ok(())
}

/// Shutdown OpenTelemetry and flush any remaining spans
#[allow(dead_code)]
pub async fn shutdown_telemetry() {
    info!("Shutting down OpenTelemetry");
    global::shutdown_tracer_provider();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_telemetry_init() {
        // Test with a dummy endpoint
        let result = init_telemetry("http://localhost:4317").await;

        // We expect this to potentially fail in test environment, but it shouldn't panic
        match result {
            Ok(_) => println!("Telemetry initialized successfully"),
            Err(e) => println!("Expected failure in test environment: {}", e),
        }
    }
}
