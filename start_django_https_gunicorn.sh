#!/bin/bash

echo "🐍 Starting Django Backend with HTTPS (Gunicorn)"

# Install gunicorn if not present
if ! command -v gunicorn &> /dev/null; then
    echo "Installing gunicorn..."
    pip install gunicorn
fi

# Kill existing processes
pkill -f gunicorn 2>/dev/null || true
lsof -ti:8001 | xargs kill -9 2>/dev/null || true
sleep 2

echo "🚀 Starting Django with Gunicorn HTTPS..."

gunicorn livestream_service.wsgi:application \
    --bind 0.0.0.0:8001 \
    --certfile=localhost+3-key.pem \
    --keyfile=localhost+3-key.pem \
    --reload &

GUNICORN_PID=$!
echo "Gunicorn HTTPS PID: $GUNICORN_PID"
echo "$GUNICORN_PID" > django_gunicorn_https.pid

sleep 3

if lsof -Pi :8001 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "✅ Django HTTPS (Gunicorn) started on https://$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}'):8001"
else
    echo "❌ Django HTTPS (Gunicorn) failed to start"
fi

trap "kill $GUNICORN_PID 2>/dev/null; rm -f django_gunicorn_https.pid; exit" INT TERM
wait
