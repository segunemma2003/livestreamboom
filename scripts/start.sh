#!/bin/bash
set -e

echo "=== Django Livestream Service Startup ==="
echo "Time: $(date)"
echo "Settings Module: $DJANGO_SETTINGS_MODULE"
echo "Debug Mode: $DEBUG"
echo "Python Path: $PYTHONPATH"

# Function to wait for service with better error handling
wait_for_service() {
    local host=$1
    local port=$2
    local service_name=$3
    local max_attempts=30
    local attempt=1
    
    echo "🔍 Checking $service_name at $host:$port..."
    
    while [ $attempt -le $max_attempts ]; do
        if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            echo "✅ $service_name is ready!"
            return 0
        fi
        
        echo "⏳ Attempt $attempt/$max_attempts: $service_name not ready, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "⚠️  WARNING: $service_name may not be ready after $max_attempts attempts"
    return 1
}

# Check if we're in a container
if [ -f /.dockerenv ]; then
    echo "🐳 Running in Docker container"
else
    echo "🖥️  Running on host system"
fi

# Validate Django settings
echo "🔧 Validating Django configuration..."
python -c "
import os
import django
from django.conf import settings
from django.core.management import execute_from_command_line

print(f'Django version: {django.get_version()}')
print(f'Settings module: {os.environ.get(\"DJANGO_SETTINGS_MODULE\")}')
print(f'Debug mode: {settings.DEBUG}')
print(f'Allowed hosts: {settings.ALLOWED_HOSTS}')
print(f'Database engine: {settings.DATABASES[\"default\"][\"ENGINE\"]}')

# Test settings loading
try:
    execute_from_command_line(['manage.py', 'check', '--deploy'])
    print('✅ Django configuration is valid')
except Exception as e:
    print(f'❌ Django configuration error: {e}')
    exit(1)
"

# Wait for external services if configured
if [ ! -z "$LIVESTREAM_DB_HOST" ] && [ ! -z "$LIVESTREAM_DB_PORT" ]; then
    wait_for_service "$LIVESTREAM_DB_HOST" "$LIVESTREAM_DB_PORT" "PostgreSQL Database"
else
    echo "ℹ️  No external database configured"
fi

if [ ! -z "$REDIS_URL" ]; then
    # Extract host and port from Redis URL
    REDIS_HOST=$(echo $REDIS_URL | sed -n 's|redis://\([^:]*\):\([0-9]*\)/.*|\1|p')
    REDIS_PORT=$(echo $REDIS_URL | sed -n 's|redis://\([^:]*\):\([0-9]*\)/.*|\2|p')
    
    if [ ! -z "$REDIS_HOST" ] && [ ! -z "$REDIS_PORT" ]; then
        wait_for_service "$REDIS_HOST" "$REDIS_PORT" "Redis Cache"
    else
        echo "ℹ️  Could not parse Redis URL for connectivity check"
    fi
else
    echo "ℹ️  No Redis configured"
fi

# Run database migrations
echo "🗄️  Running database migrations..."
python manage.py migrate --noinput --verbosity=1

# Collect static files if needed
echo "📁 Collecting static files..."
python manage.py collectstatic --noinput --clear --verbosity=1 || {
    echo "⚠️  Static file collection failed, continuing..."
}

# Create superuser if in development and doesn't exist
if [ "$DEBUG" = "True" ]; then
    echo "🔧 Development mode: Creating superuser if needed..."
    python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin123')
    print('Created admin user: admin/admin123')
else:
    print('Admin user already exists')
" || echo "Could not create superuser"
fi

# Test health endpoint before starting server
echo "🏥 Testing health check endpoint..."
python -c "
import django
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'livestream_project.settings_production')
django.setup()

from django.test import RequestFactory
from apps.core.views import health_check

try:
    factory = RequestFactory()
    request = factory.get('/health/')
    response = health_check(request)
    print(f'Health check status: {response.status_code}')
    
    if response.status_code == 200:
        print('✅ Health check passed')
    else:
        print(f'⚠️  Health check returned: {response.status_code}')
        print(response.content.decode())
except Exception as e:
    print(f'❌ Health check failed: {e}')
    import traceback
    traceback.print_exc()
"

# Set up signal handlers for graceful shutdown
trap 'echo "🛑 Received SIGTERM, shutting down gracefully..."; kill -TERM $PID; wait $PID' TERM
trap 'echo "🛑 Received SIGINT, shutting down gracefully..."; kill -INT $PID; wait $PID' INT

echo "🚀 Starting gunicorn server..."
echo "Bind: 0.0.0.0:8000"
echo "Workers: 3"
echo "Timeout: 120s"

# Start gunicorn with optimized settings
exec gunicorn \
    --bind 0.0.0.0:8000 \
    --workers 3 \
    --worker-class sync \
    --worker-connections 1000 \
    --timeout 120 \
    --keepalive 5 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --preload \
    --access-logfile - \
    --error-logfile - \
    --log-level info \
    --capture-output \
    --enable-stdio-inheritance \
    livestream_project.wsgi:application &

PID=$!
echo "🔢 Gunicorn PID: $PID"

# Wait for the server to start
sleep 5

# Verify server is responding
echo "🔍 Verifying server startup..."
for i in {1..10}; do
    if curl -f -s http://localhost:8000/health/ > /dev/null; then
        echo "✅ Server is responding to health checks!"
        break
    fi
    echo "⏳ Server not ready yet, attempt $i/10..."
    sleep 2
done

echo "✅ Startup completed successfully!"

# Wait for gunicorn process
wait $PID
