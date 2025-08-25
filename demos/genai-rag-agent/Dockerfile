# Build stage
FROM cgr.dev/chainguard/python:latest

WORKDIR /app

# Install system dependencies needed for building Python packages
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy application code
COPY src ./src
COPY models ./models
COPY setup.py .

# Runtime stage using distroless Python
FROM gcr.io/distroless/python3:latest

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /root/.local /home/nonroot/.local

# Copy application code
COPY --from=builder /app/src ./src
COPY --from=builder /app/models ./models
COPY --from=builder /app/setup.py .

# Set Python path to include user site-packages
ENV PYTHONPATH=/home/nonroot/.local/lib/python3.11/site-packages:$PYTHONPATH
ENV PATH=/home/nonroot/.local/bin:$PATH

# Switch to non-root user (distroless already provides nonroot user with uid 65532)
USER 65532:65532

# Expose port
EXPOSE 8000

# Note: Health checks removed as distroless images don't have shell or external tools
# Health monitoring should be implemented at the orchestration level (e.g., Kubernetes probes)

# Run the application
ENTRYPOINT ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]