# Build stage
FROM python:3.10-slim as builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install poetry
RUN pip install --no-cache-dir poetry==1.5.1

# Copy only requirements to cache them in docker layer
COPY pyproject.toml poetry.lock* ./

RUN poetry config virtualenvs.in-project true \
    && poetry install --no-interaction --no-ansi --no-root --only main

# Runtime stage
FROM python:3.10-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python dependencies from builder
COPY --from=builder /app/.venv .venv
ENV PATH="/app/.venv/bin:$PATH"

# Copy application code
COPY . .

# Create non-root user
RUN groupadd -r mcp && useradd -r -g mcp mcp \
    && chown -R mcp:mcp /app

# Create necessary directories
RUN mkdir -p /data /app/logs \
    && chown -R mcp:mcp /data /app/logs

# Switch to non-root user
USER mcp

# Expose ports
EXPOSE 8000-8003

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Start the server
CMD ["./start_server.sh"]
