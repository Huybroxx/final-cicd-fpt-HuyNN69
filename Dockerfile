# ==============================================================================
# Multi-Stage Production Dockerfile for FastAPI Application
# Stage 1: Build & Dependency Resolution (builder)
# Stage 2: Minimal, Secure Runtime Image (runner)
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Builder
# ------------------------------------------------------------------------------
FROM python:3.11-slim AS builder

WORKDIR /build

# Configure python & pip for clean, isolated build
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install build dependencies if needed (e.g. gcc, libpq-dev)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment for portable dependency copying
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install application dependencies into isolated venv
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt


# ------------------------------------------------------------------------------
# Stage 2: Final Runtime
# ------------------------------------------------------------------------------
FROM python:3.11-slim AS runner

WORKDIR /app

# Set production environment flags
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PORT=8000 \
    HOST=0.0.0.0

# Install lightweight runtime utility (curl) for container HEALTHCHECK
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy pre-built virtual environment from builder stage (zero compiler residue)
COPY --from=builder /opt/venv /opt/venv

# Create dedicated non-root system group and user with fixed UID/GID
RUN groupadd --system --gid 10001 appgroup && \
    useradd --system --uid 10001 --gid 10001 --no-create-home --shell /sbin/nologin appuser

# Copy application source code with proper ownership
COPY --chown=appuser:appgroup ./app /app/app

# Drop root privileges and switch to non-root user
USER appuser:appgroup

# Expose application port
EXPOSE 8000

# Built-in container health check probe
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Launch production ASGI server
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
