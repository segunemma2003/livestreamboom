#!/bin/bash

echo "🔐 Starting LiveKit with Nginx Reverse Proxy for WSS"

# Check if nginx is available
if ! command -v nginx &> /dev/null; then
    echo "❌ Nginx not found. Install with: brew install nginx"
    echo "Or try the direct TLS methods instead."
    exit 1
fi

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# Start LiveKit on HTTP (no TLS)
echo "🎥 Starting LiveKit on HTTP..."
pkill -f livekit-server 2>/dev/null || true
livekit-server --dev --bind 127.0.0.1 --port 7881 > livekit-http.log 2>&1 &
LIVEKIT_PID=$!

sleep 3

# Create nginx config for WSS proxy
cat > nginx-livekit-wss.conf << 'NGINX_EOF'
events {
    worker_connections 1024;
}

http {
    upstream livekit {
        server 127.0.0.1:7881;
    }

    server {
        listen 7880 ssl;
        server_name localhost;

        ssl_certificate livekit-cert.pem;
        ssl_certificate_key livekit-key.pem;

        location / {
            proxy_pass http://livekit;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
NGINX_EOF

# Start nginx
nginx -c "$(pwd)/nginx-livekit-wss.conf" -p . &
NGINX_PID=$!

echo "✅ LiveKit + Nginx WSS proxy started"
echo "📱 WSS URL: wss://$MACHINE_IP:7880"

cleanup() {
    echo "🛑 Stopping services..."
    kill $LIVEKIT_PID $NGINX_PID 2>/dev/null || true
    nginx -s stop -c "$(pwd)/nginx-livekit-wss.conf" -p . 2>/dev/null || true
    exit 0
}

trap cleanup INT TERM
wait
