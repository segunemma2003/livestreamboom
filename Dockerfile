# Use Python 3.11 slim image
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=livestream_project.settings_production
ENV PYTHONPATH=/app

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    postgresql-client \
    build-essential \
    libpq-dev \
    ffmpeg \
    git \
    curl \
    netcat-traditional \
    procps \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create directories early
RUN mkdir -p /app/media /app/static /app/logs /var/recordings /app/scripts

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies with better error handling
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy startup script first
COPY scripts/start.sh /app/scripts/start.sh
RUN chmod +x /app/scripts/start.sh

# Copy project files
COPY . .

# Set proper permissions for directories
RUN chmod -R 755 /app/scripts

# Try to collect static files, but don't fail if it doesn't work
RUN python manage.py collectstatic --noinput --settings=livestream_project.settings_production || {
    echo "Static collection failed during build, will retry at runtime"
    mkdir -p /app/staticfiles
}

# Create a non-root user and set permissions
RUN adduser --disabled-password --gecos '' appuser \
    && chown -R appuser:appuser /app /var/recordings

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8000

# Enhanced health check with multiple endpoints
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health/simple/ || \
        curl -f http://localhost:8000/health/ || \
        curl -f http://localhost:8000/ || \
        exit 1

# Use the startup script
CMD ["/app/scripts/start.sh"]
