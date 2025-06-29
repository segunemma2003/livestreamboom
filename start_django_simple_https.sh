#!/bin/bash

echo "🐍 Starting Django with Simple HTTPS"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# Kill existing Django processes
echo "🧹 Cleaning up existing Django processes..."
pkill -f "manage.py" 2>/dev/null || true
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
lsof -ti:8001 | xargs kill -9 2>/dev/null || true
sleep 2

# Check if django-extensions is available
if python manage.py help | grep -q runserver_plus; then
    echo -e "${GREEN}✅ runserver_plus available\033[0m"
    echo -e "${BLUE}🚀 Starting Django with runserver_plus HTTPS on port 8001...${NC}"
    
    python manage.py runserver_plus 0.0.0.0:8001 \
        --cert-file localhost+3-key.pem \
        --key-file localhost+3-key.pem &
    DJANGO_PID=$!
    
else
    echo -e "${YELLOW}⚠️ runserver_plus not available, using gunicorn...\033[0m"
    
    # Install gunicorn if not present
    if ! command -v gunicorn &> /dev/null; then
        echo "Installing gunicorn..."
        pip install gunicorn
    fi
    
    echo -e "${BLUE}🚀 Starting Django with Gunicorn HTTPS on port 8001...${NC}"
    gunicorn livestream_service.wsgi:application \
        --bind 0.0.0.0:8001 \
        --certfile=localhost+3-key.pem \
        --keyfile=localhost+3-key.pem \
        --reload &
    DJANGO_PID=$!
fi

sleep 5

if lsof -Pi :8001 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Django HTTPS server started successfully!\033[0m"
    echo -e "${BLUE}📱 Access URLs:${NC}"
    echo "  • Local: https://localhost:8001"
    echo "  • Network: https://$MACHINE_IP:8001"
    echo "  • API Test: https://$MACHINE_IP:8001/api/v1/livestream/test-connection/"
    echo ""
    echo -e "${YELLOW}📋 Update your React app:${NC}"
    echo "  const [backendUrl] = useState('https://$MACHINE_IP:8001')"
    echo ""
    echo "Django HTTPS PID: $DJANGO_PID"
    echo "$DJANGO_PID" > django_https.pid
    
    # Cleanup function
    cleanup() {
        echo -e "\n🛑 Stopping Django HTTPS server..."
        kill $DJANGO_PID 2>/dev/null || true
        rm -f django_https.pid 2>/dev/null || true
        echo "✅ Django HTTPS server stopped"
        exit 0
    }
    
    trap cleanup INT TERM
    
    echo -e "\n${GREEN}💡 Press Ctrl+C to stop Django HTTPS server${NC}"
    wait
    
else
    echo -e "${RED}❌ Django HTTPS server failed to start${NC}"
    echo "Check for errors above and try again"
    exit 1
fi
