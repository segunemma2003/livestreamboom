#!/bin/bash

echo "🐍 Starting Django Backend with SSL (Gunicorn)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# Kill existing backend processes
echo "🧹 Cleaning up existing Django processes..."
pkill -f gunicorn 2>/dev/null || true
pkill -f "manage.py runserver" 2>/dev/null || true
lsof -ti:8443 | xargs kill -9 2>/dev/null || true
sleep 2

# Verify backend certificates exist
if [[ ! -f "backend-cert.pem" || ! -f "backend-key.pem" ]]; then
    echo -e "${RED}❌ Backend SSL certificates not found${NC}"
    echo "Run the backend SSL setup script first"
    exit 1
fi

echo -e "${BLUE}🚀 Starting Django with Gunicorn HTTPS on port 8443...${NC}"

# Start Django with Gunicorn SSL
gunicorn livestream_service.wsgi:application \
    --bind 0.0.0.0:8443 \
    --certfile=backend-cert.pem \
    --keyfile=backend-key.pem \
    --worker-class=gevent \
    --worker-connections=1000 \
    --workers=1 \
    --reload \
    --access-logfile=- \
    --error-logfile=- &

DJANGO_PID=$!

sleep 5

if lsof -Pi :8443 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Django HTTPS backend started successfully!${NC}"
    echo -e "${BLUE}📱 Backend Access URLs:${NC}"
    echo "  • Local: https://localhost:8443"
    echo "  • Network: https://$MACHINE_IP:8443"
    echo "  • API Test: https://$MACHINE_IP:8443/api/v1/livestream/test-connection/"
    echo ""
    echo -e "${YELLOW}📋 Backend SSL Notes:${NC}"
    echo "  • Django HTTPS running on port 8443"
    echo "  • HTTP version still available on port 8000 (if running)"
    echo "  • CORS configured for both HTTP and HTTPS frontends"
    echo ""
    echo "Django HTTPS PID: $DJANGO_PID"
    echo "$DJANGO_PID" > django_backend_ssl.pid
    
    # Test SSL API
    echo -e "${BLUE}🧪 Testing backend SSL API...${NC}"
    if curl -k -s "https://localhost:8443/api/v1/livestream/test-connection/" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Backend HTTPS API responding${NC}"
    else
        echo -e "${YELLOW}⚠️ API test failed, but server is running${NC}"
    fi
    
    cleanup() {
        echo -e "\n🛑 Stopping Django HTTPS backend..."
        kill $DJANGO_PID 2>/dev/null || true
        rm -f django_backend_ssl.pid 2>/dev/null || true
        echo "✅ Django backend stopped"
        exit 0
    }
    
    trap cleanup INT TERM
    
    echo -e "\n${GREEN}💡 Press Ctrl+C to stop Django HTTPS backend${NC}"
    wait
    
else
    echo -e "${RED}❌ Django HTTPS backend failed to start${NC}"
    echo -e "${YELLOW}📋 Check the error output above${NC}"
    kill $DJANGO_PID 2>/dev/null || true
    exit 1
fi
