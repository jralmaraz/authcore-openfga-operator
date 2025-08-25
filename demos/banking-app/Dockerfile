# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install all dependencies (including dev dependencies for build)
RUN npm ci

# Copy source code
COPY src ./src
COPY models ./models

# Build the application
RUN npm run build

# Production dependencies stage
FROM node:18-alpine AS deps

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install only production dependencies
RUN npm ci --omit=dev && npm cache clean --force

# Runtime stage using distroless Node.js
FROM gcr.io/distroless/nodejs18:latest

WORKDIR /app

# Copy built application from builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/models ./models

# Copy production dependencies
COPY --from=deps /app/node_modules ./node_modules

# Copy package.json for metadata
COPY package.json ./

# Switch to non-root user (distroless already provides nonroot user with uid 65532)
USER 65532:65532

# Expose port
EXPOSE 3000

# Note: Health checks removed as distroless images don't have shell or external tools
# The original health check used Node.js built-in modules, but distroless doesn't support inline scripts
# Health monitoring should be implemented at the orchestration level (e.g., Kubernetes probes)

# Start the application
ENTRYPOINT ["node", "dist/app.js"]