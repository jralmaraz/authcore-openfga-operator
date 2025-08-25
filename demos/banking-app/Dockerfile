# Build stage
FROM cgr.dev/chainguard/node:latest AS builder

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
FROM cgr.dev/chainguard/node:latest AS deps

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install only production dependencies
RUN npm ci --omit=dev && npm cache clean --force

# Runtime stage using Chainguard Node.js with dev tools for health checks
FROM cgr.dev/chainguard/node:latest-dev

WORKDIR /app

# Copy built application from builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/models ./models

# Copy production dependencies
COPY --from=deps /app/node_modules ./node_modules

# Copy package.json for metadata
COPY package.json ./

# Switch to non-root user (Chainguard provides nonroot user with uid 65532)
USER 65532:65532

# Expose port
EXPOSE 3000

# Health check using Node.js built-in modules (supported in -dev variant)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { \
    process.exit(res.statusCode === 200 ? 0 : 1) \
  }).on('error', () => process.exit(1))"

# Start the application
ENTRYPOINT ["node", "dist/app.js"]