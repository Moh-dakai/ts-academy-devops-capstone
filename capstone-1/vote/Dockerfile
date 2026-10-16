# ──────────────────────────────────────────────────────────────────────────────
# Hardened Dockerfile – vote service (Python Flask)
# ──────────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim-bookworm

# Metadata
LABEL maintainer="DevOps Team" \
      service="vote" \
      version="1.0"

# Prevent Python from writing .pyc files and buffering stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install only the OS packages strictly required, then clean up in one layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user / group
RUN groupadd --gid 1001 appuser && \
    useradd --uid 1001 --gid 1001 --no-create-home --shell /sbin/nologin appuser

WORKDIR /app

# Copy dependency manifest first (layer-cache friendly)
COPY requirements.txt .

# Install production dependencies only
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source (respects .dockerignore)
COPY . .

# Fix ownership so the non-root user can read the files
RUN chown -R appuser:appuser /app

# Drop privileges
USER appuser

EXPOSE 80

# Health check – adjust path/port if the Flask app differs
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:80/ || exit 1

CMD ["python", "app.py"]
