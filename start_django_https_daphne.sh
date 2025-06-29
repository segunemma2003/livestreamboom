#!/bin/bash

echo "🐍 Starting Django with HTTPS (Daphne ASGI)"

# Install daphne if not present
if ! command -v daphne &> /dev/null; then
    echo "Installing daphne..."
    pip install daphne
fi

# Kill existing processes
pkill -f daphne 2>/dev/null || true
lsof -ti:8001 | xargs kill -9 2>/dev/null || true
sleep 2

echo "🚀 Starting Django with Daphne HTTPS..."

daphne -b 0.0.0.0 -p 8001 \
    --ssl-keyfile localhost+3-key.pem \
    --ssl-certfile localhost+3-key.pem \
    livestream_service.asgi:application &

DAPHNE_PID=$!
echo "Daphne HTTPS PID: $DAPHNE_PID"
echo "$DAPHNE_PID" > django_daphne_https.pid

sleep 3

if lsof -Pi :8001 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "✅ Django HTTPS (Daphne) started on https://$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}'):8001"
else
    echo "❌ Django HTTPS (Daphne) failed to start"
fi

trap "kill $DAPHNE_PID 2>/dev/null; rm -f django_daphne_https.pid; exit" INT TERM
wait
