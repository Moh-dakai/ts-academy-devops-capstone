# ──────────────────────────────────────────────────────────────────────────────
# Hardened Dockerfile – result service (Node.js)
# ──────────────────────────────────────────────────────────────────────────────
FROM node:20-slim

# Metadata
LABEL maintainer="DevOps Team" \
      service="result" \
      version="1.0"

ENV NODE_ENV=production

# Install curl for health-check, clean up immediately
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user / group
RUN groupadd --gid 1001 appuser && \
    useradd --uid 1001 --gid 1001 --no-create-home --shell /sbin/nologin appuser

WORKDIR /app

# Copy manifests first for layer-cache efficiency
COPY package.json package-lock.json ./

# Install production dependencies with reproducible install
RUN npm ci --only=production && \
    npm cache clean --force

# Copy the rest of the application (respects .dockerignore)
COPY . .

# Fix ownership
RUN chown -R appuser:appuser /app

# Drop privileges
USER appuser

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:80/ || exit 1

CMD ["node", "server.js"]
