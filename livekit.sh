#!/bin/bash

echo "🔧 LiveKit 1.9.0 Specific WSS Setup"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

echo -e "${BLUE}📋 Step 1: Check LiveKit capabilities${NC}"
echo "LiveKit version: $(livekit-server --version 2>/dev/null || echo 'Could not determine version')"

echo -e "\n${BLUE}🔍 Available flags:${NC}"
livekit-server --help | grep -E "(cert|tls|ssl|key)" || echo "No TLS-related flags found"

echo -e "\n${BLUE}📋 Step 2: Check if LiveKit supports TLS config in YAML${NC}"

# Let's check what configuration options are available
livekit-server help-verbose 2>/dev/null | grep -E "(cert|tls|ssl)" || echo "No TLS options in verbose help"

echo -e "\n${YELLOW}⚠️ Analysis: Your LiveKit version may not support direct TLS/WSS${NC}"
echo "Let's create alternative solutions..."

echo -e "\n${BLUE}📋 Step 3: Create Nginx reverse proxy for WSS (Best option)${NC}"

# Check if nginx is available
if command -v nginx &> /dev/null; then
    echo -e "${GREEN}✅ Nginx found - creating reverse proxy setup${NC}"
    
    cat > start_livekit_with_nginx_wss.sh << 'EOF'
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
EOF

    chmod +x start_livekit_with_nginx_wss.sh
    echo -e "${GREEN}✅ Nginx WSS proxy script created${NC}"

else
    echo -e "${YELLOW}⚠️ Nginx not found. Installing...${NC}"
    if command -v brew &> /dev/null; then
        brew install nginx
    else
        echo -e "${RED}❌ Please install nginx: brew install nginx${NC}"
    fi
fi

echo -e "\n${BLUE}📋 Step 4: Create Stunnel alternative (if Nginx doesn't work)${NC}"

cat > start_livekit_with_stunnel.sh << 'EOF'
#!/bin/bash

echo "🔐 Starting LiveKit with Stunnel WSS Proxy"

# Check if stunnel is available
if ! command -v stunnel &> /dev/null; then
    echo "Installing stunnel..."
    brew install stunnel || {
        echo "❌ Please install stunnel: brew install stunnel"
        exit 1
    }
fi

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# Kill existing processes
pkill -f livekit-server 2>/dev/null || true
pkill -f stunnel 2>/dev/null || true
lsof -ti:7880 | xargs kill -9 2>/dev/null || true
lsof -ti:7443 | xargs kill -9 2>/dev/null || true
sleep 3

# Start LiveKit on HTTP
echo "🎥 Starting LiveKit on HTTP..."
livekit-server --dev --bind 127.0.0.1 --node-ip $MACHINE_IP > livekit-http.log 2>&1 &
LIVEKIT_PID=$!

sleep 5

# Create stunnel configuration
cat > stunnel.conf << 'STUNNEL_EOF'
[https]
accept = 7443
connect = 127.0.0.1:7880
cert = livekit-cert.pem
key = livekit-key.pem
STUNNEL_EOF

# Start stunnel
echo "🚀 Starting Stunnel SSL proxy..."
stunnel stunnel.conf &
STUNNEL_PID=$!

sleep 3

echo "✅ LiveKit + Stunnel WSS setup complete!"
echo "📱 WSS URL: wss://$MACHINE_IP:7443"

cleanup() {
    echo "🛑 Stopping services..."
    kill $LIVEKIT_PID $STUNNEL_PID 2>/dev/null || true
    exit 0
}

trap cleanup INT TERM
wait
EOF

chmod +x start_livekit_with_stunnel.sh

echo -e "\n${BLUE}📋 Step 5: Create simple HTTP solution (fallback)${NC}"

cat > use_http_with_chrome_flags.sh << 'EOF'
#!/bin/bash

echo "🌐 Using HTTP LiveKit with Chrome Security Bypass"

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

echo "This approach uses HTTP LiveKit + Chrome flags to bypass security"
echo "WSS URL in React: ws://$MACHINE_IP:7880 (not wss://)"
echo ""
echo "Chrome command:"
echo "/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \\"
echo "  --allow-running-insecure-content \\"
echo "  --disable-web-security \\"
echo "  --ignore-certificate-errors \\"
echo "  --unsafely-treat-insecure-origin-as-secure=\"https://$MACHINE_IP:3000\" \\"
echo "  https://$MACHINE_IP:3000"
EOF

chmod +x use_http_with_chrome_flags.sh

echo -e "\n${GREEN}🎉 LiveKit 1.9.0 WSS Solutions Created!${NC}"

echo -e "\n${BLUE}📋 Try these solutions in order:${NC}"
echo ""
echo -e "${YELLOW}Option 1: Nginx Reverse Proxy (Best)${NC}"
echo "  ./start_livekit_with_nginx_wss.sh"
echo "  React URL: wss://$MACHINE_IP:7443"
echo ""
echo -e "${YELLOW}Option 2: Stunnel SSL Proxy${NC}"
echo "  ./start_livekit_with_stunnel.sh"
echo "  React URL: wss://$MACHINE_IP:7443"
echo ""
echo -e "${YELLOW}Option 3: HTTP + Chrome Flags${NC}"
echo "  Start normal LiveKit: livekit-server --dev --bind 0.0.0.0"
echo "  Use Chrome flags for security bypass"
echo "  React URL: ws://$MACHINE_IP:7880 (not wss://)"

echo -e "\n${BLUE}📁 Files Created:${NC}"
echo "  • start_livekit_with_nginx_wss.sh (Nginx proxy method)"
echo "  • start_livekit_with_stunnel.sh (Stunnel proxy method)"
echo "  • use_http_with_chrome_flags.sh (HTTP fallback info)"

echo -e "\n${GREEN}💡 Try Option 1 (Nginx) first - it's most reliable for your LiveKit version!${NC}"