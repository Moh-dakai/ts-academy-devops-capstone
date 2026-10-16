# ──────────────────────────────────────────────────────────────────────────────
# Hardened multi-stage Dockerfile – worker service (.NET 7)
# ──────────────────────────────────────────────────────────────────────────────

# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build

WORKDIR /src

# Copy project file(s) and restore dependencies first (cache-friendly)
COPY *.csproj ./
RUN dotnet restore --locked-mode

# Copy the rest of the source and publish in Release mode
COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/runtime:7.0 AS runtime

# Metadata
LABEL maintainer="DevOps Team" \
      service="worker" \
      version="1.0"

# Create non-root user / group
RUN groupadd --gid 1001 appuser && \
    useradd --uid 1001 --gid 1001 --no-create-home --shell /sbin/nologin appuser

WORKDIR /app

# Copy only the published output from the build stage
COPY --from=build /app/publish .

# Fix ownership
RUN chown -R appuser:appuser /app

# Drop privileges
USER appuser

# The worker is a background process — no port to expose
# HEALTHCHECK via process liveness (exit 0 = running)
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD pgrep -x Worker || exit 1

ENTRYPOINT ["dotnet", "Worker.dll"]
