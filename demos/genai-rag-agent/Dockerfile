# Build stage
FROM cgr.dev/chainguard/python:latest AS builder

WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy application code
COPY src ./src
COPY models ./models
COPY setup.py .

# Runtime stage using Chainguard Python with dev tools for health checks
FROM cgr.dev/chainguard/python:latest-dev

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /home/nonroot/.local /home/nonroot/.local

# Copy application code
COPY --from=builder /app/src ./src
COPY --from=builder /app/models ./models
COPY --from=builder /app/setup.py .

# Set Python path to include user site-packages
ENV PYTHONPATH=/home/nonroot/.local/lib/python3.12/site-packages:$PYTHONPATH
ENV PATH=/home/nonroot/.local/bin:$PATH

# Switch to non-root user (Chainguard provides nonroot user with uid 65532)
USER 65532:65532

# Expose port
EXPOSE 8000

# Health check using curl (available in -dev variant)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Run the application
ENTRYPOINT ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]