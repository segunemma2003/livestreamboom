#!/bin/bash
set -e

echo "=== Django Application Startup ==="
echo "Time: $(date)"
echo "Settings: $DJANGO_SETTINGS_MODULE"

# Function to wait for service
wait_for_service() {
    local host=$1
    local port=$2
    local service_name=$3
    local max_attempts=30
    local attempt=1
    
    echo "Waiting for $service_name at $host:$port..."
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            echo "$service_name is ready!"
            return 0
        fi
        
        echo "Attempt $attempt/$max_attempts: $service_name not ready, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "WARNING: $service_name may not be ready after $max_attempts attempts"
    return 1
}

# Wait for database if configured
if [ ! -z "$LIVESTREAM_DB_HOST" ] && [ ! -z "$LIVESTREAM_DB_PORT" ]; then
    wait_for_service "$LIVESTREAM_DB_HOST" "$LIVESTREAM_DB_PORT" "Database"
fi

# Wait for Redis if configured
if [ ! -z "$REDIS_URL" ]; then
    # Extract host and port from Redis URL
    REDIS_HOST=$(echo $REDIS_URL | sed -n 's|redis://\([^:]*\):\([0-9]*\)/.*|\1|p')
    REDIS_PORT=$(echo $REDIS_URL | sed -n 's|redis://\([^:]*\):\([0-9]*\)/.*|\2|p')
    
    if [ ! -z "$REDIS_HOST" ] && [ ! -z "$REDIS_PORT" ]; then
        wait_for_service "$REDIS_HOST" "$REDIS_PORT" "Redis"
    fi
fi

# Check Django configuration
echo "Checking Django configuration..."
python manage.py check --deploy

# Run database migrations
echo "Running database migrations..."
python manage.py migrate --noinput

# Collect static files (in case they weren't collected during build)
echo "Collecting static files..."
python manage.py collectstatic --noinput --clear || echo "Static file collection failed, continuing..."

# Test health endpoint before starting server
echo "Testing health check endpoint..."
python -c "
import django
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'livestream_project.settings_production')
django.setup()
from apps.core.views import health_check
from django.test import RequestFactory
factory = RequestFactory()
request = factory.get('/health/')
response = health_check(request)
print(f'Health check status: {response.status_code}')
if response.status_code != 200:
    print('WARNING: Health check failed during startup')
    print(response.content.decode())
"

echo "Starting gunicorn server..."
exec gunicorn \
    --bind 0.0.0.0:8000 \
    --workers 3 \
    --timeout 120 \
    --worker-connections 1000 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --access-logfile - \
    --error-logfile - \
    --log-level info \
    --capture-output \
    livestream_project.wsgi:application
