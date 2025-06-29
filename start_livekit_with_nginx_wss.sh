#!/bin/bash

echo "🔐 Starting LiveKit with Nginx WSS Proxy"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# Kill existing processes
echo "🧹 Stopping existing processes..."
pkill -f livekit-server 2>/dev/null || true
pkill -f nginx 2>/dev/null || true
lsof -ti:7880 | xargs kill -9 2>/dev/null || true
lsof -ti:7881 | xargs kill -9 2>/dev/null || true
sleep 3

# Start LiveKit on internal HTTP port
echo -e "${BLUE}🎥 Starting LiveKit on internal HTTP port 7881...${NC}"
livekit-server --dev --bind 127.0.0.1 --node-ip $MACHINE_IP > livekit-internal.log 2>&1 &
LIVEKIT_PID=$!

sleep 5

# Check if LiveKit started
if ! lsof -Pi :7880 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${RED}❌ LiveKit failed to start${NC}"
    cat livekit-internal.log
    exit 1
fi

echo -e "${GREEN}✅ LiveKit started on internal port${NC}"

# Create Nginx configuration
echo -e "${BLUE}📝 Creating Nginx WSS proxy configuration...${NC}"

cat > nginx-livekit.conf << 'NGINX_EOF'
worker_processes 1;
error_log nginx-error.log;
pid nginx.pid;

events {
    worker_connections 1024;
}

http {
    access_log nginx-access.log;
    
    # Upstream to LiveKit HTTP server
    upstream livekit_backend {
        server 127.0.0.1:7880;
    }

    # HTTPS server that proxies to LiveKit
    server {
        listen 7443 ssl;
        server_name localhost;

        # SSL configuration
        ssl_certificate livekit-cert.pem;
        ssl_certificate_key livekit-key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;

        # Proxy all requests to LiveKit
        location / {
            proxy_pass http://livekit_backend;
            proxy_http_version 1.1;
            
            # WebSocket upgrade headers
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            
            # Standard proxy headers
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeout settings for WebSocket
            proxy_read_timeout 86400;
            proxy_send_timeout 86400;
        }
    }
}
NGINX_EOF

# Start Nginx
echo -e "${BLUE}🚀 Starting Nginx WSS proxy...${NC}"
nginx -c "$(pwd)/nginx-livekit.conf" -p "$(pwd)" &
NGINX_PID=$!

sleep 3

# Check if Nginx started
if lsof -Pi :7443 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Nginx WSS proxy started successfully!${NC}"
    echo -e "${BLUE}📱 WSS Access URLs:${NC}"
    echo "  • WSS URL: wss://$MACHINE_IP:7443"
    echo "  • HTTPS URL: https://$MACHINE_IP:7443"
    echo ""
    echo -e "${YELLOW}📋 Update your React App.tsx:${NC}"
    echo "  const [serverUrl] = useState('wss://$MACHINE_IP:7443')"
    
else
    echo -e "${RED}❌ Nginx failed to start${NC}"
    echo "Check nginx-error.log for details"
    kill $LIVEKIT_PID 2>/dev/null || true
    exit 1
fi

# Store PIDs
echo "$LIVEKIT_PID" > livekit.pid
echo "$NGINX_PID" > nginx.pid

# Cleanup function
cleanup() {
    echo -e "\n🛑 Stopping LiveKit + Nginx WSS proxy..."
    kill $LIVEKIT_PID $NGINX_PID 2>/dev/null || true
    nginx -s stop -c "$(pwd)/nginx-livekit.conf" -p "$(pwd)" 2>/dev/null || true
    rm -f livekit.pid nginx.pid nginx-*.log nginx.pid 2>/dev/null || true
    echo "✅ Services stopped"
    exit 0
}

trap cleanup INT TERM

echo -e "\n${GREEN}💡 LiveKit + Nginx WSS proxy running. Press Ctrl+C to stop.${NC}"
echo -e "${BLUE}📝 Logs:${NC}"
echo "  • LiveKit: tail -f livekit-internal.log"
echo "  • Nginx: tail -f nginx-error.log"

wait
